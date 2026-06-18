import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/order_provider.dart';
import '../../shared/models/order_model.dart';

/// Thin Riverpod bridge over [OrderProvider].
/// Delegates all business logic to the existing ChangeNotifier.
/// Use ref.watch(orderNotifierProvider) in new screens instead of
/// context.watch<OrderProvider>().
class OrderNotifier extends ChangeNotifier {
  final OrderProvider _orders;

  OrderNotifier(this._orders) {
    _orders.addListener(notifyListeners);
  }

  List<OrderModel> get orders => _orders.orders;
  OrderModel? get currentOrder => _orders.currentOrder;
  bool get isLoading => _orders.isLoading;
  String? get error => _orders.error;
  List<OrderModel> get pendingOrders => _orders.pendingOrders;
  List<OrderModel> get activeOrders => _orders.activeOrders;
  List<OrderModel> get completedOrders => _orders.completedOrders;

  OrderProvider get delegate => _orders;

  @override
  void dispose() {
    _orders.removeListener(notifyListeners);
    super.dispose();
  }
}

/// Bridged from the OrderProvider in the MultiProvider tree.
/// Override in ProviderScope:
/// ```dart
/// ProviderScope(
///   overrides: [
///     orderNotifierProvider.overrideWith((ref) {
///       final orders = Provider.of<OrderProvider>(navigatorKey.currentContext!, listen: false);
///       return OrderNotifier(orders);
///     }),
///   ],
/// )
/// ```
// Riverpod 3 removed ChangeNotifierProvider — use plain Provider.
// This must always be overridden in ProviderScope; the throw is intentional.
final orderNotifierProvider = Provider<OrderNotifier>((ref) {
  throw UnimplementedError(
      'Provide orderNotifierProvider override in ProviderScope');
});
