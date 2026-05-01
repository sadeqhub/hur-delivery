import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/responsive_container.dart';

class DemoSelectionScreen extends StatelessWidget {
  const DemoSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final authProvider = context.read<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: ResponsiveText(
          loc.demoModeTitle,
          style: TextStyle(
            color: Colors.white,
            fontSize: context.rf(20),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: ResponsiveHelper.getResponsivePadding(
            context,
            horizontal: MediaQuery.sizeOf(context).width * 0.06,
            vertical: MediaQuery.sizeOf(context).width * 0.06,
          ),
          child: Column(
            children: [
              SizedBox(height: context.rs(40)),
              // Info message
              Container(
                padding: context.rp(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(context.rs(12)),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: context.ri(24),
                    ),
                    SizedBox(width: context.rs(12)),
                    Expanded(
                      child: ResponsiveText(
                        loc.demoModeInfo,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: context.rf(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.rs(40)),
              // Demo options
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Merchant demo option
                    _DemoOptionCard(
                      title: loc.demoMerchant,
                      description: loc.demoMerchantDesc,
                      icon: Icons.store,
                      onTap: () async {
                        await authProvider.enterDemoMode('merchant');
                        if (context.mounted) {
                          context.go('/merchant-dashboard');
                        }
                      },
                    ),
                    SizedBox(height: context.rs(24)),
                    // Driver demo option
                    _DemoOptionCard(
                      title: loc.demoDriver,
                      description: loc.demoDriverDesc,
                      icon: Icons.delivery_dining,
                      onTap: () async {
                        await authProvider.enterDemoMode('driver');
                        if (context.mounted) {
                          context.go('/driver-dashboard');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoOptionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _DemoOptionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: context.rp(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(context.rs(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: context.rs(60),
              height: context.rs(60),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(context.rs(12)),
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: context.ri(32),
              ),
            ),
            SizedBox(width: context.rs(20)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResponsiveText(
                    title,
                    style: TextStyle(
                      fontSize: context.rf(18),
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: context.rs(8)),
                  ResponsiveText(
                    description,
                    style: TextStyle(
                      fontSize: context.rf(14),
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.primary,
              size: context.ri(20),
            ),
          ],
        ),
      ),
    );
  }
}

