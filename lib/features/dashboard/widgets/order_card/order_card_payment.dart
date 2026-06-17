import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_localizations_ext.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/order_model.dart';
import 'order_card_tokens.dart';

/// Delivery fee (hero) centered; order total stacked directly underneath.
class OrderCardPayment extends StatelessWidget {
  const OrderCardPayment({
    super.key,
    required this.order,
    this.horizontalPadding = 16,
  });

  final OrderModel order;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final fee = order.deliveryFee.toStringAsFixed(0);
    final total = order.totalAmount.toStringAsFixed(0);
    final cur = _currencyLabel(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 4, horizontalPadding, 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.42),
            width: OrderCardTokens.cardOutlineWidth,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                loc.deliveryFee.toUpperCase(),
                style: OrderCardTokens.labelMuted(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$fee $cur',
                style: OrderCardTokens.heroDeliveryFee(context).copyWith(
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Text(
                loc.orderValue.toUpperCase(),
                style: OrderCardTokens.labelMuted(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$total $cur',
                style: OrderCardTokens.orderTotalSecondary(context).copyWith(
                  color: AppColors.primaryDeep,
                ),
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Arabic suffix when locale is Arabic, else abbreviated IQD hint.
  String _currencyLabel(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return loc.isArabic ? '\u062F.\u0639' : 'IQD';
  }
}
