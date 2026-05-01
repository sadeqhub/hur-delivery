import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/models/order_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers/auth_provider.dart';

/// Widget to display delivery timer countdown
class DeliveryTimerWidget extends StatefulWidget {
  final OrderModel order;

  const DeliveryTimerWidget({
    super.key,
    required this.order,
  });

  @override
  State<DeliveryTimerWidget> createState() => _DeliveryTimerWidgetState();
}

class _DeliveryTimerWidgetState extends State<DeliveryTimerWidget> {
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
  void didUpdateWidget(DeliveryTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.deliveryTimerExpiresAt != widget.order.deliveryTimerExpiresAt ||
        oldWidget.order.deliveryTimerStoppedAt != widget.order.deliveryTimerStoppedAt) {
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

    // Fire late popup exactly once per order, when timer hits zero or below (and not stopped)
    // BUT: Never show late popup to merchants
    final remaining = _remainingSeconds ?? 0;
    if (order.deliveryTimerStoppedAt == null &&
        remaining <= 0 &&
        (!_lateDialogShown || _lateDialogOrderId != order.id)) {
      // Check user role - don't show popup to merchants
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final userRole = authProvider.user?.role;
        if (userRole == 'merchant') {
          // Don't show late popup to merchants
          return;
        }
      } catch (e) {
        // If provider is not available, don't show popup to be safe
        print('Warning: Could not check user role for late dialog: $e');
        return;
      }
      
      _lateDialogShown = true;
      _lateDialogOrderId = order.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showLateOrderDialog();
      });
    }
  }

  Future<void> _showLateOrderDialog() async {
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
                  color: AppColors.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withOpacity(0.6)),
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
    final loc = AppLocalizations.of(context);

    // Don't show timer if order is not on the way
    if (!order.isOnTheWay) {
      return const SizedBox.shrink();
    }

    // Timer hasn't started
    if (order.deliveryTimerExpiresAt == null) {
      return const SizedBox.shrink();
    }

    // Timer stopped (driver reached dropoff)
    if (order.deliveryTimerStoppedAt != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.success.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: 16,
            ),
            SizedBox(width: 8),
            Text(
              'وصلت إلى موقع التسليم',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    // Calculate remaining / late time
    final diffSeconds = _remainingSeconds ?? 0;
    final isLate = diffSeconds <= 0;
    final lateSeconds = diffSeconds < 0 ? -diffSeconds : 0;
    final remainingSeconds = diffSeconds > 0 ? diffSeconds : 0;
    final isWarning = !isLate && remainingSeconds <= 300; // 5 minutes warning

    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final IconData icon;
    String text;

    if (isLate && lateSeconds > 0) {
      bgColor = AppColors.error.withOpacity(0.1);
      borderColor = AppColors.error.withOpacity(0.3);
      textColor = AppColors.error;
      icon = Icons.error_outline;
      text = '${loc.lateDurationLabel}${_formatTime(lateSeconds)}';
    } else {
      bgColor = isWarning
          ? AppColors.warning.withOpacity(0.1)
          : AppColors.primary.withOpacity(0.1);
      borderColor = isWarning
          ? AppColors.warning.withOpacity(0.3)
          : AppColors.primary.withOpacity(0.3);
      textColor = isWarning ? AppColors.warning : AppColors.primary;
      icon = Icons.timer_outlined;
      text = '${loc.timeRemainingLabel}${_formatTime(remainingSeconds)}';
    }

    return GestureDetector(
      onTap: _showTimerInfoDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: textColor,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
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

