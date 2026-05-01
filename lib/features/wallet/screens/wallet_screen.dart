import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/driver_wallet_provider.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/localization/app_localizations.dart';
import '../widgets/top_up_dialog.dart';
import '../../wallet/widgets/payment_webview_dialog.dart';
import '../../../shared/widgets/skeletons.dart';

enum WalletScreenType { merchant, driver }

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, this.type = WalletScreenType.merchant});

  final WalletScreenType type;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _isLoadingSummary = true;
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();

    if (authProvider.user != null) {
      if (widget.type == WalletScreenType.driver) {
        await context.read<DriverWalletProvider>().initialize(authProvider.user!.id);
        setState(() {
          _summary = null;
          _isLoadingSummary = false;
        });
        return;
      }

      final walletProvider = context.read<WalletProvider>();
      await walletProvider.initialize(authProvider.user!.id);
      final summary = await walletProvider.getWalletSummary(authProvider.user!.id);
      setState(() {
        _summary = summary;
        _isLoadingSummary = false;
      });
    }
  }

  Future<void> _refresh() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user != null) {
      if (widget.type == WalletScreenType.driver) {
        await context.read<DriverWalletProvider>().refresh(authProvider.user!.id);
        await _loadData();
        return;
      }

      await context.read<WalletProvider>().refresh(authProvider.user!.id);
      await _loadData();
    }
  }

  void _showTopUpDialog() {
    showDialog(
      context: context,
      builder: (context) => const TopUpDialog(),
    );
  }

  Future<void> _showDriverWaylTopUpDialog(
    DriverWalletProvider walletProvider,
    String driverId,
  ) async {
    final loc = AppLocalizations.of(context);
    const minAmount = 10000.0;

    final amountController = TextEditingController(
      text: minAmount.toStringAsFixed(0),
    );

    final submitted = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(loc.walletTopUp),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: minAmount.toStringAsFixed(0),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: Text(loc.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = double.tryParse(amountController.text.trim());
                if (parsed == null || parsed < minAmount) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.minimumAmountIs(minAmount))),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(parsed);
              },
              child: Text(loc.confirm),
            ),
          ],
        );
      },
    );

    if (submitted == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final result = await walletProvider.createWaylPaymentLink(
      driverId: driverId,
      amount: submitted,
      notes: loc.topUpViaWayl,
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    if (result != null && result['payment_url'] != null) {
      final paymentUrl = result['payment_url'] as String;
      final referenceId = result['reference_id'] as String?;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PaymentWebViewDialog(
          paymentUrl: paymentUrl,
          referenceId: referenceId,
          onPaymentComplete: () {
            walletProvider.refresh(driverId);
          },
          onPaymentCancelled: () {},
          onError: () {},
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(walletProvider.error ?? loc.errorGeneric),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.themeSurfaceVariant,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).myWallet),
        centerTitle: true,
        elevation: 0,
      ),
      body: widget.type == WalletScreenType.driver
          ? Consumer2<AuthProvider, DriverWalletProvider>(
              builder: (context, authProvider, walletProvider, _) {
                if (walletProvider.isLoading && walletProvider.transactions.isEmpty) {
                  return const SingleChildScrollView(
                    child: Column(
                      children: [
                        WalletBalanceCardSkeleton(),
                        SizedBox(height: 24),
                        TransactionListSkeleton(count: 5),
                        SizedBox(height: 24),
                      ],
                    ),
                  );
                }

                final driverId = authProvider.user?.id;

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _buildDriverBalanceCard(walletProvider, driverId),
                        SizedBox(height: context.rs(24)),
                        _buildDriverTransactionsList(walletProvider),
                      ],
                    ),
                  ),
                );
              },
            )
          : Consumer<WalletProvider>(
              builder: (context, walletProvider, _) {
                if (walletProvider.isLoading && walletProvider.transactions.isEmpty) {
                  return const SingleChildScrollView(
                    child: Column(
                      children: [
                        WalletBalanceCardSkeleton(),
                        SizedBox(height: 24),
                        TransactionListSkeleton(count: 5),
                        SizedBox(height: 24),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // Balance Card
                        _buildBalanceCard(walletProvider),

                        SizedBox(height: context.rs(16)),

                        // Fee Exemption Banner
                        if (walletProvider.isFeeExempt) _buildFeeExemptionBanner(walletProvider),

                        if (walletProvider.isFeeExempt) SizedBox(height: context.rs(16)),

                        // Summary Cards
                        if (_summary != null) _buildSummaryCards(_summary!),

                        SizedBox(height: context.rs(24)),

                        // Transactions List
                        _buildTransactionsList(walletProvider),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDriverBalanceCard(DriverWalletProvider walletProvider, String? driverId) {
    final loc = AppLocalizations.of(context);

    final isCritical = walletProvider.balance < 0;
    final balanceColor = isCritical ? AppColors.error : context.themePrimary;
    final balanceIcon = isCritical ? Icons.warning_amber_rounded : Icons.check_circle;
    final balanceStatus = isCritical ? loc.pleaseTopUp : loc.balanceGood;

    return Container(
      margin: context.rp(horizontal: 16, vertical: 16),
      padding: context.rp(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.isDarkMode
                ? (Color.lerp(balanceColor, Colors.black, 0.15) ?? balanceColor)
                : (Color.lerp(balanceColor, Colors.white, 0.10) ?? balanceColor),
            balanceColor,
            context.isDarkMode
                ? (Color.lerp(balanceColor, Colors.black, 0.35) ?? balanceColor)
                : (Color.lerp(balanceColor, const Color(0xFF000000), 0.15) ?? balanceColor),
          ],
          stops: const [0.0, 0.45, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(context.rs(20)),
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode
                ? Colors.black.withOpacity(0.35)
                : balanceColor.withOpacity(0.25),
            blurRadius: context.isDarkMode ? 20 : 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(balanceIcon, color: Colors.white, size: context.ri(28)),
              SizedBox(width: context.rs(8)),
              ResponsiveText(
                balanceStatus,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ).responsive(context),
              ),
            ],
          ),
          SizedBox(height: context.rs(16)),
          Column(
            children: [
              ResponsiveText(
                loc.currentBalance,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ).responsive(context),
              ),
              SizedBox(height: context.rs(8)),
              Directionality(
                textDirection: ui.TextDirection.ltr,
                child: ResponsiveText(
                  walletProvider.formattedBalance,
                  style: AppTextStyles.heading1.copyWith(
                    color: Colors.white,
                    fontSize: context.rf(36),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: context.rs(20)),
              PrimaryButton(
                text: loc.topUpWallet,
                onPressed: driverId == null
                    ? null
                    : () => _showDriverWaylTopUpDialog(walletProvider, driverId),
                icon: Icons.add_circle_outline,
                backgroundColor: Colors.white,
                textColor: balanceColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDriverTransactionsList(DriverWalletProvider walletProvider) {
    if (walletProvider.transactions.isEmpty) {
      return Container(
        padding: context.rp(horizontal: 40, vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long,
              size: context.ri(64),
              color: context.themeTextTertiary,
            ),
            SizedBox(height: context.rs(16)),
            ResponsiveText(
              AppLocalizations.of(context).noTransactions,
              style: AppTextStyles.heading3.copyWith(
                color: context.themeTextTertiary,
              ).responsive(context),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: context.rp(horizontal: 16, vertical: 0),
      padding: context.rp(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(context.rs(16)),
        border: Border.all(
          color: context.isDarkMode
              ? context.themeBorder.withOpacity(0.35)
              : context.themeBorder.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode
                ? Colors.black.withOpacity(0.25)
                : Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsiveText(
            AppLocalizations.of(context).recentTransactions,
            style: AppTextStyles.heading3.responsive(context),
          ),
          SizedBox(height: context.rs(16)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: walletProvider.transactions.length,
            separatorBuilder: (context, index) => Divider(
              height: 24,
              color: context.themeBorder.withOpacity(context.isDarkMode ? 0.35 : 0.25),
            ),
            itemBuilder: (context, index) {
              final tx = walletProvider.transactions[index];
              final order = tx.orderId == null
                  ? null
                  : walletProvider.orderSummaries[tx.orderId!];
              return _buildTransactionStrip(
                title: tx.title,
                subtitle: tx.notes,
                createdAt: tx.createdAt,
                amountText: tx.formattedAmount,
                amountColor: tx.color,
                icon: tx.icon,
                iconColor: tx.color,
                balanceAfter: tx.balanceAfter,
                orderId: tx.orderId,
                orderCustomerName: order?.customerName,
                orderMerchantName: order?.merchantName,
                orderStatus: order?.status,
                orderTotalAmount: order?.totalAmount,
                orderDeliveryFee: order?.deliveryFee,
                transactionType: tx.transactionType,
                onOpenOrder: null,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(WalletProvider walletProvider) {
    final loc = AppLocalizations.of(context);
    Color balanceColor;
    IconData balanceIcon;
    String balanceStatus;

    if (walletProvider.isBalanceCritical) {
      balanceColor = AppColors.error;
      balanceIcon = Icons.warning_amber_rounded;
      balanceStatus = loc.pleaseTopUp;
    } else if (walletProvider.isBalanceLow) {
      balanceColor = Colors.orange;
      balanceIcon = Icons.warning_outlined;
      balanceStatus = loc.balanceLow;
    } else {
      balanceColor = context.themePrimary;
      balanceIcon = Icons.check_circle;
      balanceStatus = loc.balanceGood;
    }

    return Container(
      margin: context.rp(horizontal: 16, vertical: 16),
      padding: context.rp(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.isDarkMode
                ? (Color.lerp(balanceColor, Colors.black, 0.15) ?? balanceColor)
                : (Color.lerp(balanceColor, Colors.white, 0.10) ?? balanceColor),
            balanceColor,
            context.isDarkMode
                ? (Color.lerp(balanceColor, Colors.black, 0.35) ?? balanceColor)
                : (Color.lerp(balanceColor, const Color(0xFF000000), 0.15) ?? balanceColor),
          ],
          stops: const [0.0, 0.45, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(context.rs(20)),
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode
                ? Colors.black.withOpacity(0.35)
                : balanceColor.withOpacity(0.25),
            blurRadius: context.isDarkMode ? 20 : 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(balanceIcon, color: Colors.white, size: context.ri(28)),
              SizedBox(width: context.rs(8)),
              ResponsiveText(
                balanceStatus,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ).responsive(context),
              ),
            ],
          ),
          SizedBox(height: context.rs(16)),
          Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return Column(
                children: [
                  ResponsiveText(
                    loc.currentBalance,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ).responsive(context),
                  ),
                  SizedBox(height: context.rs(8)),
                  Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: ResponsiveText(
                      walletProvider.formattedBalance,
                      style: AppTextStyles.heading1.copyWith(
                        color: Colors.white,
                        fontSize: context.rf(36),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: context.rs(4)),
                  ResponsiveText(
                    loc.creditLimit(walletProvider.creditLimit),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withOpacity(0.7),
                    ).responsive(context),
                  ),
                  SizedBox(height: context.rs(20)),
                  PrimaryButton(
                    text: loc.topUpWallet,
                    onPressed: _showTopUpDialog,
                    icon: Icons.add_circle_outline,
                    backgroundColor: Colors.white,
                    textColor: balanceColor,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> summary) {
    return Padding(
      padding: context.rp(horizontal: 16, vertical: 0),
      child: Row(
        children: [
          Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      loc.totalOrders,
                      summary['total_orders']?.toString() ?? '0',
                      Icons.shopping_bag,
                      AppColors.primary,
                    ),
                  ),
                  SizedBox(width: context.rs(12)),
                  Expanded(
                    child: _buildSummaryCard(
                      loc.totalFees,
                      '${(summary['total_spent'] as num?)?.toStringAsFixed(0) ?? '0'} IQD',
                      Icons.payments,
                      AppColors.error,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: context.rp(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(context.rs(16)),
        border: Border.all(
          color: context.isDarkMode
              ? context.themeBorder.withOpacity(0.35)
              : context.themeBorder.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode
                ? Colors.black.withOpacity(0.25)
                : Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: context.rp(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: context.ri(24)),
          ),
          SizedBox(height: context.rs(12)),
          ResponsiveText(
            title,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.themeTextSecondary,
            ).responsive(context),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.rs(4)),
          ResponsiveText(
            value,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ).responsive(context),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeeExemptionBanner(WalletProvider walletProvider) {
    final loc = AppLocalizations.of(context);
    final exemptionEndDate = walletProvider.feeExemptionEndDate;
    
    return Container(
      margin: context.rp(horizontal: 16, vertical: 0),
      padding: context.rp(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade400,
            Colors.green.shade600,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(context.rs(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.celebration,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(width: context.rs(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveText(
                  loc.feeExemptBanner,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ).responsive(context),
                ),
                SizedBox(height: context.rs(4)),
                ResponsiveText(
                  loc.feeExemptMessage,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ).responsive(context),
                ),
                if (exemptionEndDate != null) ...[
                  SizedBox(height: context.rs(8)),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: context.ri(14),
                        color: Colors.white.withOpacity(0.9),
                      ),
                      SizedBox(width: context.rs(6)),
                      ResponsiveText(
                        '${loc.feeExemptUntil}: ${DateFormat('dd/MM/yyyy', loc.locale.languageCode).format(exemptionEndDate)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                        ).responsive(context),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(WalletProvider walletProvider) {
    if (walletProvider.transactions.isEmpty) {
      return Container(
        padding: context.rp(horizontal: 40, vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long,
              size: context.ri(64),
              color: context.themeTextTertiary,
            ),
            SizedBox(height: context.rs(16)),
            ResponsiveText(
              AppLocalizations.of(context).noTransactions,
              style: AppTextStyles.heading3.copyWith(
                color: context.themeTextTertiary,
              ).responsive(context),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: context.rp(horizontal: 16, vertical: 0),
      padding: context.rp(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(context.rs(16)),
        border: Border.all(
          color: context.isDarkMode
              ? context.themeBorder.withOpacity(0.35)
              : context.themeBorder.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode
                ? Colors.black.withOpacity(0.25)
                : Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsiveText(
            AppLocalizations.of(context).recentTransactions,
            style: AppTextStyles.heading3.responsive(context),
          ),
          SizedBox(height: context.rs(16)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: walletProvider.transactions.length,
            separatorBuilder: (context, index) => Divider(
              height: 24,
              color: context.themeBorder.withOpacity(context.isDarkMode ? 0.35 : 0.25),
            ),
            itemBuilder: (context, index) {
              final transaction = walletProvider.transactions[index];
              final order = transaction.orderId == null
                  ? null
                  : walletProvider.orderSummaries[transaction.orderId!];
              return _buildTransactionStrip(
                title: transaction.title,
                subtitle: transaction.notes,
                createdAt: transaction.createdAt,
                amountText: transaction.formattedAmount,
                amountColor: transaction.color,
                icon: transaction.icon,
                iconColor: transaction.color,
                balanceAfter: transaction.balanceAfter,
                orderId: transaction.orderId,
                orderCustomerName: order?.customerName,
                orderMerchantName: order?.merchantName,
                orderStatus: order?.status,
                orderTotalAmount: order?.totalAmount,
                orderDeliveryFee: order?.deliveryFee,
                transactionType: transaction.transactionType,
                onOpenOrder: transaction.orderId == null
                    ? null
                    : () => context.push(
                        '/merchant-dashboard/order-details/${transaction.orderId}'),
              );
            },
          ),
          // Load More button
          if (walletProvider.hasMoreTransactions) ...[
            SizedBox(height: context.rs(16)),
            Center(
              child: walletProvider.isLoadingMore
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton.icon(
                      onPressed: () {
                        final authProvider = context.read<AuthProvider>();
                        if (authProvider.user != null) {
                          walletProvider
                              .loadMoreTransactions(authProvider.user!.id);
                        }
                      },
                      icon: const Icon(Icons.expand_more),
                      label: Text(AppLocalizations.of(context).loadMoreTransactions),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionStrip({
    required String title,
    required String? subtitle,
    required DateTime createdAt,
    required String amountText,
    required Color amountColor,
    required IconData icon,
    required Color iconColor,
    required double balanceAfter,
    required String? orderId,
    required String? orderCustomerName,
    required String? orderMerchantName,
    required String? orderStatus,
    required double? orderTotalAmount,
    required double? orderDeliveryFee,
    required String transactionType,
    required VoidCallback? onOpenOrder,
  }) {
    final loc = AppLocalizations.of(context);
    // Convert to GMT+3 (Baghdad timezone) before formatting
    final baghdadTime = createdAt.toUtc().add(const Duration(hours: 3));
    final dateFormat = DateFormat('dd/MM/yyyy - hh:mm a', loc.locale.languageCode);

    final sourceText = transactionType == 'top_up'
        ? loc.walletTopUp
        : (orderId != null ? loc.orderDetails : title);

    String? commissionRateText;
    if (transactionType == 'commission_deduction' && subtitle != null) {
      final match = RegExp(r'\(([0-9]+(?:\.[0-9]+)?)%\)').firstMatch(subtitle);
      if (match != null) {
        commissionRateText = '${loc.commissionLabel}: ${match.group(1)}%';
      }
    }

    final orderAmountText = orderTotalAmount == null
        ? null
        : '${loc.totalAmount}: ${orderTotalAmount.toStringAsFixed(0)} IQD';

    final deliveryFeeText = orderDeliveryFee == null
        ? null
        : '${loc.deliveryFee}: ${orderDeliveryFee.toStringAsFixed(0)} IQD';

    final statusText = orderStatus == null
        ? null
        : (orderStatus == 'pending'
            ? loc.pendingStatus
            : orderStatus == 'assigned'
                ? loc.assignedStatus
                : orderStatus == 'accepted'
                    ? loc.acceptedStatus
                    : orderStatus == 'on_the_way'
                        ? loc.onTheWayStatus
                        : orderStatus == 'delivered'
                            ? loc.deliveredStatus
                            : loc.unknownStatus);

    final metaParts = <_TxMetaPart>[
      _TxMetaPart(icon: Icons.schedule, text: dateFormat.format(baghdadTime)),
      if (commissionRateText != null)
        _TxMetaPart(icon: Icons.percent, text: commissionRateText),
      if (orderAmountText != null)
        _TxMetaPart(icon: Icons.receipt_long, text: orderAmountText),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(context.rs(14)),
        border: Border.all(
          color: context.isDarkMode
              ? context.themeBorder.withOpacity(0.35)
              : context.themeBorder.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        sourceText,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.themeTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Directionality(
                      textDirection: ui.TextDirection.ltr,
                      child: Text(
                        amountText,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: amountColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: metaParts
                            .map(
                              (m) => _TxMetaChip(
                                icon: m.icon,
                                text: m.text,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    if (onOpenOrder != null && orderId != null) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: onOpenOrder,
                        icon: Icon(
                          Icons.chevron_right,
                          color: context.themeTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                if (transactionType != 'top_up' && deliveryFeeText != null && orderAmountText == null) ...[
                  const SizedBox(height: 4),
                  _TxMetaChip(icon: Icons.local_shipping_outlined, text: deliveryFeeText),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _TxMetaPart {
  final IconData icon;
  final String text;

  const _TxMetaPart({
    required this.icon,
    required this.text,
  });
}

class _TxMetaChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TxMetaChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.themeSurfaceVariant,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: context.themeBorder.withOpacity(context.isDarkMode ? 0.30 : 0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: context.themeTextSecondary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.themeTextSecondary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}




