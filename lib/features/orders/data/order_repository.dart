import 'dart:async';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/analytics/analytics.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/logging/logger.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/models/order_status.dart';

/// Data layer for all order operations.
///
/// Replaces direct `Supabase.instance.client` calls from [OrderProvider].
/// All exceptions are mapped to [AppFailure] before propagating.
///
/// ## Pattern
///   OrderProvider → OrderRepository → ApiClient → Supabase
///
/// The provider holds state (orders list, loading flags, errors).
/// The repository holds no state — it only performs DB operations.
///
/// ## Migration status
///   - Phase P2.2: This repository is being introduced.
///   - [OrderProvider] will be migrated to call these methods iteratively.
///   - Direct Supabase calls in [OrderProvider] are removed one batch at a time.
class OrderRepository {
  OrderRepository({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;
  static const String _tag = 'OrderRepository';

  // ─── Queries ──────────────────────────────────────────────────────────────

  /// Loads all active orders for the authenticated merchant.
  Future<List<OrderModel>> getMerchantOrders(String merchantId) async {
    Logger.d(_tag, 'getMerchantOrders: ${Logger.redactId(merchantId)}');
    try {
      final rows = await _client
          .from('orders')
          .select('''
            *,
            order_items (*)
          ''')
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 20));

      return (rows as List)
          .map((row) => OrderModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      Logger.e(_tag, 'getMerchantOrders failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  /// Loads the currently active (non-terminal) order for a driver.
  Future<OrderModel?> getActiveDriverOrder(String driverId) async {
    Logger.d(_tag, 'getActiveDriverOrder: ${Logger.redactId(driverId)}');
    try {
      final row = await _client
          .from('orders')
          .select('*, order_items (*)')
          .eq('driver_id', driverId)
          .not('status', 'in', '(delivered,cancelled)')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 20));

      return row != null ? OrderModel.fromJson(row) : null;
    } catch (e, st) {
      Logger.e(_tag, 'getActiveDriverOrder failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  /// Loads a single order by ID.
  Future<OrderModel> getOrder(String orderId) async {
    Logger.d(_tag, 'getOrder: ${Logger.redactId(orderId)}');
    try {
      final row = await _client
          .from('orders')
          .select('*, order_items (*)')
          .eq('id', orderId)
          .single()
          .timeout(const Duration(seconds: 20));
      return OrderModel.fromJson(row);
    } catch (e, st) {
      Logger.e(_tag, 'getOrder failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  // ─── Mutations ─────────────────────────────────────────────────────────────

  /// Creates a new order. Returns the created [OrderModel].
  /// Blocks in demo mode.
  Future<OrderModel> createOrder({
    required Map<String, dynamic> orderData,
    bool isDemoMode = false,
  }) async {
    if (isDemoMode) {
      Logger.d(_tag, 'createOrder blocked in demo mode');
      throw const AppFailure.unauthorized();
    }
    Logger.d(_tag, 'createOrder');
    try {
      final rows = await _client
          .from('orders')
          .insert(orderData)
          .select('*, order_items (*)')
          .single()
          .timeout(const Duration(seconds: 30));
      final order = OrderModel.fromJson(rows);
      // Fire analytics event after successful creation (non-blocking)
      final distanceKm = (orderData['distance_km'] as num?)?.toDouble() ?? 0.0;
      final fee = (orderData['delivery_fee'] as num?)?.toDouble() ?? 0.0;
      unawaited(Analytics.orderCreated(
        orderId: order.id,
        distanceBand: Analytics.distanceBand(distanceKm),
        feeBand: Analytics.feeBand(fee),
      ));
      return order;
    } catch (e, st) {
      Logger.e(_tag, 'createOrder failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  /// Updates the order status. Server RLS enforces allowed transitions.
  ///
  /// Throws [AppFailure.unauthorized] if the transition is not permitted.
  Future<void> updateOrderStatus(
    String orderId,
    OrderStatus newStatus, {
    Map<String, dynamic> extraFields = const {},
    bool isDemoMode = false,
  }) async {
    if (isDemoMode) {
      Logger.d(_tag, 'updateOrderStatus blocked in demo mode');
      return;
    }
    Logger.d(_tag, 'updateOrderStatus: ${Logger.redactId(orderId)} → ${newStatus.toDb()}');
    try {
      final updates = {
        'status': newStatus.toDb(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...extraFields,
      };
      await _client
          .from('orders')
          .update(updates)
          .eq('id', orderId)
          .timeout(const Duration(seconds: 20));
    } catch (e, st) {
      Logger.e(_tag, 'updateOrderStatus failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  /// Driver accepts an assigned order.
  Future<void> acceptOrder(String orderId, {bool isDemoMode = false}) async {
    await updateOrderStatus(
      orderId,
      OrderStatus.accepted,
      extraFields: {
        'accepted_at': DateTime.now().toUtc().toIso8601String(),
      },
      isDemoMode: isDemoMode,
    );
    unawaited(Analytics.orderAccepted(orderId: orderId));
  }

  /// Driver marks order as on the way to merchant.
  Future<void> markOnTheWay(String orderId, {bool isDemoMode = false}) =>
      updateOrderStatus(orderId, OrderStatus.onTheWay, isDemoMode: isDemoMode);

  /// Driver confirms pick-up of goods.
  Future<void> markPickedUp(String orderId, {bool isDemoMode = false}) async {
    await updateOrderStatus(
      orderId,
      OrderStatus.pickedUp,
      extraFields: {
        'picked_up_at': DateTime.now().toUtc().toIso8601String(),
      },
      isDemoMode: isDemoMode,
    );
    unawaited(Analytics.orderPickedUp(orderId: orderId));
  }

  /// Driver marks order as delivered.
  Future<void> markDelivered(String orderId, {bool isDemoMode = false}) async {
    await updateOrderStatus(
      orderId,
      OrderStatus.delivered,
      extraFields: {
        'delivered_at': DateTime.now().toUtc().toIso8601String(),
      },
      isDemoMode: isDemoMode,
    );
    unawaited(Analytics.orderDelivered(
      orderId: orderId,
      feeBand: 'unknown', // fee not available at this call site; DB has it
    ));
  }

  /// Cancels an order. Only allowed from non-terminal statuses.
  Future<void> cancelOrder(
    String orderId, {
    String? reason,
    String cancelledBy = 'merchant',
    bool isDemoMode = false,
  }) async {
    if (isDemoMode) {
      Logger.d(_tag, 'cancelOrder blocked in demo mode');
      return;
    }
    Logger.d(_tag, 'cancelOrder: ${Logger.redactId(orderId)}');
    try {
      await _client
          .from('orders')
          .update({
            'status': OrderStatus.cancelled.toDb(),
            'cancellation_reason': reason,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', orderId)
          .timeout(const Duration(seconds: 20));
      unawaited(Analytics.orderCancelled(
        orderId: orderId,
        reason: reason ?? 'no_reason',
        cancelledBy: cancelledBy,
      ));
    } catch (e, st) {
      Logger.e(_tag, 'cancelOrder failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  // ─── Location ────────────────────────────────────────────────────────────

  /// Returns the most recent driver location from the materialized view.
  /// Returns null if no location record exists.
  Future<Map<String, dynamic>?> getDriverLocation(String driverId) async {
    Logger.d(_tag, 'getDriverLocation: ${Logger.redactId(driverId)}');
    try {
      final row = await _client
          .from('recent_driver_locations')
          .select()
          .eq('driver_id', driverId)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));
      return row;
    } catch (e, st) {
      Logger.e(_tag, 'getDriverLocation failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  // ─── Storage ─────────────────────────────────────────────────────────────

  /// Returns a signed URL (valid for [expiresInSeconds]) for an order proof file.
  Future<String> createOrderProofSignedUrl(
    String storagePath, {
    int expiresInSeconds = 600,
  }) async {
    Logger.d(_tag, 'createOrderProofSignedUrl: $storagePath');
    try {
      return await Supabase.instance.client.storage
          .from('order_proofs')
          .createSignedUrl(storagePath, expiresInSeconds);
    } catch (e, st) {
      Logger.e(_tag, 'createOrderProofSignedUrl failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  // ─── Merchant helpers ────────────────────────────────────────────────────

  /// Returns the merchant's city for driver-availability lookups.
  Future<String?> getMerchantCity(String merchantId) async {
    Logger.d(_tag, 'getMerchantCity: ${Logger.redactId(merchantId)}');
    try {
      final row = await _client
          .from('users')
          .select('city')
          .eq('id', merchantId)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));
      return (row?['city'] as String?)?.trim();
    } catch (e, st) {
      Logger.e(_tag, 'getMerchantCity failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  /// Returns drivers that are online and located in [city].
  Future<List<Map<String, dynamic>>> getOnlineDriversInCity(String city) async {
    Logger.d(_tag, 'getOnlineDriversInCity: $city');
    try {
      final rows = await _client
          .from('users')
          .select('id, name, is_online, manual_verified')
          .eq('role', 'driver')
          .eq('is_online', true)
          .ilike('city', city)
          .timeout(const Duration(seconds: 10));
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e, st) {
      Logger.e(_tag, 'getOnlineDriversInCity failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  /// Returns all drivers (any online status) in [city] — for diagnostic logging.
  Future<List<Map<String, dynamic>>> getAllDriversInCity(String city) async {
    Logger.d(_tag, 'getAllDriversInCity: $city');
    try {
      final rows = await _client
          .from('users')
          .select('id, name, is_online, manual_verified, role')
          .eq('role', 'driver')
          .ilike('city', city)
          .timeout(const Duration(seconds: 10));
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e, st) {
      Logger.e(_tag, 'getAllDriversInCity failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  /// Returns driver_id values for orders in active statuses filtered to [driverIds].
  Future<List<String>> getBusyDriverIds(List<String> driverIds) async {
    Logger.d(_tag, 'getBusyDriverIds: ${driverIds.length} drivers');
    try {
      final rows = await _client
          .from('orders')
          .select('driver_id')
          .inFilter('driver_id', driverIds)
          .inFilter('status', ['pending', 'assigned', 'accepted', 'on_the_way'])
          .timeout(const Duration(seconds: 10));
      return (rows as List)
          .map((r) => r['driver_id'] as String?)
          .whereType<String>()
          .toList();
    } catch (e, st) {
      Logger.e(_tag, 'getBusyDriverIds failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  /// Returns active orders for [merchantId] that have an assigned driver,
  /// with nested driver name for the "assign to same driver" UI.
  Future<List<Map<String, dynamic>>> getActiveOrdersWithDrivers(
      String merchantId) async {
    Logger.d(
        _tag, 'getActiveOrdersWithDrivers: ${Logger.redactId(merchantId)}');
    try {
      final rows = await _client
          .from('orders')
          .select('id, driver_id, driver:users!driver_id(id, name)')
          .eq('merchant_id', merchantId)
          .inFilter('status', ['pending', 'accepted', 'on_the_way'])
          .not('driver_id', 'is', null)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e, st) {
      Logger.e(_tag, 'getActiveOrdersWithDrivers failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  /// Returns historic customer_phone values for [merchantId] matching [patterns].
  Future<List<String>> getPhoneSuggestions({
    required String merchantId,
    required List<String> patterns,
    int limit = 10,
  }) async {
    Logger.d(_tag,
        'getPhoneSuggestions: ${Logger.redactId(merchantId)} patterns=${patterns.length}');
    try {
      final results = <String>{};
      for (final p in patterns) {
        final rows = await _client
            .from('orders')
            .select('customer_phone')
            .eq('merchant_id', merchantId)
            .ilike('customer_phone', p)
            .limit(limit)
            .timeout(const Duration(seconds: 5));
        for (final r in rows) {
          final ph = (r['customer_phone'] ?? '').toString();
          if (ph.isNotEmpty) results.add(ph);
        }
      }
      return results.take(limit).toList();
    } catch (e, st) {
      Logger.e(_tag, 'getPhoneSuggestions failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  /// Returns the merchant's location row (latitude, longitude, address, store_name).
  Future<Map<String, dynamic>?> getMerchantLocation(String merchantId) async {
    Logger.d(_tag, 'getMerchantLocation: ${Logger.redactId(merchantId)}');
    try {
      final row = await _client
          .from('users')
          .select('latitude, longitude, address, store_name')
          .eq('id', merchantId)
          .single()
          .timeout(const Duration(seconds: 10));
      return row;
    } catch (e, st) {
      Logger.e(_tag, 'getMerchantLocation failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  /// Caches a reverse-geocoded address back into the merchant's users row.
  Future<void> updateMerchantAddress(
      String merchantId, String address) async {
    Logger.d(_tag, 'updateMerchantAddress: ${Logger.redactId(merchantId)}');
    try {
      await _client
          .from('users')
          .update({'address': address})
          .eq('id', merchantId)
          .timeout(const Duration(seconds: 10));
    } catch (e, st) {
      Logger.e(_tag, 'updateMerchantAddress failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  /// Inserts a new scheduled order.
  Future<void> createScheduledOrder(Map<String, dynamic> data) async {
    Logger.d(_tag, 'createScheduledOrder');
    try {
      await _client
          .from('scheduled_orders')
          .insert(data)
          .timeout(const Duration(seconds: 30));
    } catch (e, st) {
      Logger.e(_tag, 'createScheduledOrder failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  /// Inserts a new order created from a voice recording.
  Future<void> createVoiceOrder(Map<String, dynamic> data) async {
    Logger.d(_tag, 'createVoiceOrder');
    try {
      await _client
          .from('orders')
          .insert(data)
          .timeout(const Duration(seconds: 30));
    } catch (e, st) {
      Logger.e(_tag, 'createVoiceOrder failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  // ─── Realtime ────────────────────────────────────────────────────────────

  /// Returns a typed stream of order updates for a given merchant.
  /// Use in conjunction with [RealtimeManager] when available.
  RealtimeChannel merchantOrderChannel(String merchantId) =>
      _client.channel('merchant_orders_$merchantId');

  /// Returns a typed stream of order updates for a given driver.
  RealtimeChannel driverOrderChannel(String driverId) =>
      _client.channel('driver_orders_$driverId');
}
