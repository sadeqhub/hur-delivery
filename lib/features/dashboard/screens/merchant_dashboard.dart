import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/widgets/header_notification.dart';
import '../../wallet/widgets/wallet_balance_widget.dart';
import '../../wallet/widgets/credit_limit_guard.dart';
import '../../wallet/screens/wallet_screen.dart';
import 'merchant_analytics_screen.dart';
import 'dart:async';
import '../../../core/riverpod/app_providers.dart';
import '../../../shared/widgets/maintenance_mode_dialog.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/screen_visibility_tracker.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/icons/hur_icons.dart';
import '../../../shared/widgets/hur_icon.dart';
import '../widgets/merchant_order_list.dart';
import '../widgets/merchant_dashboard_header.dart';
// Removed legacy stable_order_card_manager import

class MerchantDashboard extends ConsumerStatefulWidget {
  const MerchantDashboard({super.key});

  @override
  ConsumerState<MerchantDashboard> createState() => _MerchantDashboardState();
}

class _MerchantDashboardState extends ConsumerState<MerchantDashboard> with ScreenVisibilityMixin {
  @override
  String get screenName => 'merchant_dashboard';
  
  final int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final authProvider = context.read<AuthProvider>();
        
        // Skip initialization in demo mode
        if (authProvider.isDemoMode) {
          Logger.d('ℹ️ Demo mode: Skipping dashboard initialization');
          return;
        }
        
        await context.read<OrderProvider>().initialize();
        
        // Initialize system status checking
        await ref.read(systemStatusProvider.notifier).initialize();
        
        // Initialize wallet
        if (authProvider.user != null) {
          await context.read<WalletProvider>().initialize(authProvider.user!.id);
          
          // Initialize announcement checker (checks every 5 seconds)
          if (mounted) {
            await ref.read(announcementProvider.notifier).initialize(
              userRole: 'merchant',
              userId: authProvider.user!.id,
              context: context,
            );
          }
          
          // Check location/address guard
          if (mounted) {
            final user = authProvider.user!;
            final hasAddress = user.address != null && user.address!.isNotEmpty;
            final hasLocation = user.latitude != null && user.longitude != null;
            
            if (!hasAddress || !hasLocation) {
              _showLocationGuardDialog();
            }
          }

          // Check system status and show dialog if disabled
          if (mounted) {
            final systemStatus = ref.read(systemStatusProvider);
            if (!systemStatus.isSystemEnabled) {
              MaintenanceModeDialog.show(context, 'merchant');
            }
          }
        }
      } catch (e) {
        Logger.d('Error initializing merchant dashboard: $e');
        // Don't crash - just log error
      }
    });
  }

  @override
  void dispose() {
    // Stop announcement checking when leaving dashboard
    ref.read(announcementProvider.notifier).stopChecking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use select() so the whole dashboard only rebuilds when auth status
    // actually changes — not on every unrelated AuthProvider notification.
    final isAuthenticated = context.select<AuthProvider, bool>(
        (a) => a.isAuthenticated || a.isDemoMode);
    final authProvider = context.read<AuthProvider>();
    if (!isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/');
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final loc = AppLocalizations.of(context);

    return Scaffold(
<<<<<<< Updated upstream
      appBar: AppBar(
        title: const WalletBalanceWidget(),
        centerTitle: true,
        actions: [
          // Connection status indicator
          Consumer<OrderProvider>(
            builder: (context, orderProvider, _) {
              // Only show indicator if there's an error
              if (orderProvider.error != null) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(
                    message: AppLocalizations.of(context).errConnectionError,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.error, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 16,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            AppLocalizations.of(context).offlineStatus,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
=======
      drawer: _buildDrawer(context, authProvider),
      body: Column(
        children: [
          Builder(
            builder: (scaffoldContext) => MerchantDashboardHeader(
              onMenuTap: () => Scaffold.of(scaffoldContext).openDrawer(),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Consumer<OrderProvider>(
                    builder: (context, orderProvider, _) {
                      if (orderProvider.error != null) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Tooltip(
                            message: loc.noInternetTitle,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: AppTokens.glassDecoration(
                                radius: AppTokens.radiusFull,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.cloud_off_rounded,
                                      size: 14,
                                      color: Colors.white.withValues(alpha: 0.95)),
                                  const SizedBox(width: 4),
                                  Text(
                                    loc.offline,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.95),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
>>>>>>> Stashed changes
                            ),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: HurIcon(
                      HurIconKind.notifications,
                      size: HurIconSize.md,
                      tone: HurIconTone.onPrimary,
                    ),
                    onPressed: () =>
                        context.push('/merchant-dashboard/notifications'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                final walletEnabled =
                    context.select<WalletProvider, bool>((w) => w.isEnabled);
                if (!walletEnabled) {
                  return const MerchantOrdersTab();
                }
                return CreditLimitGuard(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: const [
                      MerchantOrdersTab(),
                      WalletScreen(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withOpacity(0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Allow navigation to order creation screens in demo mode
              context.push('/merchant-dashboard/create-order');
            },
            borderRadius: BorderRadius.circular(32),
            child: Center(
              child: HurIcon(
                HurIconKind.add,
                size: HurIconSize.lg,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          clipBehavior: Clip.antiAlias,
          color: context.themePrimary,
          elevation: 8,
          child: Directionality(
            textDirection: TextDirection.ltr,
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                  // Support button
                Expanded(
                  child: _buildFooterButton(
                      icon: HurIconKind.support,
                      label: loc.support,
                      isSelected: false,
                      onTap: () => _openSupportChat(context),
                  ),
                ),
                // Spacer for FAB
                const SizedBox(width: 40),
                // Voice order button
                Expanded(
                  child: _buildFooterButton(
                    icon: HurIconKind.mic,
                    label: loc.voice,
                    isSelected: false,
                    onTap: () {
                      // Allow navigation to order creation screens in demo mode
                      context.push('/merchant-dashboard/create-order?page=3');
                    },
                  ),
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.logout();
    if (mounted) {
      context.go('/');
    }
  }

  Widget _buildFooterButton({
    required HurIconKind icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final opacity = isSelected ? 1.0 : 0.6;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HurIcon(
              icon,
              size: HurIconSize.md,
              color: Colors.white.withValues(alpha: opacity),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: Colors.white.withValues(alpha: opacity),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSupportOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
  
  
  Widget _buildDrawer(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.user;
    
    return Drawer(
      backgroundColor: context.themeSurface,
      child: Column(
        children: [
          // Profile Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              context.rs(20),
              context.rs(60),
              context.rs(20),
              context.rs(20),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: context.rs(35),
                  backgroundColor: Colors.white,
                  child: HurIcon(
                    HurIconKind.merchant,
                    size: HurIconSize.lg,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: context.rs(12)),
                Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return Column(
                      children: [
                        ResponsiveText(
                          user?.name ?? loc.notSpecified,
                          style: AppTextStyles.heading3.copyWith(
                            color: Colors.white,
                          ).responsive(context),
                        ),
                        SizedBox(height: context.rs(4)),
                        ResponsiveText(
                          user?.phone ?? loc.notSpecified,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ).responsive(context),
                        ),
                        SizedBox(height: context.rs(8)),
                        Container(
                          padding: context.rp(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(context.rs(12)),
                          ),
                          child: ResponsiveText(
                            loc.merchantLabel,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ).responsive(context),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return Column(
                      children: [
                        HurNavTile(
                          icon: HurIconKind.edit,
                          title: loc.editProfile,
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/merchant-dashboard/edit-profile');
                          },
                        ),
                        HurNavTile(
                          icon: HurIconKind.notifications,
                          title: loc.notifications,
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/merchant-dashboard/notifications');
                          },
                        ),
                        HurNavTile(
                          icon: HurIconKind.analytics,
                          title: loc.analytics,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const MerchantAnalyticsScreen(),
                              ),
                            );
                          },
                        ),
                        HurNavTile(
                          icon: HurIconKind.settings,
                          title: loc.settings,
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/merchant-dashboard/settings');
                          },
                        ),
                        HurNavTile(
                          icon: HurIconKind.shield,
                          title: loc.privacyPolicy,
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/merchant-dashboard/privacy-policy');
                          },
                        ),
                        HurNavTile(
                          icon: HurIconKind.document,
                          title: loc.termsAndConditions,
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/merchant-dashboard/terms-conditions');
                          },
                        ),
                      ],
                    );
                  },
                ),
                const Divider(),
                Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return HurNavTile(
                      icon: HurIconKind.logout,
                      title: loc.logout,
                      destructive: true,
                      onTap: () {
                        Navigator.pop(context);
                        _logout();
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getUserFriendlyError(String error, [BuildContext? ctx]) {
    final errorLower = error.toLowerCase();
    final loc = ctx != null ? AppLocalizations.of(ctx) : null;

    if (errorLower.contains('connection') ||
        errorLower.contains('network') ||
        errorLower.contains('timeout')) {
      return loc?.errCannotConnectServerRetry ?? 'تعذر الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى.';
    } else if (errorLower.contains('auth') ||
               errorLower.contains('session') ||
               errorLower.contains('token')) {
      return loc?.sessionExpiredLoginAgain ?? 'انتهت جلسة العمل. يرجى تسجيل الدخول مرة أخرى.';
    } else if (errorLower.contains('permission') ||
               errorLower.contains('denied')) {
      return loc?.noPermissionData ?? 'لا تملك الصلاحية للوصول إلى هذه البيانات.';
    } else {
      return loc?.unexpectedErrorRetry ?? 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى لاحقاً.';
    }
  }

  void _showConnectionHelpDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.helpSolveProblem),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
<<<<<<< Updated upstream
                loc.tryTheseSteps,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
=======
                'جرب الخطوات التالية:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
>>>>>>> Stashed changes
              ),
              const SizedBox(height: 12),
              Text('1️⃣ ${loc.checkInternet}'),
              const SizedBox(height: 8),
              Text('2️⃣ ${loc.closeReopenApp}'),
              const SizedBox(height: 8),
              Text('3️⃣ ${loc.checkAppUpdate}'),
              const SizedBox(height: 8),
              Text('4️⃣ ${loc.restartDevice}'),
              const SizedBox(height: 12),
              Text(
                loc.contactSupportIfPersists,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.ok),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openSupportChat(context);
            },
            child: Text(loc.contactSupport),
          ),
        ],
      ),
    );
  }

  Future<void> _showLocationGuardDialog() async {
    final loc = AppLocalizations.of(context);
    final isArabic = loc.isArabic;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent back button
        child: AlertDialog(
          title: Text(loc.locationRequiredTitle),
          content: Text(loc.locationRequiredMessage),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await context.push('/merchant-dashboard/edit-profile');
                
                // Re-check after returning
                if (mounted) {
                   final authProvider = context.read<AuthProvider>();
                   // Force refresh first
                   await authProvider.refreshUser();
                   
                   final user = authProvider.user;
                   if (user != null) {
                      final hasAddress = user.address != null && user.address!.isNotEmpty;
                      final hasLocation = user.latitude != null && user.longitude != null;
                      
                      if (!hasAddress || !hasLocation) {
                        // Show again if still missing
                        _showLocationGuardDialog();
                      }
                   }
                }
              },
              child: Text(loc.updateLocation),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple elegant order button
Future<void> _openSupportChat(BuildContext context) async {
  // Go directly to support conversation - no popup or list
  context.push('/merchant/support');
}
