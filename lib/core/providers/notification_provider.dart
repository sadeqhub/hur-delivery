import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/background_service.dart';
import '../services/response_cache_service.dart';
import '../services/network_quality_service.dart';
import '../services/global_order_notification_service.dart';
import '../services/messaging_service.dart';
import '../constants/app_constants.dart';
import '../widgets/header_notification.dart';

class NotificationProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;
  String? _error;
  final Set<String> _shownNotificationIds = {}; // Track which notifications we've already shown
  DateTime? _initializationTime; // Track when provider was initialized to filter old notifications
  RealtimeChannel? _notificationChannel; // Persistent realtime channel
  RealtimeChannel? _supportMessageChannel; // Listens for incoming support agent replies

  // PERFORMANCE: Cache service for 4G optimization
  final _responseCache = ResponseCacheService();
  final _networkQuality = NetworkQualityService();

  List<Map<String, dynamic>> get notifications => _notifications;
  List<Map<String, dynamic>> get unreadNotifications => 
      _notifications.where((n) => n['is_read'] == false).toList();
  int get unreadCount => unreadNotifications.length;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Initialize notifications
  Future<void> initialize() async {
    _isLoading = true;
    
    // Set initialization time - use UTC for consistency with database
    _initializationTime = DateTime.now().toUtc();
    print('📅 NotificationProvider initialized at: $_initializationTime (UTC)');
    
    notifyListeners();

    try {
      await _loadNotifications();
      await _subscribeToNotifications();
      await _initSupportMessageListener();

      // Start background service conditionally
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        final userRole = await _getUserRole(currentUser.id);
        if (userRole == 'driver') {
          final isOnline = await _getUserOnlineStatus(currentUser.id);
          if (isOnline) {
            await startBackgroundNotifications(currentUser.id, userRole);
          }
        } else {
          await startBackgroundNotifications(currentUser.id, userRole);
        }
      }
    } catch (e) {
      _error = e.toString();
      print('Error initializing notifications: $e');
      // Don't crash - just log the error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Get user role from database
  // PERFORMANCE: Cache for 5 minutes (role rarely changes)
  Future<String> _getUserRole(String userId) async {
    final cacheKey = 'user_role_$userId';

    // Check cache first
    final cached = _responseCache.get<String>(cacheKey);
    if (cached != null) {
      print('✅ Using cached user role: $cached');
      return cached;
    }

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', userId)
          .single();
      final role = response['role'] as String? ?? 'driver';

      // Cache for 5 minutes
      _responseCache.set(cacheKey, role, const Duration(minutes: 5));
      print('💾 Cached user role: $role');

      return role;
    } catch (e) {
      print('Error getting user role: $e');
      return 'driver';
    }
  }

  // PERFORMANCE: Cache for 1 minute (online status is more volatile)
  Future<bool> _getUserOnlineStatus(String userId) async {
    final cacheKey = 'user_online_$userId';

    // Check cache first
    final cached = _responseCache.get<bool>(cacheKey);
    if (cached != null) {
      print('✅ Using cached online status: $cached');
      return cached;
    }

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('is_online')
          .eq('id', userId)
          .single();
      final isOnline = (response['is_online'] as bool?) ?? false;

      // Cache for 1 minute
      _responseCache.set(cacheKey, isOnline, const Duration(minutes: 1));
      print('💾 Cached online status: $isOnline');

      return isOnline;
    } catch (e) {
      print('Error getting user online status: $e');
      return false;
    }
  }
  
  // Start background notifications
  Future<void> startBackgroundNotifications(String userId, String userRole, {String? driverName}) async {
    try {
      await BackgroundService.start(
        userId,
        userRole,
        AppConstants.supabaseUrl,
        AppConstants.supabaseAnonKey,
        driverName: driverName,
      );
      print('✅ Background notifications started');
    } catch (e) {
      print('Error starting background notifications: $e');
    }
  }
  
  // Stop background notifications
  Future<void> stopBackgroundNotifications() async {
    try {
      await BackgroundService.stop();
      print('✅ Background notifications stopped');
    } catch (e) {
      print('Error stopping background notifications: $e');
    }
  }

  // Load notifications from database
  // PERFORMANCE: Cache for 2 minutes on slow connections, refresh in background
  Future<void> _loadNotifications() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        print('No current user - skipping notification load');
        return;
      }

      final cacheKey = 'notifications_${currentUser.id}';

      // Check cache first (only on slow connections)
      if (_networkQuality.isSlowConnection) {
        final cached = _responseCache.get<List<Map<String, dynamic>>>(cacheKey);
        if (cached != null) {
          _notifications = cached;
          print('✅ Using cached notifications (${cached.length} items) - slow connection detected');
          notifyListeners();
          // Continue to refresh in background
        }
      }

      final response = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false)
          .limit(50);

      _notifications = List<Map<String, dynamic>>.from(response);

      // Cache for 2 minutes
      _responseCache.set(cacheKey, _notifications, const Duration(minutes: 2));
      print('Loaded ${_notifications.length} notifications');
    } catch (e) {
      _error = e.toString();
      print('Error loading notifications: $e');
      // Don't throw - just log
      _notifications = [];
    }
  }

  // Subscribe to real-time notification updates using persistent channel
  Future<void> _subscribeToNotifications() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      // Unsubscribe from previous channel if exists
      await _notificationChannel?.unsubscribe();

      print('📡 Setting up persistent realtime channel for notifications...');

      // Create a persistent realtime channel with WebSocket
      _notificationChannel = Supabase.instance.client
          .channel('notifications_${currentUser.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: currentUser.id,
            ),
            callback: (payload) async {
              print('🔔 Realtime INSERT notification received!');
              final notification = payload.newRecord;
              final notificationId = notification['id'] as String;
              final createdAtStr = notification['created_at'] as String;
              final createdAt = DateTime.parse(createdAtStr).toUtc();
              
              print('⏰ Notification created at: $createdAt (UTC)');
              print('⏰ App initialized at: $_initializationTime (UTC)');
              print('⏰ Time difference: ${createdAt.difference(_initializationTime!).inSeconds}s');
              
              // Show if not already shown (primary check)
              // AND created after initialization (prevents spam on reconnect)
              if (!_shownNotificationIds.contains(notificationId)) {
                // If created within last 5 minutes, show it (catches edge cases)
                final now = DateTime.now().toUtc();
                final ageInSeconds = now.difference(createdAt).inSeconds;
                
                if (ageInSeconds < 300) { // Less than 5 minutes old
                  _shownNotificationIds.add(notificationId);
                  print('📬 Showing notification: ${notification['title']} (age: ${ageInSeconds}s)');
                  await _showLocalNotification(notification);
                  
                  // Reload notifications list
                  await _loadNotifications();
                } else {
                  print('⏭️ Skipping old notification (age: ${ageInSeconds}s)');
                }
              } else {
                print('⏭️ Skipping duplicate notification: $notificationId');
              }
            },
          )
          .subscribe();

      print('✅ Realtime channel subscribed successfully');
      
      // Also set up periodic refresh as fallback (every 10 seconds)
      _startPeriodicRefresh(currentUser.id);
      
    } catch (e) {
      _error = e.toString();
      print('❌ Error subscribing to notifications: $e');
    }
  }

  // Periodic refresh as fallback (checks for missed notifications)
  // OPTIMIZED: Increased interval from 10s to 30s since Realtime subscription is primary method
  // PERFORMANCE: Skip on poor connections - trust realtime subscription instead
  // This reduces database load while maintaining reliability
  void _startPeriodicRefresh(String userId) {
    Future.delayed(const Duration(seconds: 30), () async {
      if (_notificationChannel != null) {
        // PERFORMANCE: Skip periodic refresh on poor connections - rely on realtime
        if (_networkQuality.currentQuality == NetworkQuality.poor) {
          print('⏭️ Skipping periodic refresh - poor connection, trusting realtime subscription');
          _startPeriodicRefresh(userId); // Continue timer
          return;
        }

        // Check for any unread notifications we might have missed
        try {
          final currentUser = Supabase.instance.client.auth.currentUser;
          if (currentUser != null) {
            // Only check notifications created in the last 5 minutes to reduce query size
            final fiveMinutesAgo = DateTime.now().toUtc().subtract(const Duration(minutes: 5));
            
            final response = await Supabase.instance.client
                .from('notifications')
                .select()
                .eq('user_id', currentUser.id)
                .eq('is_read', false)
                .gte('created_at', fiveMinutesAgo.toIso8601String())
                .order('created_at', ascending: false)
                .limit(10); // Limit to reduce query size

            for (var notification in response) {
              final notificationId = notification['id'] as String;
              
              // If we haven't shown this notification yet, show it now
              if (!_shownNotificationIds.contains(notificationId)) {
                final createdAtStr = notification['created_at'] as String;
                final createdAt = DateTime.parse(createdAtStr).toUtc();
                final now = DateTime.now().toUtc();
                final ageInSeconds = now.difference(createdAt).inSeconds;
                
                // Only show if less than 5 minutes old
                if (ageInSeconds < 300) {
                  print('🔍 Periodic check found missed notification: ${notification['title']}');
                  _shownNotificationIds.add(notificationId);
                  await _showLocalNotification(notification);
                }
              }
            }
          }
        } catch (e) {
          print('Error in periodic refresh: $e');
        }
        
        await _loadNotifications();
        _startPeriodicRefresh(userId); // Continue periodic refresh
      }
    });
  }

  // Called at init time to subscribe if a support conversation already exists.
  Future<void> _initSupportMessageListener() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;
      final existing = await Supabase.instance.client
          .from('conversations')
          .select('id')
          .eq('is_support', true)
          .eq('created_by', currentUser.id)
          .or('is_archived.is.null,is_archived.eq.false')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final convId = existing?['id'] as String?;
      if (convId != null && convId.isNotEmpty) {
        await startSupportMessageListener(convId);
      }
    } catch (e) {
      print('⚠️ Could not init support message listener: $e');
    }
  }

  /// Subscribe to admin replies in the user's support conversation and show
  /// an in-app banner when a new message arrives while the chat is not open.
  Future<void> startSupportMessageListener(String conversationId) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      await _supportMessageChannel?.unsubscribe();

      _supportMessageChannel = Supabase.instance.client
          .channel('support_msg_${currentUser.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: conversationId,
            ),
            callback: (payload) {
              final record = payload.newRecord;
              final senderId = record['sender_id'] as String?;
              // Only notify for messages from others (the AI agent / admin)
              if (senderId == currentUser.id) return;
              // Suppress banner while user is actively reading the chat
              if (MessagingService.instance.isViewingSupport) return;

              final body = (record['body'] as String? ?? '').trim();
              if (body.isEmpty) return;

              final context = GlobalOrderNotificationService.navigatorKey.currentContext;
              if (context == null || !context.mounted) return;

              try {
                HapticFeedback.mediumImpact();
              } catch (_) {}

              showHeaderNotification(
                context,
                title: 'دعم هور | Hur Support',
                message: body.length > 100 ? '${body.substring(0, 100)}…' : body,
                type: NotificationType.info,
              );
            },
          )
          .subscribe();

      print('✅ Support message listener active for conversation $conversationId');
    } catch (e) {
      print('❌ Error starting support message listener: $e');
    }
  }

  // Cleanup on dispose
  @override
  void dispose() {
    _notificationChannel?.unsubscribe();
    _supportMessageChannel?.unsubscribe();
    super.dispose();
  }

  // Show local notification using NotificationService
  Future<void> _showLocalNotification(Map<String, dynamic> notification) async {
    final type = notification['type'] as String;
    final title = notification['title'] as String;
    final body = notification['body'] as String;
    final orderId = notification['data']?['order_id'] as String?;
    
    try {
      // TODO: Fix notification handling - temporarily disabled due to signature mismatches
      print('📱 Would send notification type: $type');
      /*
      switch (type) {
        case 'order_assigned':
        case 'order_accepted':
        case 'order_rejected':
        case 'order_status_update':
        case 'order_delivered':
        case 'order_cancelled':
        default:
          // Notifications handled by FCM directly
          break;
      }
      */
    } catch (e) {
      print('Error showing local notification: $e');
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);

      // Update local list
      final index = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        _notifications[index]['is_read'] = true;
        _notifications[index]['read_at'] = DateTime.now().toIso8601String();
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
    }
  }

  // Mark all as read
  Future<void> markAllAsRead() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', currentUser.id)
          .eq('is_read', false);

      // Update local list
      for (var notification in _notifications) {
        notification['is_read'] = true;
        notification['read_at'] = DateTime.now().toIso8601String();
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

