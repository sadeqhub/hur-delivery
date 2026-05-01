import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/navigation_bar_aware_footer_wrapper.dart';
import '../providers/active_order_provider.dart';

/// Bottom navigation bar shown when the driver has no active orders.
///
/// Uses a [Selector] on [ActiveOrderProvider] so it only rebuilds when
/// the presence of active orders changes — not on every location tick.
class DriverBottomNav extends StatelessWidget {
  final VoidCallback onOpenSupport;
  final VoidCallback onToggleSidebar;
  final bool showSidebar;

  /// The online toggle widget, built by the shell so it retains access to
  /// all the confirmation-dialog and permission-check logic there.
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
    // Hide when there are active orders (order cards take the bottom area).
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
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Support shortcut
                        _SupportButton(
                          onPrimaryBackground: true,
                          onTap: onOpenSupport,
                        ),

                        // Online toggle widget provided by the shell
                        Expanded(
                          child: Center(child: toggleWidget),
                        ),

                        // Menu / home button
                        IconButton(
                          icon: Icon(
                            showSidebar
                                ? Icons.home_rounded
                                : Icons.menu_rounded,
                            color: Colors.white.withOpacity(0.85),
                            size: 28,
                          ),
                          onPressed: onToggleSidebar,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
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

// ---------------------------------------------------------------------------
// Support shortcut button
// ---------------------------------------------------------------------------

class _SupportButton extends StatelessWidget {
  final bool onPrimaryBackground;
  final VoidCallback onTap;

  const _SupportButton({
    required this.onPrimaryBackground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        onPrimaryBackground ? Colors.white.withOpacity(0.15) : Colors.white;
    final iconColor = onPrimaryBackground ? Colors.white : AppColors.primary;
    final border = onPrimaryBackground
        ? Border.all(color: Colors.white.withOpacity(0.5))
        : null;
    final boxShadow = onPrimaryBackground
        ? <BoxShadow>[]
        : <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: border,
            shape: BoxShape.circle,
            boxShadow: boxShadow,
          ),
          child: Icon(Icons.support_agent, color: iconColor, size: 24),
        ),
      ),
    );
  }
}

// _OnlineToggle removed — the online toggle widget is now built by the
// dashboard shell via _buildOnlineToggleButton() and passed in as [toggleWidget].
