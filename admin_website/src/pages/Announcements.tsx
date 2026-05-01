import { useEffect, useState } from 'react';
import { supabaseAdmin } from '../lib/supabase-admin';
import { config } from '../lib/config';

interface Announcement {
  id: string;
  title: string;
  message: string;
  type: 'maintenance' | 'event' | 'update' | 'info' | 'warning' | 'success';
  is_active: boolean;
  is_dismissable: boolean;
  target_roles: string[];
  start_time?: string;
  end_time?: string;
  created_at: string;
}

type TabType = 'system' | 'whatsapp';

export default function Announcements() {
  const [activeTab, setActiveTab] = useState<TabType>('system');
  const [announcements, setAnnouncements] = useState<Announcement[]>([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editingAnnouncement, setEditingAnnouncement] = useState<Announcement | null>(null);
  const [formData, setFormData] = useState({
    title: '',
    message: '',
    type: 'info' as Announcement['type'],
    is_dismissable: true,
    target_roles: ['driver', 'merchant'] as string[],
    start_time: '',
    end_time: '',
  });

  // Mass WhatsApp announcement state
  const [whatsappMessage, setWhatsappMessage] = useState('');
  const [whatsappTargetRoles, setWhatsappTargetRoles] = useState<string[]>(['driver', 'merchant']);
  const [whatsappSending, setWhatsappSending] = useState(false);
  const [whatsappProgress, setWhatsappProgress] = useState<{
    total: number;
    successful: number;
    failed: number;
    processed: number;
    skipped?: number;
    queued?: number;
    errors: Array<{ userId: string; phone: string; error: string }>;
  } | null>(null);

  useEffect(() => {
    loadAnnouncements();
  }, []);

  const loadAnnouncements = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabaseAdmin
        .from('system_announcements')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setAnnouncements(data || []);
    } catch (error) {
      console.error('Error loading announcements:', error);
    } finally {
      setLoading(false);
    }
  };

  const saveAnnouncement = async () => {
    try {
      if (editingAnnouncement) {
        const { error } = await supabaseAdmin
          .from('system_announcements')
          .update({
            title: formData.title,
            message: formData.message,
            type: formData.type,
            is_dismissable: formData.is_dismissable,
            target_roles: formData.target_roles,
            start_time: formData.start_time || null,
            end_time: formData.end_time || null,
          })
          .eq('id', editingAnnouncement.id);

        if (error) throw error;
        alert('تم تحديث الإعلان / Announcement updated');
      } else {
        const { error } = await supabaseAdmin
          .from('system_announcements')
          .insert({
            title: formData.title,
            message: formData.message,
            type: formData.type,
            is_dismissable: formData.is_dismissable,
            target_roles: formData.target_roles,
            start_time: formData.start_time || null,
            end_time: formData.end_time || null,
          });

        if (error) throw error;
        alert('تم إنشاء الإعلان / Announcement created');
      }

      setShowModal(false);
      setEditingAnnouncement(null);
      resetForm();
      loadAnnouncements();
    } catch (error: any) {
      console.error('Error saving announcement:', error);
      alert(error.message || 'فشل الحفظ / Save failed');
    }
  };

  const toggleAnnouncement = async (id: string, currentStatus: boolean) => {
    try {
      const { error } = await supabaseAdmin
        .from('system_announcements')
        .update({ is_active: !currentStatus })
        .eq('id', id);

      if (error) throw error;
      loadAnnouncements();
    } catch (error: any) {
      console.error('Error toggling announcement:', error);
      alert(error.message || 'فشل التحديث / Update failed');
    }
  };

  const deleteAnnouncement = async (id: string) => {
    if (!confirm('هل أنت متأكد من حذف هذا الإعلان؟ / Delete this announcement?')) return;

    try {
      const { error } = await supabaseAdmin
        .from('system_announcements')
        .delete()
        .eq('id', id);

      if (error) throw error;
      loadAnnouncements();
    } catch (error: any) {
      console.error('Error deleting announcement:', error);
      alert(error.message || 'فشل الحذف / Delete failed');
    }
  };

  const openCreateModal = () => {
    resetForm();
    setEditingAnnouncement(null);
    setShowModal(true);
  };

  const openEditModal = (announcement: Announcement) => {
    setFormData({
      title: announcement.title,
      message: announcement.message,
      type: announcement.type,
      is_dismissable: announcement.is_dismissable,
      target_roles: announcement.target_roles,
      start_time: announcement.start_time?.slice(0, 16) || '',
      end_time: announcement.end_time?.slice(0, 16) || '',
    });
    setEditingAnnouncement(announcement);
    setShowModal(true);
  };

  const resetForm = () => {
    setFormData({
      title: '',
      message: '',
      type: 'info',
      is_dismissable: true,
      target_roles: ['driver', 'merchant'],
      start_time: '',
      end_time: '',
    });
  };

  const toggleRole = (role: string) => {
    if (formData.target_roles.includes(role)) {
      setFormData({ ...formData, target_roles: formData.target_roles.filter(r => r !== role) });
    } else {
      setFormData({ ...formData, target_roles: [...formData.target_roles, role] });
    }
  };

  const getTypeBadge = (type: Announcement['type']) => {
    const badges = {
      maintenance: 'bg-yellow-100 text-yellow-800',
      event: 'bg-purple-100 text-purple-800',
      update: 'bg-blue-100 text-blue-800',
      info: 'bg-gray-100 text-gray-800',
      warning: 'bg-red-100 text-red-800',
      success: 'bg-green-100 text-green-800',
    };
    return badges[type] || badges.info;
  };

  const getTypeIcon = (type: Announcement['type']) => {
    const icons = {
      maintenance: 'fa-wrench',
      event: 'fa-calendar-star',
      update: 'fa-sync-alt',
      info: 'fa-info-circle',
      warning: 'fa-exclamation-triangle',
      success: 'fa-check-circle',
    };
    return icons[type] || icons.info;
  };

  const toggleWhatsappRole = (role: string) => {
    if (whatsappTargetRoles.includes(role)) {
      setWhatsappTargetRoles(whatsappTargetRoles.filter(r => r !== role));
    } else {
      setWhatsappTargetRoles([...whatsappTargetRoles, role]);
    }
  };

  const sendMassWhatsappAnnouncement = async () => {
    if (!whatsappMessage.trim()) {
      alert('الرجاء إدخال الرسالة / Please enter a message');
      return;
    }

    if (whatsappTargetRoles.length === 0) {
      alert('الرجاء اختيار دور واحد على الأقل / Please select at least one role');
      return;
    }

    if (!confirm(`هل أنت متأكد من إرسال هذه الرسالة إلى ${whatsappTargetRoles.join(', ')}؟\nAre you sure you want to send this message to ${whatsappTargetRoles.join(', ')}?`)) {
      return;
    }

    setWhatsappSending(true);
    setWhatsappProgress(null);

    try {
      const { data: sessionData } = await supabaseAdmin.auth.getSession();
      if (!sessionData?.session) {
        throw new Error('Not authenticated');
      }

      const response = await fetch(`${config.supabaseUrl}/functions/v1/mass-whatsapp-announcement`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${sessionData.session.access_token}`,
          'apikey': config.supabaseAnonKey,
        },
        body: JSON.stringify({
          message: whatsappMessage,
          targetRoles: whatsappTargetRoles,
          delayBetweenMessages: 2000 + Math.random() * 2000, // 2-4 seconds random delay
        }),
      });

      const result = await response.json();

      if (!response.ok) {
        throw new Error(result.error || result.message || 'Failed to send messages');
      }

      // Check if messages were queued
      if (result.queued) {
        setWhatsappProgress({
          total: result.results?.total || 0,
          successful: 0,
          failed: 0,
          processed: 0,
          skipped: result.results?.skipped || 0,
          queued: result.results?.queued || 0,
          errors: [],
        });

        alert(`✅ تم إضافة ${result.queueCount || 0} رسالة إلى قائمة الانتظار!\nتم تخطي ${result.results?.skipped || 0} مستخدم تم إشعاره مؤخراً\n\nالرسائل قيد المعالجة في الخلفية...\n\n✅ ${result.queueCount || 0} messages queued!\nSkipped ${result.results?.skipped || 0} recently notified users\n\nMessages are being processed in the background...`);

        // Start processing the queue
        processQueue(sessionData.session.access_token);
      } else {
        // Direct processing results
        setWhatsappProgress({
          total: result.results?.total || 0,
          successful: result.results?.successful || 0,
          failed: result.results?.failed || 0,
          processed: result.results?.processed || 0,
          skipped: result.results?.skipped || 0,
          errors: result.results?.errors || [],
        });

        if (result.isComplete) {
          alert(`✅ تم إرسال جميع الرسائل!\nTotal: ${result.results?.total || 0}\nSuccessful: ${result.results?.successful || 0}\nFailed: ${result.results?.failed || 0}`);
        } else {
          const remaining = result.remainingCount || 0;
          alert(`⚠️ تم إرسال جزء من الرسائل\nProcessed: ${result.results?.processed || 0}/${result.results?.total || 0}\nSuccessful: ${result.results?.successful || 0}\nFailed: ${result.results?.failed || 0}\nRemaining: ${remaining}`);
        }
      }
    } catch (error: any) {
      console.error('Error sending mass WhatsApp announcement:', error);
      alert(error.message || 'فشل إرسال الرسائل / Failed to send messages');
    } finally {
      setWhatsappSending(false);
    }
  };

  const processQueue = async (accessToken: string) => {
    // Process queue in background
    const maxIterations = 20; // Process up to 20 batches
    let iteration = 0;

    const processBatch = async () => {
      if (iteration >= maxIterations) {
        console.log('✅ Queue processing completed (max iterations reached)');
        return;
      }

      try {
        const response = await fetch(`${config.supabaseUrl}/functions/v1/process-whatsapp-queue`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${accessToken}`,
            'apikey': config.supabaseAnonKey,
          },
          body: JSON.stringify({}),
        });

        const result = await response.json();

        if (result.processed > 0) {
          // Update progress
          setWhatsappProgress(prev => {
            if (!prev) return prev;
            return {
              ...prev,
              processed: (prev.processed || 0) + result.processed,
              successful: (prev.successful || 0) + result.successful,
              failed: (prev.failed || 0) + result.failed,
            };
          });

          // Continue processing if there are more messages
          if (result.hasMore || result.remaining === 'more available') {
            iteration++;
            setTimeout(processBatch, 2000); // Wait 2 seconds before next batch
          } else {
            console.log('✅ Queue processing completed');
          }
        } else if (result.hasMore) {
          // No messages processed but more available - retry
          iteration++;
          setTimeout(processBatch, 2000);
        } else {
          console.log('✅ Queue processing completed (no more messages)');
        }
      } catch (error) {
        console.error('Error processing queue:', error);
        // Retry after delay
        iteration++;
        if (iteration < maxIterations) {
          setTimeout(processBatch, 5000);
        }
      }
    };

    // Start processing after a short delay
    setTimeout(processBatch, 2000);
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
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">الإعلانات / Announcements</h2>
          <p className="text-gray-600 text-sm mt-1">إدارة إعلانات النظام / Manage system announcements</p>
        </div>
        {activeTab === 'system' && (
          <button
            onClick={openCreateModal}
            className="px-4 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-lg font-medium"
          >
            <i className="fas fa-plus mr-2"></i>
            إنشاء إعلان / Create
          </button>
        )}
      </div>

      {/* Tabs */}
      <div className="bg-white rounded-xl shadow-sm p-1">
        <div className="flex gap-2">
          <button
            onClick={() => setActiveTab('system')}
            className={`flex-1 px-4 py-3 rounded-lg font-medium transition-colors ${
              activeTab === 'system'
                ? 'bg-primary-500 text-white'
                : 'text-gray-600 hover:bg-gray-100'
            }`}
          >
            <i className="fas fa-bullhorn mr-2"></i>
            إعلانات النظام / System Announcements
          </button>
          <button
            onClick={() => setActiveTab('whatsapp')}
            className={`flex-1 px-4 py-3 rounded-lg font-medium transition-colors ${
              activeTab === 'whatsapp'
                ? 'bg-primary-500 text-white'
                : 'text-gray-600 hover:bg-gray-100'
            }`}
          >
            <i className="fab fa-whatsapp mr-2"></i>
            إعلان جماعي عبر واتساب / Mass WhatsApp Announcement
          </button>
        </div>
      </div>

      {/* System Announcements Tab */}
      {activeTab === 'system' && (
        <>

      <div className="grid grid-cols-1 gap-4">
        {announcements.map(announcement => (
          <div key={announcement.id} className="bg-white rounded-xl shadow-sm p-6">
            <div className="flex items-start justify-between mb-4">
              <div className="flex items-start gap-4 flex-1">
                <div className={`w-12 h-12 rounded-full flex items-center justify-center ${
                  announcement.is_active ? getTypeBadge(announcement.type) : 'bg-gray-100'
                }`}>
                  <i className={`fas ${getTypeIcon(announcement.type)} text-xl`}></i>
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-2">
                    <h3 className="text-lg font-bold text-gray-900">{announcement.title}</h3>
                    <span className={`px-3 py-1 text-xs font-medium rounded-full ${getTypeBadge(announcement.type)}`}>
                      {announcement.type}
                    </span>
                    {announcement.is_active ? (
                      <span className="px-3 py-1 text-xs font-medium rounded-full bg-green-100 text-green-800">
                        <i className="fas fa-check-circle mr-1"></i>نشط
                      </span>
                    ) : (
                      <span className="px-3 py-1 text-xs font-medium rounded-full bg-gray-100 text-gray-800">
                        <i className="fas fa-pause-circle mr-1"></i>موقوف
                      </span>
                    )}
                  </div>
                  <p className="text-gray-700 mb-3">{announcement.message}</p>
                  <div className="flex flex-wrap gap-4 text-sm text-gray-600">
                    <span>
                      <i className="fas fa-users mr-1"></i>
                      الأدوار: {announcement.target_roles.join(', ')}
                    </span>
                    {announcement.start_time && (
                      <span>
                        <i className="fas fa-calendar-check mr-1"></i>
                        من: {new Date(announcement.start_time).toLocaleString('ar-IQ')}
                      </span>
                    )}
                    {announcement.end_time && (
                      <span>
                        <i className="fas fa-calendar-times mr-1"></i>
                        إلى: {new Date(announcement.end_time).toLocaleString('ar-IQ')}
                      </span>
                    )}
                    <span>
                      {announcement.is_dismissable ? (
                        <><i className="fas fa-times-circle mr-1 text-blue-600"></i>يمكن إغلاقه</>
                      ) : (
                        <><i className="fas fa-ban mr-1 text-red-600"></i>لا يمكن إغلاقه</>
                      )}
                    </span>
                  </div>
                </div>
              </div>
              <div className="flex gap-2">
                <button
                  onClick={() => toggleAnnouncement(announcement.id, announcement.is_active)}
                  className={`px-3 py-2 rounded-lg text-sm ${
                    announcement.is_active 
                      ? 'bg-yellow-100 text-yellow-800 hover:bg-yellow-200'
                      : 'bg-green-100 text-green-800 hover:bg-green-200'
                  }`}
                  title={announcement.is_active ? 'تعطيل' : 'تفعيل'}
                >
                  <i className={`fas ${announcement.is_active ? 'fa-pause' : 'fa-play'}`}></i>
                </button>
                <button
                  onClick={() => openEditModal(announcement)}
                  className="px-3 py-2 bg-blue-100 text-blue-800 hover:bg-blue-200 rounded-lg text-sm"
                >
                  <i className="fas fa-edit"></i>
                </button>
                <button
                  onClick={() => deleteAnnouncement(announcement.id)}
                  className="px-3 py-2 bg-red-100 text-red-800 hover:bg-red-200 rounded-lg text-sm"
                >
                  <i className="fas fa-trash"></i>
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>

      {announcements.length === 0 && (
        <div className="bg-white rounded-xl shadow-sm p-12 text-center text-gray-500">
          <i className="fas fa-bullhorn text-4xl mb-2"></i>
          <p>لا توجد إعلانات / No announcements</p>
        </div>
      )}

      {/* Create/Edit Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between p-6 border-b border-gray-200">
              <h3 className="text-xl font-bold text-gray-900">
                {editingAnnouncement ? 'تعديل الإعلان / Edit' : 'إنشاء إعلان / Create'} Announcement
              </h3>
              <button onClick={() => setShowModal(false)} className="text-gray-400 hover:text-gray-600">
                <i className="fas fa-times text-xl"></i>
              </button>
            </div>

            <div className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">العنوان / Title</label>
                <input
                  type="text"
                  value={formData.title}
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                  placeholder="مثال: صيانة مجدولة"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">الرسالة / Message</label>
                <textarea
                  value={formData.message}
                  onChange={(e) => setFormData({ ...formData, message: e.target.value })}
                  rows={4}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                  placeholder="رسالة الإعلان..."
                ></textarea>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">النوع / Type</label>
                <select
                  value={formData.type}
                  onChange={(e) => setFormData({ ...formData, type: e.target.value as Announcement['type'] })}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                >
                  <option value="info">ℹ️ معلومات / Info</option>
                  <option value="success">✅ نجاح / Success</option>
                  <option value="warning">⚠️ تحذير / Warning</option>
                  <option value="maintenance">🔧 صيانة / Maintenance</option>
                  <option value="event">🎉 حدث / Event</option>
                  <option value="update">📱 تحديث / Update</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">الأدوار المستهدفة / Target Roles</label>
                <div className="flex flex-wrap gap-2">
                  {['driver', 'merchant', 'customer', 'admin'].map(role => (
                    <button
                      key={role}
                      type="button"
                      onClick={() => toggleRole(role)}
                      className={`px-4 py-2 rounded-lg text-sm font-medium ${
                        formData.target_roles.includes(role)
                          ? 'bg-primary-500 text-white'
                          : 'bg-gray-100 text-gray-700'
                      }`}
                    >
                      {role === 'driver' ? 'سائق' : role === 'merchant' ? 'تاجر' : role === 'customer' ? 'عميل' : 'مشرف'}
                    </button>
                  ))}
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">وقت البدء / Start Time</label>
                  <input
                    type="datetime-local"
                    value={formData.start_time}
                    onChange={(e) => setFormData({ ...formData, start_time: e.target.value })}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">وقت الانتهاء / End Time</label>
                  <input
                    type="datetime-local"
                    value={formData.end_time}
                    onChange={(e) => setFormData({ ...formData, end_time: e.target.value })}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                  />
                </div>
              </div>

              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="dismissable"
                  checked={formData.is_dismissable}
                  onChange={(e) => setFormData({ ...formData, is_dismissable: e.target.checked })}
                  className="w-4 h-4 text-primary-500 rounded focus:ring-primary-500"
                />
                <label htmlFor="dismissable" className="text-sm text-gray-700">
                  يمكن للمستخدمين إغلاق هذا الإعلان / Users can dismiss this announcement
                </label>
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 p-6 border-t border-gray-200">
              <button
                onClick={() => setShowModal(false)}
                className="px-6 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
              >
                إلغاء / Cancel
              </button>
              <button
                onClick={saveAnnouncement}
                disabled={!formData.title || !formData.message || formData.target_roles.length === 0}
                className="px-6 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-lg disabled:opacity-50"
              >
                <i className="fas fa-save mr-2"></i>
                {editingAnnouncement ? 'حفظ / Save' : 'إنشاء / Create'}
              </button>
            </div>
          </div>
        </div>
      )}
        </>
      )}

      {/* Mass WhatsApp Announcement Tab */}
      {activeTab === 'whatsapp' && (
        <div className="bg-white rounded-xl shadow-sm p-6 space-y-6">
          <div>
            <h3 className="text-xl font-bold text-gray-900 mb-2">إرسال إعلان جماعي عبر واتساب / Send Mass WhatsApp Announcement</h3>
            <p className="text-gray-600 text-sm">
              أرسل رسالة إلى جميع المستخدمين المحددين عبر واتساب. سيتم إرسال الرسائل بفترات زمنية متغيرة لتجنب الحظر.
              <br />
              Send a message to all selected users via WhatsApp. Messages will be sent at variable intervals to avoid being banned.
            </p>
          </div>

          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                الرسالة / Message <span className="text-red-500">*</span>
              </label>
              <textarea
                value={whatsappMessage}
                onChange={(e) => setWhatsappMessage(e.target.value)}
                rows={6}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                placeholder="اكتب رسالتك هنا... / Write your message here..."
                disabled={whatsappSending}
              />
              <p className="text-xs text-gray-500 mt-1">
                {whatsappMessage.length} حرف / characters
              </p>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                الأدوار المستهدفة / Target Roles <span className="text-red-500">*</span>
              </label>
              <div className="flex flex-wrap gap-2">
                {['driver', 'merchant'].map(role => (
                  <button
                    key={role}
                    type="button"
                    onClick={() => toggleWhatsappRole(role)}
                    disabled={whatsappSending}
                    className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                      whatsappTargetRoles.includes(role)
                        ? 'bg-primary-500 text-white'
                        : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                    } ${whatsappSending ? 'opacity-50 cursor-not-allowed' : ''}`}
                  >
                    <i className={`fas ${role === 'driver' ? 'fa-motorcycle' : 'fa-store'} mr-2`}></i>
                    {role === 'driver' ? 'سائقون / Drivers' : 'تجار / Merchants'}
                  </button>
                ))}
              </div>
              {whatsappTargetRoles.length === 0 && (
                <p className="text-xs text-red-500 mt-1">الرجاء اختيار دور واحد على الأقل / Please select at least one role</p>
              )}
            </div>

            <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
              <div className="flex items-start gap-3">
                <i className="fas fa-exclamation-triangle text-yellow-600 mt-1"></i>
                <div className="text-sm text-yellow-800">
                  <p className="font-medium mb-1">تنبيه / Warning:</p>
                  <ul className="list-disc list-inside space-y-1">
                    <li>سيتم إرسال الرسائل بفترات زمنية متغيرة (2-5 ثوان) لتجنب الحظر / Messages will be sent at variable intervals (2-5 seconds) to avoid being banned</li>
                    <li>قد يستغرق الإرسال وقتًا طويلاً إذا كان عدد المستخدمين كبيرًا / Sending may take a long time if there are many users</li>
                    <li>تأكد من صحة الرسالة قبل الإرسال / Make sure the message is correct before sending</li>
                  </ul>
                </div>
              </div>
            </div>

            <button
              onClick={sendMassWhatsappAnnouncement}
              disabled={whatsappSending || !whatsappMessage.trim() || whatsappTargetRoles.length === 0}
              className="w-full px-6 py-3 bg-green-500 hover:bg-green-600 text-white rounded-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              {whatsappSending ? (
                <>
                  <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white"></div>
                  <span>جاري الإرسال... / Sending...</span>
                </>
              ) : (
                <>
                  <i className="fab fa-whatsapp"></i>
                  <span>إرسال الرسائل / Send Messages</span>
                </>
              )}
            </button>

            {whatsappProgress && (
              <div className="bg-gray-50 border border-gray-200 rounded-lg p-4 space-y-3">
                <h4 className="font-medium text-gray-900">نتائج الإرسال / Sending Results</h4>
                {whatsappProgress.queued && whatsappProgress.queued > 0 && (
                  <div className="bg-blue-50 border border-blue-200 rounded-lg p-3 mb-3">
                    <div className="flex items-center gap-2 text-blue-800">
                      <i className="fas fa-clock animate-pulse"></i>
                      <span className="text-sm font-medium">
                        📦 تم إضافة {whatsappProgress.queued} رسالة إلى قائمة الانتظار - قيد المعالجة...
                        <br />
                        📦 {whatsappProgress.queued} messages queued - processing in background...
                      </span>
                    </div>
                  </div>
                )}
                {whatsappProgress.processed < whatsappProgress.total && !whatsappProgress.queued && (
                  <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-3 mb-3">
                    <div className="flex items-center gap-2 text-yellow-800">
                      <i className="fas fa-exclamation-triangle"></i>
                      <span className="text-sm font-medium">
                        ⚠️ تم إرسال {whatsappProgress.processed} من {whatsappProgress.total} رسالة
                        <br />
                        ⚠️ Sent {whatsappProgress.processed} of {whatsappProgress.total} messages
                      </span>
                    </div>
                  </div>
                )}
                <div className="grid grid-cols-5 gap-4">
                  <div className="text-center">
                    <div className="text-2xl font-bold text-gray-700">{whatsappProgress.total}</div>
                    <div className="text-xs text-gray-600">إجمالي / Total</div>
                  </div>
                  <div className="text-center">
                    <div className="text-2xl font-bold text-blue-600">{whatsappProgress.processed}</div>
                    <div className="text-xs text-gray-600">معالج / Processed</div>
                  </div>
                  <div className="text-center">
                    <div className="text-2xl font-bold text-green-600">{whatsappProgress.successful}</div>
                    <div className="text-xs text-gray-600">نجح / Successful</div>
                  </div>
                  <div className="text-center">
                    <div className="text-2xl font-bold text-yellow-600">{whatsappProgress.skipped || 0}</div>
                    <div className="text-xs text-gray-600">تم تخطيه / Skipped</div>
                  </div>
                  <div className="text-center">
                    <div className="text-2xl font-bold text-red-600">{whatsappProgress.failed}</div>
                    <div className="text-xs text-gray-600">فشل / Failed</div>
                  </div>
                </div>
                {whatsappProgress.skipped && whatsappProgress.skipped > 0 && (
                  <div className="bg-blue-50 border border-blue-200 rounded-lg p-2 mt-2">
                    <p className="text-xs text-blue-800">
                      <i className="fas fa-info-circle mr-1"></i>
                      تم تخطي {whatsappProgress.skipped} مستخدم تم إشعاره بنفس الرسالة في الساعة الماضية
                      <br />
                      Skipped {whatsappProgress.skipped} users who were notified with the same message in the last hour
                    </p>
                  </div>
                )}
                {whatsappProgress.errors.length > 0 && (
                  <details className="mt-3">
                    <summary className="cursor-pointer text-sm text-gray-700 font-medium">
                      عرض الأخطاء / View Errors ({whatsappProgress.errors.length})
                    </summary>
                    <div className="mt-2 max-h-40 overflow-y-auto space-y-1">
                      {whatsappProgress.errors.map((error, index) => (
                        <div key={index} className="text-xs bg-red-50 border border-red-200 rounded p-2">
                          <span className="font-medium">{error.phone}:</span> {error.error}
                        </div>
                      ))}
                    </div>
                  </details>
                )}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

