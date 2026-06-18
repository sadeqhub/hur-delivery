import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/icons/hur_icons.dart';
import '../../../shared/widgets/hur_icon.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';

class WalletBalanceWidget extends StatelessWidget {
  final bool onDarkBackground;

  const WalletBalanceWidget({super.key, this.onDarkBackground = false});

  @override
  Widget build(BuildContext context) {
    return Consumer2<WalletProvider, AuthProvider>(
      builder: (context, walletProvider, authProvider, _) {
        if (!walletProvider.isEnabled) {
          return const SizedBox.shrink();
        }

        if (walletProvider.isLoading) {
          return SizedBox(
            height: onDarkBackground ? 56 : 48,
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          );
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        Color backgroundColor;
        Color textColor;
        HurIconKind statusIcon;

        if (onDarkBackground) {
          backgroundColor = Colors.white;
          textColor = walletProvider.isBalanceCritical
              ? AppColors.error
              : walletProvider.isBalanceLow
                  ? Colors.orange.shade700
                  : AppColors.primary;
          statusIcon = walletProvider.isBalanceCritical
              ? HurIconKind.warning
              : walletProvider.isBalanceLow
                  ? HurIconKind.warning
                  : HurIconKind.wallet;
        } else if (walletProvider.isBalanceCritical) {
          backgroundColor = isDark ? AppColors.surfaceVariantDark : Colors.white;
          textColor = AppColors.error;
          statusIcon = HurIconKind.warning;
        } else if (walletProvider.isBalanceLow) {
          backgroundColor = isDark ? AppColors.surfaceVariantDark : Colors.white;
          textColor = Colors.orange.shade700;
          statusIcon = HurIconKind.warning;
        } else {
          backgroundColor = isDark ? AppColors.surfaceVariantDark : Colors.white;
          textColor = isDark ? AppColors.primaryDark : AppColors.primary;
          statusIcon = HurIconKind.wallet;
        }

        return GestureDetector(
          onTap: () => context.push('/merchant-wallet'),
          child: Container(
            width: onDarkBackground ? double.infinity : null,
            height: onDarkBackground ? 56 : 48,
            padding: EdgeInsets.symmetric(
              horizontal: onDarkBackground ? 20 : 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(onDarkBackground ? 16 : 24),
              border: Border.all(
                color: textColor.withValues(alpha: onDarkBackground ? 0.15 : 0.3),
                width: onDarkBackground ? 1 : 2,
              ),
              boxShadow: onDarkBackground
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: HurIcon(statusIcon, dimension: 16, color: textColor),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).myBalance,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: textColor.withOpacity(0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      walletProvider.formattedBalance,
                      style: AppTextStyles.numericHero.copyWith(
                        color: textColor,
                        fontSize: onDarkBackground ? 20 : 15,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                HurIcon(
                  HurIconKind.chevronLeft,
                  dimension: 16,
                  color: textColor.withOpacity(0.6),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
