import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/driver_wallet_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../wallet/widgets/payment_webview_dialog.dart';

class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen> {
  static const double _minTopUpAmount = 10000.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final driverId = authProvider.user?.id;
      if (driverId != null) {
        context.read<DriverWalletProvider>().initialize(driverId);
      }
    });
  }

  Widget _buildWaylTopUpButton(
    DriverWalletProvider walletProvider,
    AuthProvider authProvider,
  ) {
    final driverId = authProvider.user?.id;
    if (driverId == null) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: walletProvider.isLoading
            ? null
            : () async {
                final loc = AppLocalizations.of(context);

                final amountController = TextEditingController(
                  text: _minTopUpAmount.toStringAsFixed(0),
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
                          hintText: _minTopUpAmount.toStringAsFixed(0),
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
                            if (parsed == null || parsed < _minTopUpAmount) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(loc.minimumAmountIs(_minTopUpAmount)),
                                ),
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
                final amount = submitted;

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (loadingContext) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                final result = await walletProvider.createWaylPaymentLink(
                  driverId: driverId,
                  amount: amount,
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(loc.paymentSuccess),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      },
                      onPaymentCancelled: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(loc.paymentCancelled),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      },
                      onError: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(loc.errorLoadingPayment),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      },
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
              },
        icon: const Icon(Icons.payment),
        label: Text(
          walletProvider.balance < 0
              ? 'شحن المحفظة لتسديد العمولة'
              : 'شحن المحفظة',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final walletProvider = context.watch<DriverWalletProvider>();
    final authProvider = context.watch<AuthProvider>();

    // Check if wallet is enabled
    if (!walletProvider.isEnabled) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('المحفظة'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'المحفظة غير مفعلة حالياً',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.themeTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'يرجى التواصل مع الدعم لتفعيل المحفظة',
                style: TextStyle(
                  fontSize: 14,
                  color: context.themeTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('المحفظة'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: walletProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                final driverId = authProvider.user?.id;
                if (driverId != null) {
                  await walletProvider.refresh(driverId);
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Balance Card
                    _buildBalanceCard(walletProvider),
                    const SizedBox(height: 12),
                    _buildWaylTopUpButton(walletProvider, authProvider),
                    const SizedBox(height: 24),
                    
                    // Transactions Header
                    Text(
                      'المعاملات الأخيرة',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.themeTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Transactions List
                    if (walletProvider.transactions.isEmpty)
                      _buildEmptyTransactions()
                    else
                      ...walletProvider.transactions.map(
                        (transaction) => _buildTransactionItem(transaction),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBalanceCard(DriverWalletProvider walletProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الرصيد المتاح',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            walletProvider.formattedBalance,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد معاملات',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: context.themeTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر معاملاتك هنا عند استلام الأرباح',
            style: TextStyle(
              fontSize: 14,
              color: context.themeTextTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(DriverWalletTransaction transaction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: transaction.color.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: transaction.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              transaction.icon,
              color: transaction.color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.themeTextPrimary,
                  ),
                ),
                if (transaction.notes != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    transaction.notes!,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.themeTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _formatDate(transaction.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.themeTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            transaction.formattedAmount,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: transaction.color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Convert to GMT+3 (Baghdad timezone) before formatting
    final baghdadTime = date.toUtc().add(const Duration(hours: 3));
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    final difference = now.difference(baghdadTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'منذ ${difference.inMinutes} دقيقة';
      }
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else {
      return '${baghdadTime.day}/${baghdadTime.month}/${baghdadTime.year}';
    }
  }
}

