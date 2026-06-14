import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/background_service.dart';
import '../services/response_cache_service.dart';
import '../services/network_quality_service.dart';
import '../services/global_order_notification_service.dart';
import '../services/messaging_service.dart';
import '../constants/app_constants.dart';
import '../widgets/header_notification.dart';
import '../utils/logger.dart';

class NotificationState {
  final List<Map<String, dynamic>> notifications;
  final bool isLoading;
  final String? error;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
  });

  List<Map<String, dynamic>> get unreadNotifications =>
      notifications.where((n) => n['is_read'] == false).toList();

  int get unreadCount => unreadNotifications.length;

  NotificationState copyWith({
    List<Map<String, dynamic>>? notifications,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class NotificationNotifier extends AsyncNotifier<NotificationState> {
  final Set<String> _shownNotificationIds = {};
  DateTime? _initializationTime;
  RealtimeChannel? _notificationChannel;
  RealtimeChannel? _supportMessageChannel;

  final _responseCache = ResponseCacheService();
  final _networkQuality = NetworkQualityService();

  @override
  Future<NotificationState> build() async {
    ref.onDispose(() {
      _notificationChannel?.unsubscribe();
      _supportMessageChannel?.unsubscribe();
    });
    return const NotificationState();
  }

  // Initialize notifications
  Future<void> initialize() async {
    state = const AsyncData(NotificationState(isLoading: true));

    _initializationTime = DateTime.now().toUtc();
    Logger.d('NotificationNotifier initialized at: $_initializationTime (UTC)');

    try {
      await _loadNotifications();
      await _subscribeToNotifications();
      await _initSupportMessageListener();

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

      _setLoading(false);
    } catch (e) {
      final current = state.valueOrNull ?? const NotificationState();
      state = AsyncData(current.copyWith(isLoading: false, error: e.toString()));
      Logger.d('Error initializing notifications: $e');
    }
  }

  void _setLoading(bool loading) {
    final current = state.valueOrNull ?? const NotificationState();
    state = AsyncData(current.copyWith(isLoading: loading));
  }

  // Get user role from database
  Future<String> _getUserRole(String userId) async {
    final cacheKey = 'user_role_$userId';
    final cached = _responseCache.get<String>(cacheKey);
    if (cached != null) {
      Logger.d('Using cached user role: $cached');
      return cached;
    }

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', userId)
          .single();
      final role = response['role'] as String? ?? 'driver';
      _responseCache.set(cacheKey, role, const Duration(minutes: 5));
      Logger.d('Cached user role: $role');
      return role;
    } catch (e) {
      Logger.d('Error getting user role: $e');
      return 'driver';
    }
  }

  Future<bool> _getUserOnlineStatus(String userId) async {
    final cacheKey = 'user_online_$userId';
    final cached = _responseCache.get<bool>(cacheKey);
    if (cached != null) {
      Logger.d('Using cached online status: $cached');
      return cached;
    }

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('is_online')
          .eq('id', userId)
          .single();
      final isOnline = (response['is_online'] as bool?) ?? false;
      _responseCache.set(cacheKey, isOnline, const Duration(minutes: 1));
      Logger.d('Cached online status: $isOnline');
      return isOnline;
    } catch (e) {
      Logger.d('Error getting user online status: $e');
      return false;
    }
  }

  // Start background notifications
  Future<void> startBackgroundNotifications(String userId, String userRole,
      {String? driverName}) async {
    try {
      await BackgroundService.start(
        userId,
        userRole,
        AppConstants.supabaseUrl,
        AppConstants.supabaseAnonKey,
        driverName: driverName,
      );
      Logger.d('Background notifications started');
    } catch (e) {
      Logger.d('Error starting background notifications: $e');
    }
  }

  // Stop background notifications
  Future<void> stopBackgroundNotifications() async {
    try {
      await BackgroundService.stop();
      Logger.d('Background notifications stopped');
    } catch (e) {
      Logger.d('Error stopping background notifications: $e');
    }
  }

  // Load notifications from database
  Future<void> _loadNotifications() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        Logger.d('No current user - skipping notification load');
        return;
      }

      final cacheKey = 'notifications_${currentUser.id}';

      if (_networkQuality.isSlowConnection) {
        final cached = _responseCache.get<List<Map<String, dynamic>>>(cacheKey);
        if (cached != null) {
          final current = state.valueOrNull ?? const NotificationState();
          state = AsyncData(current.copyWith(notifications: cached));
          Logger.d(
              'Using cached notifications (${cached.length} items) - slow connection detected');
        }
      }

      final response = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false)
          .limit(50);

      final notifications = List<Map<String, dynamic>>.from(response);
      _responseCache.set(cacheKey, notifications, const Duration(minutes: 2));

      final current = state.valueOrNull ?? const NotificationState();
      state = AsyncData(current.copyWith(notifications: notifications));
      Logger.d('Loaded ${notifications.length} notifications');
    } catch (e) {
      final current = state.valueOrNull ?? const NotificationState();
      state = AsyncData(current.copyWith(
        notifications: const [],
        error: e.toString(),
      ));
      Logger.d('Error loading notifications: $e');
    }
  }

  // Subscribe to real-time notification updates using persistent channel
  Future<void> _subscribeToNotifications() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      await _notificationChannel?.unsubscribe();

      Logger.d('Setting up persistent realtime channel for notifications...');

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
              Logger.d('Realtime INSERT notification received!');
              final notification = payload.newRecord;
              final notificationId = notification['id'] as String;
              final createdAtStr = notification['created_at'] as String;
              final createdAt = DateTime.parse(createdAtStr).toUtc();

              Logger.d('Notification created at: $createdAt (UTC)');
              Logger.d('App initialized at: $_initializationTime (UTC)');
              Logger.d(
                  'Time difference: ${createdAt.difference(_initializationTime!).inSeconds}s');

              if (!_shownNotificationIds.contains(notificationId)) {
                final now = DateTime.now().toUtc();
                final ageInSeconds = now.difference(createdAt).inSeconds;

                if (ageInSeconds < 300) {
                  _shownNotificationIds.add(notificationId);
                  Logger.d(
                      'Showing notification: ${notification['title']} (age: ${ageInSeconds}s)');
                  await _showLocalNotification(notification);
                  await _loadNotifications();
                } else {
                  Logger.d('Skipping old notification (age: ${ageInSeconds}s)');
                }
              } else {
                Logger.d('Skipping duplicate notification: $notificationId');
              }
            },
          )
          .subscribe();

      Logger.d('Realtime channel subscribed successfully');
      _startPeriodicRefresh(currentUser.id);
    } catch (e) {
      final current = state.valueOrNull ?? const NotificationState();
      state = AsyncData(current.copyWith(error: e.toString()));
      Logger.d('Error subscribing to notifications: $e');
    }
  }

  void _startPeriodicRefresh(String userId) {
    Future.delayed(const Duration(seconds: 30), () async {
      if (_notificationChannel != null) {
        if (_networkQuality.currentQuality == NetworkQuality.poor) {
          Logger.d(
              'Skipping periodic refresh - poor connection, trusting realtime subscription');
          _startPeriodicRefresh(userId);
          return;
        }

        try {
          final currentUser = Supabase.instance.client.auth.currentUser;
          if (currentUser != null) {
            final fiveMinutesAgo =
                DateTime.now().toUtc().subtract(const Duration(minutes: 5));

            final response = await Supabase.instance.client
                .from('notifications')
                .select()
                .eq('user_id', currentUser.id)
                .eq('is_read', false)
                .gte('created_at', fiveMinutesAgo.toIso8601String())
                .order('created_at', ascending: false)
                .limit(10);

            for (var notification in response) {
              final notificationId = notification['id'] as String;

              if (!_shownNotificationIds.contains(notificationId)) {
                final createdAtStr = notification['created_at'] as String;
                final createdAt = DateTime.parse(createdAtStr).toUtc();
                final now = DateTime.now().toUtc();
                final ageInSeconds = now.difference(createdAt).inSeconds;

                if (ageInSeconds < 300) {
                  Logger.d(
                      'Periodic check found missed notification: ${notification['title']}');
                  _shownNotificationIds.add(notificationId);
                  await _showLocalNotification(notification);
                }
              }
            }
          }
        } catch (e) {
          Logger.d('Error in periodic refresh: $e');
        }

        await _loadNotifications();
        _startPeriodicRefresh(userId);
      }
    });
  }

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
      Logger.d('Could not init support message listener: $e');
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
              if (senderId == currentUser.id) return;
              if (MessagingService.instance.isViewingSupport) return;

              final body = (record['body'] as String? ?? '').trim();
              if (body.isEmpty) return;

              final context =
                  GlobalOrderNotificationService.navigatorKey.currentContext;
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

      Logger.d('Support message listener active for conversation $conversationId');
    } catch (e) {
      Logger.d('Error starting support message listener: $e');
    }
  }

  Future<void> _showLocalNotification(Map<String, dynamic> notification) async {
    final type = notification['type'] as String;
    try {
      // TODO: Fix notification handling - temporarily disabled due to signature mismatches
      Logger.d('Would send notification type: $type');
    } catch (e) {
      Logger.d('Error showing local notification: $e');
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);

      final current = state.valueOrNull ?? const NotificationState();
      final updated = current.notifications.map((n) {
        if (n['id'] == notificationId) {
          return {
            ...n,
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          };
        }
        return n;
      }).toList();

      state = AsyncData(current.copyWith(notifications: updated));
    } catch (e) {
      final current = state.valueOrNull ?? const NotificationState();
      state = AsyncData(current.copyWith(error: e.toString()));
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

      final current = state.valueOrNull ?? const NotificationState();
      final updated = current.notifications.map((n) {
        return {
          ...n,
          'is_read': true,
          'read_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      state = AsyncData(current.copyWith(notifications: updated));
    } catch (e) {
      final current = state.valueOrNull ?? const NotificationState();
      state = AsyncData(current.copyWith(error: e.toString()));
    }
  }

  // Clear error
  void clearError() {
    final current = state.valueOrNull ?? const NotificationState();
    state = AsyncData(current.copyWith(clearError: true));
  }
}

final notificationProvider =
    AsyncNotifierProvider<NotificationNotifier, NotificationState>(
        NotificationNotifier.new);
