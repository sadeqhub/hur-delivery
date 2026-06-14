import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/riverpod/app_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';

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
    final locale = ref.watch(localeProvider).valueOrNull ?? const Locale('ar', 'IQ');
    final loc = AppLocalizations.of(context);
    final isArabic = locale.languageCode == 'ar';

    return TextButton.icon(
      onPressed: () => ref.read(localeProvider.notifier).toggleLocale(),
      icon: Icon(
        Icons.language,
        color: iconColor ?? (textColor ?? Colors.white),
        size: iconSize ?? 18,
      ),
      label: Text(
        isArabic ? 'EN' : loc.arabicChar,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontWeight: FontWeight.bold,
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
        color: backgroundColor ?? Colors.white.withOpacity(0.2),
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
    final locale = ref.watch(localeProvider).valueOrNull ?? const Locale('ar', 'IQ');
    final loc = AppLocalizations.of(context);
    final isArabic = locale.languageCode == 'ar';

    return ListTile(
      leading: const Icon(Icons.language, color: AppColors.primary),
      title: Text(loc.language),
      subtitle: Text(isArabic ? loc.languageArabic : loc.languageEnglish),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isArabic ? 'ع' : 'EN',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: AppColors.textTertiary,
          ),
        ],
      ),
      onTap: () => ref.read(localeProvider.notifier).toggleLocale(),
    );
  }
}
