
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/najaf_districts_service.dart';

/// Mixin that provides the reusable form-field builder methods for
/// [CreateOrderScreen] (and the corresponding scheduled / voice variants).
///
/// Extracted from `create_order_screen.dart` as part of P2.4.
///
/// The mixin requires access to the following host State members:
/// - State fields: [_pickupAddressFocusNode], [_deliveryAddressFocusNode],
///   [_showPickupSuggestions], [_showDeliverySuggestions],
///   [_pickupAddressSuggestions], [_deliveryAddressSuggestions],
///   [_customerPhoneController], [_customerPhoneFocusNode],
///   [_phoneLocked], [_showPhoneSuggestions]
/// - Methods: [_geocodeAddress], [_selectDistrict],
///   [_debouncedFetchPhoneSuggestions]
/// - `setState()`, `context`, `mounted` — available from [State<T>] base class.
mixin OrderFormBuilderMixin<T extends StatefulWidget> on State<T> {
  // ─── Abstract surface area ───────────────────────────────────────────────
  // Implementing classes must expose these fields/methods.

  FocusNode get pickupAddressFocusNode;
  FocusNode get deliveryAddressFocusNode;

  bool get showPickupSuggestions;
  bool get showDeliverySuggestions;

  List<NajafDistrict> get pickupAddressSuggestions;
  List<NajafDistrict> get deliveryAddressSuggestions;

  TextEditingController get customerPhoneController;
  FocusNode get customerPhoneFocusNode;

  bool get phoneLocked;
  bool get showPhoneSuggestions;
  set showPhoneSuggestions(bool value);

  void geocodeAddress(String type);
  void selectDistrict(NajafDistrict district, String type);
  void debouncedFetchPhoneSuggestions(String input);

  // ─── Section header ───────────────────────────────────────────────────────

  /// Renders a titled section header with an icon badge.
  Widget buildSectionHeader(String title, IconData icon) {
    return Builder(
      builder: (context) {
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
      },
    );
  }

  // ─── Generic text field ───────────────────────────────────────────────────

  /// Renders a labelled [TextFormField] with the project's standard styling.
  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isRequired = false,
    String? suffix,
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

  // ─── Phone field ─────────────────────────────────────────────────────────

  /// Renders the customer phone field with IQ country code prefix,
  /// autocomplete suggestions, and Iraqi format validation.
  Widget buildPhoneField() {
    return Builder(
      builder: (context) {
        final loc = AppLocalizations.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  loc.customerPhoneLabel,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.themeTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  ' (${loc.optional})',
                  style: TextStyle(
                    color: context.themeTextSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Country code prefix
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      color: context.themeSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.themeBorder),
                    ),
                    child: Text(
                      '+964',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.themeTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Phone input field
                  Expanded(
                    child: TextFormField(
                      controller: customerPhoneController,
                      focusNode: customerPhoneFocusNode,
                      keyboardType: TextInputType.phone,
                      maxLines: 1,
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final digits = value.replaceAll(RegExp(r'\D'), '');
                          if (!(digits.length == 10 &&
                              digits.startsWith('7'))) {
                            return loc.phoneInvalidFormat;
                          }
                        }
                        return null;
                      },
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.themeTextPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      decoration: InputDecoration(
                        hintText: '7XX XXX XXXX',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: context.themeTextTertiary,
                        ),
                        prefixIcon:
                            const Icon(Icons.phone, color: AppColors.primary),
                        filled: true,
                        fillColor: context.themeSurfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: context.themeBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: context.themeBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.error),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                      onTap: () {
                        if (!phoneLocked &&
                            customerPhoneController.text
                                    .replaceAll(RegExp(r'\D'), '')
                                    .length >=
                                3) {
                          debouncedFetchPhoneSuggestions(
                              customerPhoneController.text);
                          setState(() => showPhoneSuggestions = true);
                        }
                      },
                      onChanged: (val) {
                        if (!phoneLocked &&
                            val.replaceAll(RegExp(r'\D'), '').length >= 3) {
                          setState(() => showPhoneSuggestions = true);
                        } else {
                          setState(() => showPhoneSuggestions = false);
                        }
                      },
                      onFieldSubmitted: (_) {
                        final digits = customerPhoneController.text
                            .replaceAll(RegExp(r'\D'), '');
                        if (digits.length == 10 && digits.startsWith('7')) {
                          setState(() {
                            showPhoneSuggestions = false;
                          });
                          customerPhoneFocusNode.unfocus();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Location field ───────────────────────────────────────────────────────

  /// Renders a location input field with map picker, geocode search,
  /// and address autocomplete suggestions.
  Widget buildLocationField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required VoidCallback onTap,
    required bool hasLocation,
    required String type,
    bool isRequired = false,
  }) {
    final focusNode = type == 'pickup'
        ? pickupAddressFocusNode
        : deliveryAddressFocusNode;
    final showSuggestions = type == 'pickup'
        ? showPickupSuggestions
        : showDeliverySuggestions;
    final suggestions = type == 'pickup'
        ? pickupAddressSuggestions
        : deliveryAddressSuggestions;

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
                  // Icon
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (hasLocation
                                ? AppColors.success
                                : AppColors.primary)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: hasLocation
                            ? AppColors.success
                            : AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  // Text Field
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
                      onSubmitted: (_) => geocodeAddress(type),
                    ),
                  ),
                  // Map Button
                  Builder(builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return IconButton(
                      onPressed: onTap,
                      icon: const Icon(Icons.map, color: AppColors.primary),
                      tooltip: loc.openMap,
                    );
                  }),
                  // Geocode Button
                  Builder(builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return IconButton(
                      onPressed: () => geocodeAddress(type),
                      icon:
                          const Icon(Icons.search, color: AppColors.success),
                      tooltip: loc.searchAddress,
                    );
                  }),
                ],
              ),
            ),
            // Suggestions dropdown
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
                  separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: AppColors.border.withOpacity(0.5)),
                  itemBuilder: (context, index) {
                    final district = suggestions[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on,
                          color: AppColors.primary, size: 20),
                      title: Text(
                        district.name,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () => selectDistrict(district, type),
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
