import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/order_model.dart';

/// Faint order reference (no route / distance row).
class OrderCardFaintOrderMeta extends StatelessWidget {
  const OrderCardFaintOrderMeta({
    super.key,
    required this.order,
    this.horizontalPadding = 16,
  });

  final OrderModel order;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final code = order.userFriendlyCode ?? order.id.substring(0, 8);

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 6),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          '${loc.orderNumber} $code',
          style: TextStyle(
            fontSize: 11,
            height: 1.2,
            fontWeight: FontWeight.w500,
            color: AppColors.textTertiary.withValues(alpha: 0.55),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
