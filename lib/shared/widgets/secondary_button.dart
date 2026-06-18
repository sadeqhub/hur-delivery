import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/utils/app_haptics.dart';
import 'pressable_button.dart';
import 'responsive_container.dart';

class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isEnabled;
  final double? width;
  final double? height;

  const SecondaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = isEnabled && !isLoading;
    return PressableButton(
      onPressed: enabled
          ? () {
              AppHaptics.tap();
              onPressed();
            }
          : null,
      child: AnimatedContainer(
        duration: AppTokens.durationFast,
        width: width ?? double.infinity,
        height: height ?? context.rh(56),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
            color: enabled ? AppColors.primary : AppColors.textTertiary,
            width: 1.5,
          ),
        ),
        padding: context.rp(horizontal: 24, vertical: 12),
        child: isLoading
            ? SizedBox(
                width: context.ri(20),
                height: context.ri(20),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : ResponsiveText(
                text,
                style: AppTextStyles.buttonLarge.copyWith(
                  color: enabled ? AppColors.primary : AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ).responsive(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }
}
