import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../shared/widgets/language_switcher.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/localization/app_localizations.dart';

class MerchantSettingsScreen extends StatefulWidget {
  const MerchantSettingsScreen({super.key});

  @override
  State<MerchantSettingsScreen> createState() => _MerchantSettingsScreenState();
}

class _MerchantSettingsScreenState extends State<MerchantSettingsScreen> {
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
      // Request permission
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
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.notificationsDenied),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } else {
      // Direct user to settings to disable
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
    showAboutDialog(
      context: context,
      applicationName: 'Hur Delivery',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.local_shipping, color: Colors.white, size: 30),
      ),
      children: [
        Text(AppLocalizations.of(context).appDescription),
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
        title: ResponsiveText(AppLocalizations.of(context).settings, style: TextStyle(fontSize: context.rf(20))),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: context.ri(20)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: context.rp(horizontal: 16, vertical: 16),
        children: [
          // Notifications Section
          Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return Column(
                children: [
                  _buildSectionHeader(loc.notifications),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: Icon(
                            _notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
                          ),
                          title: Text(loc.instantNotifications),
                          subtitle: Text(
                            _notificationsEnabled
                                ? loc.receiveNotifications
                                : loc.notificationsDisabled,
                          ),
                          value: _notificationsEnabled,
                          onChanged: _toggleNotifications,
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: context.rs(24)),
                  
                  // General Section
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
                  SizedBox(height: context.rs(24)),

                  // App Section
                  _buildSectionHeader(loc.support),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.info_outline, size: context.ri(24)),
                          title: ResponsiveText(loc.aboutApp, style: TextStyle(fontSize: context.rf(16))),
                          trailing: Icon(Icons.arrow_forward_ios, size: context.ri(16)),
                          onTap: _showAboutDialog,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.policy_outlined, size: context.ri(24)),
                          title: ResponsiveText(loc.privacyPolicy, style: TextStyle(fontSize: context.rf(16))),
                          trailing: Icon(Icons.arrow_forward_ios, size: context.ri(16)),
                          onTap: () => context.push('/merchant-dashboard/privacy-policy'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.description_outlined, size: context.ri(24)),
                          title: ResponsiveText(loc.termsAndConditions, style: TextStyle(fontSize: context.rf(16))),
                          trailing: Icon(Icons.arrow_forward_ios, size: context.ri(16)),
                          onTap: () => context.push('/merchant-dashboard/terms-conditions'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: context.rs(24)),
                  // Version Info
                  Center(
                    child: ResponsiveText(
                      loc.version('1.0.0'),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ).responsive(context),
                    ),
                  ),
                  SizedBox(height: context.rs(8)),
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
      padding: EdgeInsets.only(bottom: context.rs(8), right: context.rs(4)),
      child: ResponsiveText(
        title,
        style: AppTextStyles.bodyLarge.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _ThemeToggleTile extends StatelessWidget {
  const _ThemeToggleTile();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return SwitchListTile(
          secondary: Icon(
            themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            color: AppColors.primary,
          ),
          title: Text(loc.darkMode),
          subtitle: Text(themeProvider.isDarkMode ? loc.darkModeEnabled : loc.lightModeEnabled),
          value: themeProvider.isDarkMode,
          onChanged: (value) => themeProvider.toggleTheme(),
          activeColor: AppColors.primary,
        );
      },
    );
  }
}

