import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/icons/hur_icons.dart';
import 'hur_icon.dart';

/// Wraps a form field and shakes it red when [errorMessage] is set.
class ShakeErrorField extends StatefulWidget {
  final Widget child;
  final String? errorMessage;
  final VoidCallback? onErrorCleared;

  const ShakeErrorField({
    super.key,
    required this.child,
    this.errorMessage,
    this.onErrorCleared,
  });

  @override
  State<ShakeErrorField> createState() => ShakeErrorFieldState();
}

class ShakeErrorFieldState extends State<ShakeErrorField>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String? _visibleError;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _visibleError = widget.errorMessage;
  }

  @override
  void didUpdateWidget(ShakeErrorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorMessage != null &&
        widget.errorMessage != oldWidget.errorMessage) {
      _triggerShake(widget.errorMessage!);
    } else if (widget.errorMessage == null && _visibleError != null) {
      setState(() => _visibleError = null);
    }
  }

  void triggerError(String message) => _triggerShake(message);

  void _triggerShake(String message) {
    setState(() => _visibleError = message);
    _controller.forward(from: 0);
  }

  void clearError() {
    if (_visibleError != null) {
      setState(() => _visibleError = null);
      widget.onErrorCleared?.call();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _visibleError != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final shake = math.sin(_controller.value * math.pi * 4) *
                (1 - _controller.value) *
                8;
            return Transform.translate(
              offset: Offset(hasError ? shake : 0, 0),
              child: child,
            );
          },
          child: widget.child,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      HurIcon(
                        HurIconKind.warning,
                        dimension: 16,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _visibleError!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
