import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/language_switcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/riverpod/app_providers.dart';
import '../../../core/utils/async_value_ext.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/icons/hur_icons.dart';
import '../../../shared/widgets/hur_icon.dart';

class DriverSettingsScreen extends StatefulWidget {
  const DriverSettingsScreen({super.key});

  @override
  State<DriverSettingsScreen> createState() => _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends State<DriverSettingsScreen> {
  bool _notificationsEnabled = true;
  PermissionStatus _notificationPermissionStatus = PermissionStatus.granted;

  @override
  void initState() {
    super.initState();
    _checkNotificationPermission();
  }

  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    setState(() {
      _notificationPermissionStatus = status;
      _notificationsEnabled = status.isGranted;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      final status = await Permission.notification.request();
      if (status.isGranted) {
        setState(() {
          _notificationsEnabled = true;
          _notificationPermissionStatus = status;
        });
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.notificationsEnabled),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (status.isPermanentlyDenied) {
        _showPermissionDialog();
      } else {
        setState(() {
          _notificationsEnabled = false;
          _notificationPermissionStatus = status;
        });
      }
    } else {
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.notificationSettings),
        content: Text(loc.notificationSettingsHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text(loc.openSettings),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    final loc = AppLocalizations.of(context);
    showAboutDialog(
      context: context,
      applicationName: 'Hur Delivery',
      applicationVersion: '1.0.0',
      applicationIcon: HurIconBadge(
        icon: HurIconKind.bird,
        dimension: 60,
        iconSize: HurIconSize.lg,
        borderRadius: 12,
      ),
      children: [
        Text(loc.appDescriptionDriver),
        const SizedBox(height: 8),
        const Text('© 2025 Hur Delivery. All rights reserved.'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).settings),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return Column(
                children: [
                  // Notifications Section
                  _buildSectionHeader(loc.notifications),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: HurIcon(
                            HurIconKind.notifications,
                            size: HurIconSize.sm,
                            tone: HurIconTone.muted,
                          ),
                          title: Text(loc.instantNotifications),
                          subtitle: Text(
                            _notificationsEnabled
                                ? loc.receiveOrderNotifications
                                : loc.notificationsDisabled,
                          ),
                          value: _notificationsEnabled,
                          onChanged: _toggleNotifications,
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // General Section (Language, Theme)
                  _buildSectionHeader(loc.general),
                  const Card(
                    child: Column(
                      children: [
                         LanguageSwitcherTile(),
                         Divider(height: 1),
                         _ThemeToggleTile(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Legal & Support Section
                  _buildSectionHeader(loc.support),
                  Card(
                    child: Column(
                      children: [
                        HurListTile(
                          icon: HurIconKind.info,
                          title: loc.aboutApp,
                          onTap: _showAboutDialog,
                        ),
                        const Divider(height: 1),
                        HurListTile(
                          icon: HurIconKind.shield,
                          title: loc.privacyPolicy,
                          onTap: () => context.push('/driver/privacy-policy'),
                        ),
                        const Divider(height: 1),
                        HurListTile(
                          icon: HurIconKind.document,
                          title: loc.termsAndConditions,
                          onTap: () => context.push('/driver/terms-conditions'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Version Info
                  Center(
                    child: Text(
                      loc.version('1.0.0'),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(
        title,
        style: AppTextStyles.bodyLarge.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _ThemeToggleTile extends ConsumerWidget {
  const _ThemeToggleTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final themeMode = ref.watch(themeProvider).valueOrNull ?? ThemeMode.light;
    final isDarkMode = themeMode == ThemeMode.dark;
    return SwitchListTile(
      secondary: Icon(
        isDarkMode ? Icons.dark_mode : Icons.light_mode,
        color: AppColors.primary,
      ),
      title: Text(loc.darkMode),
      subtitle: Text(isDarkMode ? loc.darkModeEnabled : loc.lightModeEnabled),
      value: isDarkMode,
      onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
      activeColor: AppColors.primary,
    );
  }
}
