import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/config/env.dart';
import '../../shared/widgets/primary_button.dart';
import '../../core/localization/app_localizations.dart';
import '../../features/auth/screens/id_verification_review_screen.dart';

/// Guard widget that checks user verification status and blocks access
/// if verification is pending or rejected
class VerificationGuard extends StatefulWidget {
  final Widget child;

  const VerificationGuard({
    super.key,
    required this.child,
  });

  @override
  State<VerificationGuard> createState() => _VerificationGuardState();
}

class _VerificationGuardState extends State<VerificationGuard> {
  File? _idCardFront;
  File? _idCardBack;
  File? _selfieWithId;
  bool _isResubmitting = false;
  Timer? _statusCheckTimer;

  @override
  void initState() {
    super.initState();
    _startStatusPolling();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  void _startStatusPolling() {
    // Check status every 5 seconds
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final authProvider = context.read<AuthProvider>();
      final user = authProvider.user;

      // Only poll if status is pending
      if (user != null && user.verificationStatus == 'pending') {
        authProvider.refreshUser().then((_) {
          if (!mounted) return;
          
          final updatedUser = authProvider.user;
          // If status changed to approved, cancel the timer
          if (updatedUser?.verificationStatus == 'approved') {
            timer.cancel();
            _statusCheckTimer = null;
          }
        }).catchError((error) {
          print('Error checking verification status: $error');
        });
      } else {
        // Status is not pending, cancel the timer
        timer.cancel();
        _statusCheckTimer = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;

        // If no user or user is approved, show child
        if (user == null || user.verificationStatus == 'approved') {
          // Stop polling if status is approved
          _statusCheckTimer?.cancel();
          _statusCheckTimer = null;
          return widget.child;
        }

        // If pending, show reupload UI and ensure polling is active
        if (user.verificationStatus == 'pending') {
          // Ensure polling is active
          if (_statusCheckTimer == null || !_statusCheckTimer!.isActive) {
            _startStatusPolling();
          }
          return _buildPendingScreen(user);
        }

        // If rejected, show blocked screen
        if (user.verificationStatus == 'rejected') {
          // Stop polling if rejected
          _statusCheckTimer?.cancel();
          _statusCheckTimer = null;
          return _buildRejectedScreen();
        }

        // Default: show child (shouldn't reach here)
        _statusCheckTimer?.cancel();
        _statusCheckTimer = null;
        return widget.child;
      },
    );
  }

  Widget _buildPendingScreen(user) {
    final loc = AppLocalizations.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                
                // Status Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: const Icon(
                    Icons.pending_actions_rounded,
                    size: 64,
                    color: AppColors.warning,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Title
                Text(
                  loc.pleaseReuploadIds,
                  style: AppTextStyles.heading2,
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // Message
                Text(
                  loc.reuploadIdsMessage,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: context.themeTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // Status checking indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.warning),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'جاري التحقق من الحالة...',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 48),
                
                // Document Upload Section
                _buildDocumentUploadSection(user),
                
                const SizedBox(height: 24),
                
                // Resubmit button
                PrimaryButton(
                  text: _isResubmitting ? loc.verifying : loc.resubmitVerification,
                  onPressed: _isResubmitting ? null : () => _resubmitVerification(user),
                ),
                
                const SizedBox(height: 16),
                
                // Logout button
                OutlinedButton(
                  onPressed: () async {
                    await context.read<AuthProvider>().logout();
                    if (mounted) {
                      context.go('/');
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  ),
                  child: Text(loc.logout),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedScreen() {
    final loc = AppLocalizations.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Status Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: const Icon(
                    Icons.block_rounded,
                    size: 64,
                    color: AppColors.error,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Title
                Text(
                  loc.youAreBlocked,
                  style: AppTextStyles.heading2,
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // Message
                Text(
                  loc.accountBlockedMessage,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: context.themeTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 48),
                
                // WhatsApp Contact Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _contactAppOwner(),
                    icon: const Icon(Icons.chat, size: 24),
                    label: Text(
                      loc.contactAppOwner,
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Logout button
                OutlinedButton(
                  onPressed: () async {
                    await context.read<AuthProvider>().logout();
                    if (mounted) {
                      context.go('/');
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  ),
                  child: Text(loc.logout),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentUploadSection(user) {
    final loc = AppLocalizations.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.upload_file, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                loc.uploadNewDocuments,
                style: AppTextStyles.heading3.copyWith(
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Text(
            loc.pleaseUploadClearId,
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.themeTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '• الصورة واضحة وغير مهتزة\n• البطاقة حقيقية (وليست صورة من شاشة)\n• جميع البيانات ظاهرة ومقروءة',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
              height: 1.6,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // ID Front
          _buildUploadButton(
            loc.idCardFront,
            _idCardFront,
            () => _showImagePicker('id_front'),
          ),
          const SizedBox(height: 12),
          // ID Back
          _buildUploadButton(
            loc.idCardBack,
            _idCardBack,
            () => _showImagePicker('id_back'),
          ),
          // Selfie (only for drivers)
          if (user.role == 'driver') ...[
            const SizedBox(height: 12),
            _buildUploadButton(
              loc.selfieWithId,
              _selfieWithId,
              () => _showImagePicker('selfie'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadButton(String label, File? file, VoidCallback onTap) {
    final hasFile = file != null;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasFile ? AppColors.success.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile ? AppColors.success : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasFile ? Icons.check_circle : Icons.add_photo_alternate,
              color: hasFile ? AppColors.success : AppColors.textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: hasFile ? AppColors.success : AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePicker(String type) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(AppLocalizations.of(context).takePhoto),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera, type);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(AppLocalizations.of(context).chooseFromGallery),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery, type);
                },
              ),
            ],
          ),
        ),
      ),
    );
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
          }
        });
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.errorSelectingImage(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _resubmitVerification(user) async {
    // Validate required images
    if (_idCardFront == null || _idCardBack == null) {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.pleaseUploadIdFrontBack),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Driver-specific validation
    if (user.role == 'driver' && _selfieWithId == null) {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.pleaseUploadSelfieWithId),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isResubmitting = true;
    });

    try {
      print('🆔 Resubmitting ID verification...');
      final verificationResult = await _verifyIdWithAI(user.role, user.id);
      
      if (verificationResult == null || !verificationResult['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(verificationResult?['reason'] ?? AppLocalizations.of(context).idVerificationFailed),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }
      
      print('✅ ID verification passed by AI');
      
      // Restart polling after resubmission
      _statusCheckTimer?.cancel();
      _statusCheckTimer = null;
      _startStatusPolling();
      
      if (mounted) {
        // Navigate to review screen to confirm extracted data
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => IdVerificationReviewScreen(
              extractedData: verificationResult,
              role: user.role,
              isResubmission: true,
              idFrontFile: _idCardFront,
              idBackFile: _idCardBack,
              selfieFile: _selfieWithId,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Resubmission error: $e');
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.error}$e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResubmitting = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _verifyIdWithAI(String role, String userId) async {
    try {
      print('📤 Sending images to ID verification edge function...');
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Env.supabaseUrl}/functions/v1/verify-id-card'),
      );
      
      // Add authorization header
      request.headers['Authorization'] = 'Bearer ${Env.supabaseAnonKey}';
      
      // Add images
      request.files.add(await http.MultipartFile.fromPath(
        'id_front',
        _idCardFront!.path,
      ));
      
      request.files.add(await http.MultipartFile.fromPath(
        'id_back',
        _idCardBack!.path,
      ));
      
      // Add selfie only for drivers
      if (role == 'driver' && _selfieWithId != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'selfie',
          _selfieWithId!.path,
        ));
      }
      
      // Add role and user_id
      request.fields['role'] = role;
      request.fields['user_id'] = userId;
      
      print('⏳ Waiting for verification response...');
      
      var response = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Request timeout - please try again');
        },
      );
      
      final responseData = await response.stream.bytesToString();
      final jsonData = json.decode(responseData);
      
      print('📥 Verification response: ${jsonData.toString()}');
      
      return jsonData;
    } catch (e) {
      print('❌ ID verification error: $e');
      final loc = AppLocalizations.of(context);
      return {
        'success': false,
        'reason': '${loc.connectionFailed}$e',
      };
    }
  }

  Future<void> _contactAppOwner() async {
    final loc = AppLocalizations.of(context);
    try {
      // WhatsApp phone number: 9647814104097
      String phoneNumber = '+9647814104097';
      
      // Create message
      final message = loc.accountBlockedMessage;
      
      // WhatsApp URL format: wa.me/<phone>?text=<message>
      final phoneForUrl = phoneNumber.replaceFirst('+', '');
      final url = 'https://wa.me/$phoneForUrl?text=${Uri.encodeComponent(message)}';
      
      final uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.cannotOpenWhatsapp),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.error}$e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

