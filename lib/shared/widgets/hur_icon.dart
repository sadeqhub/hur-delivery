import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/icons/hur_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/theme_extensions.dart';

/// Renders a Hur icon with consistent sizing and semantic tinting.
///
/// All Hur SVGs share a 24×24 viewBox, 1.75px stroke, and round caps — designed
/// to tint cleanly via [ColorFilter] in teal, white, or neutral greys.
class HurIcon extends StatelessWidget {
  const HurIcon(
    this.kind, {
    super.key,
    this.size = HurIconSize.md,
    this.dimension,
    this.color,
    this.tone = HurIconTone.primary,
  }) : _assetPath = null;

  /// Legacy path-based constructor for gradual migration.
  const HurIcon.asset(
    String assetPath, {
    super.key,
    this.size = HurIconSize.md,
    this.dimension,
    this.color,
    this.tone = HurIconTone.primary,
  }) : kind = null,
       _assetPath = assetPath;

  final HurIconKind? kind;
  final String? _assetPath;
  final HurIconSize size;
  final double? dimension;
  final Color? color;
  final HurIconTone tone;

  String get _path => kind?.assetPath ?? _assetPath!;

  Color _resolveColor(BuildContext context) {
    if (color != null) return color!;
    return switch (tone) {
      HurIconTone.primary => context.themePrimary,
      HurIconTone.onPrimary => context.themeOnPrimary,
      HurIconTone.muted => context.themeTextSecondary,
      HurIconTone.destructive => AppColors.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tint = _resolveColor(context);
    final px = dimension ?? size.pixels;
    return SvgPicture.asset(
      _path,
      width: px,
      height: px,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
    );
  }
}

/// Circular brand tile for role cards, demo mode, and feature highlights.
class HurIconBadge extends StatelessWidget {
  const HurIconBadge({
    super.key,
    required this.icon,
    this.dimension = 64,
    this.iconSize = HurIconSize.lg,
    this.backgroundColor = AppColors.primary,
    this.foregroundColor = Colors.white,
    this.borderRadius = 14,
    this.elevated = false,
  });

  final HurIconKind icon;
  final double dimension;
  final HurIconSize iconSize;
  final Color backgroundColor;
  final Color foregroundColor;
  final double borderRadius;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: elevated ? AppTokens.elevationSm() : null,
      ),
      padding: EdgeInsets.all(dimension * 0.2),
      child: HurIcon(
        icon,
        size: iconSize,
        color: foregroundColor,
      ),
    );
  }
}

/// Drawer / sidebar row with a Hur icon leading tile.
class HurNavTile extends StatelessWidget {
  const HurNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
  });

  final HurIconKind icon;
  final String title;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final accent =
        destructive ? AppColors.error : context.themePrimary;
    final titleColor =
        destructive ? AppColors.error : context.themeTextPrimary;

    return ListTile(
      leading: HurIcon(
        icon,
        size: HurIconSize.sm,
        color: accent,
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(color: titleColor),
      ),
      trailing: HurIcon(
        HurIconKind.chevronRight,
        size: HurIconSize.xs,
        tone: HurIconTone.muted,
      ),
      onTap: onTap,
    );
  }
}

/// Prefix/suffix icon sized for [InputDecoration] fields.
class HurPrefixIcon extends StatelessWidget {
  const HurPrefixIcon(
    this.icon, {
    super.key,
    this.color,
    this.tone = HurIconTone.muted,
  });

  final HurIconKind icon;
  final Color? color;
  final HurIconTone tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: HurIcon(
        icon,
        size: HurIconSize.sm,
        color: color,
        tone: tone,
      ),
    );
  }
}

/// Compact list tile with a Hur icon — for settings cards and in-app menus.
class HurListTile extends StatelessWidget {
  const HurListTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.trailing,
    this.iconColor,
  });

  final HurIconKind icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: HurIcon(
        icon,
        size: HurIconSize.sm,
        color: iconColor ?? context.themePrimary,
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          color: context.themeTextPrimary,
        ),
      ),
      trailing: trailing ??
          HurIcon(
            HurIconKind.chevronRight,
            size: HurIconSize.xs,
            tone: HurIconTone.muted,
          ),
      onTap: onTap,
    );
  }
}

/// Compact icon button for footers and toolbars (support, menu, etc.).
class HurIconButton extends StatelessWidget {
  const HurIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = HurIconSize.md,
    this.tone = HurIconTone.onPrimary,
    this.backgroundColor,
    this.border,
    this.padding = const EdgeInsets.all(12),
  });

  final HurIconKind icon;
  final VoidCallback onTap;
  final HurIconSize size;
  final HurIconTone tone;
  final Color? backgroundColor;
  final BoxBorder? border;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: border,
            shape: BoxShape.circle,
          ),
          child: HurIcon(icon, size: size, tone: tone),
        ),
      ),
    );
  }
}
