import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/city_settings_provider.dart';
import '../../../core/services/version_check_service.dart';
import '../../../shared/widgets/update_required_dialog.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
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

  Future<void> _initializeApp() async {
    try {
      final versionService = VersionCheckService();
      final updateRequired = await versionService.isUpdateRequired();

      if (!mounted) return;

      if (updateRequired) {
        final currentVersion = await versionService.getCurrentAppVersion();
        final minVersion = await versionService.getMinimumRequiredVersion() ?? '1.0.0';
        if (!mounted) return;
        await UpdateRequiredDialog.show(context, currentVersion, minVersion);
        return;
      }

      final authProvider = context.read<AuthProvider>();
      final citySettingsProvider = context.read<CitySettingsProvider>();

      await authProvider.initialize();

      if (!mounted) return;

      try {
        await citySettingsProvider.loadCitySettings();
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
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icons/icon.png',
              width: 100,
              height: 100,
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
