import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

/// Handles session lifecycle: restoration, token refresh, periodic validity checks,
/// and the Supabase I/O side of force-logout.
/// Holds no Flutter state — callers supply callbacks for state mutations.
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  Timer? _sessionCheckTimer;
  bool _isLoggingOut = false;

  /// Checks the current session. If it is expired or about to expire, attempts
  /// a token refresh. Returns the valid [Session] or null if no valid session exists.
  Future<Session?> restoreSession() async {
    var session = Supabase.instance.client.auth.currentSession;
    if (session == null) return null;

    final expiresAt = session.expiresAt;
    if (expiresAt != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now >= expiresAt - 60000) {
        Logger.d('🔄 Session expired or expiring soon, attempting refresh...');
        try {
          final refreshed = await Supabase.instance.client.auth.refreshSession();
          if (refreshed.session != null) {
            Logger.d('✅ Session refreshed successfully');
            return refreshed.session;
          }
          Logger.d('⚠️ Session refresh failed - no new session returned');
          try {
            await Supabase.instance.client.auth.signOut();
          } catch (_) {}
          return null;
        } catch (e) {
          Logger.d('⚠️ Failed to refresh session: $e');
          final errorString = e.toString().toLowerCase();
          final isRefreshTokenError =
              errorString.contains('refresh_token_not_found') ||
              errorString.contains('refresh token not found') ||
              errorString.contains('invalid refresh token') ||
              errorString.contains('session_expired') ||
              errorString.contains('revoked by newer login');
          if (isRefreshTokenError || now > expiresAt) {
            Logger.d('⚠️ Refresh token invalid or session expired, signing out');
            try {
              await Supabase.instance.client.auth.signOut();
            } catch (_) {}
            return null;
          }
        }
      }
    }
    return session;
  }

  /// Attempts to refresh the current Supabase session token.
  /// Returns true if refresh succeeded.
  Future<bool> attemptRefresh() async {
    try {
      final currentSession = Supabase.instance.client.auth.currentSession;
      if (currentSession == null) {
        Logger.d('⚠️ No current session to refresh');
        return false;
      }
      Logger.d('🔄 Attempting to refresh session...');
      final refreshed = await Supabase.instance.client.auth.refreshSession();
      if (refreshed.session != null) {
        Logger.d('✅ Session refreshed successfully');
        return true;
      }
      Logger.d('⚠️ Session refresh returned null');
      return false;
    } catch (e) {
      Logger.d('❌ Failed to refresh session: $e');
      final errorString = e.toString().toLowerCase();
      final isRefreshTokenError =
          errorString.contains('refresh_token_not_found') ||
          errorString.contains('refresh token not found') ||
          errorString.contains('invalid refresh token') ||
          errorString.contains('session_expired') ||
          errorString.contains('revoked by newer login');
      if (isRefreshTokenError) {
        Logger.d('⚠️ Refresh token is invalid, clearing session');
        try {
          await Supabase.instance.client.auth.signOut();
        } catch (_) {}
      }
      return false;
    }
  }

  /// Queries the device_sessions table and calls [onForceLogout] if the current
  /// device's session is no longer active.
  Future<void> checkStatusDirectly({
    required String userId,
    required String deviceId,
    required void Function(String reason) onForceLogout,
  }) async {
    try {
      final result = await Supabase.instance.client
          .from('device_sessions')
          .select('is_active')
          .eq('user_id', userId)
          .eq('device_id', deviceId)
          .maybeSingle();

      if (result == null) {
        onForceLogout('device_logged_in_elsewhere'); // l10n key
      } else {
        final isActive = result['is_active'];
        if (isActive == false || isActive == null) {
          onForceLogout('device_logged_in_elsewhere'); // l10n key
        }
      }
    } catch (e) {
      if (e is PostgrestException && e.code == '401') {
        Logger.d('🔐 Session expired (401) - attempting refresh before logout...');
        final refreshed = await attemptRefresh();
        if (!refreshed) {
          onForceLogout('session_expired'); // l10n key
        } else {
          Logger.d('✅ Session refreshed, retrying session check...');
          Future.delayed(const Duration(milliseconds: 500), () {
            checkStatusDirectly(
              userId: userId,
              deviceId: deviceId,
              onForceLogout: onForceLogout,
            );
          });
        }
      } else if (e is AuthException &&
          (e.statusCode == '401' || (e.message?.contains('Unauthorized') ?? false))) {
        Logger.d('🔐 Unauthorized access (401) - attempting refresh before logout...');
        final refreshed = await attemptRefresh();
        if (!refreshed) {
          onForceLogout('session_expired'); // l10n key
        }
      }
    }
  }

  /// Starts a 15-second polling timer that calls [checkStatusDirectly] to
  /// detect whether the device session was invalidated by another login.
  void startPeriodicCheck({
    required String userId,
    required String deviceId,
    required void Function(String reason) onForceLogout,
  }) {
    _sessionCheckTimer?.cancel();
    _sessionCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      checkStatusDirectly(
        userId: userId,
        deviceId: deviceId,
        onForceLogout: onForceLogout,
      );
    });
    // Immediate check shortly after registration
    Future.delayed(const Duration(milliseconds: 500), () {
      checkStatusDirectly(
        userId: userId,
        deviceId: deviceId,
        onForceLogout: onForceLogout,
      );
    });
  }

  void stopPeriodicCheck() {
    _sessionCheckTimer?.cancel();
    _sessionCheckTimer = null;
  }

  /// Performs the Supabase I/O side of force-logout: marks the device session
  /// inactive via RPC then signs out.  Call this from the provider's
  /// `_forceLogout` after clearing local state.
  Future<void> performForceLogout({
    required String userId,
    required String? deviceId,
  }) async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;
    stopPeriodicCheck();
    if (deviceId != null) {
      try {
        await Supabase.instance.client.rpc('logout_device_session', params: {
          'p_user_id': userId,
          'p_device_id': deviceId,
        });
      } catch (_) {}
    }
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      Logger.d('⚠️ Error during force logout signOut: $e');
    }
    _isLoggingOut = false;
  }
}
