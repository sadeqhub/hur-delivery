import 'package:flutter_test/flutter_test.dart';

import '../helpers/supabase_test_client.dart';
import '../helpers/test_env.dart';

/// Journey C — Wallet credit on delivery
///
/// Completing an order credits the driver wallet with (fee - commission).
/// Asserts the wallet balance increases by the expected net amount.
void main() {
  group('Wallet Credit Journey', () {
    late String merchantId;
    late String driverId;
    late String orderId;
    double balanceBefore = 0;

    setUpAll(() async {
      final mRes = await SupabaseTestClient.signInMerchant();
      merchantId = mRes.session!.user.id;
      await SupabaseTestClient.signOut();

      final dRes = await SupabaseTestClient.signInDriver();
      driverId = dRes.session!.user.id;
      await SupabaseTestClient.signOut();
    });

    setUp(() {
      orderId = '';
    });

    tearDown(() async {
      if (orderId.isNotEmpty) {
        await SupabaseTestClient.client
            .from('orders')
            .delete()
            .eq('id', orderId);
      }
      await SupabaseTestClient.signOut();
    });

    test('C1 — wallet balance increases by (fee × (1 - commission)) on delivery',
        () async {
      await SupabaseTestClient.signInDriver();
      balanceBefore = await SupabaseTestClient.walletBalance(driverId);
      await SupabaseTestClient.signOut();

      // Merchant creates order
      await SupabaseTestClient.signInMerchant();
      final client = SupabaseTestClient.client;

      final row = await client.from('orders').insert({
        'merchant_id':        merchantId,
        'customer_name':      'Wallet Test Customer',
        'customer_phone':     '+9647700009998',
        'pickup_address':     'Tahrir Square, Baghdad',
        'pickup_latitude':    TestEnv.pickupLat,
        'pickup_longitude':   TestEnv.pickupLng,
        'delivery_address':   'Karrada, Baghdad',
        'delivery_latitude':  TestEnv.dropoffLat,
        'delivery_longitude': TestEnv.dropoffLng,
        'total_amount':       0,
        'delivery_fee':       0,
        'status':             'pending',
      }).select().single();

      orderId = row['id'] as String;
      final serverFee = (row['delivery_fee'] as num).toDouble();
      await SupabaseTestClient.signOut();

      // Driver: accept → on_the_way → delivered
      await SupabaseTestClient.signInDriver();
      await client.from('orders').update({
        'status': 'assigned',
        'driver_id': driverId,
      }).eq('id', orderId);
      await client.from('orders').update({'status': 'accepted'}).eq('id', orderId);
      await client.from('orders').update({'status': 'on_the_way'}).eq('id', orderId);
      await client.from('orders').update({'status': 'delivered'}).eq('id', orderId);

      // Allow async DB trigger to run
      await Future<void>.delayed(const Duration(seconds: 2));

      final balanceAfter = await SupabaseTestClient.walletBalance(driverId);
      final commission = await _fetchCommissionRate();
      final expectedCredit = serverFee * (1 - commission);

      expect(
        balanceAfter - balanceBefore,
        closeTo(expectedCredit, 5.0), // ±5 IQD rounding tolerance
        reason: 'Driver wallet must be credited fee × (1-commission) on delivery',
      );
    });
  });
}

Future<double> _fetchCommissionRate() async {
  final client = SupabaseTestClient.client;
  final row = await client
      .rpc<Map<String, dynamic>>('get_active_pricing_config');
  return (row['commission_rate'] as num?)?.toDouble() ?? 0.10;
}
