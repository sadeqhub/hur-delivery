import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';

/// Event-Driven Notification Service
/// 
/// Triggers notifications directly from app events, not database changes.
/// Simple, reliable, and immediate.
class EventNotificationService {
  static final EventNotificationService _instance = EventNotificationService._internal();
  factory EventNotificationService() => _instance;
  EventNotificationService._internal();

  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  /// Initialize the notification service
  static Future<void> initialize() async {
    if (_isInitialized) {
      Logger.d('⚠️ EventNotificationService already initialized');
      return;
    }

    Logger.d('\n═══════════════════════════════════════');
    Logger.d('🔔 EVENT NOTIFICATION SERVICE');
    Logger.d('═══════════════════════════════════════');

    // Request permissions
    final status = await Permission.notification.request();
    Logger.d('📋 Notification permission: ${status.isGranted ? "✅" : "❌"}');

    // Battery optimization exemption not requested for Play policy compliance

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        Logger.d('👆 Notification tapped: ${response.payload}');
      },
    );

    // Create notification channel
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      const channel = AndroidNotificationChannel(
        'events_channel',
        'طلبات فورية',
        description: 'إشعارات الطلبات والأحداث',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      );

      await androidPlugin.createNotificationChannel(channel);
      Logger.d('📢 Notification channel created');
    }

    _isInitialized = true;
    Logger.d('✅ Event Notification Service ready');
    Logger.d('═══════════════════════════════════════\n');
  }

  /// Show a notification immediately
  static Future<void> _showNotification({
    required String title,
    required String body,
    String? payload,
    bool isCritical = false,
  }) async {
    if (!_isInitialized) {
      Logger.d('❌ Not initialized, cannot show notification');
      return;
    }

    Logger.d('\n📱 SHOWING NOTIFICATION');
    Logger.d('Title: $title');
    Logger.d('Body: $body');
    Logger.d('Critical: $isCritical');

    final androidDetails = AndroidNotificationDetails(
      'events_channel',
      'طلبات فورية',
      channelDescription: 'إشعارات الطلبات والأحداث',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(isCritical 
          ? [0, 1000, 500, 1000]  // Long-Short-Long for critical
          : [0, 500, 200, 500]),   // Normal
      enableLights: true,
      ledColor: isCritical ? const Color(0xFF0000FF) : const Color(0xFF00FF00),
      ledOnMs: 1000,
      ledOffMs: 500,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'حُر للتوصيل',
      ),
      visibility: NotificationVisibility.public,
      category: isCritical ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.message,
      fullScreenIntent: isCritical,
      ongoing: false,
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _notifications.show(
      notificationId,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );

    Logger.d('✅ Notification shown (ID: $notificationId)\n');
  }

  // ==================== EVENT HANDLERS ====================

  /// Event: Order created and assigned to driver
  /// RECIPIENT: Driver
  static Future<void> onOrderAssignedToDriver({
    required String orderId,
    required String currentUserId,
    required String assignedDriverId,
  }) async {
    // Only show if this user is the assigned driver
    if (currentUserId != assignedDriverId) {
      Logger.d('⏭️ Skipping: Not the assigned driver');
      return;
    }
    
    Logger.d('\n🎯 EVENT: Order assigned to driver (YOU)');
    await _showNotification(
      title: '📦 طلب توصيل جديد',
      body: 'لديك طلب جديد - اضغط قبول خلال 30 ثانية',
      payload: 'order:$orderId',
      isCritical: true,
    );
  }

  /// Event: Driver accepted order
  /// RECIPIENT: Merchant
  static Future<void> onOrderAcceptedForMerchant({
    required String orderId,
    required String currentUserId,
    required String merchantId,
  }) async {
    // Only show if this user is the merchant
    if (currentUserId != merchantId) {
      Logger.d('⏭️ Skipping: Not the merchant');
      return;
    }
    
    Logger.d('\n🎯 EVENT: Order accepted (for MERCHANT)');
    await _showNotification(
      title: '✅ تم قبول الطلب',
      body: 'السائق قبل الطلب وهو في طريقه للاستلام',
      payload: 'order:$orderId',
      isCritical: false,
    );
  }

  /// Event: Driver rejected order
  /// RECIPIENT: Merchant
  static Future<void> onOrderRejectedForMerchant({
    required String orderId,
    required String currentUserId,
    required String merchantId,
  }) async {
    // Only show if this user is the merchant
    if (currentUserId != merchantId) {
      Logger.d('⏭️ Skipping: Not the merchant');
      return;
    }
    
    Logger.d('\n🎯 EVENT: Order rejected (for MERCHANT)');
    await _showNotification(
      title: '⚠️ تم رفض الطلب',
      body: 'جاري البحث عن سائق آخر...',
      payload: 'order:$orderId',
      isCritical: false,
    );
  }

  /// Event: Driver is on the way
  /// RECIPIENT: Merchant
  static Future<void> onOrderOnTheWayForMerchant({
    required String orderId,
    required String currentUserId,
    required String merchantId,
  }) async {
    // Only show if this user is the merchant
    if (currentUserId != merchantId) {
      Logger.d('⏭️ Skipping: Not the merchant');
      return;
    }
    
    Logger.d('\n🎯 EVENT: Driver on the way (for MERCHANT)');
    await _showNotification(
      title: '🚗 السائق في الطريق',
      body: 'السائق في طريقه للتوصيل',
      payload: 'order:$orderId',
      isCritical: false,
    );
  }

  /// Event: Order delivered
  /// RECIPIENT: Merchant
  static Future<void> onOrderDeliveredForMerchant({
    required String orderId,
    required String currentUserId,
    required String merchantId,
  }) async {
    // Only show if this user is the merchant
    if (currentUserId != merchantId) {
      Logger.d('⏭️ Skipping: Not the merchant');
      return;
    }
    
    Logger.d('\n🎯 EVENT: Order delivered (for MERCHANT)');
    await _showNotification(
      title: '🎉 تم التسليم',
      body: 'تم تسليم الطلب بنجاح',
      payload: 'order:$orderId',
      isCritical: false,
    );
  }

  /// Event: All drivers rejected
  /// RECIPIENT: Merchant
  static Future<void> onAllDriversRejectedForMerchant({
    required String orderId,
    required String currentUserId,
    required String merchantId,
  }) async {
    // Only show if this user is the merchant
    if (currentUserId != merchantId) {
      Logger.d('⏭️ Skipping: Not the merchant');
      return;
    }
    
    Logger.d('\n🎯 EVENT: All drivers rejected (for MERCHANT)');
    await _showNotification(
      title: '❌ لم يتم العثور على سائق',
      body: 'يمكنك إعادة نشر الطلب بزيادة الأجرة (+500 د.ع)',
      payload: 'order:$orderId',
      isCritical: false,
    );
  }

  /// Event: Driver timed out
  /// RECIPIENT: Driver
  static Future<void> onDriverTimeout({
    required String orderId,
    required String currentUserId,
    required String driverId,
  }) async {
    // Only show if this user is the driver who timed out
    if (currentUserId != driverId) {
      Logger.d('⏭️ Skipping: Not the timed-out driver');
      return;
    }
    
    Logger.d('\n🎯 EVENT: Driver timeout (for DRIVER)');
    await _showNotification(
      title: '⚠️ تم وضعك في وضع غير متصل',
      body: 'لم تقم بالرد على الطلب خلال الوقت المحدد',
      payload: 'timeout:$orderId',
      isCritical: true,
    );
  }

  /// Test notification
  static Future<void> sendTest() async {
    Logger.d('\n🧪 Sending test notification...');
    await _showNotification(
      title: '🧪 Test Notification',
      body: 'If you see this, notifications work!',
      payload: 'test',
      isCritical: true,
    );
  }
}

