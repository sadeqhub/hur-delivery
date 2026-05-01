import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../providers/active_order_provider.dart';

/// Top-edge floating buttons shown only when the driver has active orders.
///
/// - Support button (top-left)
/// - Sidebar toggle (top-right)
///
/// Uses a [Selector] on [ActiveOrderProvider.hasOrders] so it only builds
/// when the presence of active orders changes — not on every location tick.
class DriverHeaderButtons extends StatelessWidget {
  final VoidCallback onOpenSupport;
  final VoidCallback onToggleSidebar;
  final bool showSidebar;

  const DriverHeaderButtons({
    super.key,
    required this.onOpenSupport,
    required this.onToggleSidebar,
    required this.showSidebar,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<ActiveOrderProvider, bool>(
      selector: (_, ap) => ap.hasOrders,
      builder: (context, hasOrders, _) {
        if (!hasOrders) return const SizedBox.shrink();

        final topPad = MediaQuery.paddingOf(context).top + 10;

        return Stack(
          children: [
            // Support — top left
            Positioned(
              top: topPad,
              left: 10,
              child: _FloatingSupportButton(onTap: onOpenSupport),
            ),
            // Sidebar toggle — top right
            Positioned(
              top: topPad,
              right: 10,
              child: _SidebarToggleButton(
                showSidebar: showSidebar,
                onTap: onToggleSidebar,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Support button (transparent style for use over the map)
// ---------------------------------------------------------------------------

class _FloatingSupportButton extends StatelessWidget {
  final VoidCallback onTap;
  const _FloatingSupportButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x2E000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.support_agent, color: AppColors.primary, size: 24),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sidebar toggle button
// ---------------------------------------------------------------------------

class _SidebarToggleButton extends StatelessWidget {
  final bool showSidebar;
  final VoidCallback onTap;
  const _SidebarToggleButton({required this.showSidebar, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.themeSurface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          showSidebar ? Icons.home_rounded : Icons.menu_rounded,
          color: context.themePrimary,
          size: 28,
        ),
        onPressed: onTap,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }
}
