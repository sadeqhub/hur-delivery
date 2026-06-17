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

  // ─── Realtime ────────────────────────────────────────────────────────────

  /// Returns a typed stream of order updates for a given merchant.
  /// Use in conjunction with [RealtimeManager] when available.
  RealtimeChannel merchantOrderChannel(String merchantId) =>
      _client.channel('merchant_orders_$merchantId');

  /// Returns a typed stream of order updates for a given driver.
  RealtimeChannel driverOrderChannel(String driverId) =>
      _client.channel('driver_orders_$driverId');
}
