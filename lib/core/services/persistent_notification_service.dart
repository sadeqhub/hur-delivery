import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'event_notification_service.dart';

/// Persistent Notification Service using Foreground Task
/// 
/// Keeps app alive in background with a persistent notification.
/// Monitors orders in real-time and triggers notifications.
class PersistentNotificationService {
  static bool _isRunning = false;
  static String? _currentUserId;
  static String? _userRole;

  /// Start persistent foreground service
  static Future<bool> start({
    required String userId,
    required String userRole,
    String? userName,
  }) async {
    if (_isRunning) {
      print('⚠️ Persistent service already running');
      return true;
    }

    print('\n═══════════════════════════════════════');
    print('🚀 STARTING PERSISTENT SERVICE');
    print('═══════════════════════════════════════');
    print('User: ${userName ?? userId}');
    print('Role: $userRole');

    _currentUserId = userId;
    _userRole = userRole;

    // Initialize foreground task
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'persistent_service',
        channelName: 'خدمة التوصيل',
        channelDescription: 'تبقيك متصل لاستلام الطلبات',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000), // Check every 5 seconds
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    // Start the service
    await FlutterForegroundTask.startService(
      notificationTitle: userRole == 'driver' 
          ? '🟢 متصل - جاهز لاستلام الطلبات'
          : '🟢 متصل - ${userName ?? 'التاجر'}',
      notificationText: 'الخدمة نشطة - اضغط للتفاصيل',
      callback: startCallback,
    );

    _isRunning = true;
    print('✅ Persistent service started');
    print('═══════════════════════════════════════\n');
    return true;
  }

  /// Stop persistent service
  static Future<bool> stop() async {
    if (!_isRunning) {
      print('⚠️ Persistent service not running');
      return true;
    }

    print('🛑 Stopping persistent service...');
    
    await FlutterForegroundTask.stopService();
    
    _isRunning = false;
    _currentUserId = null;
    _userRole = null;
    print('✅ Persistent service stopped\n');
    return true;
  }

  /// Update notification text
  static Future<void> updateNotification({
    required String title,
    required String text,
  }) async {
    if (!_isRunning) return;

    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  /// Check if service is running
  static bool get isRunning => _isRunning;
}

/// Foreground task callback
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(PersistentTaskHandler());
}

/// Task handler that runs in background
class PersistentTaskHandler extends TaskHandler {
  StreamSubscription? _orderSubscription;
  String? _userId;
  String? _userRole;
  final Set<String> _notifiedOrders = {};

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('\n🔄 Task handler started at $timestamp');
    
    // Get user info from preferences or state
    await _initializeSubscription();
  }

  Future<void> _initializeSubscription() async {
    print('🔧 Initializing order subscription in background...');

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        print('❌ No current user');
        return;
      }

      _userId = currentUser.id;
      
      // Get user role
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', _userId!)
          .single();
      
      _userRole = userResponse['role'] as String;
      
      print('✅ User: $_userId, Role: $_userRole');

      // Subscribe to orders
      if (_userRole == 'driver') {
        _subscribeToDriverOrders();
      }
    } catch (e) {
      print('❌ Error initializing subscription: $e');
    }
  }

  void _subscribeToDriverOrders() {
    print('📡 Subscribing to orders for driver...');

    _orderSubscription = Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .listen((orders) {
      print('📦 Orders stream update: ${orders.length} orders');

      for (var order in orders) {
        final orderId = order['id'] as String;
        final driverId = order['driver_id'] as String?;
        final status = order['status'] as String?;

        // Check if order newly assigned to this driver
        if (driverId != null &&
            driverId == _userId && 
            status == 'pending' && 
            !_notifiedOrders.contains(orderId)) {
          
          print('🔔 NEW ORDER DETECTED: $orderId');
          _notifiedOrders.add(orderId);
          
          // Trigger notification
          EventNotificationService.onOrderAssignedToDriver(
            orderId: orderId,
            currentUserId: _userId!,
            assignedDriverId: driverId,
          );
          
          // Update foreground notification
          FlutterForegroundTask.updateService(
            notificationTitle: '📦 طلب جديد!',
            notificationText: 'لديك طلب جديد - افتح التطبيق للرد',
          );
        }
      }
    });

    print('✅ Orders subscription active');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // This runs every 5 seconds
    // Keep connection alive
    print('💓 Background task heartbeat: ${timestamp.toString().substring(11, 19)}');
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('🛑 Task handler destroyed at $timestamp');
    await _orderSubscription?.cancel();
  }

  @override
  void onNotificationButtonPressed(String id) {
    print('🔘 Button pressed: $id');
    
    if (id == 'test') {
      EventNotificationService.sendTest();
    } else if (id == 'status') {
      // Show status notification
      EventNotificationService.sendTest();
    }
  }

  @override
  void onNotificationPressed() {
    print('👆 Persistent notification tapped');
    FlutterForegroundTask.launchApp('/');
  }
}

