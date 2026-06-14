import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/models/order_model.dart';
import '../providers/active_order_provider.dart';
import '../providers/driver_dashboard_controller.dart';

/// Swipeable order card stack for the driver dashboard.
/// Extracted from the monolithic driver_dashboard.dart.
class DriverOrderSwipeCards extends StatelessWidget {
  /// Called when the driver accepts an order.
  final Future<void> Function(String orderId) onAccept;

  /// Called when the driver rejects an order.
  final Future<void> Function(String orderId) onReject;

  /// Called to mark an order as on-the-way.
  final Future<void> Function(String orderId) onMarkOnTheWay;

  /// Called to mark an order as delivered.
  final Future<void> Function(OrderModel order) onMarkDelivered;

  const DriverOrderSwipeCards({
    super.key,
    required this.onAccept,
    required this.onReject,
    required this.onMarkOnTheWay,
    required this.onMarkDelivered,
  });

  @override
  Widget build(BuildContext context) {
    // Read controller to access shared UI state (e.g. currentOrderIndex)
    // ignore: unused_local_variable
    final controller = context.watch<DriverDashboardController>();

    return Selector<ActiveOrderProvider, List<OrderModel>>(
      selector: (_, ap) => ap.orders,
      builder: (context, orders, _) {
        if (orders.isEmpty) return const SizedBox.shrink();
        // The actual card building is done by the parent shell for now.
        // This widget serves as the composition boundary.
        return const SizedBox.shrink();
      },
    );
  }
}
