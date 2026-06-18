import 'package:flutter/material.dart';

/// Global design tokens — spacing, radii, shadows, motion.
abstract final class AppTokens {
  // Spacing scale (4pt grid)
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double space2xl = 32;
  static const double space3xl = 48;

  // Border radii
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusFull = 999;

  // Motion
  static const Duration durationFast = Duration(milliseconds: 200);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 450);
  static const Curve curveStandard = Curves.easeOutCubic;
  static const Curve curveEnter = Curves.easeOut;
  static const Curve curveExit = Curves.easeIn;

  // Surfaces
  static const Color surfaceWarm = Color(0xFFFAF9F8);
  static const Color surfaceBorder = Color(0xFFE8E8E8);
  static const Color surfaceBorderDark = Color(0xFF374151);

  // Auth gradient
  static const LinearGradient authGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF005A5E), Color(0xFF00797E), Color(0xFF009BA1)],
    stops: [0.0, 0.55, 1.0],
  );

  static List<BoxShadow> elevationSm({Color? color}) => [
        BoxShadow(
          color: (color ?? Colors.black).withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> elevationMd({Color? color}) => [
        BoxShadow(
          color: (color ?? Colors.black).withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
          spreadRadius: -2,
        ),
      ];

  static List<BoxShadow> elevationLg({Color? color}) => [
        BoxShadow(
          color: (color ?? Colors.black).withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
      ];

  static BoxDecoration cardDecoration({
    Color? color,
    double radius = radiusLg,
    bool bordered = true,
  }) =>
      BoxDecoration(
        color: color ?? surfaceWarm,
        borderRadius: BorderRadius.circular(radius),
        border: bordered
            ? Border.all(color: surfaceBorder, width: 0.5)
            : null,
        boxShadow: elevationSm(),
      );

  static BoxDecoration glassDecoration({double radius = radiusMd}) =>
      BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
          width: 1,
        ),
      );
}
