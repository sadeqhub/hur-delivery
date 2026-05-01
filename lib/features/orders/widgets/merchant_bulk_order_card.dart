import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../shared/models/bulk_order_model.dart';
import '../../../core/localization/app_localizations.dart';

/// Card widget to display bulk orders in merchant dashboard
class MerchantBulkOrderCard extends StatelessWidget {
  final BulkOrderModel bulkOrder;
  final VoidCallback? onTap;

  const MerchantBulkOrderCard({
    super.key,
    required this.bulkOrder,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    
    // Get status color and text
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (bulkOrder.status) {
      case 'pending':
        statusColor = AppColors.warning;
        statusText = loc.bulkOrderStatusPending;
        statusIcon = Icons.pending;
        break;
      case 'assigned':
        statusColor = AppColors.secondary;
        statusText = loc.bulkOrderStatusAssigned;
        statusIcon = Icons.assignment;
        break;
      case 'accepted':
        statusColor = AppColors.primary;
        statusText = loc.bulkOrderStatusAccepted;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'picked_up':
        statusColor = AppColors.success;
        statusText = loc.pickedUp ?? 'تم الاستلام';
        statusIcon = Icons.inventory_2;
        break;
      case 'on_the_way':
        statusColor = AppColors.success;
        statusText = loc.onTheWay ?? 'في الطريق';
        statusIcon = Icons.local_shipping;
        break;
      case 'delivered':
        statusColor = AppColors.success;
        statusText = loc.delivered ?? 'تم التسليم';
        statusIcon = Icons.check_circle;
        break;
      case 'active':
        statusColor = AppColors.success;
        statusText = loc.bulkOrderStatusActive;
        statusIcon = Icons.local_shipping;
        break;
      case 'completed':
        statusColor = AppColors.success;
        statusText = loc.bulkOrderStatusCompleted;
        statusIcon = Icons.check_circle;
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        statusText = loc.bulkOrderStatusCancelled;
        statusIcon = Icons.cancel;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusText = loc.bulkOrderStatusRejected;
        statusIcon = Icons.close;
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusText = bulkOrder.status;
        statusIcon = Icons.help_outline;
    }

    // Get neighborhoods count
    final neighborhoodsCount = bulkOrder.neighborhoodItems?.length ?? bulkOrder.neighborhoods.length;
    
    // Format order date
    final now = DateTime.now();
    final orderDate = bulkOrder.orderDate;
    final today = DateTime(now.year, now.month, now.day);
    final orderDay = DateTime(orderDate.year, orderDate.month, orderDate.day);
    final daysDiff = orderDay.difference(today).inDays;
    String dateText;
    if (daysDiff == 0) {
      dateText = loc.today;
    } else if (daysDiff == 1) {
      dateText = 'غداً'; // Tomorrow
    } else if (daysDiff > 1) {
      dateText = 'في $daysDiff ${loc.daysShort}';
    } else {
      dateText = orderDate.toString().split(' ')[0];
    }

    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.getResponsiveSpacing(context, 12)),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 2),
      ),
      child: InkWell(
        onTap: onTap ?? () {
          // Navigate to bulk order details if needed
          // context.push('/bulk-order-details/${bulkOrder.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, 16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Status and Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status Badge
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 16, color: statusColor),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              statusText,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Order Date
                  Text(
                    dateText,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Neighborhoods Count
              Row(
                children: [
                  Icon(Icons.location_on, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    '$neighborhoodsCount ${loc.deliveryNeighborhoods}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Fees
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.perDeliveryFee,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${bulkOrder.perDeliveryFee.toStringAsFixed(0)} ${loc.currencySymbol}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          loc.bulkOrderFee,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${bulkOrder.bulkOrderFee.toStringAsFixed(0)} ${loc.currencySymbol}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Driver info if assigned
              if (bulkOrder.driverId != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.person, size: 18, color: cs.secondary),
                    const SizedBox(width: 8),
                    Text(
                      loc.assignedDriver,
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

