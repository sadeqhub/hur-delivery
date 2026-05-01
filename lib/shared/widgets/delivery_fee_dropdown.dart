import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/localization/app_localizations.dart';

class DeliveryFeeDropdown extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool isRequired;
  final String? Function(String?)? validator;
  final double? recommendedFee; // The calculated recommended fee based on distance

  const DeliveryFeeDropdown({
    super.key,
    required this.controller,
    required this.label,
    this.isRequired = false,
    this.validator,
    this.recommendedFee,
  });

  @override
  State<DeliveryFeeDropdown> createState() => _DeliveryFeeDropdownState();
}

class _DeliveryFeeDropdownState extends State<DeliveryFeeDropdown> {
  bool _hasBeenTouched = false;
  static const double _stepAmount = 250.0; // Step size in IQD

  @override
  void initState() {
    super.initState();
    _checkInitialValue();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _checkInitialValue() {
    final value = widget.controller.text.trim();
    if (value.isEmpty) {
      // Set default value if controller is empty
      widget.controller.value = const TextEditingValue(
        text: '2000',
        selection: TextSelection.collapsed(offset: 4),
      );
      _hasBeenTouched = true;
    }
  }

  void _onControllerChanged() {
    if (mounted) {
        setState(() {
        // Trigger rebuild to update warning visibility
        });
      }
    }
    
  void _decreaseFee() {
    final currentValue = double.tryParse(widget.controller.text.trim()) ?? 0.0;
    final newValue = (currentValue - _stepAmount).clamp(0.0, double.infinity);
    
    // Round to nearest 250
    final roundedValue = (newValue / _stepAmount).round() * _stepAmount;
    
      widget.controller.value = TextEditingValue(
      text: roundedValue.toStringAsFixed(0),
      selection: TextSelection.collapsed(offset: roundedValue.toStringAsFixed(0).length),
      );
    
    if (!_hasBeenTouched) {
    setState(() {
      _hasBeenTouched = true;
      });
    }
    
    // Trigger validation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Form.of(context).validate();
      }
    });
  }

  void _increaseFee() {
    final currentValue = double.tryParse(widget.controller.text.trim()) ?? 0.0;
    final newValue = currentValue + _stepAmount;
    
    // Round to nearest 250
    final roundedValue = (newValue / _stepAmount).round() * _stepAmount;
    
    widget.controller.value = TextEditingValue(
      text: roundedValue.toStringAsFixed(0),
      selection: TextSelection.collapsed(offset: roundedValue.toStringAsFixed(0).length),
    );
    
    if (!_hasBeenTouched) {
      setState(() {
        _hasBeenTouched = true;
      });
    }
    
    // Trigger validation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Form.of(context).validate();
      }
    });
  }

  bool _isBelowRecommended() {
    if (widget.recommendedFee == null) return false;
    final currentValue = double.tryParse(widget.controller.text.trim());
    if (currentValue == null) return false;
    return currentValue < widget.recommendedFee!;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isBelowRecommended = _isBelowRecommended();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: context.themeTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.isRequired)
              const Text(
                ' *',
                style: TextStyle(color: AppColors.error),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Text field with +/- buttons
        Row(
          children: [
            // Decrease button (-)
            Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _decreaseFee,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 44,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary,
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.remove,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Text field
            Expanded(
              child: TextFormField(
                controller: widget.controller,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: context.themeTextPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
                onTap: () {
                  if (!_hasBeenTouched) {
                    setState(() {
                      _hasBeenTouched = true;
                    });
                  }
                },
          decoration: InputDecoration(
            hintText: loc.deliveryFee,
                  hintStyle: TextStyle(
                    color: context.themeTextSecondary,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.local_shipping, color: context.themeTextSecondary, size: 20),
                  prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Center(
                      widthFactor: 1.0,
                      child: Text(
                        loc.currencySymbol,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: context.themeTextSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  suffixIconConstraints: const BoxConstraints(minWidth: 40),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isBelowRecommended ? AppColors.error : context.themeBorder,
                      width: isBelowRecommended ? 2 : 1,
                    ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isBelowRecommended ? AppColors.error : context.themeBorder,
                      width: isBelowRecommended ? 2 : 1,
                    ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isBelowRecommended ? AppColors.error : AppColors.primary,
                      width: 2,
                    ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            filled: true,
            fillColor: context.themeSurface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: (value) {
            if (widget.validator != null) {
                    return widget.validator!(value);
            }
            
            if (widget.isRequired) {
                    if (value == null || value.trim().isEmpty) {
                if (_hasBeenTouched) {
                  return loc.deliveryFeeRequired;
                }
                return null;
              }
              
                    if (double.tryParse(value) == null) {
                return loc.enterValidNumber;
              }
            }
            
            return null;
          },
        ),
            ),
            const SizedBox(width: 8),
            // Increase button (+)
            Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _increaseFee,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 44,
                  height: 48,
                  decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary,
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 20,
                  ),
              ),
              ),
            ),
          ],
        ),
        // Warning message if below recommended
        if (isBelowRecommended && widget.recommendedFee != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.error.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${loc.lowDeliveryFeeWarning}: ${widget.recommendedFee!.toStringAsFixed(0)} ${loc.currencySymbol}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
