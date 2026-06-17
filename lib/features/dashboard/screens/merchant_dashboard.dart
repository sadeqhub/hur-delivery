// TODO: extract Supabase.instance calls to a feature repository
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/providers/auth_provider.dart';
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
import '../data/dashboard_repository.dart';
import '../widgets/merchant_order_list.dart';
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
                    message: 'خطأ في الاتصال',
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.error, width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            size: 16,
                            color: AppColors.error,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'غير متصل',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              // Connection is healthy - show subtle green dot
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              context.push('/merchant-dashboard/notifications');
            },
          ),
          // Support button removed from header - now in footer
        ],
      ),
      drawer: _buildDrawer(context, authProvider),
      body: Builder(
        builder: (context) {
          // select() so only isEnabled changes trigger a body rebuild,
          // not every wallet balance/transaction update.
          final walletEnabled =
              context.select<WalletProvider, bool>((w) => w.isEnabled);
          if (!walletEnabled) {
            return const MerchantOrdersTab();
          }
          return CreditLimitGuard(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                const MerchantOrdersTab(),
                const WalletScreen(),
              ],
            ),
          );
        },
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
            child: const Center(
              child: Icon(Icons.add_rounded, size: 32, color: Colors.white),
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
                      icon: Icons.support_agent,
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
                    icon: Icons.mic_rounded,
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
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected 
                  ? Colors.white 
                  : Colors.white.withOpacity(0.6),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected 
                    ? Colors.white 
                    : Colors.white.withOpacity(0.6),
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
                      fontWeight: FontWeight.bold,
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
                  child: Icon(
                    Icons.person,
                    size: context.ri(35),
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
                        _buildDrawerItem(
                          icon: Icons.edit_outlined,
                          title: loc.editProfile,
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/merchant-dashboard/edit-profile');
                          },
                        ),
                        _buildDrawerItem(
                          icon: Icons.notifications_outlined,
                          title: loc.notifications,
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/merchant-dashboard/notifications');
                          },
                        ),
                        _buildDrawerItem(
                          icon: Icons.analytics_outlined,
                          title: loc.analytics,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const MerchantAnalyticsScreen(),
                              ),
                            );
                          },
                        ),
                        // Support removed from drawer - now in footer
                        _buildDrawerItem(
                          icon: Icons.settings_outlined,
                          title: loc.settings,
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/merchant-dashboard/settings');
                          },
                        ),
                        _buildDrawerItem(
                          icon: Icons.privacy_tip_outlined,
                          title: loc.privacyPolicy,
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/merchant-dashboard/privacy-policy');
                          },
                        ),
                        _buildDrawerItem(
                          icon: Icons.description_outlined,
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
                    return _buildDrawerItem(
                  icon: Icons.logout,
                      title: loc.logout,
                  onTap: () {
                    Navigator.pop(context);
                    _logout();
                  },
                  isDestructive: true,
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
  
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Builder(
      builder: (context) {
        return ListTile(
          leading: Icon(
            icon,
            color: isDestructive ? AppColors.error : context.themeTextSecondary,
          ),
          title: Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDestructive ? AppColors.error : context.themeTextPrimary,
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: isDestructive ? AppColors.error : context.themeTextTertiary,
          ),
          onTap: onTap,
        );
      },
    );
  }

  String _getUserFriendlyError(String error) {
    final errorLower = error.toLowerCase();
    
    if (errorLower.contains('connection') || 
        errorLower.contains('network') || 
        errorLower.contains('timeout')) {
      return 'تعذر الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى.';
    } else if (errorLower.contains('auth') || 
               errorLower.contains('session') ||
               errorLower.contains('token')) {
      return 'انتهت جلسة العمل. يرجى تسجيل الدخول مرة أخرى.';
    } else if (errorLower.contains('permission') || 
               errorLower.contains('denied')) {
      return 'لا تملك الصلاحية للوصول إلى هذه البيانات.';
    } else {
      return 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى لاحقاً.';
    }
  }

  void _showConnectionHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مساعدة في حل المشكلة'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'جرب الخطوات التالية:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text('1️⃣ تأكد من اتصال الإنترنت'),
              SizedBox(height: 8),
              Text('2️⃣ أغلق التطبيق وأعد فتحه'),
              SizedBox(height: 8),
              Text('3️⃣ تحقق من تحديث التطبيق'),
              SizedBox(height: 8),
              Text('4️⃣ أعد تشغيل جهازك إذا استمرت المشكلة'),
              SizedBox(height: 12),
              Text(
                'إذا استمرت المشكلة، تواصل مع الدعم الفني.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openSupportChat(context);
            },
            child: const Text('تواصل مع الدعم'),
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
          title: Text(isArabic ? 'الموقع مطلوب' : 'Location Required'),
          content: Text(
            isArabic 
                ? 'يرجى تحديد موقع المتجر وعنوانه المكتوب للمتابعة.\nهذا يضمن وصول السائقين إليك بدقة.'
                : 'Please set your store location and address to continue.\nThis ensures drivers can reach you accurately.'
          ),
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
              child: Text(isArabic ? 'تحديث الموقع' : 'Update Location'),
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
