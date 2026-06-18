import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/icons/hur_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/hur_icon.dart';
import '../../../shared/widgets/navigation_bar_aware_footer_wrapper.dart';
import '../providers/active_order_provider.dart';

/// Bottom navigation bar shown when the driver has no active orders.
class DriverBottomNav extends StatelessWidget {
  final VoidCallback onOpenSupport;
  final VoidCallback onToggleSidebar;
  final bool showSidebar;
  final Widget toggleWidget;

  const DriverBottomNav({
    super.key,
    required this.onOpenSupport,
    required this.onToggleSidebar,
    required this.showSidebar,
    required this.toggleWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<ActiveOrderProvider, bool>(
      selector: (_, ap) => ap.hasOrders,
      builder: (context, hasOrders, _) {
        if (hasOrders) return const SizedBox.shrink();

        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: NavigationBarAwareFooterWrapper(
            id: 'bottom_nav',
            backgroundColor: AppColors.primary,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Builder(
                builder: (ctx) {
                  final screenH = MediaQuery.of(ctx).size.height;
                  final vPad = screenH < 680
                      ? 6.0
                      : screenH < 900
                          ? 10.0
                          : 14.0;
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: vPad,
                    ),
                    decoration: const BoxDecoration(
                      gradient: AppTokens.authGradient,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 8,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        HurIconButton(
                          icon: HurIconKind.support,
                          onTap: onOpenSupport,
                          tone: HurIconTone.onPrimary,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        Expanded(
                          child: Center(child: toggleWidget),
                        ),
                        HurIconButton(
                          icon: showSidebar
                              ? HurIconKind.home
                              : HurIconKind.menu,
                          onTap: onToggleSidebar,
                          tone: HurIconTone.onPrimary,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
