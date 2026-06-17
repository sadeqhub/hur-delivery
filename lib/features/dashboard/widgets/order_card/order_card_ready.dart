import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_localizations_ext.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/order_model.dart';
import 'order_card_tokens.dart';

/// Neutral typography banner for merchant ready time (size/weight hierarchy only).
class OrderCardReadyBanner extends StatelessWidget {
  const OrderCardReadyBanner({
    super.key,
    required this.order,
    this.horizontalPadding = 14,
  });

  final OrderModel order;
  final double horizontalPadding;

  static String _formatCountdown(BuildContext context, int seconds) {
    final loc = AppLocalizations.of(context);
    if (seconds <= 0) return loc.now;

    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (loc.isArabic) {
      if (hours > 0) {
        return minutes > 0 ? '${hours}س $minutesد' : '${hours}س';
      }
      if (minutes > 0) {
        return secs > 0 ? '${minutes}د $secsث' : '${minutes}د';
      }
      return secs > 0 ? '${secs}ث' : loc.now;
    }

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    final readyAt = order.readyAt;
    if (readyAt == null) return const SizedBox.shrink();

    final initial = order.secondsUntilReady;
    final loc = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 4,
      ),
      child: StreamBuilder<int>(
        stream: Stream<int>.periodic(
          const Duration(seconds: 1),
          (_) {
            final difference = readyAt.difference(DateTime.now());
            final s = difference.inSeconds;
            return s > 0 ? s : 0;
          },
        ).takeWhile((s) => s >= 0),
        initialData: initial > 0 ? initial : 0,
        builder: (context, snap) {
          final seconds = snap.data ?? 0;
          final ready = seconds <= 0;
          final timeStr = ready ? '' : _formatCountdown(context, seconds);

          return DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: OrderCardTokens.cardOutline,
                width: OrderCardTokens.cardOutlineWidth,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ready
                        ? loc.orderReadyNow
                        : loc.driverReadyInPrefix,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.06,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ready ? loc.orderReadyNow : timeStr,
                    style: TextStyle(
                      fontSize: ready ? 17 : 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
