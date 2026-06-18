import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/icons/hur_icons.dart';
import '../../../shared/widgets/auth_scaffold.dart';
import '../../../shared/widgets/hur_icon.dart';
import '../../../shared/widgets/pressable_button.dart';

class DemoSelectionScreen extends StatelessWidget {
  const DemoSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final authProvider = context.read<AuthProvider>();

    return AuthScaffold(
      title: loc.demoModeTitle,
      onBack: () => context.pop(),
      showLogo: true,
      logoSizeFactor: 0.22,
      body: Column(
        children: [
          Container(
            padding: context.rp(horizontal: 20, vertical: 16),
            decoration: AppTokens.glassDecoration(),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.white.withValues(alpha: 0.95), size: 22),
                SizedBox(width: context.rs(12)),
                Expanded(
                  child: ResponsiveText(
                    loc.demoModeInfo,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: context.rf(14),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.rs(32)),
          _DemoOptionCard(
            title: loc.demoMerchant,
            description: loc.demoMerchantDesc,
            icon: HurIconKind.merchant,
            onTap: () async {
              await authProvider.enterDemoMode('merchant');
              if (context.mounted) context.go('/merchant-dashboard');
            },
          ),
          SizedBox(height: context.rs(20)),
          _DemoOptionCard(
            title: loc.demoDriver,
            description: loc.demoDriverDesc,
            icon: HurIconKind.driver,
            onTap: () async {
              await authProvider.enterDemoMode('driver');
              if (context.mounted) context.go('/driver-dashboard');
            },
          ),
        ],
      ),
    );
  }
}

class _DemoOptionCard extends StatelessWidget {
  final String title;
  final String description;
  final HurIconKind icon;
  final VoidCallback onTap;

  const _DemoOptionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableButton(
      onPressed: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTokens.spaceXl),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          boxShadow: AppTokens.elevationMd(),
        ),
        child: Row(
          children: [
            HurIconBadge(
              icon: icon,
              dimension: 64,
              iconSize: HurIconSize.lg,
              elevated: true,
            ),
            const SizedBox(width: AppTokens.spaceLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.heading3.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
