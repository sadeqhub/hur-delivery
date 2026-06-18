import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/supabase_test_client.dart';
import '../helpers/test_env.dart';

/// Journey A — Login OTP flow
///
/// a. OTP happy path (correct code → session established)
/// b. Wrong-code error (incorrect code → error returned, no session)
/// c. Attempt lockout message (>5 wrong codes → locked out)
void main() {
  group('Auth Journey — OTP login', () {
    tearDown(() async {
      await SupabaseTestClient.signOut();
    });

    test('A1 — happy path: correct OTP yields a valid session', () async {
      final res = await SupabaseTestClient.signInMerchant();
      expect(res.session, isNotNull,
          reason: 'Expected a session after correct OTP');
      expect(res.session!.user.phone, equals(TestEnv.merchantPhone));
    });

    test('A2 — wrong OTP returns an error, no session created', () async {
      final client = SupabaseTestClient.client;
      await client.auth.signInWithOtp(phone: TestEnv.merchantPhone);

      expect(
        () async => client.auth.verifyOTP(
          phone: TestEnv.merchantPhone,
          token: '000000', // wrong code
          type: OtpType.sms,
        ),
        throwsA(isA<AuthException>()),
        reason: 'Wrong OTP must throw AuthException',
      );
      expect(client.auth.currentSession, isNull,
          reason: 'No session should be created after wrong OTP');
    });

    test('A3 — rate-limit: repeated wrong OTPs trigger lockout response',
        () async {
      if (!TestEnv.testMode) {
        // Skip: would hammer the real OTP relay
        markTestSkipped(
            'TEST_MODE not enabled — skipping lockout test to protect OTP relay');
        return;
      }

      final client = SupabaseTestClient.client;
      await client.auth.signInWithOtp(phone: TestEnv.driverPhone);

      AuthException? lastError;
      for (var i = 0; i < 6; i++) {
        try {
          await client.auth.verifyOTP(
            phone: TestEnv.driverPhone,
            token: '000000',
            type: OtpType.sms,
          );
        } on AuthException catch (e) {
          lastError = e;
        }
      }

      expect(lastError, isNotNull, reason: 'Expected an error after 6 attempts');
      // The otp-handler-clean edge function returns 429 or a lockout message
      // after exceeding max_attempts (defined in the DB rate-limit logic).
      expect(
        lastError!.message.toLowerCase(),
        anyOf(contains('locked'), contains('too many'), contains('rate')),
        reason: 'Error message should indicate lockout',
      );
    });
  });
}
