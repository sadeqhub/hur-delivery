import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/localization/app_localizations.dart';
import 'payment_webview_dialog.dart';

class TopUpDialog extends StatefulWidget {
  const TopUpDialog({super.key});

  @override
  State<TopUpDialog> createState() => _TopUpDialogState();
}

class _TopUpDialogState extends State<TopUpDialog> {
  String? _selectedMethod = 'wayl'; // Default to Wayl (only option for merchants)
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static const double minAmount = 10000.0;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }


  Future<void> _submitTopUp() async {
    final loc = AppLocalizations.of(context);
    
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.pleaseEnterValidAmount)),
      );
      return;
    }

    // Validate minimum amount
    if (amount < minAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.minimumAmountIs(minAmount)),
        ),
      );
      return;
    }

    // Only Wayl online checkout is available for merchants
    if (_selectedMethod == 'wayl') {
      final authProvider = context.read<AuthProvider>();
      final walletProvider = context.read<WalletProvider>();

      if (authProvider.user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.mustLoginFirst)),
        );
        return;
      }

      // Store scaffold messenger before any navigation
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      
      // Show loading dialog without closing top-up dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (loadingContext) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Create payment link
      print('[TopUpDialog] Calling createWaylPaymentLink...');
      final result = await walletProvider.createWaylPaymentLink(
        merchantId: authProvider.user!.id,
        amount: amount,
        notes: loc.topUpViaWayl,
      );

      print('[TopUpDialog] Received result: $result');
      print('[TopUpDialog] Result is null: ${result == null}');
      print('[TopUpDialog] Result keys: ${result?.keys}');
      
      // Close loading dialog
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      
      if (result != null && result['payment_url'] != null) {
        final paymentUrl = result['payment_url'] as String;
        final referenceId = result['reference_id'] as String?;
        print('[TopUpDialog] Payment URL found: $paymentUrl');
        print('[TopUpDialog] Reference ID: $referenceId');

        // Close top-up dialog first
        Navigator.of(context).pop();
        
        // Show WebView payment dialog
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => PaymentWebViewDialog(
              paymentUrl: paymentUrl,
              referenceId: referenceId,
              onPaymentComplete: () {
                print('[TopUpDialog] Payment completed callback');
                // Refresh wallet balance - realtime listeners will also update automatically
                if (authProvider.user != null) {
                  walletProvider.loadWalletData(authProvider.user!.id);
                  walletProvider.loadTransactions(authProvider.user!.id);
                }
                // Show success message
                final loc = AppLocalizations.of(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loc.paymentSuccess),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 4),
                  ),
                );
              },
              onPaymentCancelled: () {
                print('[TopUpDialog] Payment cancelled');
                final loc = AppLocalizations.of(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loc.paymentCancelled),
                    duration: const Duration(seconds: 3),
        ),
      );
              },
              onError: () {
                print('[TopUpDialog] Payment error');
                final loc = AppLocalizations.of(context);
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
        }
      } else {
        print('[TopUpDialog] No payment URL in result');
        print('[TopUpDialog] Result: $result');
        print('[TopUpDialog] Error: ${walletProvider.error}');
        
        // Close top-up dialog
        Navigator.of(context).pop();
        
        final loc = AppLocalizations.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(loc.failedCreatePaymentLink(walletProvider.error ?? loc.errorGeneric)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.themeSurface, // Dark mode responsive
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).topUpWallet,
                      style: AppTextStyles.heading2.copyWith(
                        color: context.themeTextPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: context.themeTextPrimary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Amount Input
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.amountIqd,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.themeTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: false),
                        textInputAction: TextInputAction.done,
                        style: TextStyle(color: context.themeTextPrimary),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return loc.pleaseEnterAmount;
                          }
                          final amount = double.tryParse(value);
                          if (amount == null) {
                            return loc.pleaseEnterValidNumber;
                          }
                          if (amount < minAmount) {
                            return loc.minimumAmountIs(minAmount);
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: loc.minimumAmount(minAmount),
                          hintStyle: TextStyle(color: context.themeTextSecondary),
                          prefixIcon: Icon(Icons.money, color: context.themeTextSecondary),
                          suffixText: 'IQD',
                          suffixStyle: TextStyle(color: context.themeTextSecondary),
                          filled: true,
                          fillColor: context.themeSurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.themeBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.themeBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.error),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Payment Methods
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.selectPaymentMethod,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.themeTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Wayl Online Checkout (only option for merchants)
                      _buildPaymentMethodOption(
                        method: 'wayl',
                        title: loc.onlineCheckout,
                        subtitle: loc.zainCashQiVisaMastercard,
                        icon: Icons.payment,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 24),
                      // Submit Button
                      PrimaryButton(
                        text: loc.continueText,
                        onPressed: _submitTopUp,
                        icon: Icons.arrow_forward,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodOption({
    required String method,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedMethod == method;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethod = method;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withOpacity(0.1) 
              : context.themeSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? color 
                : context.themeBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : context.themeTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.themeTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: color,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}
