import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/icons/hur_icons.dart';
import '../../../shared/widgets/hur_icon.dart';

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
            decoration: const BoxDecoration(
              gradient: AppTokens.authGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: context.themeOnPrimary,
                  child: HurIcon(
                    HurIconKind.driver,
                    size: HurIconSize.lg,
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
                HurNavTile(
                  icon: HurIconKind.edit,
                  title: loc.editProfile,
                  onTap: () {
                    onClose();
                    context.push('/driver/profile');
                  },
                ),
                HurNavTile(
                  icon: HurIconKind.orders,
                  title: loc.driverOrders,
                  onTap: () {
                    onClose();
                    context.push('/driver/orders');
                  },
                ),
                HurNavTile(
                  icon: HurIconKind.wallet,
                  title: loc.driverEarnings,
                  onTap: () {
                    onClose();
                    context.push('/driver/earnings');
                  },
                ),
                HurNavTile(
                  icon: HurIconKind.support,
                  title: loc.helpSupport,
                  onTap: () {
                    onClose();
                    onOpenSupport();
                  },
                ),
                HurNavTile(
                  icon: HurIconKind.settings,
                  title: loc.settings,
                  onTap: () {
                    onClose();
                    context.push('/driver/settings');
                  },
                ),
                HurNavTile(
                  icon: HurIconKind.shield,
                  title: loc.privacyPolicy,
                  onTap: () {
                    onClose();
                    context.push('/driver/privacy-policy');
                  },
                ),
                HurNavTile(
                  icon: HurIconKind.document,
                  title: loc.termsAndConditions,
                  onTap: () {
                    onClose();
                    context.push('/driver/terms-conditions');
                  },
                ),
                const Divider(),
                HurNavTile(
                  icon: HurIconKind.logout,
                  title: loc.logout,
                  destructive: true,
                  onTap: () {
                    onClose();
                    context.read<AuthProvider>().logout();
                    context.go('/');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
