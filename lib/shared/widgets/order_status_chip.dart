import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/models/order_status.dart';

/// Unified order status chip — soft tinted background + dot + label.
class OrderStatusChip extends StatelessWidget {
  final String status;
  final bool compact;

  const OrderStatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final dbStatus = OrderStatus.fromDb(status);
    final (color, label) = _resolve(status, dbStatus, loc);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 6 : 7,
            height: compact ? 6 : 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: compact ? 5 : 6),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  (Color, String) _resolve(String raw, OrderStatus s, AppLocalizations loc) {
    if (raw == 'scheduled') {
      return (Colors.purple, loc.statusScheduled);
    }
    return switch (s) {
      OrderStatus.pending => (AppColors.statusPending, loc.statusPending),
      OrderStatus.assigned => (AppColors.primary, loc.statusAssigned),
      OrderStatus.accepted => (AppColors.statusAccepted, loc.statusAccepted),
      OrderStatus.onTheWay => (AppColors.statusInProgress, loc.statusOnTheWay),
      OrderStatus.pickedUp => (AppColors.statusInProgress, loc.statusOnTheWay),
      OrderStatus.delivered => (AppColors.statusCompleted, loc.statusDelivered),
      OrderStatus.cancelled => (AppColors.statusCancelled, loc.statusCancelled),
      OrderStatus.rejected => (AppColors.statusCancelled, loc.statusRejected),
      OrderStatus.unassigned => (AppColors.warning, loc.statusPending),
      OrderStatus.unknown => (AppColors.textTertiary, loc.statusUnknown),
    };
  }
}
