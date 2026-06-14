import '../../../core/network/api_client.dart';

class MerchantRepository {
  MerchantRepository._();
  static final MerchantRepository instance = MerchantRepository._();

  Future<void> updateProfile(String userId, Map<String, dynamic> data) =>
      ApiClient.instance.from('users').update(data).eq('id', userId);

  Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    final response = await ApiClient.instance
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> markNotificationRead(String notificationId) =>
      ApiClient.instance
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

  Future<void> deleteNotification(String notificationId) =>
      ApiClient.instance
          .from('notifications')
          .delete()
          .eq('id', notificationId);

  Future<void> markAllNotificationsRead(String userId) =>
      ApiClient.instance
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
}
