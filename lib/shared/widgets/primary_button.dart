import 'package:flutter/material.dart';

import '../../core/icons/hur_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';
import 'hur_icon.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final double? width;
  final double? height;
  final IconData? icon;
  final HurIconKind? hurIcon;
  final Color? backgroundColor;
  final Color? textColor;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.width,
    this.height,
    this.icon,
    this.hurIcon,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final responsiveWidth =
        width ?? ResponsiveHelper.getFormElementWidth(context);
    final responsiveHeight =
        height ?? ResponsiveHelper.getFormElementHeight(context);
    final responsivePadding = ResponsiveHelper.getResponsivePadding(
      context,
      horizontal: 24,
      vertical: 12,
    );
    final fg = textColor ?? Colors.white;

    return Center(
      child: SizedBox(
        width: responsiveWidth,
        height: responsiveHeight,
        child: ElevatedButton(
          onPressed: isEnabled && !isLoading ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? AppColors.primary,
            foregroundColor: fg,
            elevation: 0,
            padding: responsivePadding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            disabledBackgroundColor: AppColors.textTertiary,
          ),
          child: isLoading
              ? SizedBox(
                  width: ResponsiveHelper.getResponsiveIconSize(context, 20),
                  height: ResponsiveHelper.getResponsiveIconSize(context, 20),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(fg),
                  ),
                )
              : hurIcon != null || icon != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (hurIcon != null)
                          HurIcon(
                            hurIcon!,
                            dimension: ResponsiveHelper.getResponsiveIconSize(
                              context,
                              20,
                            ),
                            color: fg,
                          )
                        else
                          Icon(
                            icon,
                            size: ResponsiveHelper.getResponsiveIconSize(
                              context,
                              20,
                            ),
                            color: fg,
                          ),
                        SizedBox(
                          width: ResponsiveHelper.getResponsivePadding(
                            context,
                            horizontal: 8,
                            vertical: 0,
                          ).left,
                        ),
                        Flexible(
                          child: Text(
                            text,
                            style:
                                AppTextStyles.responsiveButtonLarge(context)
                                    .copyWith(
                              color: textColor ?? AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines:
                                ResponsiveHelper.isVerySmallScreen(context)
                                    ? 2
                                    : 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      text,
                      style: AppTextStyles.responsiveButtonLarge(context)
                          .copyWith(
                        color: textColor ?? AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines:
                          ResponsiveHelper.isVerySmallScreen(context) ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
        ),
      ),
    );
  }
}
