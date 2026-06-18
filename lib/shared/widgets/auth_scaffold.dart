import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/icons/hur_icons.dart';
import '../../core/utils/responsive_helper.dart';
import 'hur_icon.dart';
import 'language_switcher.dart';

/// Unified auth layout — gradient background, bird logo, consistent chrome.
class AuthScaffold extends StatelessWidget {
  final String? title;
  final Widget body;
  final VoidCallback? onBack;
  final bool showLogo;
  final double logoSizeFactor;

  const AuthScaffold({
    super.key,
    this.title,
    required this.body,
    this.onBack,
    this.showLogo = true,
    this.logoSizeFactor = 0.38,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final logoSize = ResponsiveHelper.getResponsiveLogoSize(
      context,
      width * logoSizeFactor,
    );

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTokens.authGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceSm,
                  vertical: AppTokens.spaceXs,
                ),
                child: Row(
                  children: [
                    if (onBack != null)
                      IconButton(
                        icon: HurIcon(
                          HurIconKind.chevronLeft,
                          size: HurIconSize.sm,
                          color: Colors.white,
                        ),
                        onPressed: onBack,
                      )
                    else
                      const SizedBox(width: 48),
                    if (title != null)
                      Expanded(
                        child: Text(
                          title!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    LanguageSwitcherButton(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      foregroundColor: Colors.white,
                    ),
                  ],
                ),
              ),
              if (showLogo) ...[
                HurIcon(
                  HurIconKind.bird,
                  dimension: logoSize,
                  color: Colors.white,
                ),
                const SizedBox(height: AppTokens.spaceMd),
              ],
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceXl,
                    vertical: AppTokens.spaceLg,
                  ),
                  child: body,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
