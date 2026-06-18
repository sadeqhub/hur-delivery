import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../wallet/widgets/wallet_balance_widget.dart';

/// Premium teal header with wallet balance card for merchant dashboard.
class MerchantDashboardHeader extends StatelessWidget {
  final Widget? trailing;
  final VoidCallback? onMenuTap;

  const MerchantDashboardHeader({
    super.key,
    this.trailing,
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTokens.authGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppTokens.radiusXl),
          bottomRight: Radius.circular(AppTokens.radiusXl),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x3300797E),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu_rounded, color: Colors.white),
                    onPressed: onMenuTap,
                  ),
                  const Spacer(),
                  if (trailing != null) trailing!,
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.all(AppTokens.spaceLg),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: const WalletBalanceWidget(
                    onDarkBackground: true,
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
