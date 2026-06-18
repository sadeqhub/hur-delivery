import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/order_status.dart';
import '../../../../shared/widgets/order_status_chip.dart';
import 'order_card_actions.dart';
import 'order_card_header.dart';
import 'order_card_payment.dart';
import 'order_card_ready.dart';
import 'order_card_tokens.dart';

/// Driver swipeable bottom sheet card — always expanded (no collapse).
class DriverOrderCard extends StatelessWidget {
  const DriverOrderCard({
    super.key,
    required this.order,
    required this.onOpenPickupMaps,
    required this.onOpenDropoffMaps,
    required this.onOpenFullRouteMaps,
    required this.onCallMerchant,
    required this.onCallCustomer,
    required this.onReject,
    required this.onAccept,
    required this.onPickedUp,
    required this.onDeliver,
  });

  final OrderModel order;
  final VoidCallback onOpenPickupMaps;
  final VoidCallback onOpenDropoffMaps;
  final VoidCallback onOpenFullRouteMaps;
  final VoidCallback onCallMerchant;
  final VoidCallback onCallCustomer;
  final VoidCallback onReject;
  final VoidCallback onAccept;
  final VoidCallback onPickedUp;
  final VoidCallback onDeliver;

  bool get _awaitingAccept =>
      order.statusEnum == OrderStatus.pending || order.statusEnum == OrderStatus.assigned;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {},
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: OrderCardTokens.elegantSheetWhite,
          borderRadius: OrderCardTokens.expandedTopRadius,
          border: Border.all(
            color: OrderCardTokens.cardOutline,
            width: OrderCardTokens.cardOutlineWidth,
          ),
          boxShadow: OrderCardTokens.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: OrderCardTokens.expandedTopRadius,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OrderStatusChip(status: order.status, compact: true),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  clipBehavior: Clip.hardEdge,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OrderCardPayment(order: order),
                      OrderCardReadyBanner(order: order),
                      OrderCardFaintOrderMeta(order: order),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Divider(
                          height: 1,
                          thickness: OrderCardTokens.cardOutlineWidth,
                          color: OrderCardTokens.cardOutline,
                        ),
                      ),
                      OrderCardQuickActions(
                        onPickupMaps: onOpenPickupMaps,
                        onDropoffMaps: onOpenDropoffMaps,
                        onFullRouteMaps: onOpenFullRouteMaps,
                        onMerchant: onCallMerchant,
                        onCustomer: onCallCustomer,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                        child: _awaitingAccept
                            ? OrderCardPendingAcceptRow(
                                orderId: order.id,
                                onReject: onReject,
                                onAccept: onAccept,
                              )
                            : OrderCardPostAcceptActions(
                                status: order.status,
                                onPickedUp: onPickedUp,
                                onDeliver: onDeliver,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
