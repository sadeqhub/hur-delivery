import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/icons/hur_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/auth_scaffold.dart';
import '../../../shared/widgets/hur_icon.dart';
import '../../../shared/widgets/pressable_button.dart';
import '../../../core/localization/app_localizations.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;

  void _selectRole(String role) {
    AppHaptics.selection();
    setState(() => _selectedRole = role);
  }

  void _continue() {
    if (_selectedRole == null) return;
    AppHaptics.success();
    context.go('/user-registration', extra: _selectedRole);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final buttonWidth = ResponsiveHelper.getFormElementWidth(context);

    return AuthScaffold(
      title: loc.selectRole,
      onBack: () => context.go('/'),
      showLogo: true,
      logoSizeFactor: 0.24,
      body: Column(
        children: [
          Text(
            loc.selectRole,
            style: AppTextStyles.heading2.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: context.rf(22),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Text(
            loc.platformForDriversMerchants,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.space2xl),
          _RoleCard(
            icon: HurIconKind.merchant,
            title: loc.merchant,
            description: loc.merchantDescription,
            benefit: loc.merchantDescription,
            isSelected: _selectedRole == 'merchant',
            onTap: () => _selectRole('merchant'),
          ),
          const SizedBox(height: AppTokens.spaceLg),
          _RoleCard(
            icon: HurIconKind.driver,
            title: loc.driver,
            description: loc.driverDescription,
            benefit: loc.driverDescription,
            isSelected: _selectedRole == 'driver',
            onTap: () => _selectRole('driver'),
          ),
          const SizedBox(height: AppTokens.space2xl),
          AuthPrimaryButton(
            label: loc.continueText,
            width: buttonWidth,
            onPressed: _selectedRole != null ? _continue : null,
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final HurIconKind icon;
  final String title;
  final String description;
  final String benefit;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.benefit,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableButton(
      onPressed: onTap,
      child: AnimatedContainer(
        duration: AppTokens.durationNormal,
        curve: AppTokens.curveStandard,
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.35),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? AppTokens.elevationMd() : null,
        ),
        child: Row(
          children: [
            AnimatedScale(
              scale: isSelected ? 1.05 : 1.0,
              duration: AppTokens.durationFast,
              child: HurIconBadge(
                icon: icon,
                dimension: 72,
                iconSize: HurIconSize.lg,
                backgroundColor: isSelected
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(width: AppTokens.spaceLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.heading3.copyWith(
                      color: isSelected ? AppColors.primary : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    benefit,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isSelected
                          ? AppColors.textSecondary
                          : Colors.white.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: isSelected ? AppColors.primary : Colors.white54,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
