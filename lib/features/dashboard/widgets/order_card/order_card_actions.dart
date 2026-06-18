import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/icons/hur_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/models/order_status.dart';
import '../../../../core/providers/order_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../shared/widgets/hur_icon.dart';
import 'order_card_tokens.dart';

/// Map + phone actions as labeled buttons inside the sheet.
class OrderCardQuickActions extends StatelessWidget {
  const OrderCardQuickActions({
    super.key,
    required this.onPickupMaps,
    required this.onDropoffMaps,
    required this.onFullRouteMaps,
    required this.onMerchant,
    required this.onCustomer,
    this.horizontalPadding = 14,
  });

  final VoidCallback onPickupMaps;
  final VoidCallback onDropoffMaps;
  final VoidCallback onFullRouteMaps;
  final VoidCallback onMerchant;
  final VoidCallback onCustomer;
  final double horizontalPadding;

  static Color _accentSheetWash(Color accent) {
    return Color.alphaBlend(
      accent.withValues(alpha: 0.18),
      OrderCardTokens.elegantSheetWhite,
    );
  }

  ButtonStyle _accentOutlined(Color accent) {
    return OutlinedButton.styleFrom(
      foregroundColor: accent,
      backgroundColor: _accentSheetWash(accent),
      side: BorderSide(
        color: accent,
        width: OrderCardTokens.cardOutlineWidth,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OrderCardTokens.ctaCornerRadius),
      ),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  /// Pickup — map pin store; same teal as pickup marker.
  ButtonStyle _pickupPinButtonStyle() => _accentOutlined(AppColors.primary);

  /// Delivery address — map pin destination; amber like drop-off marker.
  ButtonStyle _deliveryPinButtonStyle() => _accentOutlined(AppColors.warning);

  /// Turn-by-turn / full-route preview — blue itinerary.
  ButtonStyle _routeButtonStyle() => _accentOutlined(AppColors.secondary);

  /// Call merchant — deep teal / business line.
  ButtonStyle _merchantCallButtonStyle() => _accentOutlined(AppColors.primaryDeep);

  /// Call customer — success / end customer.
  ButtonStyle _customerCallButtonStyle() => _accentOutlined(AppColors.success);

  Widget _actionIcon(HurIconKind kind, Color color) =>
      HurIcon(kind, dimension: 18, color: color);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    const neutralLabelStyle = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );
    final pickupLabelStyle = neutralLabelStyle.copyWith(color: AppColors.primary);
    final deliveryLabelStyle = neutralLabelStyle.copyWith(color: AppColors.warning);
    final routeLabelStyle =
        neutralLabelStyle.copyWith(color: AppColors.secondary);
    final merchantLabelStyle =
        neutralLabelStyle.copyWith(color: AppColors.primaryDeep);
    final customerLabelStyle =
        neutralLabelStyle.copyWith(color: AppColors.success);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickupMaps,
                  icon: _actionIcon(HurIconKind.merchant, AppColors.primary),
                  label: Text(loc.store, maxLines: 1, overflow: TextOverflow.ellipsis, style: pickupLabelStyle),
                  style: _pickupPinButtonStyle(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDropoffMaps,
                  icon: _actionIcon(HurIconKind.mapPin, AppColors.warning),
                  label: Text(loc.delivery, maxLines: 1, overflow: TextOverflow.ellipsis, style: deliveryLabelStyle),
                  style: _deliveryPinButtonStyle(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onFullRouteMaps,
                  icon: _actionIcon(HurIconKind.navigation, AppColors.secondary),
                  label: Text(loc.showRoute, maxLines: 1,
                      overflow: TextOverflow.ellipsis, style: routeLabelStyle),
                  style: _routeButtonStyle(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(
            height: 1,
            thickness: OrderCardTokens.cardOutlineWidth,
            color: OrderCardTokens.cardOutline,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onMerchant,
                  icon: _actionIcon(HurIconKind.phone, AppColors.primaryDeep),
                  label: Text(loc.merchantButton, maxLines: 1,
                      overflow: TextOverflow.ellipsis, style: merchantLabelStyle),
                  style: _merchantCallButtonStyle(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCustomer,
                  icon: _actionIcon(HurIconKind.profile, AppColors.success),
                  label: Text(loc.customerButton, maxLines: 1,
                      overflow: TextOverflow.ellipsis, style: customerLabelStyle),
                  style: _customerCallButtonStyle(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OrderCardPendingAcceptRow extends StatelessWidget {
  const OrderCardPendingAcceptRow({
    super.key,
    required this.orderId,
    required this.onReject,
    required this.onAccept,
  });

  final String orderId;
  final VoidCallback onReject;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: _RejectButton(onTap: onReject),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child:
              AcceptOrderLongPressBar(orderId: orderId, onAccept: onAccept),
        ),
      ],
    );
  }
}

/// Post-accept primary CTA row (picked up → deliver).
class OrderCardPostAcceptActions extends StatelessWidget {
  const OrderCardPostAcceptActions({
    super.key,
    required this.status,
    required this.onPickedUp,
    required this.onDeliver,
  });

  final String status;
  final VoidCallback onPickedUp;
  final VoidCallback onDeliver;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (OrderStatus.fromDb(status) == OrderStatus.accepted) {
      return _PrimaryFullWidthButton(
        label: loc.driverPickupReceivedButton,
        onTap: onPickedUp,
        backgroundColor: AppColors.warning,
        foregroundColor: Colors.white,
      );
    }
    if (OrderStatus.fromDb(status) == OrderStatus.onTheWay) {
      return _PrimaryFullWidthButton(
        label: loc.driverDeliverCompleteButton,
        onTap: onDeliver,
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
      );
    }
    return _PrimaryFullWidthButton(
      label: loc.driverOrderCompletedStub,
      onTap: null,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    );
  }
}

class _PrimaryFullWidthButton extends StatelessWidget {
  const _PrimaryFullWidthButton({
    required this.label,
    required this.onTap,
    this.backgroundColor = AppColors.primary,
    this.foregroundColor = Colors.white,
  });

  final String label;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: OrderCardTokens.ctaButtonHeight,
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: AppColors.surfaceVariant,
          disabledForegroundColor: AppColors.textTertiary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OrderCardTokens.ctaCornerRadius),
            side: OrderCardTokens.cardBorderSide,
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _RejectButton extends StatelessWidget {
  const _RejectButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return SizedBox(
      height: OrderCardTokens.ctaButtonHeight,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OrderCardTokens.ctaCornerRadius),
            side: OrderCardTokens.cardBorderSide,
          ),
          elevation: 0,
        ),
        child: Text(
          loc.reject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// 3-second secure accept bar with timeout drain coloured in primary teal.
class AcceptOrderLongPressBar extends StatefulWidget {
  const AcceptOrderLongPressBar({
    super.key,
    required this.orderId,
    required this.onAccept,
  });

  final String orderId;
  final VoidCallback onAccept;

  @override
  State<AcceptOrderLongPressBar> createState() =>
      _AcceptOrderLongPressBarState();
}

class _AcceptOrderLongPressBarState extends State<AcceptOrderLongPressBar>
    with SingleTickerProviderStateMixin {
  Timer? _pressTimer;
  Timer? _timeoutTimer;
  double _progress = 0;
  bool _isPressed = false;
  int _lastHapticStep = -1;
  int _remainingSeconds = AppConstants.driverAcceptTimeoutSeconds;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.96).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _updateTimeout();
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateTimeout();
    });
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    _timeoutTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _updateTimeout() {
    final orderProvider =
        Provider.of<OrderProvider>(context, listen: false);
    final remain =
        orderProvider.getLiveAcceptCountdownSeconds(widget.orderId);
    if (remain != _remainingSeconds && mounted) {
      setState(() => _remainingSeconds = remain);
    }
  }

  void _startPress() {
    if (_isPressed) return;
    setState(() {
      _isPressed = true;
      _progress = 0;
      _lastHapticStep = -1;
    });
    _animationController.forward();
    AppHaptics.medium();

    const duration = Duration(seconds: 3);
    const interval = Duration(milliseconds: 50);
    final steps = duration.inMilliseconds / interval.inMilliseconds;
    final increment = 1.0 / steps;

    _pressTimer = Timer.periodic(interval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _progress += increment;
        final step = (timer.tick * interval.inMilliseconds / 400).floor();
        if (step > _lastHapticStep && step < 10) {
          _lastHapticStep = step;
          AppHaptics.selection();
        }
        if (_progress >= 1) {
          _progress = 1;
          timer.cancel();
          _completePress();
        }
      });
    });
  }

  void _cancelPress() {
    _pressTimer?.cancel();
    _animationController.reverse();
    if (mounted) {
      setState(() {
        _isPressed = false;
        _progress = 0;
      });
    }
  }

  void _completePress() {
    _pressTimer?.cancel();
    AppHaptics.heavy();
    widget.onAccept();
    if (mounted) {
      setState(() {
        _isPressed = false;
        _progress = 0;
      });
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final timeoutFactor =
        (_remainingSeconds / AppConstants.driverAcceptTimeoutSeconds)
            .clamp(0.0, 1.0);
    final buttonText = _isPressed
        ? '${((1 - _progress) * 3).ceil()}…'
        : '${loc.acceptOrderButton} (${_remainingSeconds}s)';

    return GestureDetector(
      onTapDown: (_) => _startPress(),
      onTapUp: (_) => _cancelPress(),
      onTapCancel: _cancelPress,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, _) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              height: OrderCardTokens.ctaButtonHeight,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius:
                    BorderRadius.circular(OrderCardTokens.ctaCornerRadius),
                border: Border.all(
                  color: AppColors.primaryDeep,
                  width: OrderCardTokens.cardOutlineWidth,
                ),
              ),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(OrderCardTokens.ctaCornerRadius),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: timeoutFactor,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                    ),
                    if (_isPressed)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _progress,
                          heightFactor: 1,
                          child: ColoredBox(
                            color: Colors.white.withValues(alpha: 0.32),
                          ),
                        ),
                      ),
                    Positioned.fill(
                      left: 8,
                      right: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!_isPressed) ...[
                            const Icon(Icons.check_circle_outline,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              buttonText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
