import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/test_env.dart';
import 'journeys/auth_journey_test.dart' as auth;
import 'journeys/cancellation_journey_test.dart' as cancellation;
import 'journeys/order_lifecycle_test.dart' as lifecycle;
import 'journeys/wallet_credit_test.dart' as wallet;

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  TestEnv.assertConfigured();

  await Supabase.initialize(
    url:     TestEnv.supabaseUrl,
    anonKey: TestEnv.supabaseAnonKey,
  );

  // Run each journey in isolation (each sets up + tears down its own state).
  auth.main();
  lifecycle.main();
  wallet.main();
  cancellation.main();
}
