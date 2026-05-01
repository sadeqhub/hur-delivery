import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { supabaseAdmin } from '../lib/supabase-admin';

interface MerchantSetting {
  id: string;
  merchant_id: string;
  merchant_wallet_enabled: boolean | null;
  merchant_commission_type: 'fixed' | 'percentage_order_fee' | 'percentage_delivery_fee' | null;
  merchant_commission_value: number | null;
  updated_at: string;
}

interface Merchant {
  id: string;
  name: string;
  phone: string;
  city: string | null;
  store_name: string | null;
}

interface CitySetting {
  merchant_wallet_enabled: boolean;
  merchant_commission_type: 'fixed' | 'percentage_order_fee' | 'percentage_delivery_fee';
  merchant_commission_value: number;
}

export default function MerchantSettings() {
  const { merchantId } = useParams<{ merchantId: string }>();
  const navigate = useNavigate();
  const [merchant, setMerchant] = useState<Merchant | null>(null);
  const [setting, setSetting] = useState<MerchantSetting | null>(null);
  const [citySetting, setCitySetting] = useState<CitySetting | null>(null);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState(false);
  const [editData, setEditData] = useState<Partial<MerchantSetting>>({});
  const [useCityDefaults, setUseCityDefaults] = useState(false);

  useEffect(() => {
    if (merchantId) {
      loadData();
    }
  }, [merchantId]);

  const loadData = async () => {
    if (!merchantId) return;
    
    setLoading(true);
    try {
      // Load merchant info
      const { data: merchantData, error: merchantError } = await supabaseAdmin
        .from('users')
        .select('id, name, phone, city, store_name')
        .eq('id', merchantId)
        .eq('role', 'merchant')
        .single();

      if (merchantError) throw merchantError;
      setMerchant(merchantData);

      // Load merchant settings
      const { data: settingData, error: settingError } = await supabaseAdmin
        .from('merchant_settings')
        .select('*')
        .eq('merchant_id', merchantId)
        .maybeSingle();

      if (settingError && settingError.code !== 'PGRST116') throw settingError;
      
      if (settingData) {
        setSetting(settingData);
        setUseCityDefaults(false);
      } else {
        setSetting(null);
        setUseCityDefaults(true);
      }

      // Load city settings if merchant has a city
      if (merchantData?.city) {
        const { data: cityData, error: cityError } = await supabaseAdmin
          .from('city_settings')
          .select('merchant_wallet_enabled, merchant_commission_type, merchant_commission_value')
          .eq('city', merchantData.city)
          .single();

        if (cityError && cityError.code !== 'PGRST116') {
          console.error('Error loading city settings:', cityError);
        } else if (cityData) {
          setCitySetting(cityData);
        }
      }
    } catch (error: any) {
      console.error('Error loading data:', error);
      alert(error.message || 'فشل تحميل البيانات / Failed to load data');
    } finally {
      setLoading(false);
    }
  };

  const startEdit = () => {
    if (setting) {
      setEditData({
        merchant_wallet_enabled: setting.merchant_wallet_enabled,
        merchant_commission_type: setting.merchant_commission_type,
        merchant_commission_value: setting.merchant_commission_value,
      });
    } else {
      // Initialize from city settings or defaults
      setEditData({
        merchant_wallet_enabled: citySetting?.merchant_wallet_enabled ?? true,
        merchant_commission_type: citySetting?.merchant_commission_type ?? 'fixed',
        merchant_commission_value: citySetting?.merchant_commission_value ?? 500.00,
      });
    }
    setEditing(true);
  };

  const cancelEdit = () => {
    setEditing(false);
    setEditData({});
  };

  const saveSettings = async () => {
    if (!merchantId) return;

    try {
      if (useCityDefaults) {
        // Delete merchant settings to use city defaults
        const { error } = await supabaseAdmin
          .from('merchant_settings')
          .delete()
          .eq('merchant_id', merchantId);

        if (error) throw error;
        alert('تم حذف الإعدادات المخصصة. سيتم استخدام إعدادات المدينة / Custom settings deleted. City settings will be used');
      } else {
        // Upsert merchant settings
        const updateData: any = {
          merchant_id: merchantId,
          merchant_wallet_enabled: editData.merchant_wallet_enabled ?? null,
          merchant_commission_type: editData.merchant_commission_type ?? null,
          merchant_commission_value: editData.merchant_commission_value ?? null,
          updated_at: new Date().toISOString(),
        };

        const { error } = await supabaseAdmin
          .from('merchant_settings')
          .upsert(updateData, { onConflict: 'merchant_id' });

        if (error) throw error;
        alert('تم حفظ الإعدادات بنجاح / Settings saved successfully');
      }

      setEditing(false);
      setEditData({});
      loadData();
    } catch (error: any) {
      console.error('Error saving settings:', error);
      alert(error.message || 'فشل حفظ الإعدادات / Failed to save settings');
    }
  };

  const getCityName = (city: string | null) => {
    if (!city) return 'غير محدد / Not specified';
    return city === 'najaf' ? 'النجف / Najaf' : city === 'mosul' ? 'الموصل / Mosul' : city;
  };

  const getDisplayValue = (key: keyof MerchantSetting, defaultValue: any) => {
    if (useCityDefaults) {
      return citySetting ? (citySetting as any)[key] : defaultValue;
    }
    if (setting && setting[key] !== null) {
      return setting[key];
    }
    return citySetting ? (citySetting as any)[key] : defaultValue;
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-500"></div>
      </div>
    );
  }

  if (!merchant) {
    return (
      <div className="bg-white rounded-xl shadow-sm p-12 text-center text-gray-500">
        <i className="fas fa-store text-4xl mb-2"></i>
        <p>التاجر غير موجود / Merchant not found</p>
        <button
          onClick={() => navigate('/merchants')}
          className="mt-4 px-4 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg"
        >
          العودة إلى التجار / Back to Merchants
        </button>
      </div>
    );
  }

  const currentWalletEnabled = getDisplayValue('merchant_wallet_enabled', true);
  const currentCommissionType = getDisplayValue('merchant_commission_type', 'fixed');
  const currentCommissionValue = getDisplayValue('merchant_commission_value', 500.00);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <button
            onClick={() => navigate('/merchants')}
            className="mb-4 text-blue-500 hover:text-blue-600 flex items-center gap-2"
          >
            <i className="fas fa-arrow-right"></i>
            العودة إلى التجار / Back to Merchants
          </button>
          <h2 className="text-2xl font-bold text-gray-900">إعدادات التاجر / Merchant Settings</h2>
          <p className="text-gray-600 text-sm mt-1">
            إدارة إعدادات العمولات والمحفظة للتاجر / Manage commission and wallet settings for merchant
          </p>
        </div>
      </div>

      {/* Merchant Info Card */}
      <div className="bg-white rounded-xl shadow-sm p-6">
        <div className="flex items-center gap-4">
          <div className="w-16 h-16 bg-purple-100 rounded-full flex items-center justify-center">
            <i className="fas fa-store text-purple-600 text-2xl"></i>
          </div>
          <div>
            <h3 className="text-xl font-bold text-gray-900">{merchant.name}</h3>
            <p className="text-gray-600">{merchant.phone}</p>
            {merchant.store_name && (
              <p className="text-sm text-gray-500">{merchant.store_name}</p>
            )}
            <span className="inline-flex items-center gap-1 px-2 py-1 bg-blue-100 text-blue-800 text-xs rounded mt-2">
              {getCityName(merchant.city)}
            </span>
          </div>
        </div>
      </div>

      {/* Settings Card */}
      <div className="bg-white rounded-xl shadow-sm overflow-hidden">
        <div className="p-6 border-b border-gray-200 bg-gradient-to-r from-purple-50 to-indigo-50">
          <div className="flex items-center justify-between">
            <h3 className="text-xl font-bold text-gray-900">الإعدادات المخصصة / Custom Settings</h3>
            {!useCityDefaults && setting && (
              <span className="px-3 py-1 bg-green-100 text-green-800 rounded-full text-sm font-medium">
                إعدادات مخصصة / Custom Settings Active
              </span>
            )}
            {useCityDefaults && (
              <span className="px-3 py-1 bg-blue-100 text-blue-800 rounded-full text-sm font-medium">
                استخدام إعدادات المدينة / Using City Settings
              </span>
            )}
          </div>
        </div>

        <div className="p-6 space-y-6">
          {/* Use City Defaults Toggle */}
          <div className="border-b border-gray-200 pb-4">
            <div className="flex items-center justify-between">
              <label className="text-sm font-medium text-gray-700">
                استخدام إعدادات المدينة الافتراضية / Use City Default Settings
              </label>
              {editing ? (
                <input
                  type="checkbox"
                  checked={useCityDefaults}
                  onChange={(e) => {
                    setUseCityDefaults(e.target.checked);
                    if (e.target.checked) {
                      setEditData({});
                    }
                  }}
                  className="w-5 h-5 text-primary-600 rounded focus:ring-primary-500"
                />
              ) : (
                <span
                  className={`px-3 py-1 rounded-full text-sm font-medium ${
                    useCityDefaults
                      ? 'bg-blue-100 text-blue-800'
                      : 'bg-purple-100 text-purple-800'
                  }`}
                >
                  {useCityDefaults ? 'نعم / Yes' : 'لا / No'}
                </span>
              )}
            </div>
            {useCityDefaults && citySetting && (
              <p className="text-xs text-gray-500 mt-2">
                سيتم استخدام إعدادات مدينة {getCityName(merchant.city)} / Will use settings from {getCityName(merchant.city)}
              </p>
            )}
          </div>

          {/* Merchant Wallet Settings */}
          <div className="border-b border-gray-200 pb-6">
            <h4 className="text-lg font-semibold text-gray-900 mb-4">
              إعدادات محفظة التاجر / Merchant Wallet Settings
            </h4>

            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <label className="text-sm font-medium text-gray-700">
                  تفعيل محفظة التاجر / Enable Merchant Wallet
                </label>
                {editing && !useCityDefaults ? (
                  <input
                    type="checkbox"
                    checked={editData.merchant_wallet_enabled ?? currentWalletEnabled}
                    onChange={(e) =>
                      setEditData({ ...editData, merchant_wallet_enabled: e.target.checked })
                    }
                    className="w-5 h-5 text-primary-600 rounded focus:ring-primary-500"
                  />
                ) : (
                  <span
                    className={`px-3 py-1 rounded-full text-sm font-medium ${
                      currentWalletEnabled
                        ? 'bg-green-100 text-green-800'
                        : 'bg-red-100 text-red-800'
                    }`}
                  >
                    {currentWalletEnabled ? 'مفعل / Enabled' : 'معطل / Disabled'}
                    {useCityDefaults && ' (من المدينة)'}
                  </span>
                )}
              </div>
            </div>
          </div>

          {/* Merchant Commission Settings */}
          <div>
            <h4 className="text-lg font-semibold text-gray-900 mb-4">
              إعدادات عمولة التاجر / Merchant Commission Settings
            </h4>

            <div className="space-y-4">
              {editing && !useCityDefaults ? (
                <>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      نوع عمولة التاجر / Merchant Commission Type
                    </label>
                    <select
                      value={editData.merchant_commission_type ?? currentCommissionType}
                      onChange={(e) =>
                        setEditData({
                          ...editData,
                          merchant_commission_type: e.target.value as
                            | 'fixed'
                            | 'percentage_order_fee'
                            | 'percentage_delivery_fee',
                        })
                      }
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                    >
                      <option value="fixed">مبلغ ثابت / Fixed Amount</option>
                      <option value="percentage_order_fee">
                        نسبة من قيمة الطلب / Percentage of Order Fee
                      </option>
                      <option value="percentage_delivery_fee">
                        نسبة من رسوم التوصيل / Percentage of Delivery Fee
                      </option>
                    </select>
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      {editData.merchant_commission_type === 'fixed'
                        ? 'المبلغ الثابت (IQD) / Fixed Amount (IQD)'
                        : 'النسبة المئوية (%) / Percentage (%)'}
                    </label>
                    <input
                      type="number"
                      step="0.01"
                      value={editData.merchant_commission_value ?? currentCommissionValue}
                      onChange={(e) =>
                        setEditData({
                          ...editData,
                          merchant_commission_value: parseFloat(e.target.value) || 0,
                        })
                      }
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                      placeholder="0.00"
                    />
                  </div>
                </>
              ) : (
                <>
                  <div className="flex justify-between">
                    <span className="text-sm text-gray-600">النوع / Type:</span>
                    <span className="font-medium">
                      {currentCommissionType === 'fixed'
                        ? 'مبلغ ثابت / Fixed'
                        : currentCommissionType === 'percentage_order_fee'
                        ? 'نسبة من قيمة الطلب / % of Order'
                        : 'نسبة من رسوم التوصيل / % of Delivery Fee'}
                      {useCityDefaults && ' (من المدينة)'}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm text-gray-600">القيمة / Value:</span>
                    <span className="font-medium">
                      {currentCommissionValue} {currentCommissionType === 'fixed' ? 'IQD' : '%'}
                    </span>
                  </div>
                </>
              )}
            </div>
          </div>

          {/* Action Buttons */}
          <div className="flex items-center justify-end gap-3 pt-4 border-t border-gray-200">
            {editing ? (
              <>
                <button
                  onClick={cancelEdit}
                  className="px-4 py-2 bg-gray-500 hover:bg-gray-600 text-white rounded-lg text-sm font-medium"
                >
                  إلغاء / Cancel
                </button>
                <button
                  onClick={saveSettings}
                  className="px-4 py-2 bg-green-500 hover:bg-green-600 text-white rounded-lg text-sm font-medium"
                >
                  حفظ / Save
                </button>
              </>
            ) : (
              <button
                onClick={startEdit}
                className="px-4 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg text-sm font-medium"
              >
                تعديل / Edit
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

