import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Extension on BuildContext to easily access theme colors
extension ThemeExtension on BuildContext {
  /// Check if dark mode is active
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Get the appropriate color based on theme
  Color themeColor({required Color light, required Color dark}) {
    return isDarkMode ? dark : light;
  }

  /// Get background color based on theme
  Color get themeBackground =>
      isDarkMode ? AppColors.backgroundDark : AppColors.background;

  /// Get surface color based on theme
  Color get themeSurface =>
      isDarkMode ? AppColors.surfaceDark : AppColors.surface;

  /// Get surface variant color based on theme
  Color get themeSurfaceVariant =>
      isDarkMode ? AppColors.surfaceVariantDark : AppColors.surfaceVariant;

  /// Get primary text color based on theme
  Color get themeTextPrimary =>
      isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary;

  /// Get secondary text color based on theme
  Color get themeTextSecondary =>
      isDarkMode ? AppColors.textSecondaryDark : AppColors.textSecondary;

  /// Get tertiary text color based on theme
  Color get themeTextTertiary =>
      isDarkMode ? AppColors.textTertiaryDark : AppColors.textTertiary;

  /// Get primary color based on theme
  Color get themePrimary =>
      isDarkMode ? AppColors.primaryDark : AppColors.primary;

  /// Get accent (gold) color — same across themes
  Color get themeAccent => AppColors.accent;

  /// Get secondary (cool blue) color based on theme
  Color get themeSecondary =>
      isDarkMode ? AppColors.secondaryDark : AppColors.secondary;

  /// Get primary tint surface color based on theme
  Color get themePrimaryTint =>
      isDarkMode ? AppColors.primaryDeep : AppColors.primaryTint;

  /// Get border color based on theme
  Color get themeBorder => isDarkMode ? AppColors.borderDark : AppColors.border;

  /// Get border focus color based on theme
  Color get themeBorderFocus =>
      isDarkMode ? AppColors.borderFocusDark : AppColors.borderFocus;

  /// Get on-primary color (text/icon color on primary background)
  Color get themeOnPrimary => Colors.white;

  /// Get error color (same for both themes)
  Color get themeError => AppColors.error;

  /// Get success color (same for both themes)
  Color get themeSuccess => AppColors.success;

  /// Get warning color (same for both themes)
  Color get themeWarning => AppColors.warning;

  /// Get info color (same for both themes)
  Color get themeInfo => AppColors.info;

  /// Map overlay colors
  Color get mapActiveRoute => AppColors.mapActiveRoute;
  Color get mapCompletedDelivery => AppColors.mapCompletedDelivery;
  Color get mapDriverNearby => AppColors.mapDriverNearby;
}

/// Helper class for theme-aware colors (when context is not available)
class ThemeColors {
  /// Get background color
  static Color getBackground(BuildContext context) {
    return context.themeBackground;
  }

  /// Get surface color
  static Color getSurface(BuildContext context) {
    return context.themeSurface;
  }

  /// Get text primary color
  static Color getTextPrimary(BuildContext context) {
    return context.themeTextPrimary;
  }

  /// Get primary color
  static Color getPrimary(BuildContext context) {
    return context.themePrimary;
  }
}
