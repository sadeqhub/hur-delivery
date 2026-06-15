import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/order_model.dart';
import '../constants/app_constants.dart';
import '../services/notification_manager.dart';
import '../services/error_manager.dart';
import '../services/order_timeout_service.dart';
import '../services/route_time_service.dart';
import '../providers/location_provider.dart';
import '../services/optimized_order_loader.dart';
import '../services/performance_optimizer.dart';
import '../services/request_priority_manager.dart';
import '../services/network_quality_service.dart';
import '../services/response_cache_service.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/logger.dart';

class OrderProvider extends ChangeNotifier {
  List<OrderModel> _orders = [];
  OrderModel? _currentOrder;
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _ordersSubscription;

  // Cache user role to avoid repeated DB queries during order loading
  String? _cachedUserRole;
  DateTime? _roleCacheTime;
  static const _roleCacheExpiry = Duration(minutes: 5);

  // Response cache service for 4G optimization
  final _responseCache = ResponseCacheService();

  // Cached filtered lists — invalidated on _orders change
  List<OrderModel>? _cachedPendingOrders;
  List<OrderModel>? _cachedActiveOrders;
  List<OrderModel>? _cachedCompletedOrders;

  // Per-driver cache for getAllActiveOrdersForDriver
  final Map<String, List<OrderModel>> _driverActiveOrdersCache = {};

  List<OrderModel> get orders => _orders;
  OrderModel? get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Override notifyListeners to always invalidate derived-list caches first.
  // This guarantees no stale cache is ever served after a rebuild, without
  // having to touch every mutation site individually.
  @override
  void notifyListeners() {
    _cachedPendingOrders = null;
    _cachedActiveOrders = null;
    _cachedCompletedOrders = null;
    _driverActiveOrdersCache.clear();
    super.notifyListeners();
  }

  /// Seconds remaining in the accept window for [orderId], based purely on
  /// the server timestamp stored on the order. Returns 0 when no order found.
  int getLiveAcceptCountdownSeconds(String orderId) {
    final order = _orders.where((o) => o.id == orderId).firstOrNull;
    return OrderTimeoutService.instance
        .getLiveAcceptCountdownSeconds(orderId, order?.driverAssignedAt);
  }

  // Kept for call sites not yet updated — delegates to the new method.
  int? getTimeoutRemaining(String orderId) => getLiveAcceptCountdownSeconds(orderId);

  // Filtered orders by status — cached, O(1) after first call
  List<OrderModel> get pendingOrders =>
      _cachedPendingOrders ??= _orders.where((o) => o.isPending).toList();
  List<OrderModel> get activeOrders =>
      _cachedActiveOrders ??= _orders.where((o) => o.isActive).toList();
  List<OrderModel> get completedOrders =>
      _cachedCompletedOrders ??= _orders.where((o) => o.isCompleted).toList();
  
  // Get active order for driver (assigned and not completed)
  OrderModel? getActiveOrderForDriver(String driverId) {
    final activeOrders = getAllActiveOrdersForDriver(driverId);
    return activeOrders.firstOrNull;
  }

  // Get ALL active orders for a driver (for swipeable cards)
  // Results are cached per-driver and invalidated when orders or timeout states change.
  List<OrderModel> getAllActiveOrdersForDriver(String driverId) {
    final cached = _driverActiveOrdersCache[driverId];
    if (cached != null) return cached;

    final activeOrders = _orders
        .where((order) {
          if (order.driverId != driverId) return false;
          if (order.status == 'delivered' ||
              order.status == 'cancelled' ||
              order.status == 'rejected') {
            return false;
          }

          // Hide pending orders whose accept window has expired client-side.
          // The DB auto-reject function is the authoritative enforcer; this
          // just keeps the UI clean while waiting for the next realtime event.
          if (order.status == 'pending' && order.driverAssignedAt != null) {
            final remaining = OrderTimeoutService.instance
                .getLiveAcceptCountdownSeconds(order.id, order.driverAssignedAt);
            if (remaining <= 0) return false;
          }

          return true;
        })
        .toList()
      ..sort((a, b) {
        if (a.status == 'pending' && b.status != 'pending') return -1;
        if (a.status != 'pending' && b.status == 'pending') return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

    _driverActiveOrdersCache[driverId] = activeOrders;
    return activeOrders;
  }

  // Get pending orders available for drivers
  List<OrderModel> getPendingOrdersForDrivers() {
    return _orders
        .where((order) => order.status == 'pending' && order.driverId == null)
        .toList();
  }

  // Initialize orders
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadOrders();
      await _subscribeToOrders();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    OrderTimeoutService.instance.dispose();
    _ordersSubscription?.cancel();
    super.dispose();
  }

  // Refresh orders manually
  Future<void> refreshOrders() async {
    await ErrorManager.safeExecute(
      operation: () => _loadOrders(),
      operationName: 'refresh-orders',
      isCritical: false,
    );
  }

  // Refresh a specific order (useful for coordinate updates)
  // OPTIMIZED: Uses priority system for faster loading
  Future<void> refreshOrder(String orderId) async {
    try {
      Logger.d('🔄 Refreshing order $orderId...');
      
      final optimizer = PerformanceOptimizer();
      final loader = OptimizedOrderLoader();
      
      // Determine priority - if order details screen is visible, use critical
      final screenName = optimizer.visibilityTracker.currentScreen;
      final isOrderDetailsVisible = screenName == 'order_details';
      
      final priority = isOrderDetailsVisible 
          ? RequestPriority.critical  // User is viewing this order
          : RequestPriority.high;     // Background refresh
      
      // Load order details with priority
      final updatedOrder = await loader.loadOrderDetails(
        orderId: orderId,
        priority: priority,
      );
      
      if (updatedOrder != null) {
        // Find and update the order in the list
        final orderIndex = _orders.indexWhere((o) => o.id == orderId);
        if (orderIndex != -1) {
          _orders[orderIndex] = updatedOrder;
          Logger.d('✅ Order $orderId refreshed with coordinates: ${updatedOrder.deliveryLatitude}, ${updatedOrder.deliveryLongitude}');
        }
        
        // Update current order if it's the same
        if (_currentOrder?.id == orderId) {
          _currentOrder = updatedOrder;
        }
        
        notifyListeners();
      }
    } catch (e) {
      Logger.d('❌ Error refreshing order $orderId: $e');
    }
  }

  // Load orders from database
  // OPTIMIZED: Uses priority system and optimized loader for better 4G performance
  Future<void> _loadOrders() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      // Get user role - try multiple sources to avoid unnecessary DB queries
      String? userRole;
      
      // METHOD 1: Check cache first (if valid)
      if (_cachedUserRole != null && 
          _roleCacheTime != null && 
          DateTime.now().difference(_roleCacheTime!) < _roleCacheExpiry) {
        userRole = _cachedUserRole;
        Logger.d('✅ Using cached role: $userRole');
      } else {
        // METHOD 2: Try to get from auth user metadata (no DB query)
        userRole = currentUser.userMetadata?['role'] as String? ??
            currentUser.appMetadata['role'] as String?;

        // METHOD 3: Try to infer from cached auth provider/user model if available
        if ((userRole == null || userRole.isEmpty) && _orders.isNotEmpty) {
          final hasDriverOrder =
              _orders.any((order) => order.driverId == currentUser.id);
          if (hasDriverOrder) {
            userRole = 'driver';
          }
        }

        // METHOD 4: If still unknown, fall back to safe default without hitting DB
        if (userRole == null || userRole.isEmpty) {
          Logger.d(
              '⚠️ User role not found in metadata/cache - defaulting to merchant to avoid network fetch');
          userRole = null; // let default below handle final value
        } else {
          // Cache the role from metadata/inference
          _cachedUserRole = userRole;
          _roleCacheTime = DateTime.now();
        }
      }
      
      // Default to 'merchant' if role still unknown (safer default for merchant dashboard)
      if (userRole == null || userRole.isEmpty) {
        _cachedUserRole = 'merchant';
        _roleCacheTime = DateTime.now();
      }
      final effectiveRole = userRole ?? 'merchant';

      // OPTIMIZED: Use optimized loader with priority system and caching
      final optimizer = PerformanceOptimizer();
      final loader = OptimizedOrderLoader();
      final networkQualityService = NetworkQualityService();
      
      // Determine priority based on current screen visibility
      final screenName = optimizer.visibilityTracker.currentScreen;
      final isDashboardVisible = screenName == 'merchant_dashboard' || 
                                 screenName == 'driver_dashboard';
      
      final priority = isDashboardVisible 
          ? RequestPriority.critical  // Dashboard is visible - load immediately
          : RequestPriority.high;      // Background load - still important
      
      // Check cache first (if network is slow)
      final cacheKey = 'orders_${currentUser.id}_${effectiveRole}_0';
      if (networkQualityService.isSlowConnection) {
        final cachedOrders = await _responseCache.getCachedResponse<List<OrderModel>>(cacheKey);
        if (cachedOrders != null && cachedOrders.isNotEmpty) {
          _orders = cachedOrders;
          notifyListeners();
          // Load fresh data in background
          unawaited(_loadFreshOrdersAndCache(currentUser.id, effectiveRole, loader, priority, cacheKey));
          return; // Return early with cached data
        }
      }
      
      // Load first page of orders with priority
      final orders = await loader.loadOrdersOptimized(
        userId: currentUser.id,
        userRole: effectiveRole,
        page: 0,
        priority: priority,
      );
      
      // Update orders list
      _orders = orders;
      
      // Cache the response (if network is slow)
      if (networkQualityService.isSlowConnection) {
        await _responseCache.cacheResponse(
          key: cacheKey,
          data: orders,
          cacheDuration: const Duration(minutes: 2),
        );
      }
      
      // If connection is good, prefetch next page in background (non-blocking)
      if (optimizer.networkQuality != NetworkQuality.poor && 
          optimizer.networkQuality != NetworkQuality.offline) {
        // Prefetch next page in background
        loader.loadOrdersOptimized(
          userId: currentUser.id,
          userRole: effectiveRole,
          page: 1,
          priority: RequestPriority.low, // Background prefetch
        ).then((nextPageOrders) {
          // Append next page if we got results
          if (nextPageOrders.isNotEmpty) {
            _orders.addAll(nextPageOrders);
            notifyListeners();
          }
        }).catchError((e) {
          // Silently fail for background prefetch
          Logger.d('⚠️ Background prefetch failed: $e');
        }); // Don't await - fire and forget
      }

      // Bulk orders removed - no longer loading bulk orders
      
      // Keep existing scheduled orders loading logic (unchanged)
      
      // For merchants, also fetch scheduled orders and convert them to OrderModel format
      if (effectiveRole == 'merchant') {
        try {
          final scheduledOrdersResponse = await Supabase.instance.client
              .from('scheduled_orders')
              .select('*')
              .eq('merchant_id', currentUser.id)
              .eq('status', 'scheduled')
              .order('scheduled_at', ascending: true)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  Logger.d('⚠️ Scheduled orders query timeout');
                  return <Map<String, dynamic>>[];
                },
              );

          // Filter out scheduled orders that have already been posted (created_order_id is not null)
          final scheduledOrders = scheduledOrdersResponse
              .where((scheduledOrder) => scheduledOrder['created_order_id'] == null)
              .map((scheduledOrder) {
            // Convert scheduled order to OrderModel format
            // Use scheduled_at if available, otherwise use scheduled_date + scheduled_time
            DateTime scheduledDateTime;
            if (scheduledOrder['scheduled_at'] != null) {
              scheduledDateTime = DateTime.parse(scheduledOrder['scheduled_at'] as String);
            } else if (scheduledOrder['scheduled_date'] != null && scheduledOrder['scheduled_time'] != null) {
              final dateStr = scheduledOrder['scheduled_date'] as String;
              final timeStr = scheduledOrder['scheduled_time'] as String;
              scheduledDateTime = DateTime.parse('$dateStr $timeStr');
            } else {
              scheduledDateTime = DateTime.parse(scheduledOrder['created_at'] as String);
            }

            // Normalize vehicle type (motorcycle -> motorbike)
            String vehicleType = scheduledOrder['vehicle_type'] as String? ?? 'motorbike';
            if (vehicleType == 'motorcycle') {
              vehicleType = 'motorbike';
            }

            return OrderModel(
              id: 'scheduled_${scheduledOrder['id']}', // Prefix to distinguish from regular orders
              merchantId: scheduledOrder['merchant_id'] as String,
              customerName: scheduledOrder['customer_name'] as String,
              customerPhone: scheduledOrder['customer_phone'] as String,
              pickupAddress: scheduledOrder['pickup_address'] as String,
              pickupLatitude: double.parse(scheduledOrder['pickup_latitude'].toString()),
              pickupLongitude: double.parse(scheduledOrder['pickup_longitude'].toString()),
              deliveryAddress: scheduledOrder['delivery_address'] as String,
              deliveryLatitude: double.parse(scheduledOrder['delivery_latitude'].toString()),
              deliveryLongitude: double.parse(scheduledOrder['delivery_longitude'].toString()),
              status: 'scheduled',
              totalAmount: double.parse(scheduledOrder['total_amount']?.toString() ?? '0'),
              deliveryFee: double.parse(scheduledOrder['delivery_fee']?.toString() ?? '0'),
              notes: scheduledOrder['notes'] as String?,
              vehicleType: vehicleType,
              createdAt: DateTime.parse(scheduledOrder['created_at'] as String),
              updatedAt: scheduledOrder['updated_at'] != null ? DateTime.parse(scheduledOrder['updated_at'] as String) : null,
              readyAt: scheduledDateTime, // Use scheduled time as readyAt for display purposes
              items: const [], // Scheduled orders don't have items yet
            );
          }).toList();

          // Merge scheduled orders into the orders list
          _orders.addAll(scheduledOrders);
          Logger.d('✅ Loaded ${scheduledOrders.length} scheduled order(s)');
        } catch (e) {
          Logger.d('⚠️ Error loading scheduled orders: $e');
          // Don't fail the entire load if scheduled orders fail
        }
      }
      
      // Invalidate cache when orders are updated
      final cacheKeyToInvalidate = 'orders_${currentUser.id}_${effectiveRole}_0';
      await _responseCache.invalidate(cacheKeyToInvalidate);

    } catch (e) {
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('failed host lookup') ||
          errorString.contains('socketexception') ||
          errorString.contains('hostname') ||
          errorString.contains('no address associated')) {
        _error = 'لا يمكن الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت / Unable to connect to server. Please check your internet connection.';
      } else if (errorString.contains('timeout')) {
        _error = 'انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى / Connection timeout. Please try again.';
      } else if (errorString.contains('network') || errorString.contains('connection')) {
        _error = 'مشكلة في الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت / Network connection problem. Please check your internet connection.';
      } else {
        _error = 'حدث خطأ أثناء تحميل الطلبات. يرجى المحاولة مرة أخرى / An error occurred while loading orders. Please try again.';
      }
      Logger.d('❌ Error in _loadOrders: $e');
      // Set orders to empty list on error to avoid showing stale data
      _orders = [];
      notifyListeners();
    }
  }

  // Subscribe to real-time order updates
  Future<void> _subscribeToOrders() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      // Get user role to determine subscription filter
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', currentUser.id)
          .single();

      final userRole = userResponse['role'] as String;

      if (userRole == 'driver') {
        // For drivers, ensure single realtime subscription
        await _ordersSubscription?.cancel();
        
        // Bulk orders removed - no longer subscribing to bulk orders
        
        // Define stream with error handling for regular orders
        final stream = Supabase.instance.client
            .from('orders')
            .stream(primaryKey: ['id'])
            .handleError((error) {
              Logger.d('❌ Realtime stream error: $error');
              // Attempt to reconnect after delay
              Logger.d('🔄 Scheduling stream reconnection...');
              Future.delayed(const Duration(seconds: 5), () {
                if (_ordersSubscription != null) { // Only if still active
                   Logger.d('🔄 Reconnecting order stream now...');
                   _subscribeToOrders();
                }
              });
            });

        _ordersSubscription = stream.listen((data) async {
          // Process each order and fetch items if needed
          final List<OrderModel> processedOrders = [];
          
          for (var orderData in data) {
            // Check if this order is relevant to this driver
            final driverId = orderData['driver_id'];
            final status = orderData['status'];
            final orderId = orderData['id'];
            final driverAssignedAt = orderData['driver_assigned_at'];
            
            // Check for delivery location updates
            final existingOrder = _orders.where((o) => o.id == orderId).firstOrNull;
            if (existingOrder != null && driverId == currentUser.id) {
              final newLat = (orderData['delivery_latitude'] as num?)?.toDouble();
              final newLng = (orderData['delivery_longitude'] as num?)?.toDouble();
              final oldLat = existingOrder.deliveryLatitude;
              final oldLng = existingOrder.deliveryLongitude;
              
              // Check if coordinates changed (with small threshold to avoid floating point issues)
              if (newLat != null && newLng != null && 
                  ((newLat - oldLat).abs() > 0.0001 || 
                   (newLng - oldLng).abs() > 0.0001)) {
                Logger.d('📍 Customer location updated for order $orderId');
                Logger.d('   Old: $oldLat, $oldLng');
                Logger.d('   New: $newLat, $newLng');
                
                // Refresh the order to get complete data
                await refreshOrder(orderId);
              }
            }
            
            // 🔔 TRIGGER NOTIFICATION: Order newly assigned to this driver
            if (driverId != null && driverId == currentUser.id && status == 'pending') {
              // Check if this is a NEW assignment (not already in our list with this driver)
              final isNewAssignment = existingOrder == null || existingOrder.driverId != currentUser.id;
              
              if (isNewAssignment) {
                // 🔔 NOTIFICATION NOW HANDLED BY DATABASE TRIGGER
                // Database trigger (trigger_notify_driver_assignment) automatically
                // creates notification when driver_id is set on an order
                // App-side notification call disabled to prevent duplicates
                Logger.d('ℹ️  New driver assignment detected - database trigger will send notification');
              }
            }
            
          // IMPORTANT: Include ONLY orders assigned to this driver with allowed statuses
          if (driverId == currentUser.id &&
              (status == 'pending' || status == 'accepted' || status == 'on_the_way')) {
              
              
              // Fetch order items if not included
              if (orderData['items'] == null) {
                try {
                  final items = await Supabase.instance.client
                      .from('order_items')
                      .select()
                      .eq('order_id', orderData['id']);
                  orderData['items'] = items;
                } catch (e) {
                  Logger.d('Error fetching items for order: $e');
                  orderData['items'] = [];
                }
              }
              
              // Calculate timeout_remaining_seconds if order is pending with driver assigned
              // Formula: 30 - (NOW() - driver_assigned_at)
              if (orderData['status'] == 'pending' && 
                  orderData['driver_id'] != null && 
                  orderData['driver_assigned_at'] != null) {
                try {
                  final assignedAtStr = orderData['driver_assigned_at'] as String;
                  final assignedAt = DateTime.parse(assignedAtStr);
                  final now = DateTime.now().toUtc();
                  final assignedAtUtc = assignedAt.toUtc();
                  final elapsed = now.difference(assignedAtUtc).inSeconds;
                  final remaining = 30 - elapsed;
                  final remainingClamped = remaining.clamp(0, 30);
                  
                  orderData['timeout_remaining_seconds'] = remainingClamped;
                  
                  Logger.d('');
                  Logger.d('═══════════════════════════════════════════════════════');
                  Logger.d('⏱️  TIMEOUT CALCULATION for order ${orderData['id']}');
                  Logger.d('───────────────────────────────────────────────────────');
                  Logger.d('   driver_assigned_at (string): $assignedAtStr');
                  Logger.d('   driver_assigned_at (parsed): $assignedAt');
                  Logger.d('   driver_assigned_at (UTC)   : $assignedAtUtc');
                  Logger.d('   NOW() (UTC)                : $now');
                  Logger.d('   Difference                 : ${now.difference(assignedAtUtc)}');
                  Logger.d('   Elapsed seconds            : $elapsed');
                  Logger.d('   Formula: 30 - $elapsed     : $remaining');
                  Logger.d('   Clamped (0-30)            : $remainingClamped');
                  Logger.d('═══════════════════════════════════════════════════════');
                  Logger.d('');
                  
                  if (remaining < 0) {
                    Logger.d('⚠️  WARNING: Remaining is NEGATIVE ($remaining)');
                    Logger.d('⚠️  This order should have been auto-rejected already!');
                  }
                  if (remaining > 30) {
                    Logger.d('⚠️  WARNING: Remaining is > 30 seconds ($remaining)');
                    Logger.d('⚠️  This suggests driver_assigned_at is in the FUTURE!');
                  }
                  
                } catch (e) {
                  Logger.d('❌ Error calculating timeout: $e');
                  Logger.d('❌ driver_assigned_at value: ${orderData['driver_assigned_at']}');
                  orderData['timeout_remaining_seconds'] = null;
                }
              } else {
                orderData['timeout_remaining_seconds'] = null;
              }
              
              // Ensure numeric delivery coords
              if (orderData['delivery_latitude'] == null || orderData['delivery_longitude'] == null) {
                orderData['delivery_latitude'] = orderData['delivery_latitude'] ?? 0.0;
                orderData['delivery_longitude'] = orderData['delivery_longitude'] ?? 0.0;
              }
              
              processedOrders.add(OrderModel.fromJson(orderData));
            }
          }
          
      // Update orders list (de-duplicate by ID and prefer latest status)
      final Map<String, OrderModel> byId = {};
      for (final o in processedOrders) {
        byId[o.id] = o;
      }
      _orders = byId.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          Logger.d('📊 Driver orders update: ${_orders.length} orders processed');
          Logger.d('   Orders for driver $currentUser.id:');
          for (var o in _orders.where((o) => o.driverId == currentUser.id)) {
            Logger.d('     - ${o.id}: status=${o.status}, assigned_at=${o.driverAssignedAt}');
          }
          
          notifyListeners();
        });
      } else {
        // For merchants, listen to their orders with complete data loading
        Logger.d('👨‍💼 Setting up merchant realtime subscription for user: ${currentUser.id}');
        
        await _ordersSubscription?.cancel();
        
        final stream = Supabase.instance.client
            .from('orders')
            .stream(primaryKey: ['id'])
            .eq('merchant_id', currentUser.id)
            .order('created_at', ascending: false)
            .limit(50) // PERFORMANCE FIX: Reduced from 200 to 50 to reduce memory usage
            .handleError((error) {
              Logger.d('❌ Merchant realtime stream error: $error');
              Logger.d('🔄 Scheduling stream reconnection...');
              Future.delayed(const Duration(seconds: 5), () {
                if (_ordersSubscription != null) {
                   Logger.d('🔄 Reconnecting merchant stream now...');
                   _subscribeToOrders();
                }
              });
            });

        _ordersSubscription = stream.listen(
          (data) async {
          Logger.d('📦 Merchant real-time update: ${data.length} orders received');
          Logger.d('   Update time: ${DateTime.now()}');
          
          // Process each order and fetch related data
          
            // Parallelize fetching of order details
            final futures = data.map((orderData) async {
              final orderId = orderData['id'];
              
              // Reuse existing items if available to save bandwidth
              final existingOrder = _orders.where((o) => o.id == orderId).firstOrNull;
              
              // 1. ITEMS caching - Inject into JSON if missing and available in cache
              if (orderData['items'] == null) {
                if (existingOrder != null && existingOrder.items.isNotEmpty) {
                  // Re-serialize items to JSON format so OrderModel.fromJson can read them
                  // (OrderModel.fromJson expects 'items' to be List<dynamic> of maps)
                  orderData['items'] = existingOrder.items.map((i) => i.toJson()).toList();
                } else {
                 // No cache, fetch
                 try {
                  final items = await Supabase.instance.client
                      .from('order_items')
                      .select()
                      .eq('order_id', orderId);
                  orderData['items'] = items;
                } catch (e) {
                   orderData['items'] = [];
                }
               }
              }

              // 2. DRIVER INFO caching - Inject into JSON if missing and available in cache
              if (orderData['driver_id'] != null && orderData['driver'] == null) {
                 if (existingOrder != null && existingOrder.driverName != null) {
                    orderData['driver_name'] = existingOrder.driverName;
                    orderData['driver_phone'] = existingOrder.driverPhone;
                 } else {
                    try {
                      final driverData = await Supabase.instance.client
                          .from('users')
                          .select('name, phone')
                          .eq('id', orderData['driver_id'])
                          .maybeSingle();
                      
                      if (driverData != null) {
                        orderData['driver_name'] = driverData['name'];
                        orderData['driver_phone'] = driverData['phone'];
                      }
                    } catch (e) {
                      // Log but don't fail - driver info is optional
                      Logger.d('⚠️ Could not fetch driver info: $e');
                    }
                 }
              }
              
              // Calculate timeout for pending orders with driver assigned
              if (orderData['status'] == 'pending' && 
                  orderData['driver_id'] != null && 
                  orderData['driver_assigned_at'] != null) {
                try {
                  final assignedAtStr = orderData['driver_assigned_at'] as String;
                  final assignedAt = DateTime.parse(assignedAtStr);
                  final now = DateTime.now().toUtc();
                  final assignedAtUtc = assignedAt.toUtc();
                  final elapsed = now.difference(assignedAtUtc).inSeconds;
                  final remaining = 30 - elapsed;
                  final remainingClamped = remaining.clamp(0, 30);
                  
                  orderData['timeout_remaining_seconds'] = remainingClamped;
                } catch (e) {
                  orderData['timeout_remaining_seconds'] = null;
                }
              }
              
              return OrderModel.fromJson(orderData);
            });
            
            // Wait for all fetches to complete
            final processedOrders = await Future.wait(futures);
          
          // Detect status changes for notifications and logging
          for (var newOrder in processedOrders) {
            final existingOrder = _orders.where((o) => o.id == newOrder.id).firstOrNull;
            
            if (existingOrder != null && existingOrder.status != newOrder.status) {
              Logger.d('📢 Order ${newOrder.id} status changed: ${existingOrder.status} → ${newOrder.status}');
              
             // 🔔 NOTIFICATIONS NOW HANDLED BY DATABASE TRIGGERS
             // Database triggers automatically create notifications for:
             // - Order accepted → trigger_notify_order_accepted
             // - Order on the way → trigger_notify_order_on_the_way
             // - Order delivered → trigger_notify_order_delivered
             // - Order rejected → trigger_notify_order_rejected
             // App-side notification calls disabled to prevent duplicates
             if (newOrder.status == AppConstants.statusAccepted && existingOrder.status == AppConstants.statusPending) {
               Logger.d('ℹ️  Order accepted - database trigger will send notification');
             } else if (newOrder.status == AppConstants.statusOnTheWay) {
               Logger.d('ℹ️  Order on the way - database trigger will send notification');
             } else if (newOrder.status == AppConstants.statusDelivered) {
               Logger.d('ℹ️  Order delivered - database trigger will send notification');
             } else if (newOrder.status == AppConstants.statusRejected) {
               Logger.d('ℹ️  Order rejected - database trigger will send notification');
             }
            } else if (existingOrder == null) {
              Logger.d('🆕 New order detected: ${newOrder.id} with status ${newOrder.status}');
            }
          }
          
          // Update orders and sort by creation date (de-duplicate)
          final Map<String, OrderModel> byId = {};
          for (final o in processedOrders) {
            byId[o.id] = o;
          }
          _orders = byId.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          Logger.d('✅ Merchant orders updated: ${_orders.length} total');
          Logger.d('   Status breakdown:');
          for (var status in ['pending', 'assigned', 'accepted', 'on_the_way', 'delivered', 'cancelled', 'rejected']) {
            final count = _orders.where((o) => o.status == status).length;
            if (count > 0) Logger.d('      $status: $count');
          }
          
          notifyListeners();
        },
        onError: (error) {
          Logger.d('❌ Merchant realtime subscription error: $error');
          // Try to resubscribe after error
          Future.delayed(const Duration(seconds: 3), () {
            _subscribeToOrders();
          });
        },
      );
      
      Logger.d('✅ Merchant realtime subscription initialized');
      }
    } catch (e) {
      Logger.d('❌ Error setting up order subscription: $e');
    }
  }

  // Bulk order subscription removed - bulk orders are no longer supported

  // Create new order
  Future<Map<String, dynamic>?> createOrder({
    required String customerName,
    String? customerPhone,
    required String pickupAddress,
    required double pickupLatitude,
    required double pickupLongitude,
    required String deliveryAddress,
    required double deliveryLatitude,
    required double deliveryLongitude,
    double totalAmount = 0.0,
    double deliveryFee = 0.0,
    String? notes,
    String? vehicleType, // Optional: 'motorbike' (default), 'car', or 'truck'
    DateTime? readyAt, // When order will be ready for pickup
    int? readyCountdown, // Minutes until ready
    String? assignedDriverId, // Optional: assign to specific driver (e.g., same driver as active order)
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _error = 'المستخدم غير مسجل الدخول';
        return null;
      }

      // Prepare order data
      final orderData = <String, dynamic>{
        'merchant_id': currentUser.id,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'pickup_address': pickupAddress,
        'pickup_latitude': pickupLatitude,
        'pickup_longitude': pickupLongitude,
        'delivery_address': deliveryAddress,
        'delivery_latitude': deliveryLatitude,
        'delivery_longitude': deliveryLongitude,
        'total_amount': totalAmount,
        'delivery_fee': deliveryFee,
        'notes': (notes != null && notes.isNotEmpty) ? notes : null,
        'vehicle_type': vehicleType ?? 'motorbike', // Default to motorbike
        'status': AppConstants.statusPending,
      };
      
      // Add optional fields only if they have values
      if (readyAt != null) {
        orderData['ready_at'] = readyAt.toIso8601String();
      }
      if (readyCountdown != null) {
        orderData['ready_countdown'] = readyCountdown;
      }
      // If assignedDriverId is provided, assign directly to that driver
      if (assignedDriverId != null) {
        orderData['driver_id'] = assignedDriverId;
        orderData['driver_assigned_at'] = DateTime.now().toIso8601String();
      }
      
      // Log the data being sent for debugging
      Logger.d('📝 Creating order with data:');
      Logger.d('   merchant_id: ${orderData['merchant_id']}');
      Logger.d('   customer_name: ${orderData['customer_name']}');
      Logger.d('   customer_phone: ${orderData['customer_phone']}');
      Logger.d('   vehicle_type: ${orderData['vehicle_type']}');
      Logger.d('   status: ${orderData['status']}');
      Logger.d('   ready_at: ${orderData['ready_at']}');
      Logger.d('   ready_countdown: ${orderData['ready_countdown']}');
      
      // Create order (wrap with ErrorManager to capture DB errors)
      final orderResponse = await ErrorManager.safeExecute<Map<String, dynamic>>(
        operationName: 'create-order',
        isCritical: true,
        operation: () async {
          return await Supabase.instance.client
              .from('orders')
              .insert(orderData)
              .select()
              .single();
        },
      );
      if (orderResponse == null) {
        _error = _error ?? 'حدث خطأ في إنشاء الطلب. يرجى المحاولة مرة أخرى.';
        return null;
      }

      // Optimistically add order to local state for instant feedback
      try {
        final createdOrder = OrderModel.fromJson(orderResponse);
        _orders = [createdOrder, ..._orders];
        notifyListeners();
      } catch (e) {
        Logger.d('⚠️ Failed to parse created order: $e');
      }
      
      // Invalidate cache when new order is created
      final cacheKey = 'orders_${currentUser.id}_merchant_0';
      await _responseCache.invalidate(cacheKey);

      // Fire-and-forget refresh + notification (don't block UI)
      unawaited(_loadOrders());
      unawaited(_sendMerchantNotification(() async {
        final success = await NotificationManager.notifyMerchantOrderCreated(
          merchantId: currentUser.id,
          orderId: orderResponse['id'],
          customerName: customerName,
          totalAmount: totalAmount,
          deliveryFee: deliveryFee,
        );
        Logger.d('✅ Order created notification sent: $success');
      }));

      // Return the created order data (including ID)
      return orderResponse;
    } catch (e, stackTrace) {
      // Log detailed error information
      Logger.d('❌ Error creating order:');
      Logger.d('   Error: $e');
      Logger.d('   Stack trace: $stackTrace');
      
      // Check if error is due to system being disabled
      final errorString = e.toString();
      if (errorString.contains('SYSTEM_DISABLED') || errorString.contains('وضع الصيانة')) {
        _error = 'النظام حالياً في وضع الصيانة. لا يمكن إنشاء طلبات جديدة.';
      } else {
        // Extract more detailed error message
        String detailedError = errorString;
        if (e.toString().contains('PostgrestException')) {
          // Try to extract the actual error message from Supabase
          try {
            final match = RegExp(r'message: (.+?)(?:,|$)').firstMatch(errorString);
            if (match != null) {
              detailedError = match.group(1) ?? errorString;
            }
          } catch (_) {
            // If parsing fails, use original error
          }
        }
        _error = detailedError.isNotEmpty ? detailedError : 'حدث خطأ في إنشاء الطلب. يرجى المحاولة مرة أخرى.';
        Logger.d('   User-friendly error: $_error');
      }
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update order status
  Future<bool> updateOrderStatus(String orderId, String status) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _error = 'User not authenticated';
        return false;
      }

      // Get order details for notification
      final order = getOrderById(orderId);
      final merchantId = order?.merchantId;

      // Use database function for proper validation and permissions
      final ok = await ErrorManager.safeExecute<bool>(
        operationName: 'update-order-status',
        isCritical: true,
        operation: () async {
          try {
            // Call the database function with timer support (returns JSON)
            final functionResult = await Supabase.instance.client.rpc(
              'update_order_status_with_timer',
              params: {
                'p_order_id': orderId,
                'p_new_status': status,
                'p_user_id': currentUser.id,
                'p_delivery_time_limit_seconds': null, // Only needed for on_the_way status
              },
            );
            
            Logger.d('🔍 Update order status response: $functionResult');
            Logger.d('🔍 Response type: ${functionResult.runtimeType}');
            
            // Function now returns JSON with success flag
            if (functionResult is Map) {
              if (functionResult['success'] == true) {
                Logger.d('✅ Order status updated successfully');
                return true;
              } else {
                // Function returned error details
                final error = functionResult['error'] ?? 'UNKNOWN_ERROR';
                final message = functionResult['message'] ?? 'Failed to update order status';
                Logger.d('❌ Update failed: $error - $message');
                Logger.d('   Full response: $functionResult');
                _error = message;
                return false;
              }
            }
            
            // Unexpected response format
            Logger.d('⚠️ Unexpected response format: $functionResult');
            _error = 'Unexpected response from server';
            return false;
          } catch (e) {
            // Exception occurred
            Logger.d('❌ Exception updating order status: $e');
            Logger.d('   Exception type: ${e.runtimeType}');
            if (e is PostgrestException) {
              Logger.d('   Postgrest code: ${e.code}');
              Logger.d('   Postgrest message: ${e.message}');
              Logger.d('   Postgrest details: ${e.details}');
              Logger.d('   Postgrest hint: ${e.hint}');
            }
            rethrow;
          }
          
          // Fallback: Direct update with verification
          final response = await Supabase.instance.client
              .from('orders')
              .update({
                'status': status,
                'updated_at': DateTime.now().toIso8601String(),
                // Set picked_up_at when status changes to on_the_way
                if (status == 'on_the_way') 'picked_up_at': DateTime.now().toIso8601String(),
                // Set delivered_at when status changes to delivered
                if (status == 'delivered') 'delivered_at': DateTime.now().toIso8601String(),
              })
              .eq('id', orderId)
              .select();
          
          // Verify the update actually happened
          if (response.isEmpty) {
            throw Exception('Order not found or update failed - no rows updated');
          }
          
          // Verify the status was actually updated
          final updatedOrder = response.first;
          if (updatedOrder['status'] != status) {
            throw Exception('Status update failed - status mismatch. Expected: $status, Got: ${updatedOrder['status']}');
          }
          
          return true;
        },
        defaultValue: false,
      );
      if (ok != true) {
        _error = _error ?? 'تعذر تحديث حالة الطلب.';
        return false;
      }

      // NOTE: Merchant notifications are handled in _processOrderUpdate method
      // to avoid duplicate notifications

      // Update local order
      final orderIndex = _orders.indexWhere((o) => o.id == orderId);
      if (orderIndex != -1) {
        _orders[orderIndex] = _orders[orderIndex].copyWith(
          status: status,
          updatedAt: DateTime.now(),
        );
      }

      // Update current order if it's the same
      if (_currentOrder?.id == orderId) {
        _currentOrder = _currentOrder!.copyWith(
          status: status,
          updatedAt: DateTime.now(),
        );
      }
      
      // Invalidate cache when order status is updated
      final effectiveRole = _cachedUserRole ?? 'merchant';
      final cacheKey = 'orders_${currentUser.id}_${effectiveRole}_0';
      await _responseCache.invalidate(cacheKey);

      notifyListeners();
      return true;
    } catch (e) {
      _error = _getErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Assign order to driver
  Future<bool> assignOrderToDriver(String orderId, String driverId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Update order with driver (keep status as 'pending' to trigger auto-reject timer)
      await Supabase.instance.client
          .from('orders')
          .update({
            'driver_id': driverId,
            // Keep status as 'pending' - this triggers the driver_assigned_at timestamp
            // Driver must accept within 30 seconds or will be auto-rejected
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      // Create assignment record
      await Supabase.instance.client
          .from('order_assignments')
          .insert({
            'order_id': orderId,
            'driver_id': driverId,
            'status': 'pending',
            'assigned_at': DateTime.now().toIso8601String(),
            'timeout_at': DateTime.now()
                .add(const Duration(minutes: AppConstants.orderTimeoutMinutes))
                .toIso8601String(),
          });

      // Invalidate cache
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        final effectiveRole = _cachedUserRole ?? 'merchant';
        final cacheKey = 'orders_${currentUser.id}_${effectiveRole}_0';
        await _responseCache.invalidate(cacheKey);
      }
      
      // Load updated orders
      await _loadOrders();
      return true;
    } catch (e) {
      _error = _getErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Accept order (driver)
  Future<bool> acceptOrder(String orderId) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return false;

      // Get order details for notification
      final order = getOrderById(orderId);
      final merchantId = order?.merchantId;

      // Call database function to accept order (handles history tracking)
      final ok = await ErrorManager.safeExecute<bool>(
        operationName: 'driver-accept-order',
        isCritical: true,
        operation: () async {
          await Supabase.instance.client.rpc('driver_accept_order', params: {
            'p_order_id': orderId,
            'p_driver_id': currentUser.id,
          });
          return true;
        },
        defaultValue: false,
      );
      if (ok != true) {
        _error = _error ?? 'تعذر قبول الطلب.';
        return false;
      }

           // NOTE: Merchant notification will be sent by _processOrderUpdate method
           // when the order status changes to 'accepted' to avoid duplicates

      // Invalidate cache
      final effectiveRole = _cachedUserRole ?? 'driver';
      final cacheKey = 'orders_${currentUser.id}_${effectiveRole}_0';
      await _responseCache.invalidate(cacheKey);
      
      // Reload orders
      await _loadOrders();

      notifyListeners();
      return true;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('DRIVER_WALLET_NEGATIVE')) {
        _error = 'رصيد محفظتك بالسالب. يرجى شحن المحفظة أولاً لتسديد العمولة ثم حاول مرة أخرى.';
      } else {
        _error = msg;
      }
      return false;
    }
  }

  // Reject order (driver) - Immediately reassigns to next driver
  Future<bool> rejectOrder(String orderId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _error = 'User not authenticated';
        return false;
      }

      // Get order details for notification
      final order = getOrderById(orderId);
      final merchantId = order?.merchantId;

      // Call database function to reject and auto-reassign to next driver
      final ok = await ErrorManager.safeExecute<bool>(
        operationName: 'driver-reject-order',
        isCritical: true,
        operation: () async {
          await Supabase.instance.client.rpc('driver_reject_order', params: {
            'p_order_id': orderId,
            'p_driver_id': currentUser.id,
          });
          return true;
        },
        defaultValue: false,
      );
      if (ok != true) {
        _error = _error ?? 'تعذر رفض الطلب.';
        return false;
      }

           // NOTE: Merchant notification will be sent by _processOrderUpdate method
           // when the order status changes to 'rejected' to avoid duplicates

      // Invalidate cache
      final effectiveRole = _cachedUserRole ?? 'driver';
      final cacheKey = 'orders_${currentUser.id}_${effectiveRole}_0';
      await _responseCache.invalidate(cacheKey);
      
      // Reload orders
      await _loadOrders();
      return true;
    } catch (e) {
      _error = _getErrorMessage(e);
      return false;
    } finally{
      _isLoading = false;
      notifyListeners();
    }
  }

  // Mark order as on the way (being delivered) with location validation and timer setup
  // PERFORMANCE FIX: Optimized for responsiveness - uses cached location and parallel operations
  // Update customer phone for an order
  Future<bool> updateCustomerPhone(String orderId, String customerPhone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Format phone number
      String formattedPhone = customerPhone.replaceAll(RegExp(r'\D'), '');
      if (formattedPhone.startsWith('964')) {
        formattedPhone = formattedPhone.substring(3);
      }
      formattedPhone = formattedPhone.replaceFirst(RegExp('^0+'), '');
      formattedPhone = '+964$formattedPhone';

      // Get order details before updating (needed for WhatsApp request)
      final order = getOrderById(orderId);
      final customerName = order?.customerName ?? 'عميلنا العزيز';
      String? merchantName;

      // Get merchant name
      if (order?.merchantId != null) {
        try {
          final merchantResponse = await Supabase.instance.client
              .from('users')
              .select('name, store_name')
              .eq('id', order!.merchantId)
              .single();
          merchantName = merchantResponse['store_name'] as String? ?? 
                       merchantResponse['name'] as String? ?? 
                       'متجرنا';
        } catch (e) {
          Logger.d('⚠️ Could not fetch merchant name: $e');
          merchantName = 'متجرنا';
        }
      } else {
        merchantName = 'متجرنا';
      }

      await Supabase.instance.client
          .from('orders')
          .update({
            'customer_phone': formattedPhone,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      // Update local order
      final orderIndex = _orders.indexWhere((o) => o.id == orderId);
      if (orderIndex != -1) {
        _orders[orderIndex] = _orders[orderIndex].copyWith(
          customerPhone: formattedPhone,
        );
      }

      if (_currentOrder?.id == orderId) {
        _currentOrder = _currentOrder!.copyWith(
          customerPhone: formattedPhone,
        );
      }

      // Trigger WhatsApp location request (fire-and-forget, non-blocking)
      _sendWhatsAppLocationRequest(
        orderId: orderId,
        customerPhone: formattedPhone,
        customerName: customerName,
        merchantName: merchantName,
      );

      notifyListeners();
      return true;
    } catch (e) {
      _error = _getErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Send WhatsApp location request (fire-and-forget, non-blocking)
  void _sendWhatsAppLocationRequest({
    required String orderId,
    required String customerPhone,
    required String customerName,
    required String merchantName,
  }) {
    // Fire-and-forget - don't await, don't block UI
    Supabase.instance.client.functions.invoke(
      'send-location-request',
      body: {
        'order_id': orderId,
        'customer_phone': customerPhone,
        'customer_name': customerName,
        'merchant_name': merchantName,
      },
    ).then((response) {
      if (response.status == 200) {
        Logger.d('✅ WhatsApp location request sent successfully after phone update');
      } else {
        Logger.d('⚠️ WhatsApp location request failed: ${response.status}');
      }
    }).catchError((error) {
      Logger.d('⚠️ Failed to send WhatsApp location request (non-critical): $error');
      // Don't show error to user - this is a background operation
    });
  }

  Future<bool> markOrderOnTheWay(String orderId, {BuildContext? context}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _error = 'User not authenticated';
        return false;
      }

      // Get order details
      final order = getOrderById(orderId);
      if (order == null) {
        _error = 'Order not found';
        return false;
      }

      // Check if customer phone is missing - if so, return false to trigger dialog
      if (order.customerPhone == null || order.customerPhone!.isEmpty) {
        _error = 'CUSTOMER_PHONE_REQUIRED';
        return false;
      }

      // PERFORMANCE FIX: Use cached location from LocationProvider (instant) instead of triggering new GPS fix
      Position? driverPosition;
      if (context != null) {
        try {
          final locationProvider = Provider.of<LocationProvider>(context, listen: false);
          // Use cached currentPosition if available and recent (within last 30 seconds)
          if (locationProvider.currentPosition != null) {
            final positionAge = DateTime.now().difference(
              locationProvider.currentPosition!.timestamp
            );
            if (positionAge.inSeconds < 30) {
              // Use cached position - much faster!
              driverPosition = locationProvider.currentPosition;
              Logger.d('✅ Using cached location (age: ${positionAge.inSeconds}s)');
            } else {
              Logger.d('⚠️ Cached location too old (${positionAge.inSeconds}s), fetching new...');
            }
          }
          
          // Only fetch new location if cached is not available or too old
          driverPosition ??= await locationProvider.getCurrentLocation()
                .timeout(const Duration(seconds: 3), onTimeout: () {
              Logger.d('⚠️ Location fetch timed out, using cached if available');
              return locationProvider.currentPosition;
            });
        } catch (e) {
          Logger.d('⚠️ Could not get location from LocationProvider: $e');
          // Fallback to cached position if available
          final locationProvider = Provider.of<LocationProvider>(context, listen: false);
          driverPosition = locationProvider.currentPosition;
                }
      }
      
      // Fallback: use Geolocator directly with short timeout
      if (driverPosition == null) {
        try {
          driverPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium, // Reduced from high for speed
            timeLimit: const Duration(seconds: 3), // Short timeout
          );
        } catch (e) {
          Logger.d('❌ Could not get location: $e');
          _error = 'Unable to get current location. Please enable location services.';
          return false;
        }
      }

      Logger.d('📍 Driver location: ${driverPosition.latitude}, ${driverPosition.longitude}');
      Logger.d('📍 Pickup location: ${order.pickupLatitude}, ${order.pickupLongitude}');

      // PERFORMANCE FIX: Start route calculation in parallel with validation
      // Route calculation can happen in background and doesn't block the status update
      final routeTimeFuture = RouteTimeService.calculateRouteTime(
        pickupLatitude: order.pickupLatitude,
        pickupLongitude: order.pickupLongitude,
        dropoffLatitude: order.deliveryLatitude,
        dropoffLongitude: order.deliveryLongitude,
      );

      // Validate pickup location (must be within 100m) with timeout
      final validationResult = await Supabase.instance.client.rpc(
        'validate_pickup_location',
        params: {
          'p_order_id': orderId,
          'p_driver_id': currentUser.id,
          'p_driver_latitude': driverPosition.latitude,
          'p_driver_longitude': driverPosition.longitude,
        },
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        Logger.d('⚠️ Validation timed out');
        return {'success': false, 'error': 'TIMEOUT', 'message': 'Validation timed out'};
      });

      if (validationResult is Map && validationResult['success'] != true) {
        final error = validationResult['error'] ?? 'VALIDATION_FAILED';
        final message = validationResult['message'] ?? 'Cannot mark as picked up';
        _error = message;
        Logger.d('❌ Pickup validation failed: $error - $message');
        return false;
      }

      Logger.d('✅ Pickup location validated');

      // Wait for route calculation (should be done or nearly done by now)
      final routeTimeResult = await routeTimeFuture.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          Logger.d('⚠️ Route calculation timed out, using default time limit');
          return null; // Will use default time limit
        },
      );

      // Use default time limit if route calculation failed (non-critical)
      int? timeLimitSeconds;
      if (routeTimeResult != null) {
        timeLimitSeconds = routeTimeResult.timeLimitSeconds;
        Logger.d('✅ Route time calculated: ${routeTimeResult.timeLimitSeconds}s');
      } else {
        // Use a reasonable default (e.g., 30 minutes) if route calculation fails
        timeLimitSeconds = 1800; // 30 minutes default
        Logger.d('⚠️ Using default time limit: ${timeLimitSeconds}s');
      }

      // Update order status with timer
      final ok = await ErrorManager.safeExecute<bool>(
        operationName: 'update-order-status-with-timer',
        isCritical: true,
        operation: () async {
          final functionResult = await Supabase.instance.client.rpc(
            'update_order_status_with_timer',
            params: {
              'p_order_id': orderId,
              'p_new_status': AppConstants.statusOnTheWay,
              'p_user_id': currentUser.id,
              'p_delivery_time_limit_seconds': timeLimitSeconds,
            },
          ).timeout(const Duration(seconds: 5), onTimeout: () {
            return {'success': false, 'error': 'TIMEOUT', 'message': 'Update timed out'};
          });

          if (functionResult is Map) {
            if (functionResult['success'] == true) {
              Logger.d('✅ Order status updated with timer');
              return true;
            } else {
              final error = functionResult['error'] ?? 'UNKNOWN_ERROR';
              final message = functionResult['message'] ?? 'Failed to update order status';
              Logger.d('❌ Update failed: $error - $message');
              _error = message;
              return false;
            }
          }

          _error = 'Unexpected response from server';
          return false;
        },
        defaultValue: false,
      );

      if (ok != true) {
        _error = _error ?? 'تعذر تحديث حالة الطلب.';
        return false;
      }

      // PERFORMANCE FIX: Removed _loadOrders() - realtime subscription handles updates
      // This prevents blocking the UI with a heavy database operation

      notifyListeners();
      return true;
    } catch (e) {
      _error = _getErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Mark order as delivered
  Future<bool> markOrderDelivered(String orderId) async {
    return await updateOrderStatus(orderId, AppConstants.statusDelivered);
  }

  // Cancel order
  Future<bool> cancelOrder(String orderId) async {
    return await updateOrderStatus(orderId, AppConstants.statusCancelled);
  }

  // Upload order proof (driver must upload before delivery completion)
  // OPTIMIZED: Parallel upload and DB insert, with timeout handling
  Future<bool> uploadOrderProof({
    required String orderId,
    required Uint8List fileBytes,
    required String contentType,
    String? fileName,
  }) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _error = 'User not authenticated';
        return false;
      }
      final name = fileName ?? 'proof_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final objectPath = '$orderId/$name';

      // OPTIMIZATION: Upload to storage first (with timeout), then insert DB record
      // This ensures we don't create orphaned DB records if upload fails
      // Using timeout to prevent hanging uploads
      await Supabase.instance.client.storage
          .from('order_proofs')
          .uploadBinary(
            objectPath, 
            fileBytes, 
            fileOptions: FileOptions(
              contentType: contentType, 
              upsert: true,
              cacheControl: '3600', // Cache for 1 hour
            ),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Storage upload timed out after 30 seconds');
            },
          );

      // Insert DB record after successful upload (with timeout)
      await Supabase.instance.client
          .from('order_proofs')
          .insert({
            'order_id': orderId,
            'driver_id': currentUser.id,
            'storage_path': objectPath,
            'content_type': contentType,
            'size_bytes': fileBytes.length,
          })
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Database insert timed out after 10 seconds');
            },
          );

      return true;
    } on TimeoutException catch (e) {
      _error = 'انتهت مهلة الرفع. يرجى المحاولة مرة أخرى / Upload timeout. Please try again.';
      Logger.d('❌ Upload timeout: $e');
      return false;
    } catch (e) {
      _error = _getErrorMessage(e);
      Logger.d('❌ Upload error: $e');
      return false;
    }
  }

  // Check if order has at least one proof
  Future<bool> hasOrderProof(String orderId) async {
    try {
      final result = await Supabase.instance.client
          .from('order_proofs')
          .select('id')
          .eq('order_id', orderId)
          .limit(1);
      return (result as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Fetch proof list for an order
  Future<List<Map<String, dynamic>>> getOrderProofs(String orderId) async {
    try {
      final rows = await Supabase.instance.client
          .from('order_proofs')
          .select('id, storage_path, created_at, content_type, size_bytes')
          .eq('order_id', orderId)
          .order('created_at', ascending: false);
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // Repost rejected order with increased delivery fee
  Future<bool> repostOrder(String orderId, double newDeliveryFee) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _error = 'المستخدم غير مسجل الدخول';
        return false;
      }

      Logger.d('🔄 Reposting order $orderId with new fee: $newDeliveryFee');

      // Use the database function to repost with vehicle type checking
      final response = await Supabase.instance.client.rpc(
        'repost_order_with_increased_fee',
        params: {
          'p_order_id': orderId,
          'p_merchant_id': currentUser.id,
        },
      );

      Logger.d('📦 Repost response: $response');
      Logger.d('📦 Response type: ${response.runtimeType}');

      // Handle both boolean (old function) and JSON (new function) responses
      bool success = false;
      String? errorMessage;
      
      if (response is Map<String, dynamic>) {
        // New JSON response
        success = response['success'] as bool? ?? false;

        if (!success) {
          final error = response['error'] as String?;
          final message = response['message'] as String?;

          // Handle specific error types
          if (error == 'no_drivers') {
            final vehicleType = response['vehicle_type'] as String?;
            final vehicleTypeArabic = vehicleType == 'motorcycle' || vehicleType == 'motorbike'
                ? 'دراجة نارية'
                : vehicleType == 'car'
                    ? 'سيارة'
                    : vehicleType == 'truck'
                        ? 'شاحنة'
                        : 'مركبة';
            
            errorMessage = 'لا يوجد سائقي $vehicleTypeArabic متصلين حالياً. يرجى المحاولة لاحقاً.';
          } else {
            errorMessage = message ?? 'فشل إعادة نشر الطلب';
          }

          Logger.d('❌ Repost failed: $errorMessage');
          _error = errorMessage;
          return false;
        }

        // Success
        final newFee = response['new_fee'];
        final availableDrivers = response['available_drivers'];
        Logger.d('✅ Order $orderId reposted successfully!');
        Logger.d('   New fee: $newFee IQD');
        Logger.d('   Available drivers: $availableDrivers');
      } else if (response is bool) {
        // Old boolean response (backward compatibility)
        success = response;
        Logger.d('✅ Order $orderId reposted (legacy boolean response): $success');
        if (!success) {
          errorMessage = 'فشل إعادة نشر الطلب';
          _error = errorMessage;
          return false;
        }
      } else {
        // Unexpected response type
        Logger.d('⚠️ Unexpected response type: ${response.runtimeType}');
        errorMessage = 'استجابة غير متوقعة من الخادم';
        _error = errorMessage;
        return false;
      }

      // Invalidate cache
      final effectiveRole = _cachedUserRole ?? 'merchant';
      final cacheKey = 'orders_${currentUser.id}_${effectiveRole}_0';
      await _responseCache.invalidate(cacheKey);
      
      // Reload orders to get updated list
      await _loadOrders();
      return true;
    } catch (e) {
      Logger.d('❌ Error reposting order: $e');
      _error = _getErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Set current order
  void setCurrentOrder(OrderModel? order) {
    _currentOrder = order;
    notifyListeners();
  }

  // Get order by ID
  OrderModel? getOrderById(String orderId) {
    try {
      return _orders.firstWhere((order) => order.id == orderId);
    } catch (e) {
      return null;
    }
  }


  // Get error message
  String _getErrorMessage(dynamic error) {
    if (error.toString().contains('Order not found')) {
      return 'الطلب غير موجود';
    } else if (error.toString().contains('Driver not available')) {
      return 'لا يوجد سائق متاح';
    } else if (error.toString().contains('Order already assigned')) {
      return 'الطلب مخصص بالفعل';
    } else if (error.toString().contains('Invalid status transition')) {
      return 'تغيير الحالة غير صحيح';
    } else {
      return 'حدث خطأ غير متوقع';
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Helper method to send merchant notifications asynchronously
  /// Send merchant notification with proper async/await handling
  /// This ensures notifications are not dropped
  Future<void> _sendMerchantNotification(Future<void> Function() notificationCall) async {
    try {
      await notificationCall();
    } catch (e) {
      Logger.d('❌ Merchant notification failed: $e');
    }
  }

  /// Manually remove an order from local state (for immediate UI updates)
  /// This is used when an order is marked as delivered to ensure immediate disappearance
  /// The subscription will also handle removal, but this prevents visual lag
  void removeOrderFromLocalState(String orderId) {
    Logger.d('🗑️  Manually removing order $orderId from local state');
    final initialCount = _orders.length;
    _orders.removeWhere((order) => order.id == orderId);
    final finalCount = _orders.length;
    
    if (initialCount != finalCount) {
      Logger.d('✅ Order $orderId removed from local state ($initialCount → $finalCount orders)');
      
      // Invalidate cache when order is removed
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        final effectiveRole = _cachedUserRole ?? 'merchant';
        final cacheKey = 'orders_${currentUser.id}_${effectiveRole}_0';
        _responseCache.invalidate(cacheKey);
      }
      
      notifyListeners();
    } else {
      Logger.d('⚠️  Order $orderId not found in local state (may already be removed)');
    }
  }
  
  /// Load fresh orders and cache them (background operation)
  Future<void> _loadFreshOrdersAndCache(
    String userId,
    String userRole,
    OptimizedOrderLoader loader,
    RequestPriority priority,
    String cacheKey,
  ) async {
    try {
      final orders = await loader.loadOrdersOptimized(
        userId: userId,
        userRole: userRole,
        page: 0,
        priority: priority,
      );
      
      if (orders.isNotEmpty) {
        _orders = orders;
        await _responseCache.cacheResponse(
          key: cacheKey,
          data: orders,
          cacheDuration: const Duration(minutes: 2),
        );
        notifyListeners();
      }
    } catch (e) {
      // Silently fail - we already have cached data
      Logger.d('⚠️ Background refresh failed: $e');
    }
  }

  // Bulk order methods removed - bulk orders are no longer supported

}
