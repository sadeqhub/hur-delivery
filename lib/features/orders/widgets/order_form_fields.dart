import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/services/najaf_districts_service.dart';
import '../../../core/localization/app_localizations.dart';

class OrderFormTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final int maxLines;
  final bool isRequired;
  final String? suffix;
  final String? Function(String?)? validator;

  const OrderFormTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.isRequired = false,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
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
            if (isRequired)
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
          maxLines: maxLines,
          validator: validator,
          style: AppTextStyles.bodyMedium.copyWith(
            color: context.themeTextPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
            prefixIcon: Icon(icon, color: AppColors.primary),
            suffixText: suffix,
            suffixStyle: AppTextStyles.bodyMedium.copyWith(
              color: context.themeTextSecondary,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: context.themeSurfaceVariant,
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}

class OrderSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const OrderSectionHeader({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
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
}

class OrderLocationField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final VoidCallback onMapTap;
  final VoidCallback onGeocode;
  final bool hasLocation;
  final bool isRequired;
  final List<NajafDistrict> suggestions;
  final bool showSuggestions;
  final void Function(NajafDistrict) onSuggestionTap;

  const OrderLocationField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onMapTap,
    required this.onGeocode,
    required this.hasLocation,
    required this.suggestions,
    required this.showSuggestions,
    required this.onSuggestionTap,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
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
            if (isRequired)
              const Text(' *', style: TextStyle(color: AppColors.error)),
          ],
        ),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (hasLocation ? AppColors.success : AppColors.primary)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: hasLocation ? AppColors.success : AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.themeTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        suffixIcon: hasLocation
                            ? const Icon(Icons.check_circle,
                                color: AppColors.success, size: 20)
                            : null,
                      ),
                      onSubmitted: (_) => onGeocode(),
                    ),
                  ),
                  IconButton(
                    onPressed: onMapTap,
                    icon: const Icon(Icons.map, color: AppColors.primary),
                    tooltip: loc.openMap,
                  ),
                  IconButton(
                    onPressed: onGeocode,
                    icon: const Icon(Icons.search, color: AppColors.success),
                    tooltip: loc.searchAddress,
                  ),
                ],
              ),
            ),
            if (showSuggestions && suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: AppColors.border.withOpacity(0.5),
                  ),
                  itemBuilder: (context, index) {
                    final district = suggestions[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on,
                          color: AppColors.primary, size: 20),
                      title: Text(
                        district.name,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      onTap: () => onSuggestionTap(district),
                    );
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }
}
