import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/logger.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../shared/widgets/auth_scaffold.dart';
import '../../../shared/widgets/otp_input_boxes.dart';
import '../../../shared/widgets/pressable_button.dart';
import '../../../shared/widgets/shake_error_field.dart';
import '../data/auth_repository.dart';

class PhoneInputScreen extends StatefulWidget {
  final String role;

  const PhoneInputScreen({
    super.key,
    required this.role,
  });

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _phoneShakeKey = GlobalKey<ShakeErrorFieldState>();
  final _otpShakeKey = GlobalKey<ShakeErrorFieldState>();
  final _otpKey = GlobalKey<OtpInputBoxesState>();

  bool _isValidPhone = false;
  bool _otpSent = false;
  String? _fullPhone;
  String? _phoneError;
  String? _otpError;
  Timer? _timer;
  int _countdown = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_validatePhone);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  void _validatePhone() {
    final phone = _phoneController.text.trim();
    final fullPhone = AppConstants.countryCode + phone;
    final regex = RegExp(AppConstants.phonePattern);
    final isDriverTest = phone.startsWith('78000000') && phone.length == 10;
    final isMerchantTest = phone.startsWith('77000000') && phone.length == 10;
    final isLegacyTest = phone.startsWith('999') && phone.length == 10;
    final isRegular = phone.startsWith('7') && phone.length == 10;
    final isValidFormat =
        isDriverTest || isMerchantTest || isLegacyTest || isRegular;
    setState(() {
      _isValidPhone = isValidFormat && regex.hasMatch(fullPhone);
      if (_phoneError != null && _isValidPhone) _phoneError = null;
    });
  }

  void _onOtpCompleted(String otp) {
    if (otp.length == 6) _verifyOTP();
  }

  String? _validatePhoneValue(String? value) {
    final loc = AppLocalizations.of(context);
    if (value == null || value.isEmpty) return loc.phoneRequired;
    if (value.length != 10) return loc.phoneMustBe10Digits;
    final isDriverTest = value.startsWith('78000000');
    final isMerchantTest = value.startsWith('77000000');
    final isLegacyTest = value.startsWith('999');
    final isRegular = value.startsWith('7');
    if (!isDriverTest && !isMerchantTest && !isLegacyTest && !isRegular) {
      return loc.phoneMustStartWithPattern;
    }
    return null;
  }

  void _startCountdown([int seconds = 60]) {
    _timer?.cancel();
    _countdown = seconds;
    _canResend = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  void _showPhoneError(String message) {
    setState(() => _phoneError = message);
    _phoneShakeKey.currentState?.triggerError(message);
  }

  void _showOtpError(String message) {
    setState(() => _otpError = message);
    _otpShakeKey.currentState?.triggerError(message);
  }

  Future<void> _sendOTP() async {
    final validationError = _validatePhoneValue(_phoneController.text.trim());
    if (validationError != null) {
      _showPhoneError(validationError);
      return;
    }

    final phone = _phoneController.text.trim();
    final fullPhone = AppConstants.countryCode + phone;

    final authProvider = context.read<AuthProvider>();
    final purpose = widget.role == 'login' ? 'reset_password' : 'signup';
    final success =
        await authProvider.sendOtpViaOtpiq(fullPhone, purpose: purpose);

    if (success && mounted) {
      setState(() {
        _otpSent = true;
        _fullPhone = fullPhone;
        _phoneError = null;
        _otpError = null;
      });
      _startCountdown();

      final cleaned = fullPhone.replaceAll(RegExp(r'[^\d]'), '');
      final isTest = cleaned.startsWith('96478000000') ||
          cleaned.startsWith('96477000000');
      if (isTest) {
        _otpKey.currentState?.setValue('000000');
      }

      AppHaptics.light();
    } else if (mounted) {
      final loc = AppLocalizations.of(context);
      final errorMessage = authProvider.error ?? loc.errorGeneric;
      final isAlreadyRegistered =
          errorMessage.contains(loc.accountAlreadyRegistered);
      final isNoAccount = errorMessage.contains(loc.noAccountRegistered);

      if (isAlreadyRegistered || isNoAccount) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  isAlreadyRegistered
                      ? Icons.info_outline
                      : Icons.warning_amber_rounded,
                  color: isAlreadyRegistered
                      ? AppColors.primary
                      : AppColors.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAlreadyRegistered ? loc.haveAccount : loc.noAccount,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(
                errorMessage,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(loc.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (isAlreadyRegistered) {
                    context.go('/login');
                  } else {
                    context.go('/phone-input', extra: 'signup');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                    isAlreadyRegistered ? loc.login : loc.createAccount),
              ),
            ],
          ),
        );
      } else {
        _showPhoneError(errorMessage);
      }
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpKey.currentState?.value ?? '';
    final loc = AppLocalizations.of(context);

    if (otp.length != 6) {
      _showOtpError(loc.otpInvalid);
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final phone = _fullPhone ?? AppConstants.countryCode + _phoneController.text.trim();
    final success = await authProvider.verifyOtpViaOtpiq(phone, otp);

    if (success && mounted) {
      _otpKey.currentState?.showSuccess();
      AppHaptics.success();
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _showOtpError(loc.otpFailedIdentity);
        return;
      }

      Logger.d('✅ OTP verified for user: ${currentUser.id}');
      final auth = context.read<AuthProvider>();
      unawaited(auth.loadUserProfile());

      final quickRole = await _resolveUserRoleQuickly(auth, currentUser);
      if (quickRole != null && quickRole.isNotEmpty) {
        _navigateByRole(quickRole);
        return;
      }
      await _handleRoleResolutionFallback(auth, currentUser);
    } else if (mounted) {
      AppHaptics.error();
      _showOtpError(authProvider.error ?? loc.otpInvalid);
    }
  }

  Future<void> _resendOTP() async {
    if (!_canResend) return;
    final authProvider = context.read<AuthProvider>();
    final phone = _fullPhone ?? AppConstants.countryCode + _phoneController.text.trim();
    final success =
        await authProvider.sendOtpViaOtpiq(phone, purpose: 'signup');

    if (success && mounted) {
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).otpResentVia('WhatsApp')),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (mounted) {
      final retry = authProvider.otpRetryAfterSeconds;
      if (retry != null && retry > 0) _startCountdown(retry);
      _showOtpError(authProvider.error ??
          AppLocalizations.of(context).otpSendError);
    }
  }

  Future<String?> _resolveUserRoleQuickly(
      AuthProvider auth, User currentUser) async {
    final cachedRole = auth.user?.role;
    if (cachedRole != null && cachedRole.isNotEmpty) return cachedRole;

    try {
      final dbRole = await AuthRepository().getUserRole(currentUser.id);
      if (dbRole != null && dbRole.isNotEmpty) return dbRole;
    } catch (e) {
      Logger.d('⚠️ Quick role lookup error: $e');
    }
    return null;
  }

  Future<void> _handleRoleResolutionFallback(
      AuthProvider auth, User currentUser) async {
    Map<String, dynamic>? profileCheck;
    String? userRole;

    final repo = AuthRepository();
    try {
      profileCheck = await repo.getUserRoleById(currentUser.id);
    } catch (e) {
      Logger.d('⚠️ Fallback lookup by ID failed: $e');
    }

    if (profileCheck != null) {
      userRole = profileCheck['role'] as String?;
    } else {
      final phone = _fullPhone ?? '';
      if (phone.isNotEmpty) {
        try {
          String cleanedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
          cleanedPhone = cleanedPhone.replaceFirst(RegExp(r'^0+'), '');
          if (!cleanedPhone.startsWith('964')) {
            cleanedPhone = '964$cleanedPhone';
          }
          profileCheck =
              await repo.getUserRoleByPhone(cleanedPhone, '+$cleanedPhone');
          userRole ??= profileCheck?['role'] as String?;
        } catch (e) {
          Logger.d('⚠️ Fallback phone search failed: $e');
        }
      }
    }

    if (userRole != null && userRole.isNotEmpty) {
      _navigateByRole(userRole);
      return;
    }

    final routeRole = widget.role.trim().toLowerCase();
    final isLoginFlow = routeRole == 'login';

    if (isLoginFlow) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context).noAccountRegisteredThisNumber),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: AppLocalizations.of(context).register,
              textColor: Colors.white,
              onPressed: () => context.go('/phone-input', extra: 'signup'),
            ),
          ),
        );
        context.go('/');
      }
      return;
    }

    if (routeRole == 'merchant' || routeRole == 'driver') {
      if (mounted) context.go('/user-registration', extra: routeRole);
      return;
    }

    // New user signup flow: phone first, then role selection
    if (mounted) context.go('/role-selection');
  }

  void _navigateByRole(String role) {
    switch (role.trim().toLowerCase()) {
      case 'merchant':
        if (mounted) context.go('/merchant-dashboard');
        break;
      case 'driver':
        if (mounted) context.go('/driver-dashboard');
        break;
      case 'admin':
        if (mounted) context.go('/admin-dashboard');
        break;
      default:
        if (mounted) context.go('/');
    }
  }

  void _resetOtp() {
    setState(() {
      _otpSent = false;
      _fullPhone = null;
      _otpError = null;
    });
    _otpKey.currentState?.clear();
    _timer?.cancel();
  }

  void _handleBack() {
    if (_otpSent) {
      _resetOtp();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isLogin = widget.role == 'login';
    final buttonWidth = ResponsiveHelper.getFormElementWidth(context);

    return AuthScaffold(
      title: _otpSent ? loc.verifyCode : loc.phoneNumber,
      onBack: _handleBack,
      showLogo: !_otpSent,
      logoSizeFactor: 0.32,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _otpSent ? loc.enterOtp : loc.welcomeToHur,
              style: AppTextStyles.responsiveHeading2(context).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Text(
              _otpSent
                  ? '${loc.otpSentTo} +${_fullPhone ?? ''}'
                  : (isLogin
                      ? loc.enterIraqiPhoneLogin
                      : loc.enterIraqiPhoneOtp),
              style: AppTextStyles.responsiveBodyMedium(context).copyWith(
                color: Colors.white.withValues(alpha: 0.88),
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
            if (_otpSent) ...[
              const SizedBox(height: AppTokens.spaceSm),
              _WhatsAppTrustBadge(label: loc.sentViaWhatsapp),
            ],
            SizedBox(height: _otpSent ? AppTokens.spaceXl : AppTokens.space3xl),
            _buildPhoneField(loc),
            AnimatedSize(
              duration: AppTokens.durationNormal,
              curve: AppTokens.curveStandard,
              child: _otpSent
                  ? Column(
                      children: [
                        const SizedBox(height: AppTokens.spaceXl),
                        ShakeErrorField(
                          key: _otpShakeKey,
                          errorMessage: _otpError,
                          onErrorCleared: () => setState(() => _otpError = null),
                          child: OtpInputBoxes(
                            key: _otpKey,
                            autofocus: true,
                            hasError: _otpError != null,
                            onCompleted: _onOtpCompleted,
                            onChanged: (_) {
                              if (_otpError != null) {
                                setState(() => _otpError = null);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: AppTokens.spaceMd),
                        _buildResendRow(loc),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: AppTokens.spaceXl),
            Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                final isLoading = authProvider.isLoading;
                final canPress = _otpSent
                    ? (_otpKey.currentState?.value.length ?? 0) == 6 &&
                        !isLoading
                    : _isValidPhone && !isLoading;
                return AuthPrimaryButton(
                  label: _otpSent ? loc.confirmOtp : loc.sendCode,
                  width: buttonWidth,
                  isLoading: isLoading,
                  onPressed: canPress
                      ? () => _otpSent ? _verifyOTP() : _sendOTP()
                      : null,
                );
              },
            ),
            const SizedBox(height: AppTokens.spaceMd),
            AuthSecondaryButton(
              label: _otpSent ? loc.changePhone : loc.back,
              width: buttonWidth,
              onPressed: _handleBack,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneField(AppLocalizations loc) {
    final hasError = _phoneError != null;

    return ShakeErrorField(
      key: _phoneShakeKey,
      errorMessage: _phoneError,
      onErrorCleared: () => setState(() => _phoneError = null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ResponsiveText(
            loc.phoneNumber,
            style: AppTextStyles.heading3.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontSize: context.rf(18),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.rs(8)),
          Center(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Container(
                width: ResponsiveHelper.getFormElementWidth(context),
                height: ResponsiveHelper.getFormElementHeight(context),
                decoration: BoxDecoration(
                  color: hasError
                      ? Colors.red.shade50
                      : Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(context.rs(12)),
                  border: Border.all(
                    color: hasError ? AppColors.error : Colors.white,
                    width: hasError ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: context.rp(horizontal: 16, vertical: 12),
                      child: ResponsiveText(
                        '+964',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: hasError ? AppColors.error : Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: context.rf(14),
                        ),
                      ),
                    ),
                    Container(
                      height: context.rs(30),
                      width: 1,
                      color: hasError
                          ? AppColors.error.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.3),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        enabled: !_otpSent,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: hasError ? AppColors.error : Colors.black,
                          fontSize: context.rf(14),
                        ),
                        decoration: InputDecoration(
                          hintText: '7XX XXX XXXX',
                          hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.grey.withOpacity(0.6),
                            fontSize: context.rf(14),
                          ),
                          border: InputBorder.none,
                          contentPadding: context.rp(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          counterText: '',
                        ),
                        onChanged: (_) {
                          if (_phoneError != null) {
                            setState(() => _phoneError = null);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResendRow(AppLocalizations loc) {
    return _canResend
        ? TextButton(
            onPressed: _resendOTP,
            child: Text(
              loc.resendOtp,
              style: TextStyle(
                color: Colors.white,
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        : Text(
            loc.resendInSeconds(_countdown),
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
              color: Colors.white.withValues(alpha: 0.7),
            ),
          );
  }
}

class _WhatsAppTrustBadge extends StatelessWidget {
  final String label;

  const _WhatsAppTrustBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: AppTokens.glassDecoration(radius: AppTokens.radiusFull),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 14, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
