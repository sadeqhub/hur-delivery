import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../shared/widgets/pressable_button.dart';

/// Bottom-sheet widget for drivers to upload delivery proof before completing.
class OrderProofUploader extends StatefulWidget {
  final String orderId;
  final VoidCallback onUploaded;
  final VoidCallback? onCancel;

  const OrderProofUploader({
    super.key,
    required this.orderId,
    required this.onUploaded,
    this.onCancel,
  });

  @override
  State<OrderProofUploader> createState() => _OrderProofUploaderState();
}

class _OrderProofUploaderState extends State<OrderProofUploader> {
  File? _image;
  bool _uploading = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _image = File(picked.path);
          _error = null;
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _upload() async {
    final file = _image;
    if (file == null) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    final provider = context.read<OrderProvider>();
    final bytes = await file.readAsBytes();
    final ok = await provider.uploadOrderProof(
      orderId: widget.orderId,
      fileBytes: bytes,
      contentType: 'image/jpeg',
    );

    if (!mounted) return;

    if (ok) {
      AppHaptics.success();
      widget.onUploaded();
    } else {
      AppHaptics.error();
      setState(() {
        _uploading = false;
        _error = provider.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Text(
          loc.deliveryProof,
          style: AppTextStyles.heading3.copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        if (_image != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            child: Image.file(_image!, height: 180, fit: BoxFit.cover),
          )
        else
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Icon(Icons.camera_alt_outlined,
                  size: 48, color: AppColors.primary),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _uploading ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(loc.takePhoto),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _uploading ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(loc.chooseFromGallery),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
            AuthPrimaryButton(
              label: loc.upload,
              isLoading: _uploading,
              onPressed: _image != null && !_uploading ? _upload : null,
            ),
            if (widget.onCancel != null) ...[
              const SizedBox(height: AppTokens.spaceSm),
              AuthSecondaryButton(
                label: loc.cancel,
                onPressed: widget.onCancel,
              ),
            ],
            const SizedBox(height: 8),
      ],
    );
  }
}
