import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/supabase_test_client.dart';
import '../helpers/test_env.dart';

/// Journey B — Full order lifecycle (realtime)
///
/// Merchant creates order → driver receives it (realtime subscription) →
/// driver accepts → on_the_way → delivered.
/// Asserts status transitions and that timestamps are set server-side.
void main() {
  group('Order Lifecycle Journey', () {
    late String merchantId;
    late String driverId;
    late String orderId;

    setUpAll(() async {
      // Sign in merchant to get merchant ID
      final mRes = await SupabaseTestClient.signInMerchant();
      merchantId = mRes.session!.user.id;
      await SupabaseTestClient.signOut();

      // Sign in driver to get driver ID
      final dRes = await SupabaseTestClient.signInDriver();
      driverId = dRes.session!.user.id;
      await SupabaseTestClient.signOut();
    });

    tearDown(() async {
      if (orderId.isNotEmpty) {
        // Clean up the test order
        await SupabaseTestClient.client
            .from('orders')
            .delete()
            .eq('id', orderId);
        orderId = '';
      }
      await SupabaseTestClient.signOut();
    });

    setUp(() {
      orderId = '';
    });

    test('B1 — merchant creates order; server enforces fee', () async {
      await SupabaseTestClient.signInMerchant();
      final client = SupabaseTestClient.client;

      final row = await client.from('orders').insert({
        'merchant_id':        merchantId,
        'customer_name':      'Test Customer',
        'customer_phone':     '+9647700009999',
        'pickup_address':     'Tahrir Square, Baghdad',
        'pickup_latitude':    TestEnv.pickupLat,
        'pickup_longitude':   TestEnv.pickupLng,
        'delivery_address':   'Karrada, Baghdad',
        'delivery_latitude':  TestEnv.dropoffLat,
        'delivery_longitude': TestEnv.dropoffLng,
        'total_amount':       0,
        'delivery_fee':       9999, // client-tampered value — must be overwritten
        'status':             'pending',
      }).select().single();

      orderId = row['id'] as String;

      // Trigger must have overwritten the fee with the server value (~2500 IQD)
      final serverFee = (row['delivery_fee'] as num).toDouble();
      expect(serverFee, isNot(equals(9999.0)),
          reason: 'Trigger must overwrite client-tampered fee');
      expect(serverFee, greaterThanOrEqualTo(1500.0));
      expect(serverFee, lessThanOrEqualTo(5000.0));
      expect(row['status'], equals('pending'));
    });

    test('B2 — driver receives order via realtime', () async {
      // Create the order as merchant
      await SupabaseTestClient.signInMerchant();
      final client = SupabaseTestClient.client;

      final row = await client.from('orders').insert({
        'merchant_id':        merchantId,
        'customer_name':      'Test Customer',
        'customer_phone':     '+9647700009999',
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
      await SupabaseTestClient.signOut();

      // Sign in as driver and subscribe to orders channel
      await SupabaseTestClient.signInDriver();
      var realtimeReceived = false;
      final channel = client.channel('test-orders-${DateTime.now().millisecondsSinceEpoch}');
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: orderId,
        ),
        callback: (payload) => realtimeReceived = true,
      ).subscribe(
        // ignore: avoid_redundant_argument_values — explicit to suppress unawaited_futures
      );

      // Dispatch assigns the order (simulate via direct update)
      await client
          .from('orders')
          .update({'status': 'assigned', 'driver_id': driverId})
          .eq('id', orderId);

      // Wait for realtime event
      await SupabaseTestClient.waitUntil(
        () async => realtimeReceived,
        timeout: const Duration(seconds: 10),
      );

      await channel.unsubscribe();
      expect(realtimeReceived, isTrue,
          reason: 'Driver should receive realtime update when order is assigned');
    });

    test('B3 — full status progression: assigned → accepted → on_the_way → delivered',
        () async {
      await SupabaseTestClient.signInMerchant();
      final client = SupabaseTestClient.client;

      final row = await client.from('orders').insert({
        'merchant_id':        merchantId,
        'customer_name':      'Test Customer',
        'customer_phone':     '+9647700009999',
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
      await SupabaseTestClient.signOut();

      await SupabaseTestClient.signInDriver();

      Future<Map<String, dynamic>> fetchOrder() async =>
          client.from('orders').select().eq('id', orderId).single();

      // assigned
      await client.from('orders').update({
        'status': 'assigned',
        'driver_id': driverId,
      }).eq('id', orderId);
      expect((await fetchOrder())['status'], equals('assigned'));

      // accepted
      await client.from('orders').update({'status': 'accepted'}).eq('id', orderId);
      final accepted = await fetchOrder();
      expect(accepted['status'], equals('accepted'));
      expect(accepted['accepted_at'], isNotNull,
          reason: 'accepted_at timestamp must be set by DB trigger');

      // on_the_way
      await client.from('orders').update({'status': 'on_the_way'}).eq('id', orderId);
      final onTheWay = await fetchOrder();
      expect(onTheWay['status'], equals('on_the_way'));
      expect(onTheWay['picked_up_at'], isNotNull,
          reason: 'picked_up_at timestamp must be set by DB trigger');

      // delivered
      await client.from('orders').update({'status': 'delivered'}).eq('id', orderId);
      final delivered = await fetchOrder();
      expect(delivered['status'], equals('delivered'));
      expect(delivered['delivered_at'], isNotNull,
          reason: 'delivered_at timestamp must be set by DB trigger');
    });
  });
}
