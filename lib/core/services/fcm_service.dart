import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../constants/app_constants.dart';
import '../utils/logger.dart';

/// Firebase Cloud Messaging Service
/// 
/// Enterprise-grade push notifications like Uber/Doordash
/// - FCM for reliable delivery
/// - Supabase Edge Functions for processing
/// - Background message handling
/// - Token management
/// - Permission handling
class FCMService {
  static FirebaseMessaging? _messaging;
  static FlutterLocalNotificationsPlugin? _localNotifications;
  static StreamSubscription<RemoteMessage>? _messageSubscription;
  static String? _fcmToken;
  static bool _isInitialized = false;

  /// Initialize FCM service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    Logger.d('\n═══════════════════════════════════════');
    Logger.d('🔥 INITIALIZING FCM SERVICE');
    Logger.d('═══════════════════════════════════════');

    try {
      // Initialize Firebase Messaging
      _messaging = FirebaseMessaging.instance;
      
      // Initialize local notifications
      _localNotifications = FlutterLocalNotificationsPlugin();
      
      // Request permissions
      await _requestPermissions();
      
      // Configure local notifications
      await _configureLocalNotifications();
      
      // Configure message handlers
      await _configureMessageHandlers();
      
      _isInitialized = true;
      
      Logger.d('✅ FCM Service initialized successfully');
      Logger.d('✅ Ready for token generation after authentication');
      Logger.d('═══════════════════════════════════════\n');
      
    } catch (e) {
      Logger.d('❌ FCM initialization failed: $e');
      rethrow;
    }
  }

  /// Request notification permissions
  static Future<void> _requestPermissions() async {
    Logger.d('🔐 Requesting notification permissions...');
    
    // Request FCM permissions
    final settings = await _messaging!.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    Logger.d('FCM Permission status: ${settings.authorizationStatus}');
    
    // Request Android permissions
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
  }

  /// Configure local notifications
  static Future<void> _configureLocalNotifications() async {
    Logger.d('🔧 Configuring local notifications...');
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications!.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Create notification channel for Android
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'fcm_channel',
        'FCM Notifications',
        description: 'Firebase Cloud Messaging notifications',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );
      
      await _localNotifications!
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Initialize FCM with token generation (call after user authentication)
  static Future<void> initializeWithToken() async {
    Logger.d('\n═══════════════════════════════════════');
    Logger.d('🔥 INITIALIZING FCM WITH TOKEN GENERATION');
    Logger.d('═══════════════════════════════════════');

    try {
      // Get FCM token
      await _getFCMToken();
      
      Logger.d('✅ FCM token generated and saved');
      Logger.d('✅ Token: ${_fcmToken?.substring(0, 20)}...');
      Logger.d('═══════════════════════════════════════\n');
      
    } catch (e) {
      Logger.d('❌ FCM token generation failed: $e');
      rethrow;
    }
  }

  /// Get FCM token
  static Future<void> _getFCMToken() async {
    Logger.d('🎫 Getting FCM token...');
    
    try {
      _fcmToken = await _messaging!.getToken();
      
      if (_fcmToken != null) {
        Logger.d('✅ FCM Token obtained: ${_fcmToken!.substring(0, 20)}...');
        Logger.d('   Full token length: ${_fcmToken!.length}');
        Logger.d('   Token starts with: ${_fcmToken!.substring(0, 10)}');
        
        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);
        Logger.d('✅ FCM token saved to SharedPreferences');
        
        // Listen for token refresh
        _messaging!.onTokenRefresh.listen((newToken) {
          Logger.d('🔄 FCM token refreshed: ${newToken.substring(0, 20)}...');
          _fcmToken = newToken;
          _saveTokenToDatabase();
        });
        
        // Save to database immediately
        await _saveTokenToDatabase();
      } else {
        Logger.d('❌ FCM token is null');
        throw Exception('Failed to get FCM token');
      }
    } catch (e) {
      Logger.d('❌ Failed to get FCM token: $e');
      Logger.d('❌ Error details: ${e.toString()}');
      rethrow;
    }
  }

  /// Configure message handlers
  static Future<void> _configureMessageHandlers() async {
    Logger.d('📡 Configuring message handlers...');
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle background messages
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
    
    // Handle terminated app messages
    final initialMessage = await _messaging!.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessage(initialMessage);
    }
  }

  /// Save FCM token to database
  static Future<void> _saveTokenToDatabase() async {
    if (_fcmToken == null) {
      Logger.d('❌ Cannot save FCM token: token is null');
      return;
    }
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        Logger.d('❌ Cannot save FCM token: user not authenticated');
        return;
      }
      
      Logger.d('💾 Saving FCM token to database...');
      Logger.d('   User ID: ${user.id}');
      Logger.d('   FCM Token: ${_fcmToken!.substring(0, 20)}...');
      Logger.d('   Platform: ${Platform.isAndroid ? 'android' : 'ios'}');
      
      final result = await Supabase.instance.client
          .from('user_fcm_tokens')
          .upsert({
            'user_id': user.id,
            'fcm_token': _fcmToken,
            'platform': Platform.isAndroid ? 'android' : 'ios',
            'updated_at': DateTime.now().toIso8601String(),
          });
      
      Logger.d('✅ FCM token saved to database successfully');
      Logger.d('   Result: $result');
      
      // Verify the token was saved
      final verifyResult = await Supabase.instance.client
          .from('user_fcm_tokens')
          .select('*')
          .eq('user_id', user.id)
          .single();
      
      Logger.d('✅ Token verification: ${verifyResult['fcm_token']?.toString().substring(0, 20)}...');
      
    } catch (e) {
      Logger.d('❌ Failed to save FCM token: $e');
      Logger.d('❌ Error details: ${e.toString()}');
      
      // Check if it's an RLS issue
      if (e.toString().contains('row-level security')) {
        Logger.d('❌ RLS policy violation detected');
      }
    }
  }

  /// Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    Logger.d('\n═══════════════════════════════════════');
    Logger.d('📨 FOREGROUND MESSAGE RECEIVED');
    Logger.d('═══════════════════════════════════════');
    Logger.d('Title: ${message.notification?.title}');
    Logger.d('Body: ${message.notification?.body}');
    Logger.d('Data: ${message.data}');
    Logger.d('═══════════════════════════════════════\n');
    
    // Show local notification
    await _showLocalNotification(message);
  }

  /// Handle background messages
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    Logger.d('\n═══════════════════════════════════════');
    Logger.d('📨 BACKGROUND MESSAGE RECEIVED');
    Logger.d('═══════════════════════════════════════');
    Logger.d('Title: ${message.notification?.title}');
    Logger.d('Body: ${message.notification?.body}');
    Logger.d('Data: ${message.data}');
    Logger.d('═══════════════════════════════════════\n');
    
    // Handle based on message type
    await _processMessageData(message.data);
  }

  /// Show local notification
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    if (_localNotifications == null) return;
    
    final notification = message.notification;
    if (notification == null) return;
    
    const androidDetails = AndroidNotificationDetails(
      'fcm_channel',
      'FCM Notifications',
      channelDescription: 'Firebase Cloud Messaging notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications!.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification.title,
      notification.body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  /// Process message data
  static Future<void> _processMessageData(Map<String, dynamic> data) async {
    final messageType = data['type'];
    
    switch (messageType) {
      case 'order_assigned':
        Logger.d('📦 Processing order assignment...');
        // Handle order assignment
        break;
      case 'order_accepted':
        Logger.d('✅ Processing order acceptance...');
        // Handle order acceptance
        break;
      case 'order_delivered':
        Logger.d('🎉 Processing order delivery...');
        // Handle order delivery
        break;
      default:
        Logger.d('❓ Unknown message type: $messageType');
    }
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    Logger.d('👆 Notification tapped: ${response.payload}');
    
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        _processMessageData(data);
      } catch (e) {
        Logger.d('❌ Failed to parse notification payload: $e');
      }
    }
  }

  /// Legacy method - now handled by database triggers
  @deprecated
  static Future<void> sendPushNotification({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    // This method is deprecated - notifications are now handled by database triggers
    Logger.d('⚠️ sendPushNotification is deprecated - use database triggers instead');
  }


  /// Get current FCM token
  static String? get fcmToken => _fcmToken;

  /// Check if FCM is initialized
  static bool get isInitialized => _isInitialized;

  /// Dispose resources
  static Future<void> dispose() async {
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    _isInitialized = false;
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  Logger.d('📨 Background message received: ${message.messageId}');
  
  // Initialize Supabase in background isolate
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );
  
  // Process the message
  await FCMService._handleBackgroundMessage(message);
}
