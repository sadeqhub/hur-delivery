import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'error_manager.dart';
import '../utils/logger.dart';
import '../realtime/realtime_manager.dart';

/// Service to check system status and handle maintenance mode
class SystemStatusService {
  static final SystemStatusService _instance = SystemStatusService._internal();
  factory SystemStatusService() => _instance;
  SystemStatusService._internal();

  final _supabase = Supabase.instance.client;
  
  bool _isSystemEnabled = true;
  DateTime? _lastCheck;
  Timer? _checkTimer;
  RealtimeChannel? _statusChannel;

  // Callbacks for status changes
  final List<Function(bool)> _statusChangeCallbacks = [];
  
  bool get isSystemEnabled => _isSystemEnabled;

  /// Start real-time listening for system_settings changes.
  /// Falls back to a 30-second poll when Realtime is not available.
  void startPeriodicChecking() {
    if (_checkTimer != null || _statusChannel != null) return;

    Logger.d('🔄 Starting system status realtime listener...');
    checkSystemStatus();

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
          callback: (payload) {
            final newValue = payload.newRecord['value'] as String?;
            final newStatus = newValue == 'true';
            if (newStatus == _isSystemEnabled) return;
            Logger.d('🔔 System status changed via realtime: ${newStatus ? "ENABLED" : "DISABLED"}');
            _isSystemEnabled = newStatus;
            _notifyStatusChange(newStatus);
          },
        )
        .subscribe((status, error) {
          // Start fallback poll if the WebSocket fails to connect.
          if ((error != null || status == 'CLOSED') &&
              RealtimeManager.instance.isDisabled) {
            _checkTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
              checkSystemStatus();
            });
          }
        });

    // Immediate fallback when realtime is known-disabled at startup.
    if (RealtimeManager.instance.isDisabled) {
      _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        checkSystemStatus();
      });
    }
  }

  /// Stop periodic checking and realtime subscription.
  void stopPeriodicChecking() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _statusChannel?.unsubscribe();
    _statusChannel = null;
    Logger.d('⏹️ Stopped system status checks');
  }

  /// Check current system status
  Future<bool> checkSystemStatus() async {
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
        _lastCheck = DateTime.now();
        
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

