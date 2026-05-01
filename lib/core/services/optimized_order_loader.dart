import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/order_model.dart';
import 'network_quality_service.dart';
import 'request_priority_manager.dart';

/// Optimized order loader with priority-based loading and pagination
class OptimizedOrderLoader {
  static final OptimizedOrderLoader _instance = OptimizedOrderLoader._internal();
  factory OptimizedOrderLoader() => _instance;
  OptimizedOrderLoader._internal();

  final NetworkQualityService _networkQuality = NetworkQualityService();
  final RequestPriorityManager _priorityManager = RequestPriorityManager();

  /// Load orders with priority-based fetching
  /// - Critical: First page of orders (visible on screen)
  /// - High: Order items and driver info for visible orders
  /// - Normal: Additional pages
  /// - Low: Background prefetching
  Future<List<OrderModel>> loadOrdersOptimized({
    required String userId,
    required String userRole,
    int page = 0,
    int pageSize = 20,
    RequestPriority priority = RequestPriority.critical,
  }) async {
    // Adjust page size based on network quality
    final networkQuality = _networkQuality.currentQuality;
    final adjustedPageSize = _networkQuality.getRecommendedBatchSize();
    final effectivePageSize = priority == RequestPriority.critical 
        ? adjustedPageSize 
        : pageSize;

    return await _priorityManager.executeWithPriority<List<OrderModel>>(
      requestId: 'load_orders_${userId}_$page',
      operation: () => _loadOrdersPage(
        userId: userId,
        userRole: userRole,
        page: page,
        pageSize: effectivePageSize,
      ),
      priority: priority,
      description: 'Load orders page $page ($userRole)',
    ) ?? [];
  }

  /// Load a single page of orders
  Future<List<OrderModel>> _loadOrdersPage({
    required String userId,
    required String userRole,
    required int page,
    required int pageSize,
  }) async {
    try {
      final timeout = _networkQuality.getRecommendedTimeout();
      final offset = page * pageSize;

      List<Map<String, dynamic>> response = [];

      // 4G OPTIMIZATION: Select only required fields to reduce response size
      // This significantly reduces data transfer on slow connections
      const essentialFields = '''
        id,
        merchant_id,
        driver_id,
        customer_name,
        customer_phone,
        pickup_address,
        pickup_latitude,
        pickup_longitude,
        delivery_address,
        delivery_latitude,
        delivery_longitude,
        status,
        total_amount,
        delivery_fee,
        notes,
        vehicle_type,
        created_at,
        updated_at,
        driver_assigned_at,
        accepted_at,
        picked_up_at,
        delivered_at,
        ready_at,
        ready_countdown,
        items:order_items(id, name, quantity, price, notes)
      ''';

      if (userRole == 'driver') {
        // For drivers, load orders assigned to them
        response = await Supabase.instance.client
            .from('orders')
            .select('''
              $essentialFields,
              driver:users!driver_id(name, phone),
              merchant:users!merchant_id(name, phone, store_name)
            ''')
            .eq('driver_id', userId)
            .inFilter('status', ['pending', 'accepted', 'on_the_way', 'delivered', 'cancelled'])
            .order('created_at', ascending: false)
            .range(offset, offset + pageSize - 1)
            .timeout(timeout, onTimeout: () {
              print('⚠️ Orders query timeout');
              return <Map<String, dynamic>>[];
            });
      } else {
        // For merchants, load their orders
        response = await Supabase.instance.client
            .from('orders')
            .select('''
              $essentialFields,
              driver:users!driver_id(name, phone)
            ''')
            .eq('merchant_id', userId)
            .order('created_at', ascending: false)
            .range(offset, offset + pageSize - 1)
            .timeout(timeout, onTimeout: () {
              print('⚠️ Orders query timeout');
              return <Map<String, dynamic>>[];
            });
      }

      // Process orders
      final orders = response.map((order) {
        // Extract driver info
        if (order['driver'] != null && order['driver'] is Map) {
          order['driver_name'] = order['driver']['name'];
          order['driver_phone'] = order['driver']['phone'];
        }

        // Extract merchant info
        if (order['merchant'] != null && order['merchant'] is Map) {
          order['merchant_name'] = order['merchant']['store_name'] ?? order['merchant']['name'];
          order['merchant_phone'] = order['merchant']['phone'];
        }

        // Calculate timeout for pending orders
        if (order['status'] == 'pending' &&
            order['driver_id'] != null &&
            order['driver_assigned_at'] != null) {
          try {
            final assignedAt = DateTime.parse(order['driver_assigned_at'] as String);
            final elapsed = DateTime.now().toUtc().difference(assignedAt.toUtc()).inSeconds;
            order['timeout_remaining_seconds'] = (30 - elapsed).clamp(0, 30);
          } catch (e) {
            order['timeout_remaining_seconds'] = null;
          }
        }

        // Ensure numeric delivery coords
        if (order['delivery_latitude'] == null || order['delivery_longitude'] == null) {
          order['delivery_latitude'] = order['delivery_latitude'] ?? 0.0;
          order['delivery_longitude'] = order['delivery_longitude'] ?? 0.0;
        }

        return OrderModel.fromJson(order);
      }).toList();

      return orders;
    } catch (e) {
      print('❌ Error loading orders page: $e');
      return [];
    }
  }

  /// Load order details with priority (for order details screen)
  Future<OrderModel?> loadOrderDetails({
    required String orderId,
    RequestPriority priority = RequestPriority.critical,
  }) async {
    return await _priorityManager.executeWithPriority<OrderModel?>(
      requestId: 'load_order_details_$orderId',
      operation: () => _loadOrderDetailsInternal(orderId),
      priority: priority,
      description: 'Load order details $orderId',
    );
  }

  Future<OrderModel?> _loadOrderDetailsInternal(String orderId) async {
    try {
      final timeout = _networkQuality.getRecommendedTimeout();

      // 4G OPTIMIZATION: Select only required fields for order details
      final response = await Supabase.instance.client
          .from('orders')
          .select('''
            id,
            merchant_id,
            driver_id,
            customer_name,
            customer_phone,
            pickup_address,
            pickup_latitude,
            pickup_longitude,
            delivery_address,
            delivery_latitude,
            delivery_longitude,
            status,
            total_amount,
            delivery_fee,
            notes,
            vehicle_type,
            created_at,
            updated_at,
            driver_assigned_at,
            accepted_at,
            picked_up_at,
            delivered_at,
            ready_at,
            ready_countdown,
            items:order_items(id, name, quantity, price, notes),
            driver:users!driver_id(name, phone),
            merchant:users!merchant_id(name, phone, store_name)
          ''')
          .eq('id', orderId)
          .single()
          .timeout(timeout, onTimeout: () {
            return <String, dynamic>{};
          });

      if (response.isEmpty) return null;

      // Process order data
      final orderData = Map<String, dynamic>.from(response);

      // Extract driver info
      if (orderData['driver'] != null && orderData['driver'] is Map) {
        orderData['driver_name'] = orderData['driver']['name'];
        orderData['driver_phone'] = orderData['driver']['phone'];
      }

      // Extract merchant info
      if (orderData['merchant'] != null && orderData['merchant'] is Map) {
        orderData['merchant_name'] = orderData['merchant']['store_name'] ?? orderData['merchant']['name'];
        orderData['merchant_phone'] = orderData['merchant']['phone'];
      }

      // Ensure numeric delivery coords
      if (orderData['delivery_latitude'] == null || orderData['delivery_longitude'] == null) {
        orderData['delivery_latitude'] = orderData['delivery_latitude'] ?? 0.0;
        orderData['delivery_longitude'] = orderData['delivery_longitude'] ?? 0.0;
      }

      return OrderModel.fromJson(orderData);
    } catch (e) {
      print('❌ Error loading order details: $e');
      return null;
    }
  }

  /// Load order items separately (for lazy loading)
  Future<List<Map<String, dynamic>>> loadOrderItems({
    required String orderId,
    RequestPriority priority = RequestPriority.high,
  }) async {
    return await _priorityManager.executeWithPriority<List<Map<String, dynamic>>>(
      requestId: 'load_order_items_$orderId',
      operation: () => _loadOrderItemsInternal(orderId),
      priority: priority,
      description: 'Load items for order $orderId',
    ) ?? [];
  }

  Future<List<Map<String, dynamic>>> _loadOrderItemsInternal(String orderId) async {
    try {
      final timeout = _networkQuality.getRecommendedTimeout();

      final response = await Supabase.instance.client
          .from('order_items')
          .select('*')
          .eq('order_id', orderId)
          .timeout(timeout, onTimeout: () {
            return <Map<String, dynamic>>[];
          });

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Error loading order items: $e');
      return [];
    }
  }
}

