import { useEffect, useState } from 'react';
import { supabaseAdmin } from '../lib/supabase-admin';

interface CitySetting {
  id: string;
  city: 'najaf' | 'mosul';
  driver_wallet_enabled: boolean;
  driver_commission_type: 'fixed' | 'percentage_delivery_fee';
  driver_commission_value: number | null;
  driver_commission_by_rank: {
    trial?: number;
    bronze?: number;
    silver?: number;
    gold?: number;
  };
  merchant_wallet_enabled: boolean;
  merchant_commission_type: 'fixed' | 'percentage_order_fee' | 'percentage_delivery_fee';
  merchant_commission_value: number;
  updated_at: string;
}

export default function CitySettings() {
  const [settings, setSettings] = useState<CitySetting[]>([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState<string | null>(null);
  const [editData, setEditData] = useState<Partial<CitySetting>>({});

  useEffect(() => {
    loadSettings();
  }, []);

  const loadSettings = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabaseAdmin
        .from('city_settings')
        .select('*')
        .order('city');

      if (error) throw error;
      setSettings(data || []);
    } catch (error) {
      console.error('Error loading city settings:', error);
      alert('فشل تحميل إعدادات المدن / Failed to load city settings');
    } finally {
      setLoading(false);
    }
  };

  const startEdit = (setting: CitySetting) => {
    setEditing(setting.city);
    setEditData({
      driver_wallet_enabled: setting.driver_wallet_enabled,
      driver_commission_type: setting.driver_commission_type,
      driver_commission_value: setting.driver_commission_value,
      driver_commission_by_rank: { ...setting.driver_commission_by_rank },
      merchant_wallet_enabled: setting.merchant_wallet_enabled,
      merchant_commission_type: setting.merchant_commission_type,
      merchant_commission_value: setting.merchant_commission_value,
    });
  };

  const cancelEdit = () => {
    setEditing(null);
    setEditData({});
  };

  const updateSetting = async (city: string) => {
    try {
      const updateData: any = {
        driver_wallet_enabled: editData.driver_wallet_enabled,
        driver_commission_type: editData.driver_commission_type,
        driver_commission_value: editData.driver_commission_value,
        driver_commission_by_rank: editData.driver_commission_by_rank,
        merchant_wallet_enabled: editData.merchant_wallet_enabled,
        merchant_commission_type: editData.merchant_commission_type,
        merchant_commission_value: editData.merchant_commission_value,
        updated_at: new Date().toISOString(),
      };

      const { error } = await supabaseAdmin
        .from('city_settings')
        .update(updateData)
        .eq('city', city);

      if (error) throw error;

      alert('تم تحديث الإعدادات بنجاح / Settings updated successfully');
      setEditing(null);
      setEditData({});
      loadSettings();
    } catch (error: any) {
      console.error('Error updating city setting:', error);
      alert(error.message || 'فشل التحديث / Update failed');
    }
  };

  const getCityName = (city: string) => {
    return city === 'najaf' ? 'النجف / Najaf' : 'الموصل / Mosul';
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-500"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-gray-900">إعدادات المدن / City Settings</h2>
        <p className="text-gray-600 text-sm mt-1">
          إدارة إعدادات العمولات والمحافظ لكل مدينة / Manage commission and wallet settings per city
        </p>
      </div>

      {settings.map((setting) => (
        <div key={setting.city} className="bg-white rounded-xl shadow-sm overflow-hidden">
          <div className="p-6 border-b border-gray-200 bg-gradient-to-r from-blue-50 to-indigo-50">
            <h3 className="text-xl font-bold text-gray-900">
              {getCityName(setting.city)}
            </h3>
          </div>

          <div className="p-6 space-y-6">
            {/* Driver Wallet Settings */}
            <div className="border-b border-gray-200 pb-6">
              <h4 className="text-lg font-semibold text-gray-900 mb-4">
                إعدادات محفظة السائقين / Driver Wallet Settings
              </h4>

              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <label className="text-sm font-medium text-gray-700">
                    تفعيل محفظة السائقين / Enable Driver Wallet
                  </label>
                  {editing === setting.city ? (
                    <input
                      type="checkbox"
                      checked={editData.driver_wallet_enabled ?? setting.driver_wallet_enabled}
                      onChange={(e) =>
                        setEditData({ ...editData, driver_wallet_enabled: e.target.checked })
                      }
                      className="w-5 h-5 text-primary-600 rounded focus:ring-primary-500"
                    />
                  ) : (
                    <span
                      className={`px-3 py-1 rounded-full text-sm font-medium ${
                        setting.driver_wallet_enabled
                          ? 'bg-green-100 text-green-800'
                          : 'bg-red-100 text-red-800'
                      }`}
                    >
                      {setting.driver_wallet_enabled ? 'مفعل / Enabled' : 'معطل / Disabled'}
                    </span>
                  )}
                </div>

                {editing === setting.city && (
                  <>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">
                        نوع عمولة السائقين / Driver Commission Type
                      </label>
                      <select
                        value={editData.driver_commission_type ?? setting.driver_commission_type}
                        onChange={(e) =>
                          setEditData({
                            ...editData,
                            driver_commission_type: e.target.value as 'fixed' | 'percentage_delivery_fee',
                          })
                        }
                        className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                      >
                        <option value="percentage_delivery_fee">
                          نسبة من رسوم التوصيل / Percentage of Delivery Fee
                        </option>
                        <option value="fixed">مبلغ ثابت / Fixed Amount</option>
                      </select>
                    </div>

                    {editData.driver_commission_type === 'fixed' ? (
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-2">
                          المبلغ الثابت (IQD) / Fixed Amount (IQD)
                        </label>
                        <input
                          type="number"
                          step="0.01"
                          value={editData.driver_commission_value ?? setting.driver_commission_value ?? ''}
                          onChange={(e) =>
                            setEditData({
                              ...editData,
                              driver_commission_value: parseFloat(e.target.value) || null,
                            })
                          }
                          className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                          placeholder="0.00"
                        />
                      </div>
                    ) : (
                      <div className="space-y-3">
                        <label className="block text-sm font-medium text-gray-700">
                          النسبة المئوية حسب الرتبة (%) / Percentage by Rank (%)
                        </label>
                        {['trial', 'bronze', 'silver', 'gold'].map((rank) => (
                          <div key={rank} className="flex items-center justify-between">
                            <label className="text-sm text-gray-600 capitalize">
                              {rank === 'trial' ? 'تجريبي / Trial' :
                               rank === 'bronze' ? 'برونزي / Bronze' :
                               rank === 'silver' ? 'فضي / Silver' :
                               'ذهبي / Gold'}
                            </label>
                            <input
                              type="number"
                              step="0.1"
                              value={
                                editData.driver_commission_by_rank?.[rank as keyof typeof editData.driver_commission_by_rank] ??
                                setting.driver_commission_by_rank[rank as keyof typeof setting.driver_commission_by_rank] ??
                                ''
                              }
                              onChange={(e) => {
                                const newRankData = {
                                  ...(editData.driver_commission_by_rank ?? setting.driver_commission_by_rank),
                                  [rank]: parseFloat(e.target.value) || 0,
                                };
                                setEditData({
                                  ...editData,
                                  driver_commission_by_rank: newRankData,
                                });
                              }}
                              className="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                              placeholder="0"
                            />
                          </div>
                        ))}
                      </div>
                    )}
                  </>
                )}
              </div>
            </div>

            {/* Merchant Wallet Settings */}
            <div>
              <h4 className="text-lg font-semibold text-gray-900 mb-4">
                إعدادات محفظة التجار / Merchant Wallet Settings
              </h4>

              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <label className="text-sm font-medium text-gray-700">
                    تفعيل محفظة التجار / Enable Merchant Wallet
                  </label>
                  {editing === setting.city ? (
                    <input
                      type="checkbox"
                      checked={editData.merchant_wallet_enabled ?? setting.merchant_wallet_enabled}
                      onChange={(e) =>
                        setEditData({ ...editData, merchant_wallet_enabled: e.target.checked })
                      }
                      className="w-5 h-5 text-primary-600 rounded focus:ring-primary-500"
                    />
                  ) : (
                    <span
                      className={`px-3 py-1 rounded-full text-sm font-medium ${
                        setting.merchant_wallet_enabled
                          ? 'bg-green-100 text-green-800'
                          : 'bg-red-100 text-red-800'
                      }`}
                    >
                      {setting.merchant_wallet_enabled ? 'مفعل / Enabled' : 'معطل / Disabled'}
                    </span>
                  )}
                </div>

                {editing === setting.city && (
                  <>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">
                        نوع عمولة التجار / Merchant Commission Type
                      </label>
                      <select
                        value={editData.merchant_commission_type ?? setting.merchant_commission_type}
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
                        value={editData.merchant_commission_value ?? setting.merchant_commission_value}
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
                )}
              </div>
            </div>

            {/* Action Buttons */}
            <div className="flex items-center justify-end gap-3 pt-4 border-t border-gray-200">
              {editing === setting.city ? (
                <>
                  <button
                    onClick={cancelEdit}
                    className="px-4 py-2 bg-gray-500 hover:bg-gray-600 text-white rounded-lg text-sm font-medium"
                  >
                    إلغاء / Cancel
                  </button>
                  <button
                    onClick={() => updateSetting(setting.city)}
                    className="px-4 py-2 bg-green-500 hover:bg-green-600 text-white rounded-lg text-sm font-medium"
                  >
                    حفظ / Save
                  </button>
                </>
              ) : (
                <button
                  onClick={() => startEdit(setting)}
                  className="px-4 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg text-sm font-medium"
                >
                  تعديل / Edit
                </button>
              )}
            </div>
          </div>
        </div>
      ))}

      {settings.length === 0 && (
        <div className="bg-white rounded-xl shadow-sm p-12 text-center text-gray-500">
          <i className="fas fa-city text-4xl mb-2"></i>
          <p>لا توجد إعدادات للمدن / No city settings found</p>
        </div>
      )}
    </div>
  );
}

