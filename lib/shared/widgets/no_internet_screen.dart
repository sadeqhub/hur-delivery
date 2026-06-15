import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/utils/responsive_extensions.dart';
import 'responsive_container.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/riverpod/app_providers.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/global_order_notification_service.dart';
import '../../core/utils/logger.dart';

class NoInternetScreen extends ConsumerStatefulWidget {
  const NoInternetScreen({super.key});

  @override
  ConsumerState<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends ConsumerState<NoInternetScreen> {
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    // Listen to connectivity changes after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndNavigateIfOnline();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndNavigateIfOnline();
  }

  void _checkAndNavigateIfOnline() {
    if (_hasNavigated || !mounted) return;
    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted || _hasNavigated) return;
        final stillOnline = ref.read(connectivityProvider).valueOrNull ?? false;
        if (stillOnline) {
          _hasNavigated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _navigateToDashboard();
          });
        }
      });
    }
  }

  Future<void> _navigateToDashboard() async {
    if (!mounted) return;

    try {
      BuildContext? navigatorContext = mounted ? context : null;
      navigatorContext ??= GlobalOrderNotificationService.navigatorKey.currentContext;

      if (navigatorContext == null || !navigatorContext.mounted) {
        Logger.d('⚠️ No valid context for navigation after reconnection');
        return;
      }

      final authProvider = Provider.of<AuthProvider>(navigatorContext, listen: false);

      if (authProvider.isAuthenticated) {
        final user = authProvider.user;
        if (user != null) {
          if (user.verificationStatus != 'approved') {
            Logger.d('🔄 Reconnecting: Navigating to verification pending');
            navigatorContext.go('/verification-pending');
            return;
          }

          String targetRoute = '/';
          switch (user.role) {
            case 'merchant':
              if (!user.merchantWalkthroughCompleted) {
                targetRoute = '/merchant-walkthrough';
              } else {
                targetRoute = '/merchant-dashboard';
              }
              break;
            case 'driver':
              if (!user.driverWalkthroughCompleted) {
                targetRoute = '/driver-walkthrough';
              } else {
                targetRoute = '/driver-dashboard';
              }
              break;
            case 'admin':
              targetRoute = '/admin-dashboard';
              break;
            default:
              targetRoute = '/';
          }

          Logger.d('🔄 Reconnecting: Navigating to $targetRoute for ${user.role}');
          navigatorContext.go(targetRoute);
        } else {
          Logger.d('🔄 Reconnecting: No user found, navigating to home');
          navigatorContext.go('/');
        }
      } else {
        Logger.d('🔄 Reconnecting: Not authenticated, navigating to home');
        navigatorContext.go('/');
      }
    } catch (e, stackTrace) {
      Logger.d('❌ Error navigating after reconnection: $e');
      Logger.d('Stack trace: $stackTrace');

      try {
        final navigatorContext = GlobalOrderNotificationService.navigatorKey.currentContext;
        if (navigatorContext != null && navigatorContext.mounted) {
          navigatorContext.go('/');
        }
      } catch (fallbackError) {
        Logger.d('❌ Fallback navigation also failed: $fallbackError');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? false;
    final loc = AppLocalizations.of(context);

    // Navigate when connection is restored
    if (isOnline && !_hasNavigated) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndNavigateIfOnline());
    }

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Padding(
          padding: context.rp(horizontal: 32, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off,
                size: context.ri(100),
                color: Colors.white.withOpacity(0.9),
              ),
              SizedBox(height: context.rs(24)),
              ResponsiveText(
                loc.noInternetTitle,
                style: AppTextStyles.heading2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ).responsive(context),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.rs(16)),
              ResponsiveText(
                loc.noInternetMessage,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ).responsive(context),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.rs(32)),
              if (isOnline)
                Column(
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: context.rs(16)),
                    ResponsiveText(
                      'جاري إعادة الاتصال... / Reconnecting...',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                      ).responsive(context),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: context.rs(16)),
                    ResponsiveText(
                      loc.loading,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.7),
                      ).responsive(context),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
