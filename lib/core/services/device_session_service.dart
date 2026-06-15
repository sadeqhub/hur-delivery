import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import 'device_manager.dart';
import 'session_service.dart';

/// Handles device-level session registration and monitoring.
/// Delegates periodic status checks to [SessionService].
/// Holds no Flutter state — callers supply force-logout callbacks.
class DeviceSessionService {
  DeviceSessionService._();
  static final DeviceSessionService instance = DeviceSessionService._();

  /// Registers this device session via the register_device_session RPC.
  /// Retries once after a 401 token-refresh; calls [onForceLogout] if refresh fails.
  Future<void> register({
    required String userId,
    required String deviceId,
    required void Function(String reason) onForceLogout,
  }) async {
    try {
      final deviceInfo = await DeviceManager.getDeviceInfo();
      await Supabase.instance.client.rpc('register_device_session', params: {
        'p_user_id': userId,
        'p_device_id': deviceId,
        'p_device_info': deviceInfo,
      });
    } catch (e) {
      Logger.d('Error registering device session: $e');
      if (e is PostgrestException && e.code == '401') {
        Logger.d(
            '🔐 Session expired during device registration - attempting refresh...');
        final refreshed = await SessionService.instance.attemptRefresh();
        if (refreshed) {
          Logger.d('✅ Session refreshed, retrying device registration...');
          Future.delayed(const Duration(milliseconds: 300), () {
            register(
                userId: userId,
                deviceId: deviceId,
                onForceLogout: onForceLogout);
          });
        } else {
          onForceLogout('انتهت صلاحية الجلسة');
        }
      } else if (e is AuthException &&
          (e.statusCode == '401' || e.message.contains('Unauthorized'))) {
        Logger.d(
            '🔐 Unauthorized access during device registration - attempting refresh...');
        final refreshed = await SessionService.instance.attemptRefresh();
        if (!refreshed) {
          onForceLogout('انتهت صلاحية الجلسة');
        }
      }
    }
  }

  /// Starts the 15-second polling loop (via [SessionService.startPeriodicCheck])
  /// that watches for the current device being deactivated by another login.
  void startMonitoring({
    required String userId,
    required String deviceId,
    required void Function(String reason) onForceLogout,
  }) {
    SessionService.instance.startPeriodicCheck(
      userId: userId,
      deviceId: deviceId,
      onForceLogout: onForceLogout,
    );
  }

  void stopMonitoring() {
    SessionService.instance.stopPeriodicCheck();
  }

  /// Processes raw stream rows from the device_sessions table.
  /// Calls [onForceLogout] if this device's session is no longer active.
  void checkSessionStatus(
    List<Map<String, dynamic>> data,
    String deviceId, {
    required void Function(String reason) onForceLogout,
  }) {
    final ourSession = data.firstWhere(
      (s) => s['device_id'] == deviceId,
      orElse: () => {},
    );
    if (ourSession.isNotEmpty) {
      final isActive = ourSession['is_active'];
      if (isActive == false || isActive == null) {
        onForceLogout('تم تسجيل الدخول من جهاز آخر');
      }
    }
  }
}
