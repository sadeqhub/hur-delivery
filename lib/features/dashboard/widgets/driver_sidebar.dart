import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';

/// Sliding sidebar drawer for the driver dashboard.
///
/// Extracted from the 8 000-line monolith so it can be tested and maintained
/// independently.  Uses `context.read<AuthProvider>()` (not watch) because the
/// user profile does not change during a session; there is no reason to rebuild
/// the entire sidebar on every auth notify.
class DriverSidebar extends StatelessWidget {
  final bool visible;
  final VoidCallback onClose;
  final VoidCallback onOpenSupport;

  const DriverSidebar({
    super.key,
    required this.visible,
    required this.onClose,
    required this.onOpenSupport,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onTap: onClose,
          child: Container(
            color: Colors.black.withOpacity(0.4),
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {}, // Absorb taps inside the drawer
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: MediaQuery.sizeOf(context).width * 0.75,
                  transform: Matrix4.translationValues(
                    visible ? 0 : MediaQuery.sizeOf(context).width * 0.75,
                    0,
                    0,
                  ),
                  child: _SidebarContent(
                    onClose: onClose,
                    onOpenSupport: onOpenSupport,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sidebar content
// ---------------------------------------------------------------------------

class _SidebarContent extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onOpenSupport;

  const _SidebarContent({
    required this.onClose,
    required this.onOpenSupport,
  });

  @override
  Widget build(BuildContext context) {
    // Read once — the user profile doesn't change mid-session.
    final user = context.read<AuthProvider>().user;
    final loc = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: context.themeSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Profile header ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 20,
              20,
              20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: context.themeOnPrimary,
                  child: Icon(
                    Icons.delivery_dining,
                    size: 35,
                    color: context.themePrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.name ?? loc.notSpecified,
                  style: AppTextStyles.heading3.copyWith(
                    color: context.themeOnPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.phone ?? loc.notSpecified,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.themeOnPrimary.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.themeOnPrimary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    loc.driver,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.themeOnPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Menu items ──────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _SidebarItem(
                  icon: Icons.edit_outlined,
                  title: loc.editProfile,
                  onTap: () {
                    onClose();
                    context.push('/driver/profile');
                  },
                ),
                _SidebarItem(
                  icon: Icons.list_alt,
                  title: loc.driverOrders,
                  onTap: () {
                    onClose();
                    context.push('/driver/orders');
                  },
                ),
                _SidebarItem(
                  icon: Icons.analytics_outlined,
                  title: loc.driverEarnings,
                  onTap: () {
                    onClose();
                    context.push('/driver/earnings');
                  },
                ),
                _SidebarItem(
                  icon: Icons.help_outline,
                  title: loc.helpSupport,
                  onTap: () {
                    onClose();
                    onOpenSupport();
                  },
                ),
                _SidebarItem(
                  icon: Icons.settings_outlined,
                  title: loc.settings,
                  onTap: () {
                    onClose();
                    context.push('/driver/settings');
                  },
                ),
                _SidebarItem(
                  icon: Icons.privacy_tip_outlined,
                  title: loc.privacyPolicy,
                  onTap: () {
                    onClose();
                    context.push('/driver/privacy-policy');
                  },
                ),
                _SidebarItem(
                  icon: Icons.description_outlined,
                  title: loc.termsAndConditions,
                  onTap: () {
                    onClose();
                    context.push('/driver/terms-conditions');
                  },
                ),
                const Divider(),
                _SidebarItem(
                  icon: Icons.logout,
                  title: loc.logout,
                  onTap: () {
                    onClose();
                    context.read<AuthProvider>().logout();
                    context.go('/');
                  },
                  isDestructive: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable list tile for sidebar menu items
// ---------------------------------------------------------------------------

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? context.themeError : context.themeTextSecondary,
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          color:
              isDestructive ? context.themeError : context.themeTextPrimary,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: isDestructive
            ? context.themeError
            : context.themeTextTertiary,
      ),
      onTap: onTap,
    );
  }
}
