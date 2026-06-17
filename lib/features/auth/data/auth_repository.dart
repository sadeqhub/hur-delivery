import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/analytics/analytics.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/logging/logger.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/user_model.dart';

/// Data layer for authentication and user-profile operations.
///
/// Replaces direct Supabase calls from [AuthProvider].
///
/// Pattern: AuthProvider → AuthRepository → ApiClient → Supabase
class AuthRepository {
  AuthRepository({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;
  static const String _tag = 'AuthRepository';

  // ─── Profile ───────────────────────────────────────────────────────────────

  /// Loads the current user's profile from the `users` table.
  /// Returns null if no profile exists yet.
  Future<UserModel?> getUserProfile(String userId) async {
    Logger.d(_tag, 'getUserProfile: ${Logger.redactId(userId)}');
    try {
      final row = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 20));
      return row != null ? UserModel.fromJson(row) : null;
    } catch (e, st) {
      Logger.e(_tag, 'getUserProfile failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  /// Updates the user's profile fields.
  Future<UserModel> updateUserProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    Logger.d(_tag, 'updateUserProfile: ${Logger.redactId(userId)}');
    try {
      final row = await _client
          .from('users')
          .update({...updates, 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', userId)
          .select()
          .single()
          .timeout(const Duration(seconds: 20));
      return UserModel.fromJson(row);
    } catch (e, st) {
      Logger.e(_tag, 'updateUserProfile failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  // ─── OTP ──────────────────────────────────────────────────────────────────

  /// Sends an OTP to the given phone number via the edge function.
  /// Phone must be in E.164 format.
  Future<bool> sendOtp({
    required String phoneE164,
    required String role,
  }) async {
    Logger.i(_tag, 'sendOtp: ${Logger.redactPhone(phoneE164)} role=$role');
    try {
      final result = await _client.invoke(
        'otp-handler-clean',
        body: {
          'action': 'send',
          'phone': phoneE164,
          'role': role,
        },
      );
      final success = result['success'] == true;
      if (success) {
        unawaited(Analytics.otpRequested(isRegistration: false));
      }
      return success;
    } on AppFailure {
      rethrow;
    } catch (e, st) {
      Logger.e(_tag, 'sendOtp failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  /// Verifies an OTP and returns a Supabase session on success.
  Future<AuthResponse> verifyOtp({
    required String phoneE164,
    required String otp,
    required String role,
  }) async {
    Logger.i(_tag, 'verifyOtp: ${Logger.redactPhone(phoneE164)}');
    try {
      final result = await _client.invoke(
        'otp-handler-clean',
        body: {
          'action': 'verify',
          'phone': phoneE164,
          'code': otp,
          'role': role,
        },
        timeout: const Duration(seconds: 20),
      );

      if (result['success'] != true) {
        final code = result['code'] as String? ?? 'invalid_otp';
        final reason = result['reason'] as String? ?? code;
        unawaited(Analytics.otpFailed(reason: reason));
        throw AppFailure.validation(code, hint: result['reason'] as String?);
      }

      unawaited(Analytics.otpVerified());

      // Session is returned in the response; set it in the Supabase client.
      final accessToken = result['access_token'] as String?;
      final refreshToken = result['refresh_token'] as String?;
      if (accessToken != null && refreshToken != null) {
        return await Supabase.instance.client.auth.setSession(refreshToken);
      }

      throw AppFailure.unknown('OTP verified but no session returned');
    } on AppFailure {
      rethrow;
    } catch (e, st) {
      Logger.e(_tag, 'verifyOtp failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  // ─── Device Sessions ──────────────────────────────────────────────────────

  /// Registers the current device in `device_sessions`.
  Future<void> registerDevice({
    required String userId,
    required String deviceId,
    required String platform,
    String? fcmToken,
  }) async {
    Logger.d(_tag, 'registerDevice: ${Logger.redactId(userId)}');
    try {
      await _client.from('device_sessions').upsert({
        'user_id': userId,
        'device_id': deviceId,
        'platform': platform,
        if (fcmToken != null) 'fcm_token': fcmToken,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'device_id').timeout(const Duration(seconds: 15));
    } catch (e) {
      Logger.w(_tag, 'registerDevice failed (non-critical)', error: e);
      // Intentionally not rethrowing — device registration failure is non-critical
    }
  }

  /// Checks whether a phone number exists in the `users` table.
  /// Returns only a boolean — does NOT expose name or role to unauthenticated callers.
  Future<bool> phoneExists(String phoneE164) async {
    Logger.d(_tag, 'phoneExists: ${Logger.redactPhone(phoneE164)}');
    try {
      final result = await _client.rpc<dynamic>(
        'check_phone_exists',
        params: {'phone_e164': phoneE164},
        timeout: const Duration(seconds: 10),
      );
      return result == true;
    } catch (e) {
      Logger.w(_tag, 'phoneExists failed', error: e);
      throw ErrorMapper.map(e);
    }
  }

  // ─── Sign-out ─────────────────────────────────────────────────────────────

  /// Signs out the current user from Supabase Auth.
  Future<void> signOut() async {
    Logger.i(_tag, 'signOut');
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      Logger.w(_tag, 'signOut failed', error: e);
      // Non-fatal: local session will be cleared regardless
    }
  }
}
