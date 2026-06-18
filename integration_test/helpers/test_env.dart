import 'dart:io';

/// Test environment constants.
///
/// All values are injected via --dart-define at test time:
///   flutter test integration_test/
///     --dart-define=SUPABASE_URL=...
///     --dart-define=SUPABASE_ANON_KEY=...
///     --dart-define=TEST_MODE=true
///
/// Never hard-code secrets here.
abstract final class TestEnv {
  TestEnv._();

  static const supabaseUrl =
      String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// When true, the otp-handler edge function accepts '123456' without
  /// calling the real OTP relay. NEVER enabled in production.
  static const testMode =
      bool.fromEnvironment('TEST_MODE');

  // Fixed test user phones (seeded by supabase/scripts/seed_test_data.sql)
  static const merchantPhone = '+9647700000001';
  static const driverPhone   = '+9647700000002';

  // Fixed OTP code accepted when TEST_MODE=true
  static const testOtp = '123456';

  // Baghdad coordinates for test orders
  // Pickup: Tahrir Square (~33.3406, 44.3932)
  // Dropoff: Karrada (~33.3152, 44.4009) — ~2.9 km, fee ~2500 IQD
  static const pickupLat  = 33.3406;
  static const pickupLng  = 44.3932;
  static const dropoffLat = 33.3152;
  static const dropoffLng = 44.4009;

  /// Throws if required env vars are not set, preventing silent failures.
  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      stderr.writeln(
        'INTEGRATION TEST ERROR: SUPABASE_URL and SUPABASE_ANON_KEY '
        'must be set via --dart-define. Aborting.',
      );
      exit(1);
    }
    if (!testMode) {
      stderr.writeln(
        'INTEGRATION TEST WARNING: TEST_MODE is not set to true. '
        'OTP tests will attempt to call the real OTP relay and will fail.',
      );
    }
  }
}
