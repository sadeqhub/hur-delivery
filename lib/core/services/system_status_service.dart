import 'package:supabase_flutter/supabase_flutter.dart';
import 'error_manager.dart';
import '../utils/logger.dart';

/// Service to check system status and handle maintenance mode.
/// Uses a Supabase Realtime subscription for instant change detection.
class SystemStatusService {
  static final SystemStatusService _instance = SystemStatusService._internal();
  factory SystemStatusService() => _instance;
  SystemStatusService._internal();

  final _supabase = Supabase.instance.client;

  bool _isSystemEnabled = true;
  /// Timestamp of the last successful fetch — used for cache-freshness checks.
  DateTime? _cachedAt;
  RealtimeChannel? _statusChannel;

  // Callbacks for status changes
  final List<Function(bool)> _statusChangeCallbacks = [];

  bool get isSystemEnabled => _isSystemEnabled;

  /// Returns true when the cached status is less than 60 seconds old.
  /// Callers can skip a fresh fetch when this is true (e.g. after waking from
  /// background while the realtime channel reconnects).
  bool get _isFresh =>
      _cachedAt != null &&
      DateTime.now().difference(_cachedAt!) < const Duration(seconds: 60);

  /// Start real-time listening for system_settings changes.
  /// Fetches the current status immediately on subscribe so the value is
  /// populated without waiting for the next change event.
  void startPeriodicChecking() {
    if (_statusChannel != null) return;

    Logger.d('🔄 Starting system status realtime listener...');

    // Primary: realtime change events on the system_settings row.
    _statusChannel = _supabase
        .channel('system_status_settings')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'system_settings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'key',
            value: 'system_enabled',
          ),
          callback: (payload) => _updateFromRecord(payload.newRecord),
        )
        .subscribe();

    // Fetch immediately so callers don't wait for a change event.
    checkSystemStatus();
  }

  /// Apply a status update from a realtime payload record.
  void _updateFromRecord(Map<String, dynamic> record) {
    final newValue = record['value'] as String?;
    final newStatus = newValue == 'true';
    if (newStatus == _isSystemEnabled) return;
    Logger.d(
        '🔔 System status changed via realtime: ${newStatus ? "ENABLED" : "DISABLED"}');
    _isSystemEnabled = newStatus;
    _cachedAt = DateTime.now();
    _notifyStatusChange(newStatus);
  }

  /// Stop realtime subscription.
  void stopPeriodicChecking() {
    _statusChannel?.unsubscribe();
    _statusChannel = null;
    Logger.d('⏹️ Stopped system status checks');
  }

  /// Check current system status.
  /// Skips the network round-trip when the cached value is fresh (< 60 s old),
  /// which avoids redundant fetches while the realtime channel reconnects after
  /// the app wakes from background.
  Future<bool> checkSystemStatus() async {
    if (_isFresh) return _isSystemEnabled;

    return await ErrorManager.safeExecute<bool>(
      operation: () async {
        final response = await _supabase
            .from('system_settings')
            .select('value')
            .eq('key', 'system_enabled')
            .maybeSingle();

        final newStatus = response?['value'] == 'true';

        // If status changed, notify callbacks
        if (newStatus != _isSystemEnabled) {
          Logger.d('🔔 System status changed: ${newStatus ? "ENABLED" : "DISABLED"}');
          _isSystemEnabled = newStatus;
          _notifyStatusChange(newStatus);
        }

        _isSystemEnabled = newStatus;
        _cachedAt = DateTime.now();

        return _isSystemEnabled;
      },
      operationName: 'check-system-status',
      isCritical: false, // Non-critical - assume enabled on error
      defaultValue: true, // On error, assume system is enabled to avoid blocking users
    ) ?? true;
  }

  /// Register a callback for status changes
  void onStatusChange(Function(bool) callback) {
    _statusChangeCallbacks.add(callback);
  }

  /// Remove a callback
  void removeStatusCallback(Function(bool) callback) {
    _statusChangeCallbacks.remove(callback);
  }

  /// Notify all callbacks of status change
  void _notifyStatusChange(bool isEnabled) {
    for (final callback in _statusChangeCallbacks) {
      try {
        callback(isEnabled);
      } catch (e) {
        Logger.d('Error in status change callback: $e');
      }
    }
  }

  /// Force refresh status
  Future<void> refresh() async {
    await checkSystemStatus();
  }

  /// Dispose resources
  void dispose() {
    stopPeriodicChecking();
    _statusChangeCallbacks.clear();
  }
}

