import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/hur_icons.dart';
import '../../core/riverpod/app_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import 'hur_icon.dart';
import '../../core/utils/async_value_ext.dart';
/// Language switcher widget that can be used in app bars or anywhere
class LanguageSwitcher extends ConsumerWidget {
  final bool showLabel;
  final Color? iconColor;
  final Color? textColor;
  final double? iconSize;
  final double? fontSize;

  const LanguageSwitcher({
    super.key,
    this.showLabel = true,
    this.iconColor,
    this.textColor,
    this.iconSize,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale =
        ref.watch(localeProvider).valueOrNull ?? const Locale('ar', 'IQ');
    final loc = AppLocalizations.of(context);
    final isArabic = locale.languageCode == 'ar';
    final fg = textColor ?? Colors.white;

    return TextButton.icon(
      onPressed: () => ref.read(localeProvider.notifier).toggleLocale(),
      icon: HurIcon(
        HurIconKind.globe,
        dimension: iconSize ?? 18,
        color: iconColor ?? fg,
      ),
      label: Text(
        isArabic ? 'EN' : loc.arabicChar,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: fontSize ?? 14,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }
}

/// Compact language switcher button for app bars
class LanguageSwitcherButton extends StatelessWidget {
  final Color? backgroundColor;
  final Color? foregroundColor;

  const LanguageSwitcherButton({
    super.key,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LanguageSwitcher(
        iconColor: foregroundColor ?? Colors.white,
        textColor: foregroundColor ?? Colors.white,
      ),
    );
  }
}

/// Language switcher as a list tile for settings screens
class LanguageSwitcherTile extends ConsumerWidget {
  const LanguageSwitcherTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale =
        ref.watch(localeProvider).valueOrNull ?? const Locale('ar', 'IQ');
    final loc = AppLocalizations.of(context);
    final isArabic = locale.languageCode == 'ar';

    return ListTile(
      leading: HurIcon(HurIconKind.globe, tone: HurIconTone.primary),
      title: Text(loc.language),
      subtitle: Text(isArabic ? loc.languageArabic : loc.languageEnglish),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isArabic ? 'ع' : 'EN',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          HurIcon(
            HurIconKind.chevronRight,
            size: HurIconSize.xs,
            tone: HurIconTone.muted,
          ),
        ],
      ),
      onTap: () => ref.read(localeProvider.notifier).toggleLocale(),
    );
  }
}
