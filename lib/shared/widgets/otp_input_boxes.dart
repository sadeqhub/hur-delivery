import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/icons/hur_icons.dart';
import '../../core/utils/app_haptics.dart';
import 'hur_icon.dart';

/// Six-box OTP input with auto-advance and paste support.
class OtpInputBoxes extends StatefulWidget {
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool hasError;
  final bool autofocus;

  const OtpInputBoxes({
    super.key,
    required this.onCompleted,
    this.onChanged,
    this.hasError = false,
    this.autofocus = false,
  });

  @override
  State<OtpInputBoxes> createState() => OtpInputBoxesState();
}

class OtpInputBoxesState extends State<OtpInputBoxes> {
  static const _length = 6;
  final _controllers = List.generate(_length, (_) => TextEditingController());
  final _focusNodes = List.generate(_length, (_) => FocusNode());
  bool _verified = false;

  String get value => _controllers.map((c) => c.text).join();

  void setValue(String otp) {
    final digits = otp.replaceAll(RegExp(r'\D'), '');
    for (var i = 0; i < _length; i++) {
      _controllers[i].text = i < digits.length ? digits[i] : '';
    }
    if (digits.length == _length) {
      widget.onCompleted(digits);
    }
    setState(() {});
  }

  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
    setState(() => _verified = false);
  }

  void showSuccess() {
    setState(() => _verified = true);
    AppHaptics.success();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      // Paste support
      setValue(value);
      return;
    }

    if (value.isNotEmpty && index < _length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    final code = this.value;
    widget.onChanged?.call(code);
    if (code.length == _length) {
      widget.onCompleted(code);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNodes.first.requestFocus();
      });
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_length, (i) {
        final borderColor = widget.hasError
            ? AppColors.error
            : _verified
                ? AppColors.success
                : Colors.white;

        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
          child: AnimatedContainer(
            duration: AppTokens.durationFast,
            width: 44,
            height: 52,
            decoration: BoxDecoration(
              color: widget.hasError
                  ? Colors.red.shade50
                  : Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              border: Border.all(color: borderColor, width: widget.hasError ? 2 : 1.5),
              boxShadow: AppTokens.elevationSm(),
            ),
            child: _verified && _controllers[i].text.isNotEmpty
                ? HurIcon(HurIconKind.check, dimension: 20, color: AppColors.success)
                : TextField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) => _onChanged(i, v),
                  ),
          ),
        );
      }),
    );
  }
}
