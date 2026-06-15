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
      } catch (invokeError) {
        Logger.d('❌ [OtpService] Function invoke failed: $invokeError');
        if (invokeError.toString().contains('404') ||
            invokeError.toString().contains('not found') ||
            invokeError.toString().contains('Function not found')) {
          return const OtpSendResult(
            success: false,
            error: 'الدالة غير متاحة. الرجاء التأكد من نشر الدالة على Supabase.',
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
              error: 'الرجاء الانتظار $retry ثانية قبل إعادة الإرسال',
              retryAfterSeconds: retry,
            );
          }
          if (errorMsg != null && errorMsg.isNotEmpty) {
            return OtpSendResult(success: false, error: errorMsg);
          }
          return const OtpSendResult(
            success: false,
            error:
                'عذرًا لقد تجاوزت الحد المسموح من المحاولات. يرجى اعادة المحاولة لاحقًا.',
          );
        }
        return OtpSendResult(
          success: false,
          error: errorMsg?.isNotEmpty == true
              ? errorMsg!
              : 'فشل إرسال رمز التحقق، الرجاء المحاولة لاحقاً',
        );
      }

      Logger.d('✅ [OtpService] OTP sent successfully');
      return const OtpSendResult(success: true);
    } catch (e, stackTrace) {
      Logger.d('❌ [OtpService] sendOtp error: $e\n$stackTrace');
      String error;
      if (e.toString().contains('timeout') ||
          e.toString().contains('TimeoutException')) {
        error =
            'انتهت مهلة الطلب. يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى';
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('network')) {
        error =
            'خطأ في الاتصال بالإنترنت. يرجى التحقق من الاتصال والمحاولة مرة أخرى';
      } else if (e.toString().contains('404') ||
          e.toString().contains('not found')) {
        error = 'الدالة غير متاحة. الرجاء التأكد من نشر الدالة على Supabase.';
      } else {
        error = 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';
      }
      return OtpSendResult(success: false, error: error);
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
          error: (data?['error'] as String?) ?? 'فشل التحقق من رمز التحقق',
        );
      }

      final data = response.data as Map<String, dynamic>?;
      final success = data?['success'] as bool? ?? false;
      if (!success) {
        return OtpVerifyResult(
          success: false,
          error: (data?['error'] as String?) ?? 'رمز التحقق غير صحيح',
        );
      }

      final sessionData = data?['session'] as Map<String, dynamic>?;
      if (sessionData == null ||
          sessionData['access_token'] == null ||
          sessionData['refresh_token'] == null) {
        return const OtpVerifyResult(
          success: false,
          error: 'فشل التحقق: يرجى المحاولة مرة أخرى',
        );
      }

      Logger.d('✅ [OtpService] OTP verified, session received');
      return OtpVerifyResult(success: true, session: sessionData);
    } catch (e) {
      Logger.d('❌ [OtpService] verifyOtp error: $e');
      return const OtpVerifyResult(
        success: false,
        error: 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.',
      );
    }
  }
}
