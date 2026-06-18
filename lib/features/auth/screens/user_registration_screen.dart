import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../shared/widgets/shake_error_field.dart';
import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../orders/screens/location_picker_screen.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/app_haptics.dart';

class UserRegistrationScreen extends StatefulWidget {
  final String role;

  const UserRegistrationScreen({
    super.key,
    required this.role,
  });

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Merchant-specific fields
  final _storeNameController = TextEditingController();
  final _storeAddressController = TextEditingController();
  double? _storeLatitude;
  double? _storeLongitude;

  // Driver-specific fields
  String _selectedVehicleType = 'motorbike'; // Default to motorbike
  bool _hasDrivingLicense = false;
  bool _ownsVehicle = false;
  String _selectedDocumentType = 'national_id'; // Default to national ID

  // Merchant-specific fields
  String? _selectedBusinessType; // Type of business for merchants

  // City selection (for both merchants and drivers)
  String? _selectedCity; // 'najaf'

  // Referral source (how did they hear about us)
  String? _referralSource;

  // Documents
  File? _idCardFront;
  File? _idCardBack;
  File? _selfieWithId; // Required for drivers, optional for merchants
  File? _driverProfilePhoto; // Optional driver profile photo

  bool _isLoading = false;
  String? _extractedLegalName; // Name extracted from ID

  int _currentStep = 0;
  static const _totalSteps = 4;
  String? _stepError;
  final _stepShakeKey = GlobalKey<ShakeErrorFieldState>();

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeAddressController.dispose();
    super.dispose();
  }

  String _getRoleDisplayName() {
    final loc = AppLocalizations.of(context);
    return widget.role == 'merchant' ? loc.merchant : loc.driver;
  }

  List<String> _getStepTitles() {
    final loc = AppLocalizations.of(context);
    return [
      loc.city,
      widget.role == 'merchant' ? loc.storeInformation : loc.vehicleInformation,
      loc.howDidYouHear,
      loc.requiredDocuments,
    ];
  }

  void _showStepError(String message) {
    setState(() => _stepError = message);
    _stepShakeKey.currentState?.triggerError(message);
  }

  bool _validateCurrentStep() {
    final loc = AppLocalizations.of(context);
    setState(() => _stepError = null);

    switch (_currentStep) {
      case 0:
        if (_selectedCity == null) {
          _showStepError(loc.cityRequired);
          return false;
        }
        return true;
      case 1:
        if (widget.role == 'merchant') {
          if (_storeNameController.text.trim().isEmpty) {
            _showStepError(loc.storeNameRequired);
            return false;
          }
          if (_storeLatitude == null || _storeLongitude == null) {
            _showStepError(loc.pleaseSelectStoreLocation);
            return false;
          }
        }
        return true;
      case 2:
        return true; // referral is optional
      case 3:
        if (_idCardFront == null) {
          _showStepError(loc.pleaseUploadDocument);
          return false;
        }
        if (_selectedDocumentType != 'passport' && _idCardBack == null) {
          _showStepError(loc.pleaseUploadDocumentBack);
          return false;
        }
        if (widget.role == 'driver' && _selfieWithId == null) {
          _showStepError(loc.pleaseUploadSelfie);
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _nextStep() {
    if (!_validateCurrentStep()) {
      AppHaptics.error();
      return;
    }
    AppHaptics.light();
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
        _stepError = null;
      });
    } else {
      _submitRegistration();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _stepError = null;
      });
    } else {
      context.go('/role-selection');
    }
  }

  Future<void> _pickImage(ImageSource source, String type) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          switch (type) {
            case 'id_front':
              _idCardFront = File(image.path);
              break;
            case 'id_back':
              _idCardBack = File(image.path);
              break;
            case 'selfie':
              _selfieWithId = File(image.path);
              break;
            case 'avatar':
              _driverProfilePhoto = File(image.path);
              break;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).errorSelectingImage(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showImagePicker(String type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.themeSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          color: context.themeSurface,
          child: Padding(
            padding: context.rp(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ResponsiveText(
                  AppLocalizations.of(context).selectImageSource,
                  style: AppTextStyles.heading3
                      .copyWith(color: context.themeTextPrimary)
                      .responsive(context),
                ),
                SizedBox(height: context.rs(16)),
                ListTile(
                  tileColor: context.themeSurface,
                  textColor: context.themeTextPrimary,
                  iconColor: context.themeTextPrimary,
                  leading: Container(
                    padding: context.rp(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.themePrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.camera_alt, color: context.themePrimary),
                  ),
                  title: Text(
                    AppLocalizations.of(context).takePhoto,
                    style: TextStyle(color: context.themeTextPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera, type);
                  },
                ),
                ListTile(
                  tileColor: context.themeSurface,
                  textColor: context.themeTextPrimary,
                  iconColor: context.themeTextPrimary,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.themeSecondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.photo_library, color: context.themeSecondary),
                  ),
                  title: Text(
                    AppLocalizations.of(context).chooseFromGallery,
                    style: TextStyle(color: context.themeTextPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery, type);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickStoreLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLatitude: _storeLatitude,
          initialLongitude: _storeLongitude,
          title: AppLocalizations.of(context).selectStoreLocation,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _storeLatitude = result['latitude'];
        _storeLongitude = result['longitude'];
        _storeAddressController.text = result['address'] ?? AppLocalizations.of(context).locationSelected;
      });
    }
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate documents (back image not required for passport)
    final loc = AppLocalizations.of(context);
    if (_idCardFront == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.pleaseUploadDocument),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Back image required for national ID and driver license, but NOT for passport
    if (_selectedDocumentType != 'passport' && _idCardBack == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.pleaseUploadDocumentBack),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Selfie required only for drivers
    if (widget.role == 'driver' && _selfieWithId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.pleaseUploadSelfie),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // City validation (required for both merchants and drivers)
    if (_selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.cityRequired),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Merchant-specific validation
    if (widget.role == 'merchant') {
      if (_storeLatitude == null || _storeLongitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.pleaseSelectStoreLocation),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();

      // Step 1: Verify ID card with AI
      Logger.d('🆔 Verifying ID card with AI...');
      final verificationResult = await _verifyIdWithAI();

      if (verificationResult == null || !verificationResult['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(verificationResult?['reason'] ??
                  AppLocalizations.of(context).idVerificationFailedReason),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      Logger.d('✅ ID verification passed');

      // Extract legal name from verification result
      final legalName = verificationResult['legal_name'];
      final fullName =
          '${legalName['first']} ${legalName['father']} ${legalName['grandfather']} ${legalName['family']}';
      final idNumber = verificationResult['id_number'];

      Logger.d('📝 Extracted name: $fullName');
      Logger.d('🆔 Extracted ID: $idNumber');

      // Validate ID number format if document type is national_id
      String? idNumberToUse = idNumber;
      if (_selectedDocumentType == 'national_id' && idNumber != null) {
        // Remove any non-digit characters for validation
        final cleanedIdNumber = idNumber.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleanedIdNumber.length != 12) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context).nationalIdMustBe12DigitsExtracted(idNumber)),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return;
        }
        // Use cleaned version
        idNumberToUse = cleanedIdNumber;
      }

      // Step 2: Prepare registration data with AI-extracted name
      Map<String, dynamic> userData = {
        'name': fullName,
        'role': widget.role,
        'id_number': idNumberToUse,
        'legal_first_name': legalName['first'],
        'legal_father_name': legalName['father'],
        'legal_grandfather_name': legalName['grandfather'],
        'legal_family_name': legalName['family'],
        'id_expiry_date': verificationResult['id_expiry_date'],
        'id_birth_date': verificationResult['id_birth_date'],
        'verification_status': 'approved', // Auto-approve if AI check passed
        'document_type': _selectedDocumentType,
        'city': _selectedCity, // Add city to registration data
      };

      // Add referral source if provided
      if (_referralSource != null) {
        userData['referral_source'] = _referralSource;
      }

      if (widget.role == 'merchant') {
        userData.addAll({
          'store_name': _storeNameController.text.trim(),
          'address': _storeAddressController.text.trim(),
          'latitude': _storeLatitude,
          'longitude': _storeLongitude,
        });

        // Add business type if provided
        if (_selectedBusinessType != null) {
          userData['business_type'] = _selectedBusinessType;
        }
      } else if (widget.role == 'driver') {
        userData.addAll({
          'vehicle_type': _selectedVehicleType,
          'has_driving_license': _hasDrivingLicense,
          'owns_vehicle': _ownsVehicle,
        });
      }

      // Step 3: Register user with AI-verified data
      final success = await authProvider.registerUser(
        userData: userData,
        idCardFront: _idCardFront!,
        idCardBack: _idCardBack!,
        selfieWithId: widget.role == 'driver' ? _selfieWithId! : null,
        driverProfilePhoto:
            widget.role == 'driver' ? _driverProfilePhoto : null,
      );

      if (success && mounted) {
        // Navigate to review screen (GoRouter) to confirm extracted data
        context.goNamed('id-verification-review', extra: {
          'extractedData': verificationResult,
          'role': widget.role,
          'isResubmission': false,
          'idFrontFile': _idCardFront,
          'idBackFile': _idCardBack,
          'selfieFile': _selfieWithId,
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? AppLocalizations.of(context).registrationError),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      Logger.d('❌ Registration error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).errorLabel(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _verifyIdWithAI() async {
    try {
      final userId = context.read<AuthProvider>().user?.id;

      Logger.d('📤 Sending images to ID verification edge function...');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Env.supabaseUrl}/functions/v1/verify-id-card'),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Bearer ${Env.supabaseAnonKey}';

      // Add front image (always required)
      request.files.add(await http.MultipartFile.fromPath(
        'id_front',
        _idCardFront!.path,
      ));

      // Add back image only if document type requires it (not for passport)
      if (_selectedDocumentType != 'passport' && _idCardBack != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'id_back',
          _idCardBack!.path,
        ));
      }

      // Add selfie only for drivers
      if (widget.role == 'driver' && _selfieWithId != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'selfie',
          _selfieWithId!.path,
        ));
      }

      // Add role, user_id, and document_type
      request.fields['role'] = widget.role;
      request.fields['document_type'] = _selectedDocumentType;
      if (userId != null) {
        request.fields['user_id'] = userId;
      }

      Logger.d('⏳ Waiting for verification response...');
      Logger.d('📄 Document type: $_selectedDocumentType');

      var response = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Request timeout - please try again');
        },
      );

      final responseData = await response.stream.bytesToString();
      final jsonData = json.decode(responseData);

      Logger.d('📥 Verification response: ${jsonData.toString()}');

      return jsonData;
    } catch (e) {
      Logger.d('❌ ID verification error: $e');
      return {
        'success': false,
        'reason': AppLocalizations.of(context).connectionFailed(e.toString()),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final stepTitles = _getStepTitles();

    return Theme(
      data: ThemeData.light().copyWith(
        primaryColor: AppColors.primary,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(loc.registeringAs(_getRoleDisplayName())),
          centerTitle: true,
          backgroundColor: context.themePrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: _previousStep,
          ),
        ),
        body: Column(
          children: [
            _buildStepIndicator(stepTitles),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: context.rp(horizontal: 20, vertical: 20),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(_currentStep),
                      child: ShakeErrorField(
                        key: _stepShakeKey,
                        errorMessage: _stepError,
                        onErrorCleared: () => setState(() => _stepError = null),
                        child: _buildStepContent(loc),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _buildStepNavigation(loc),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(List<String> stepTitles) {
    return Container(
      width: double.infinity,
      padding: context.rp(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: context.themePrimaryTint,
        border: Border(
          bottom: BorderSide(color: context.themeBorder.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.themePrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentStep + 1} / $_totalSteps',
              style: AppTextStyles.caption.copyWith(
                color: context.themePrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: context.rs(14)),
          Row(
            children: List.generate(_totalSteps, (index) {
              final isActive = index == _currentStep;
              final isDone = index < _currentStep;
              return Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDone
                            ? context.themePrimary
                            : isActive
                                ? context.themePrimary.withValues(alpha: 0.15)
                                : context.themeSurfaceVariant,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDone || isActive
                              ? context.themePrimary
                              : context.themeBorder,
                          width: isActive ? 2 : 1,
                        ),
                      ),
                      child: isDone
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isActive
                                      ? context.themePrimary
                                      : context.themeTextTertiary,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      stepTitles[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        color: isActive || isDone
                            ? context.themeTextPrimary
                            : context.themeTextTertiary,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 10,
                      ),
                    ),
                    if (index < _totalSteps - 1)
                      const SizedBox.shrink(),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(AppLocalizations loc) {
    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader(
              loc.completeData(_getRoleDisplayName()),
              loc.pleaseFillAllRequired,
            ),
            SizedBox(height: context.rs(24)),
            _buildSectionHeader(loc.city, Icons.location_city),
            SizedBox(height: context.rs(16)),
            _buildCityDropdown(),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader(
              widget.role == 'merchant'
                  ? loc.storeInformation
                  : loc.vehicleInformation,
              loc.pleaseFillAllRequired,
            ),
            SizedBox(height: context.rs(24)),
            if (widget.role == 'merchant')
              ..._buildMerchantFields()
            else
              ..._buildDriverFields(),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader(loc.howDidYouHear, loc.pleaseFillAllRequired),
            SizedBox(height: context.rs(24)),
            _buildSectionHeader(loc.howDidYouHear, Icons.campaign),
            SizedBox(height: context.rs(16)),
            _buildReferralSourceDropdown(),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader(loc.requiredDocuments, loc.pleaseFillAllRequired),
            SizedBox(height: context.rs(24)),
            _buildSectionHeader(loc.requiredDocuments, Icons.upload_file),
            SizedBox(height: context.rs(16)),
            _buildDocumentTypeDropdown(),
            SizedBox(height: context.rs(16)),
            _buildImageUpload(
              title: _getDocumentFrontLabel(),
              file: _idCardFront,
              onTap: () => _showImagePicker('id_front'),
              icon: Icons.credit_card,
            ),
            if (_selectedDocumentType != 'passport') ...[
              SizedBox(height: context.rs(16)),
              _buildImageUpload(
                title: _getDocumentBackLabel(),
                file: _idCardBack,
                onTap: () => _showImagePicker('id_back'),
                icon: Icons.credit_card,
              ),
            ],
            if (widget.role == 'driver') ...[
              SizedBox(height: context.rs(16)),
              _buildImageUpload(
                title: _getSelfieLabel(),
                file: _selfieWithId,
                onTap: () => _showImagePicker('selfie'),
                icon: Icons.face,
                isImportant: true,
              ),
            ],
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStepHeader(String title, String subtitle) {
    return Center(
      child: Column(
        children: [
          ResponsiveText(
            title,
            style: AppTextStyles.heading2
                .copyWith(color: context.themeTextPrimary)
                .responsive(context),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.rs(8)),
          ResponsiveText(
            subtitle,
            style: AppTextStyles.bodyMedium
                .copyWith(
                  color: context.themeTextSecondary,
                  fontWeight: FontWeight.w400,
                )
                .responsive(context),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepNavigation(AppLocalizations loc) {
    final isLastStep = _currentStep == _totalSteps - 1;

    return Container(
      padding: context.rp(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: context.themeSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _previousStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.themePrimary,
                    side: BorderSide(color: context.themePrimary),
                    minimumSize: Size(0, context.rh(52)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(loc.back),
                ),
              ),
            if (_currentStep > 0) SizedBox(width: context.rs(12)),
            Expanded(
              flex: _currentStep > 0 ? 2 : 1,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _nextStep,
                icon: _isLoading
                    ? SizedBox(
                        width: context.ri(20),
                        height: context.ri(20),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        isLastStep ? Icons.check_circle : Icons.arrow_forward,
                        color: Colors.white,
                        size: context.ri(20),
                      ),
                label: ResponsiveText(
                  _isLoading
                      ? loc.registering
                      : (isLastStep ? loc.completeRegistration : loc.continueText),
                  style: AppTextStyles.buttonMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.themePrimary,
                  foregroundColor: Colors.white,
                  minimumSize: Size(0, context.rh(52)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMerchantFields() {
    return [
      // Note about AI extraction
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.isDarkMode 
              ? AppColors.secondaryDark.withOpacity(0.2)
              : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: context.isDarkMode 
                ? AppColors.secondaryDark.withOpacity(0.3)
                : Colors.blue.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline, 
              color: context.isDarkMode 
                  ? AppColors.secondaryDark
                  : Colors.blue.shade700, 
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context).fullNameExtractedAutomatically,
                style: TextStyle(
                  fontSize: 13, 
                  color: context.themeTextPrimary,
                ),
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 24),

      // Removed profile photo upload for cleaner merchant registration

      // Store Information
      Builder(
        builder: (context) {
          final loc = AppLocalizations.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(loc.storeInformation, Icons.store),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _storeNameController,
                label: loc.storeName,
                hint: loc.enterStoreName,
                icon: Icons.storefront,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return loc.storeNameRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Store Address with Map
              _buildLocationField(
                controller: _storeAddressController,
                label: loc.storeAddress,
                hint: loc.selectStoreLocationMap,
                onTap: _pickStoreLocation,
                hasLocation: _storeLatitude != null && _storeLongitude != null,
              ),

              const SizedBox(height: 16),

              // Business Type Selection
              _buildBusinessTypeDropdown(),
            ],
          );
        },
      ),
    ];
  }

  List<Widget> _buildDriverFields() {
    return [
      // Note about AI extraction
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.isDarkMode 
              ? AppColors.secondaryDark.withOpacity(0.2)
              : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: context.isDarkMode 
                ? AppColors.secondaryDark.withOpacity(0.3)
                : Colors.blue.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline, 
              color: context.isDarkMode 
                  ? AppColors.secondaryDark
                  : Colors.blue.shade700, 
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context).nameExtractedAutomatically,
                style: TextStyle(
                  fontSize: 13, 
                  color: context.themeTextPrimary,
                ),
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 24),

      // Vehicle Information
      Builder(
        builder: (context) {
          return _buildSectionHeader(AppLocalizations.of(context).vehicleInformation, Icons.directions_car);
        },
      ),
      const SizedBox(height: 16),

      // Vehicle Type Selection
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Builder(
                builder: (context) {
                  return Text(
                    AppLocalizations.of(context).vehicleType,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: context.themeTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
              const Text(
                ' *',
                style: TextStyle(color: AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.themeSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.themeBorder),
            ),
            child: Column(
              children: [
                // Motorbike option (default)
                Container(
                  decoration: BoxDecoration(
                    color: _selectedVehicleType == 'motorbike'
                          ? context.themePrimary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedVehicleType == 'motorbike'
                            ? context.themePrimary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: RadioListTile<String>(
                    title: Row(
                      children: [
                        Icon(
                          Icons.two_wheeler,
                          color: _selectedVehicleType == 'motorbike'
                              ? context.themePrimary
                              : context.themeTextSecondary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Builder(
                          builder: (context) {
                            final loc = AppLocalizations.of(context);
                            return Text(
                              loc.motorbike,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: context.themeTextPrimary,
                                fontWeight: _selectedVehicleType == 'motorbike'
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        if (_selectedVehicleType == 'motorbike')
                          Builder(
                            builder: (context) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: context.themePrimary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  AppLocalizations.of(context).defaultLabel,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    value: 'motorbike',
                    groupValue: _selectedVehicleType,
                    onChanged: (value) {
                      setState(() {
                        _selectedVehicleType = value!;
                      });
                    },
                    activeColor: context.themePrimary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                const SizedBox(height: 8),
                // Car option
                Container(
                  decoration: BoxDecoration(
                    color: _selectedVehicleType == 'car'
                        ? context.themePrimary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedVehicleType == 'car'
                          ? context.themePrimary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: RadioListTile<String>(
                    title: Row(
                      children: [
                        Icon(
                          Icons.directions_car,
                          color: _selectedVehicleType == 'car'
                              ? context.themePrimary
                              : context.themeTextSecondary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Builder(
                          builder: (context) {
                            return Text(
                              AppLocalizations.of(context).car,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: context.themeTextPrimary,
                                fontWeight: _selectedVehicleType == 'car'
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    value: 'car',
                    groupValue: _selectedVehicleType,
                    onChanged: (value) {
                      setState(() {
                        _selectedVehicleType = value!;
                      });
                    },
                    activeColor: context.themePrimary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                const SizedBox(height: 8),
                // Truck option
                Container(
                  decoration: BoxDecoration(
                    color: _selectedVehicleType == 'truck'
                        ? context.themePrimary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedVehicleType == 'truck'
                          ? context.themePrimary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: RadioListTile<String>(
                    title: Row(
                      children: [
                        Icon(
                          Icons.local_shipping,
                          color: _selectedVehicleType == 'truck'
                              ? context.themePrimary
                              : context.themeTextSecondary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Builder(
                          builder: (context) {
                            return Text(
                              AppLocalizations.of(context).truck,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: context.themeTextPrimary,
                                fontWeight: _selectedVehicleType == 'truck'
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    value: 'truck',
                    groupValue: _selectedVehicleType,
                    onChanged: (value) {
                      setState(() {
                        _selectedVehicleType = value!;
                      });
                    },
                    activeColor: context.themePrimary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      const SizedBox(height: 16),

      // Driving License
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.themeSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.themeBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.card_membership, color: context.themePrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context).doYouHaveLicense,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.themeTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Switch(
              value: _hasDrivingLicense,
              onChanged: (value) {
                setState(() {
                  _hasDrivingLicense = value;
                });
              },
              activeColor: AppColors.success,
            ),
          ],
        ),
      ),

      const SizedBox(height: 16),

      // Vehicle Ownership
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.themeSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.themeBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.key, color: context.themePrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context).doYouOwnVehicle,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.themeTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Switch(
              value: _ownsVehicle,
              onChanged: (value) {
                setState(() {
                  _ownsVehicle = value;
                });
              },
              activeColor: AppColors.success,
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildDriverAvatarPicker() {
    final avatarSize = math.min(96.0, context.screenWidth * 0.25);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (context) {
            return _buildSectionHeader(AppLocalizations.of(context).profilePhotoOptional, Icons.person);
          },
        ),
        SizedBox(height: context.rs(12)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showImagePicker('avatar'),
                borderRadius: BorderRadius.circular(avatarSize / 2),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.themePrimary.withOpacity(0.4),
                          width: 2,
                        ),
                        color: context.themePrimary.withOpacity(0.08),
                      ),
                      child: ClipOval(
                        child: _driverProfilePhoto != null
                            ? Image.file(
                                _driverProfilePhoto!,
                                fit: BoxFit.cover,
                              )
                            : Icon(
                                Icons.person,
                                color: context.themePrimary,
                                size: avatarSize * 0.55,
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: context.themePrimary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: context.rs(16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).addClearProfilePhoto,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: context.themeTextSecondary,
                    ),
                  ),
                  if (_driverProfilePhoto != null) ...[
                    SizedBox(height: context.rs(8)),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _driverProfilePhoto = null;
                        });
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: Text(AppLocalizations.of(context).removeImage),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.themePrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: context.themePrimary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: AppTextStyles.heading3.copyWith(
            color: context.themeTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: context.themeTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(
              ' *',
              style: TextStyle(color: AppColors.error),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: AppTextStyles.bodyMedium.copyWith(
            color: context.themeTextPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: context.themeTextTertiary,
            ),
            prefixIcon: Icon(icon, color: context.themePrimary),
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
              borderSide: BorderSide(color: context.themePrimary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required VoidCallback onTap,
    required bool hasLocation,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: context.themeTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(
              ' *',
              style: TextStyle(color: AppColors.error),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: context.themeSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasLocation ? AppColors.success : context.themeBorder,
              width: hasLocation ? 2 : 1,
            ),
            boxShadow: hasLocation
                ? [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (hasLocation
                                ? AppColors.success
                              : context.themePrimary)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.location_on,
                        color:
                            hasLocation ? AppColors.success : context.themePrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.text.isEmpty ? hint : controller.text,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: controller.text.isEmpty
                                  ? context.themeTextTertiary
                                  : context.themeTextPrimary,
                              fontWeight: controller.text.isEmpty
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (hasLocation) const SizedBox(height: 4),
                          if (hasLocation)
                            Text(
                              AppLocalizations.of(context).locationSelectedCheckmark,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.push_pin,
                      color:
                          hasLocation ? AppColors.success : context.themePrimary,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCityDropdown() {
    final loc = AppLocalizations.of(context);
    final cityOptions = [
      {'value': 'najaf', 'label': '🏛️ ${loc.najaf} / Najaf'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              loc.city,
              style: AppTextStyles.bodyMedium.copyWith(
                color: context.themeTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(
              ' *',
              style: TextStyle(color: AppColors.error),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: context.themeSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.themeBorder),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedCity,
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.themeTextPrimary,
            ),
            decoration: InputDecoration(
              labelText: loc.selectCity,
              labelStyle: TextStyle(color: context.themeTextSecondary),
              hintText: loc.selectCity,
              hintStyle: TextStyle(color: context.themeTextTertiary),
              prefixIcon: Icon(Icons.location_city, color: context.themePrimary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text(
                  loc.selectCity,
                  style: TextStyle(color: context.themeTextTertiary),
                ),
              ),
              ...cityOptions.map((option) => DropdownMenuItem<String>(
                    value: option['value'],
                    child: Text(
                      option['label']!,
                      style: TextStyle(color: context.themeTextPrimary),
                    ),
                  )),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCity = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return loc.cityRequired;
              }
              return null;
            },
            dropdownColor: context.themeSurface,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }

  Widget _buildReferralSourceDropdown() {
    final referralOptions = [
      {
        'value': 'social_media',
        'label': '📱 وسائل التواصل الاجتماعي'
      },
      {'value': 'friend', 'label': '👥 صديق أو معارف'},
      {'value': 'representative', 'label': '🤝 ممثل حر'},
      {'value': 'advertisement', 'label': '📺 إعلان'},
      {'value': 'search_engine', 'label': '🔍 محرك بحث'},
      {'value': 'word_of_mouth', 'label': '💬 من شخص آخر'},
      {'value': 'store_banner', 'label': '🏪 لافتة في متجر'},
      {'value': 'other', 'label': '📋 أخرى'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.themeBorder),
      ),
      child: DropdownButtonFormField<String>(
        value: _referralSource,
        isExpanded: true,
        style: AppTextStyles.bodyMedium.copyWith(
          color: context.themeTextPrimary,
        ),
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).howDidYouHearHur,
          labelStyle: TextStyle(color: context.themeTextSecondary),
          hintText: AppLocalizations.of(context).optional,
          hintStyle: TextStyle(color: context.themeTextTertiary),
          prefixIcon: Icon(Icons.campaign, color: context.themePrimary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(
              AppLocalizations.of(context).optional,
              style: TextStyle(color: context.themeTextTertiary),
            ),
          ),
          ...referralOptions.map((option) => DropdownMenuItem<String>(
                value: option['value'],
                child: Text(
                  option['label']!,
                  overflow: TextOverflow.visible,
                  softWrap: true,
                  style: TextStyle(color: context.themeTextPrimary),
                ),
              )),
        ],
        onChanged: (value) {
          setState(() {
            _referralSource = value;
          });
        },
        dropdownColor: context.themeSurface,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildDocumentTypeDropdown() {
    final documentTypes = [
      {'value': 'national_id', 'label': '🪪 البطاقة الوطنية / National ID'},
      {'value': 'driver_license', 'label': '🚗 رخصة القيادة / Driver License'},
      {'value': 'passport', 'label': '✈️ جواز السفر / Passport'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.themeBorder),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedDocumentType,
        style: AppTextStyles.bodyMedium.copyWith(
          color: context.themeTextPrimary,
        ),
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).documentType,
          labelStyle: TextStyle(color: context.themeTextSecondary),
          hintText: AppLocalizations.of(context).selectDocumentType,
          hintStyle: TextStyle(color: context.themeTextTertiary),
          prefixIcon: Icon(Icons.badge, color: context.themePrimary),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        items: documentTypes
            .map((type) => DropdownMenuItem<String>(
                  value: type['value'],
                  child: Text(
                    type['label']!,
                    style: TextStyle(color: context.themeTextPrimary),
                  ),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedDocumentType = value!;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return AppLocalizations.of(context).documentTypeRequired;
          }
          return null;
        },
        dropdownColor: context.themeSurface,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildBusinessTypeDropdown() {
    final businessTypes = [
      {'value': 'restaurant', 'label': '🍽️ مطعم / Restaurant'},
      {'value': 'grocery', 'label': '🛒 بقالة / Grocery'},
      {'value': 'pharmacy', 'label': '💊 صيدلية / Pharmacy'},
      {'value': 'bakery', 'label': '🥖 مخبز / Bakery'},
      {'value': 'cafe', 'label': '☕ مقهى / Cafe'},
      {'value': 'supermarket', 'label': '🏪 سوبرماركت / Supermarket'},
      {'value': 'electronics', 'label': '📱 إلكترونيات / Electronics'},
      {'value': 'clothing', 'label': '👕 ملابس / Clothing'},
      {'value': 'other', 'label': '📦 أخرى / Other'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.themeBorder),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedBusinessType,
        style: AppTextStyles.bodyMedium.copyWith(
          color: context.themeTextPrimary,
        ),
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).businessTypeLabel,
          labelStyle: TextStyle(color: context.themeTextSecondary),
          hintText: AppLocalizations.of(context).businessTypeHint,
          hintStyle: TextStyle(color: context.themeTextTertiary),
          prefixIcon: Icon(Icons.business, color: context.themePrimary),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(
              AppLocalizations.of(context).selectBusinessType,
              style: TextStyle(color: context.themeTextTertiary),
            ),
          ),
          ...businessTypes.map((type) => DropdownMenuItem<String>(
                value: type['value'],
                child: Text(
                  type['label']!,
                  style: TextStyle(color: context.themeTextPrimary),
                ),
              )),
        ],
        onChanged: (value) {
          setState(() {
            _selectedBusinessType = value;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return AppLocalizations.of(context).businessTypeRequired;
          }
          return null;
        },
        dropdownColor: context.themeSurface,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  String _getDocumentFrontLabel([BuildContext? ctx]) {
    final loc = ctx != null ? AppLocalizations.of(ctx) : null;
    switch (_selectedDocumentType) {
      case 'driver_license':
        return loc?.drivingLicenseFront ?? 'رخصة القيادة - الجانب الأمامي';
      case 'passport':
        return loc?.passportMainPage ?? 'جواز السفر - الصفحة الرئيسية';
      default:
        return loc?.nationalIdFront ?? 'الهوية الوطنية - الجانب الأمامي';
    }
  }

  String _getDocumentBackLabel() {
    switch (_selectedDocumentType) {
      case 'driver_license':
        return 'رخصة القيادة - الجانب الخلفي';
      case 'passport':
        return 'جواز السفر - صفحة إضافية'; // Not shown for passport
      default:
        return 'الهوية الوطنية - الجانب الخلفي';
    }
  }

  String _getSelfieLabel() {
    switch (_selectedDocumentType) {
      case 'driver_license':
        return 'صورة سيلفي مع رخصة القيادة';
      case 'passport':
        return 'صورة سيلفي مع جواز السفر';
      default:
        return 'صورة سيلفي مع الهوية الوطنية';
    }
  }

  Widget _buildImageUpload({
    required String title,
    required File? file,
    required VoidCallback onTap,
    required IconData icon,
    bool isImportant = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: file != null ? AppColors.success : context.themeBorder,
          width: file != null ? 2 : 1,
        ),
        boxShadow: file != null
            ? [
                BoxShadow(
                  color: AppColors.success.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Image preview or icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: file != null
                        ? AppColors.success.withOpacity(0.1)
                        : context.themePrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: file != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            file,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(
                          icon,
                          color: context.themePrimary,
                          size: 30,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: context.themeTextPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isImportant)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'مهم',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        file != null ? 'تم الرفع ✓' : 'اضغط للرفع',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: file != null
                              ? AppColors.success
                              : context.themeTextTertiary,
                          fontWeight:
                              file != null ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  file != null ? Icons.check_circle : Icons.cloud_upload,
                  color: file != null ? AppColors.success : context.themePrimary,
                  size: 24,
                ),
              ],
          ),
        ),
      ),
      ),
    );
  }
}
