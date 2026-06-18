import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/icons/hur_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/hur_icon.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../shared/widgets/language_switcher.dart';
import '../../../shared/widgets/pressable_button.dart';
import '../../../core/localization/app_localizations.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0, 0.7, curve: AppTokens.curveEnter),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 1, curve: AppTokens.curveStandard),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final buttonWidth = ResponsiveHelper.getFormElementWidth(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTokens.authGradient),
        child: SafeArea(
          child: Stack(
            children: [
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: ResponsiveHelper.getResponsivePadding(
                      context,
                      horizontal: MediaQuery.of(context).size.width * 0.06,
                      vertical: MediaQuery.of(context).size.width * 0.06,
                    ),
                    child: Column(
                      children: [
                        const Spacer(),
                        HurIcon(
                          HurIconKind.bird,
                          dimension: ResponsiveHelper.getResponsiveLogoSize(
                            context,
                            MediaQuery.of(context).size.width * 0.45,
                          ),
                          color: Colors.white,
                        ),
                        SizedBox(height: context.rs(24)),
                        ResponsiveText(
                          loc.fastDeliveryService,
                          style: AppTextStyles.responsiveBodyLarge(context)
                              .copyWith(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: context.rf(20),
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: context.rs(12)),
                        ResponsiveText(
                          loc.platformForDriversMerchants,
                          style: AppTextStyles.responsiveBodyMedium(context)
                              .copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w400,
                            fontSize: context.rf(15),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Spacer(),
                        AuthPrimaryButton(
                          label: loc.login,
                          width: buttonWidth,
                          onPressed: () => context.push('/login'),
                        ),
                        SizedBox(height: context.rs(14)),
                        AuthSecondaryButton(
                          label: loc.createAccount,
                          width: buttonWidth,
                          onPressed: () =>
                              context.push('/phone-input', extra: 'signup'),
                        ),
                        SizedBox(height: context.rs(24)),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: DecoratedBox(
                  decoration:
                      AppTokens.glassDecoration(radius: AppTokens.radiusFull),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: LanguageSwitcherButton(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
