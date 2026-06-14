import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import 'error_manager.dart';

/// Manages per-order timeout state and the auto-reject heartbeat timer.
/// Holds no Flutter state — callers receive updates via the [onUpdate] callback.
class OrderTimeoutService {
  OrderTimeoutService._();
  static final OrderTimeoutService instance = OrderTimeoutService._();

  Timer? _autoRejectTimer;
  Timer? _timeoutStateUpdateTimer;

  Map<String, int> _timeoutStates = {};
  final Set<String> _timedOutOrders = {};

  // Cached user role to avoid repeated DB queries inside the 5 s tick
  String? _cachedUserRole;
  DateTime? _roleCacheTime;
  static const _roleCacheExpiry = Duration(minutes: 5);

  // ────────────────────────────── Public reads ──────────────────────────────

  int? getTimeoutRemaining(String orderId) => _timeoutStates[orderId];

  bool isTimedOut(String orderId) => _timedOutOrders.contains(orderId);

  void markTimedOut(String orderId) => _timedOutOrders.add(orderId);

  void clearTimedOut(String orderId) => _timedOutOrders.remove(orderId);

  /// Computes the live accept countdown for a pending order.
  /// Prefers the server-maintained [_timeoutStates] value; falls back to
  /// elapsed-time arithmetic using [assignedAt].
  int getLiveAcceptCountdown(String orderId, DateTime? assignedAt) {
    final fromState = _timeoutStates[orderId];
    if (fromState != null) return fromState;
    if (assignedAt == null) return 0;
    final elapsed = DateTime.now().difference(assignedAt).inSeconds;
    return (30 - elapsed).clamp(0, 30);
  }

  /// Removes timed-out markers for order IDs that no longer appear in the
  /// live order list (prevents memory growth).
  void removeStaleTimedOutOrders(Set<String> currentOrderIds) {
    _timedOutOrders.removeWhere((id) => !currentOrderIds.contains(id));
  }

  // ──────────────────────────── Timer management ────────────────────────────

  /// Starts the 5-second polling loop that refreshes per-driver timeout states.
  /// [onUpdate] is called with the new state map only when it differs from the
  /// previous one.
  void startTimeoutStateUpdater({
    required void Function(Map<String, int> newStates) onUpdate,
  }) {
    _timeoutStateUpdateTimer?.cancel();
    _timeoutStateUpdateTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) {
      unawaited(_tickTimeoutStateUpdate(onUpdate));
    });
  }

  /// Starts the 30-second timer that calls the auto-reject RPC.
  void startAutoRejectTimer() {
    _autoRejectTimer?.cancel();
    _autoRejectTimer =
        Timer.periodic(const Duration(seconds: 30), (timer) {
      unawaited(ErrorManager.safeExecute(
        operation: () async {
          await Supabase.instance.client
              .rpc('app_check_expired_orders')
              .timeout(const Duration(seconds: 5), onTimeout: () => null);
        },
        operationName: 'auto-reject-check',
        isCritical: false,
      ));
    });
  }

  void stopAutoRejectTimer() {
    _autoRejectTimer?.cancel();
    _autoRejectTimer = null;
  }

  void dispose() {
    stopAutoRejectTimer();
    _timeoutStateUpdateTimer?.cancel();
    _timeoutStateUpdateTimer = null;
  }

  // ─────────────────────────────── Internals ────────────────────────────────

  Future<void> _tickTimeoutStateUpdate(
    void Function(Map<String, int>) onUpdate,
  ) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      final role = await _getCachedUserRole(currentUser.id);
      if (role != 'driver') return;

      // Advance server-side countdown
      await Supabase.instance.client
          .rpc('update_order_timeout_states')
          .timeout(const Duration(seconds: 3), onTimeout: () {
        Logger.d('⚠️ Timeout state update timed out');
        return null;
      });

      // Fetch latest per-driver timeout states
      final response = await Supabase.instance.client
          .from('order_timeout_state')
          .select('order_id, remaining_seconds')
          .eq('driver_id', currentUser.id)
          .timeout(const Duration(seconds: 2), onTimeout: () {
        return <Map<String, dynamic>>[];
      });

      final Map<String, int> newStates = {};
      for (final row in response) {
        newStates[row['order_id'] as String] = row['remaining_seconds'] as int;
      }

      if (!mapEquals(newStates, _timeoutStates)) {
        _timeoutStates = newStates;
        onUpdate(_timeoutStates);
      }
    } catch (_) {
      // Silence errors to prevent log spam
    }
  }

  Future<String?> _getCachedUserRole(String userId) async {
    final now = DateTime.now();
    if (_cachedUserRole != null &&
        _roleCacheTime != null &&
        now.difference(_roleCacheTime!) < _roleCacheExpiry) {
      return _cachedUserRole;
    }
    final row = await Supabase.instance.client
        .from('users')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    _cachedUserRole = row?['role'] as String?;
    _roleCacheTime = now;
    return _cachedUserRole;
  }
}
