import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/app_haptics.dart';

/// Button wrapper with scale-down press animation and optional haptic.
class PressableButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool enableHaptic;
  final double scaleFactor;

  const PressableButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.enableHaptic = true,
    this.scaleFactor = 0.98,
  });

  @override
  State<PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<PressableButton> {
  bool _pressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onPressed == null) return;
    setState(() => _pressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    setState(() => _pressed = false);
  }

  void _handleTapCancel() {
    setState(() => _pressed = false);
  }

  void _handleTap() {
    if (widget.onPressed == null) return;
    if (widget.enableHaptic) AppHaptics.tap();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? widget.scaleFactor : 1.0;
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onPressed != null ? _handleTap : null,
      child: AnimatedScale(
        scale: scale,
        duration: AppTokens.durationFast,
        curve: AppTokens.curveStandard,
        child: widget.child,
      ),
    );
  }
}

/// Primary auth CTA — white fill, teal text.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final double height;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.width,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    return PressableButton(
      onPressed: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: AppTokens.durationFast,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          boxShadow: enabled ? AppTokens.elevationMd() : null,
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF00797E),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF00797E),
                ),
              ),
      ),
    );
  }
}

/// Secondary auth CTA — frosted glass.
class AuthSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double? width;
  final double height;

  const AuthSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.width,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return PressableButton(
      onPressed: onPressed,
      child: Container(
        width: width,
        height: height,
        decoration: AppTokens.glassDecoration(),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
      ),
    );
  }
}
