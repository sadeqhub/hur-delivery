import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/models/order_model.dart';
// ignore: unused_import
import '../../../shared/widgets/delivery_timer_widget.dart';

/// Prominent delivery-countdown banner shown at the top of the driver map.
///
/// Extracted from the private `_ProminentTimerWidget` that previously lived
/// inside driver_dashboard.dart.  Renamed to public `DriverTimerBanner` so
/// other files can reference it without relying on the monolith.
class DriverTimerBanner extends StatefulWidget {
  final OrderModel order;

  const DriverTimerBanner({super.key, required this.order});

  @override
  State<DriverTimerBanner> createState() => _DriverTimerBannerState();
}

class _DriverTimerBannerState extends State<DriverTimerBanner> {
  Timer? _timer;
  int? _remainingSeconds;
  bool _lateDialogShown = false;
  String? _lateDialogOrderId;

  @override
  void initState() {
    super.initState();
    _calculateRemainingTime();
    _startTimer();
  }

  @override
  void didUpdateWidget(DriverTimerBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.deliveryTimerExpiresAt !=
            widget.order.deliveryTimerExpiresAt ||
        oldWidget.order.deliveryTimerStoppedAt !=
            widget.order.deliveryTimerStoppedAt) {
      _calculateRemainingTime();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateRemainingTime() {
    final order = widget.order;

    // Timer is stopped if driver reached dropoff
    if (order.deliveryTimerStoppedAt != null) {
      _remainingSeconds = 0;
      return;
    }

    // Timer hasn't started yet
    if (order.deliveryTimerExpiresAt == null) {
      _remainingSeconds = null;
      return;
    }

    // Calculate remaining / late time (allow negative to count how late)
    final now = DateTime.now();
    final expiresAt = order.deliveryTimerExpiresAt!;
    final difference = expiresAt.difference(now);

    _remainingSeconds = difference.inSeconds;

    // Fire late popup exactly once per order, when timer hits zero (and not stopped)
    final remaining = _remainingSeconds ?? 0;
    if (order.deliveryTimerStoppedAt == null &&
        remaining <= 0 &&
        (!_lateDialogShown || _lateDialogOrderId != order.id)) {
      _lateDialogShown = true;
      _lateDialogOrderId = order.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showLateOrderDialog();
      });
    }
  }

  Future<void> _showLateOrderDialog() async {
    // Avoid stacking dialogs
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loc.deliveryLateTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.deliveryLateMessage,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loc.deliveryTimerInfoMessage,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.deliveryLateAck),
            ),
          ],
        );
      },
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _calculateRemainingTime();
        });
      }
    });
  }

  String _formatTime(int seconds) {
    if (seconds < 0) return '00:00';

    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    // Timer stopped (driver reached dropoff)
    if (order.deliveryTimerStoppedAt != null) {
      return Container(
        height: 64, // Same height as rank badge
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            colors: [
              AppColors.success,
              AppColors.success.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.1),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.2),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'وصلت إلى موقع التسليم',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      height: 2,
                      width: 20,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate remaining / late time
    final diffSeconds = _remainingSeconds ?? 0;
    final isLate = diffSeconds <= 0;
    final lateSeconds = diffSeconds < 0 ? -diffSeconds : 0;
    final remainingSeconds = diffSeconds > 0 ? diffSeconds : 0;
    final isWarning = !isLate && remainingSeconds <= 300; // 5 minutes warning

    // Choose colors based on status
    List<Color> gradientColors;
    Color iconColor;
    Color shadowColor;
    IconData timerIcon;

    if (isLate && lateSeconds > 0) {
      gradientColors = [
        AppColors.error,
        AppColors.error.withValues(alpha: 0.8),
      ];
      iconColor = Colors.white;
      shadowColor = AppColors.error.withValues(alpha: 0.4);
      timerIcon = Icons.error_outline;
    } else if (isWarning) {
      gradientColors = [
        AppColors.warning,
        AppColors.warning.withValues(alpha: 0.8),
      ];
      iconColor = Colors.white;
      shadowColor = AppColors.warning.withValues(alpha: 0.4);
      timerIcon = Icons.timer_outlined;
    } else {
      gradientColors = [
        AppColors.primary,
        AppColors.primary.withValues(alpha: 0.8),
      ];
      iconColor = Colors.white;
      shadowColor = AppColors.primary.withValues(alpha: 0.4);
      timerIcon = Icons.timer_outlined;
    }

    return GestureDetector(
      onTap: _showTimerInfoDialog,
      child: Container(
        height: 64, // Same height as rank badge
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 16,
              offset: const Offset(0, 8),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.1),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Circle
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.2),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Icon(
                  timerIcon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Text
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (isLate && lateSeconds > 0
                              ? _formatTime(lateSeconds)
                              : _formatTime(remainingSeconds))
                          .toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      height: 2,
                      width: 20,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTimerInfoDialog() async {
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                color: AppColors.primary,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loc.deliveryTimerInfoTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.deliveryTimerInfoMessage,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loc.deliveryTimerInfoMessage,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.ok),
            ),
          ],
        );
      },
    );
  }
}
