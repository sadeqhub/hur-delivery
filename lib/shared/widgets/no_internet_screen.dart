import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/utils/responsive_extensions.dart';
import 'responsive_container.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers/connectivity_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/global_order_notification_service.dart';

class NoInternetScreen extends StatefulWidget {
  const NoInternetScreen({super.key});

  @override
  State<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends State<NoInternetScreen> {
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    // Listen to connectivity changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupConnectivityListener();
    });
  }

  void _setupConnectivityListener() {
    final connectivityProvider = context.read<ConnectivityProvider>();
    connectivityProvider.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    if (_hasNavigated || !mounted) return;

    final connectivityProvider = context.read<ConnectivityProvider>();
    
    // If connection is restored, navigate back to dashboard
    if (connectivityProvider.isOnline) {
      // Wait a moment to ensure connection is stable
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted || _hasNavigated) return;
        
        // Double-check connection is still online
        if (connectivityProvider.isOnline) {
          _hasNavigated = true;
          // Use postFrameCallback to ensure navigation happens after router is rebuilt
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _navigateToDashboard();
            }
          });
        }
      });
    }
  }

  Future<void> _navigateToDashboard() async {
    if (!mounted) return;

    try {
      // Try to use current context first (most reliable)
      BuildContext? navigatorContext = mounted ? context : null;
      
      // Fallback to global navigator key if context is not available
      navigatorContext ??= GlobalOrderNotificationService.navigatorKey.currentContext;
      
      if (navigatorContext == null || !navigatorContext.mounted) {
        print('⚠️ No valid context for navigation after reconnection');
        return;
      }

      final authProvider = Provider.of<AuthProvider>(navigatorContext, listen: false);
      
      // If user is authenticated, navigate to appropriate dashboard
      if (authProvider.isAuthenticated) {
        final user = authProvider.user;
        if (user != null) {
          // Check verification status first
          if (user.verificationStatus != 'approved') {
            print('🔄 Reconnecting: Navigating to verification pending');
            navigatorContext.go('/verification-pending');
            return;
          }
          
          // Navigate based on role
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
          
          print('🔄 Reconnecting: Navigating to $targetRoute for ${user.role}');
          navigatorContext.go(targetRoute);
        } else {
          print('🔄 Reconnecting: No user found, navigating to home');
          navigatorContext.go('/');
        }
      } else {
        // If not authenticated, go to landing page
        print('🔄 Reconnecting: Not authenticated, navigating to home');
        navigatorContext.go('/');
      }
    } catch (e, stackTrace) {
      print('❌ Error navigating after reconnection: $e');
      print('Stack trace: $stackTrace');
      
      // Fallback: try using router directly
      try {
        final navigatorContext = GlobalOrderNotificationService.navigatorKey.currentContext;
        if (navigatorContext != null && navigatorContext.mounted) {
          navigatorContext.go('/');
        }
      } catch (fallbackError) {
        print('❌ Fallback navigation also failed: $fallbackError');
      }
    }
  }

  @override
  void dispose() {
    // Remove listener to prevent memory leaks
    try {
      final connectivityProvider = context.read<ConnectivityProvider>();
      connectivityProvider.removeListener(_onConnectivityChanged);
    } catch (e) {
      // Provider might be disposed, ignore
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
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
              Consumer<ConnectivityProvider>(
                builder: (context, connectivityProvider, _) {
                  if (connectivityProvider.isOnline) {
                    return Column(
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
                    );
                  }
                  return Column(
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
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
