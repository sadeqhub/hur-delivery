import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/icons/hur_icons.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/hur_icon.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/riverpod/app_providers.dart';
import '../../../core/services/version_check_service.dart';
import '../../../shared/widgets/update_required_dialog.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: AppTokens.curveEnter,
    );
    _fadeController.forward();
    _initializeApp();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          await Geolocator.requestPermission();
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      final versionService = VersionCheckService();
      final updateRequired = await versionService.isUpdateRequired();

      if (!mounted) return;

      if (updateRequired) {
        final currentVersion = await versionService.getCurrentAppVersion();
        final minVersion =
            await versionService.getMinimumRequiredVersion() ?? '1.0.0';
        if (!mounted) return;
        await UpdateRequiredDialog.show(context, currentVersion, minVersion);
        return;
      }

      final authProvider = context.read<AuthProvider>();
      await authProvider.initialize();

      if (!mounted) return;

      try {
        await ref.read(citySettingsProvider.notifier).loadCitySettings();
      } catch (e) {
        debugPrint('Warning: Failed to load city settings: $e');
      }

      if (!mounted) return;

      if (authProvider.isAuthenticated) {
        final user = authProvider.user;
        if (user != null) {
          if (user.verificationStatus != 'approved') {
            context.go('/verification-pending');
          } else {
            switch (user.role) {
              case 'merchant':
                context.go(user.merchantWalkthroughCompleted
                    ? '/merchant-dashboard'
                    : '/merchant-walkthrough');
                break;
              case 'driver':
                context.go(user.driverWalkthroughCompleted
                    ? '/driver-dashboard'
                    : '/driver-walkthrough');
                break;
              case 'admin':
                context.go('/admin-dashboard');
                break;
              default:
                context.go('/');
            }
          }
        } else {
          context.go('/');
        }
      } else {
        context.go('/');
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTokens.authGradient),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HurIcon(
                  HurIconKind.bird,
                  dimension: 96,
                  color: Colors.white,
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: Colors.white.withValues(alpha: 0.9),
                    strokeWidth: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
