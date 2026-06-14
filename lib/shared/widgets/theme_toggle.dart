import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/riverpod/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';

/// Widget to toggle between light and dark theme
class ThemeToggle extends ConsumerWidget {
  final bool showLabel;

  const ThemeToggle({
    super.key,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final themeMode = ref.watch(themeProvider).valueOrNull ?? ThemeMode.light;
    final isDarkMode = themeMode == ThemeMode.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (showLabel) ...[
            Row(
              children: [
                Icon(
                  isDarkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.darkMode,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      isDarkMode ? loc.darkModeEnabled : loc.lightModeEnabled,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
          Switch(
            value: isDarkMode,
            onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
            activeColor: AppColors.primaryDark,
          ),
        ],
      ),
    );
  }
}

/// Simple icon button to toggle theme
class ThemeToggleIconButton extends ConsumerWidget {
  const ThemeToggleIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider).valueOrNull ?? ThemeMode.light;
    final isDarkMode = themeMode == ThemeMode.dark;

    return IconButton(
      icon: Icon(
        isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
      ),
      onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
      tooltip: isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
    );
  }
}
