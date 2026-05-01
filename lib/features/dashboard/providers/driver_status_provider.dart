import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/notification_provider.dart';

/// Single source of truth for the driver's online/offline status.
///
/// Replaces the three conflicting sources that existed in the old monolith:
///   1. `_isOnline` local widget state
///   2. `authProvider.user.isOnline`
///   3. Supabase `users.is_online` column
///
/// Any component that needs the driver's status reads [isOnline] from this
/// provider and calls [setOnline] to change it.  The realtime subscription
/// and 15 s fallback poll both update only this provider, which then
/// notifyListeners() — preventing the cascading multi-source divergence.
class DriverStatusProvider extends ChangeNotifier {
  bool _isOnline = false;
  bool _initialized = false;
  String? _userId;

  Timer? _statusCheckTimer;
  RealtimeChannel? _onlineStatusChannel;

  /// Callbacks invoked when the driver goes online / offline so callers
  /// (e.g. DriverLocationManager) can react without coupling to this provider.
  VoidCallback? onWentOnline;
  VoidCallback? onWentOffline;

  bool get isOnline => _isOnline;
  bool get initialized => _initialized;

  // ---------------------------------------------------------------------------
  // Init / Dispose
  // ---------------------------------------------------------------------------

  Future<void> initialize(AuthProvider authProvider) async {
    _userId = authProvider.user?.id;
    if (_userId == null) return;

    _isOnline = authProvider.user?.isOnline ?? false;
    _initialized = true;
    notifyListeners();

    _subscribeToRealtime();
    _startStatusCheckTimer(authProvider);
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _onlineStatusChannel?.unsubscribe();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Atomically update the driver's status in the DB and local state.
  ///
  /// Returns true on success. On failure the local state is rolled back and
  /// the caller can show an error.
  Future<bool> setOnline(
    bool value, {
    required AuthProvider authProvider,
    NotificationProvider? notificationProvider,
  }) async {
    final previous = _isOnline;

    // Optimistic update so the UI feels instant.
    _isOnline = value;
    notifyListeners();

    try {
      await authProvider.setOnlineStatus(value);

      if (value) {
        if (authProvider.user != null && notificationProvider != null) {
          await notificationProvider.startBackgroundNotifications(
            authProvider.user!.id,
            authProvider.user!.role,
            driverName: authProvider.user!.name,
          );
        }
        onWentOnline?.call();
      } else {
        if (notificationProvider != null) {
          await notificationProvider.stopBackgroundNotifications();
        }
        onWentOffline?.call();
      }

      return true;
    } catch (e) {
      // Roll back optimistic update.
      _isOnline = previous;
      notifyListeners();
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Realtime subscription
  // ---------------------------------------------------------------------------

  void _subscribeToRealtime() {
    _onlineStatusChannel?.unsubscribe();
    if (_userId == null) return;

    _onlineStatusChannel = Supabase.instance.client
        .channel('driver_online_status_$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _userId!,
          ),
          callback: (payload) {
            final dbOnline = payload.newRecord['is_online'] as bool? ?? false;
            if (dbOnline == _isOnline) return;

            _isOnline = dbOnline;
            notifyListeners();

            if (dbOnline) {
              onWentOnline?.call();
            } else {
              onWentOffline?.call();
            }
          },
        )
        .subscribe();
  }

  // ---------------------------------------------------------------------------
  // 15 s fallback poll (catches missed realtime events)
  // ---------------------------------------------------------------------------

  void _startStatusCheckTimer(AuthProvider authProvider) {
    _statusCheckTimer?.cancel();
    if (_userId == null) return;

    _statusCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        final data = await Supabase.instance.client
            .from('users')
            .select('is_online')
            .eq('id', _userId!)
            .single();
        final dbOnline = data['is_online'] as bool? ?? false;
        if (dbOnline == _isOnline) return;

        _isOnline = dbOnline;
        notifyListeners();

        if (dbOnline) {
          onWentOnline?.call();
        } else {
          onWentOffline?.call();
        }
      } catch (_) {}
    });
  }
}
