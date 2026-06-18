import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/auth_scaffold.dart';
import '../../../shared/widgets/pressable_button.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String phoneE164;
  final String? prefilledCode;

  const ResetPasswordScreen({
    super.key,
    required this.phoneE164,
    this.prefilledCode,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledCode != null) {
      _codeController.text = widget.prefilledCode!;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.resetPasswordWithOtp(
      phoneE164: widget.phoneE164,
      code: _codeController.text.trim(),
      newPassword: _passwordController.text.trim(),
    );
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.passwordUpdatedSuccess)),
      );
      context.go('/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? loc.passwordUpdateFailed),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final loc = AppLocalizations.of(context);
    final fieldWidth = ResponsiveHelper.getFormElementWidth(context);

    return AuthScaffold(
      title: loc.resetPassword,
      onBack: () => context.pop(),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              loc.enterCodeNewPassword,
              style: AppTextStyles.heading2.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.space2xl),
            _AuthField(
              width: fieldWidth,
              child: TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: loc.verificationCode,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                validator: (v) {
                  final val = (v ?? '').trim();
                  if (val.length != 6) return loc.enter6DigitCode;
                  return null;
                },
              ),
            ),
            const SizedBox(height: AppTokens.spaceMd),
            _AuthField(
              width: fieldWidth,
              child: TextFormField(
                controller: _passwordController,
                obscureText: _obscure,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: loc.newPassword,
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                validator: (v) {
                  final val = (v ?? '').trim();
                  if (val.isEmpty) return loc.passwordRequired;
                  if (!RegExp(r'^[A-Za-z0-9]{8,}$').hasMatch(val)) {
                    return loc.lettersNumbersOnly8Min;
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: AppTokens.spaceXl),
            AuthPrimaryButton(
              label: loc.updatePassword,
              width: fieldWidth,
              isLoading: auth.isLoading,
              onPressed: auth.isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  final double width;
  final Widget child;

  const _AuthField({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          boxShadow: AppTokens.elevationSm(),
        ),
        child: child,
      ),
    );
  }
}
