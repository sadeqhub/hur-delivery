import 'package:flutter/material.dart';

import '../../core/icons/hur_icons.dart';
import '../../core/theme/app_theme.dart';
import 'hur_icon.dart';

/// @deprecated Use [HurIcon] instead.
@Deprecated('Use HurIcon instead')
class BrandSvgIcon extends StatelessWidget {
  final String assetPath;
  final double size;
  final Color? color;

  const BrandSvgIcon({
    super.key,
    required this.assetPath,
    this.size = 22,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return HurIcon.asset(
      assetPath,
      size: _nearestSize(size),
      color: color ?? AppColors.primary,
    );
  }

  static HurIconSize _nearestSize(double size) {
    if (size <= 17) return HurIconSize.xs;
    if (size <= 22) return HurIconSize.sm;
    if (size <= 28) return HurIconSize.md;
    if (size <= 36) return HurIconSize.lg;
    if (size <= 44) return HurIconSize.xl;
    return HurIconSize.hero;
  }
}
