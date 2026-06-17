import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

class OtpSendResult {
  final bool success;
  final String? error;
  final int? retryAfterSeconds;
  const OtpSendResult({required this.success, this.error, this.retryAfterSeconds});
}

class OtpVerifyResult {
  final bool success;
  final String? error;
  final Map<String, dynamic>? session;
  const OtpVerifyResult({required this.success, this.error, this.session});
}

/// Handles OTP send/verify via the otp-handler-clean Edge Function.
/// Holds no Flutter state — results are returned as value objects.
class OtpService {
  OtpService._();
  static final OtpService instance = OtpService._();

  /// Sends an OTP to [cleanedPhone] (digits only, no +) for the given [purpose].
  Future<OtpSendResult> sendOtp(String cleanedPhone, {String purpose = 'signup'}) async {
    Logger.d('📤 [OtpService] Sending OTP to $cleanedPhone, purpose=$purpose');
    try {
      FunctionResponse response;
      try {
        response = await Supabase.instance.client.functions
            .invoke(
              'otp-handler-clean',
              body: {
                'action': 'send',
                'phoneNumber': cleanedPhone,
                'purpose': purpose,
              },
            )
            .timeout(const Duration(seconds: 30));
      } on FunctionException catch (e) {
        Logger.d('❌ [OtpService] Function invoke failed: $e');
        if (e.status == 404 || (e.details?.toString().contains('not found') ?? false)) {
          return const OtpSendResult(
            success: false,
            error: 'otp_function_not_found', // l10n key
          );
        }
        rethrow;
      }

      Logger.d('✅ [OtpService] OTP send response status: ${response.status}');
      if (response.status != 200) {
        final data = response.data as Map<String, dynamic>?;
        final errorMsg = data?['error'] as String?;
        if (response.status == 429) {
          final retry = (data?['retry_after'] is num)
              ? (data!['retry_after'] as num).toInt()
              : null;
          if (retry != null && retry > 0) {
            return OtpSendResult(
              success: false,
              error: 'otp_rate_limit_seconds:$retry', // l10n key with seconds suffix
              retryAfterSeconds: retry,
            );
          }
          if (errorMsg != null && errorMsg.isNotEmpty) {
            return OtpSendResult(success: false, error: errorMsg);
          }
          return const OtpSendResult(
            success: false,
            error: 'otp_rate_limit_exceeded', // l10n key
          );
        }
        return OtpSendResult(
          success: false,
          error: errorMsg?.isNotEmpty == true
              ? errorMsg!
              : 'otp_send_failed', // l10n key
        );
      }

      Logger.d('✅ [OtpService] OTP sent successfully');
      return const OtpSendResult(success: true);
    } on TimeoutException catch (_) {
      return const OtpSendResult(
        success: false,
        error: 'otp_request_timeout', // l10n key
      );
    } on SocketException catch (_) {
      return const OtpSendResult(
        success: false,
        error: 'otp_network_error', // l10n key
      );
    } on FunctionException catch (e) {
      Logger.d('❌ [OtpService] sendOtp FunctionException: $e');
      if (e.status == 404 || (e.details?.toString().contains('not found') ?? false)) {
        return const OtpSendResult(
          success: false,
          error: 'otp_function_not_found', // l10n key
        );
      }
      return const OtpSendResult(success: false, error: 'otp_unexpected_error'); // l10n key
    } catch (e, stackTrace) {
      Logger.d('❌ [OtpService] sendOtp error: $e\n$stackTrace');
      return const OtpSendResult(success: false, error: 'otp_unexpected_error'); // l10n key
    }
  }

  /// Verifies [code] for [cleanedPhone] (digits only) via Edge Function.
  /// On success, [OtpVerifyResult.session] contains the raw session map.
  Future<OtpVerifyResult> verifyOtp(String cleanedPhone, String code) async {
    Logger.d('📤 [OtpService] Verifying OTP for $cleanedPhone');
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'otp-handler-clean',
        body: {
          'action': 'authenticate',
          'phoneNumber': cleanedPhone,
          'code': code,
        },
      );

      Logger.d('✅ [OtpService] authenticate response status: ${response.status}');
      if (response.status != 200) {
        final data = response.data as Map<String, dynamic>?;
        return OtpVerifyResult(
          success: false,
          error: (data?['error'] as String?) ?? 'otp_verify_failed', // l10n key
        );
      }

      final data = response.data as Map<String, dynamic>?;
      final success = data?['success'] as bool? ?? false;
      if (!success) {
        return OtpVerifyResult(
          success: false,
          error: (data?['error'] as String?) ?? 'otp_invalid_code', // l10n key
        );
      }

      final sessionData = data?['session'] as Map<String, dynamic>?;
      if (sessionData == null ||
          sessionData['access_token'] == null ||
          sessionData['refresh_token'] == null) {
        return const OtpVerifyResult(
          success: false,
          error: 'otp_verify_failed', // l10n key
        );
      }

      Logger.d('✅ [OtpService] OTP verified, session received');
      return OtpVerifyResult(success: true, session: sessionData);
    } catch (e) {
      Logger.d('❌ [OtpService] verifyOtp error: $e');
      return const OtpVerifyResult(
        success: false,
        error: 'otp_unexpected_error', // l10n key
      );
    }
  }
}
