// EXAMPLE: How to integrate priority system into OrderProvider
// This is a reference implementation showing how to modify OrderProvider._loadOrders()

/*
import 'package:hur_delivery/core/services/optimized_order_loader.dart';
import 'package:hur_delivery/core/services/performance_optimizer.dart';
import 'package:hur_delivery/core/services/request_priority_manager.dart';

// In OrderProvider class, modify _loadOrders() method:

Future<void> _loadOrders() async {
  try {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    // Get user role (use existing caching logic)
    String? userRole = _cachedUserRole;
    // ... existing role detection code ...

    // Get performance optimizer
    final optimizer = PerformanceOptimizer();
    final loader = OptimizedOrderLoader();
    
    // Determine priority based on current screen
    final screenName = optimizer.visibilityTracker.currentScreen;
    final isDashboardVisible = screenName == 'merchant_dashboard' || 
                               screenName == 'driver_dashboard';
    
    final priority = isDashboardVisible 
        ? RequestPriority.critical  // Dashboard is visible - load immediately
        : RequestPriority.high;     // Background load - still important
    
    // Load first page of orders with priority
    final orders = await loader.loadOrdersOptimized(
      userId: currentUser.id,
      userRole: effectiveRole,
      page: 0,
      priority: priority,
    );
    
    // Update orders list
    _orders = orders;
    
    // If connection is good, prefetch next page in background
    if (optimizer.networkQuality != NetworkQuality.poor) {
      unawaited(loader.loadOrdersOptimized(
        userId: currentUser.id,
        userRole: effectiveRole,
        page: 1,
        priority: RequestPriority.low, // Background prefetch
      ));
    }
    
    notifyListeners();
  } catch (e) {
    _error = e.toString();
    print('❌ Error loading orders: $e');
    _orders = [];
    notifyListeners();
  }
}

// For loading order details (when user opens order details screen):

Future<void> refreshOrder(String orderId) async {
  try {
    final optimizer = PerformanceOptimizer();
    final loader = OptimizedOrderLoader();
    
    // Load order details with high priority (user is viewing this)
    final updatedOrder = await loader.loadOrderDetails(
      orderId: orderId,
      priority: RequestPriority.critical, // User is viewing this screen
    );
    
    if (updatedOrder != null) {
      // Update order in list
      final orderIndex = _orders.indexWhere((o) => o.id == orderId);
      if (orderIndex != -1) {
        _orders[orderIndex] = updatedOrder;
      }
      
      // Update current order if it's the same
      if (_currentOrder?.id == orderId) {
        _currentOrder = updatedOrder;
      }
      
      notifyListeners();
    }
  } catch (e) {
    print('❌ Error refreshing order: $e');
  }
}
*/

