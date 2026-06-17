import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Minimal design tokens for the driver order bottom sheet card.
abstract final class OrderCardTokens {
  /// 1 dp black outlines for sheet + inner panels (driver order card).
  static const Color cardOutline = Color(0xFF000000);
  static const double cardOutlineWidth = 1;

  /// Elegant soft white: brighter than greyed “paper” (avoids a faded look),
  /// neutral-warm (no peach/cream cast), not pure #FFF (reduces screen glare).
  static const Color elegantSheetWhite = Color(0xFFFAF9F8);

  static const BorderRadius expandedTopRadius = BorderRadius.only(
    topLeft: Radius.circular(24),
    topRight: Radius.circular(24),
  );

  static const double collapsedHeight = 60;

  static const BorderSide cardBorderSide = BorderSide(
    color: cardOutline,
    width: cardOutlineWidth,
  );

  /// Shared compact layout for CTAs inside the constrained bottom sheet.
  static const double ctaButtonHeight = 48;
  static const double ctaCornerRadius = 14;

  /// Primary typography (addresses, amounts headline)
  static TextStyle headline(BuildContext context) => TextStyle(
        fontSize: ResponsiveFont.apply(context, 20),
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: AppColors.textPrimary,
      );

  static TextStyle bodyMuted(BuildContext context) => TextStyle(
        fontSize: ResponsiveFont.apply(context, 14),
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: AppColors.textSecondary,
      );

  /// Label strips (PICKUP FROM MERCHANT, etc.)
  static TextStyle labelMuted(BuildContext context) => TextStyle(
        fontSize: ResponsiveFont.apply(context, 11),
        fontWeight: FontWeight.w600,
        height: 1.1,
        letterSpacing: 0.06,
        color: AppColors.textTertiary,
      );

  static TextStyle bodyNotes(BuildContext context) => TextStyle(
        fontSize: ResponsiveFont.apply(context, 13.5),
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: AppColors.textSecondary,
      );

  /// Delivery fee headline (hero) at top of fee block.
  static TextStyle heroDeliveryFee(BuildContext context) => TextStyle(
        fontSize: ResponsiveFont.apply(context, 28),
        fontWeight: FontWeight.w800,
        height: 1.12,
        letterSpacing: -0.02,
        color: AppColors.textPrimary,
      );

  /// Order total below divider (secondary prominence).
  static TextStyle orderTotalSecondary(BuildContext context) => TextStyle(
        fontSize: ResponsiveFont.apply(context, 20),
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.textPrimary,
      );
}

/// Local responsive font scaler — slightly smaller floor so content fits sheet height.
abstract final class ResponsiveFont {
  static double apply(BuildContext context, double base) {
    final w = MediaQuery.sizeOf(context).width;
    final scale = (w / 390).clamp(0.84, 0.98);
    return base * scale;
  }
}
