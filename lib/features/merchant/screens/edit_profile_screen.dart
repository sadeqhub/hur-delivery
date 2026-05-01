import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/localization/app_localizations.dart';
import '../../orders/screens/location_picker_screen.dart';
import '../../../core/constants/app_constants.dart';

class MerchantEditProfileScreen extends StatefulWidget {
  const MerchantEditProfileScreen({super.key});

  @override
  State<MerchantEditProfileScreen> createState() => _MerchantEditProfileScreenState();
}

class _MerchantEditProfileScreenState extends State<MerchantEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _storeNameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _storeNameController = TextEditingController(text: user?.storeName ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
    _latitude = user?.latitude;
    _longitude = user?.longitude;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _storeNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = context.read<AuthProvider>().user;
      if (user == null) throw Exception('User not found');

      await Supabase.instance.client.from('users').update({
        'name': _nameController.text.trim(),
        'store_name': _storeNameController.text.trim(),
        'address': _addressController.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
      }).eq('id', user.id);

      // Refresh user data
      await context.read<AuthProvider>().refreshUser();

      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.profileUpdatedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.errorOccurred(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickLocationOnMap() async {
    final loc = AppLocalizations.of(context);
    
    // Use current location or default if missing
    final double initialLat = _latitude ?? AppConstants.defaultLatitude;
    final double initialLng = _longitude ?? AppConstants.defaultLongitude;
    
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLatitude: initialLat,
          initialLongitude: initialLng,
          title: loc.pickStoreLocation,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitude = result['latitude'];
        _longitude = result['longitude'];
        if (result['address'] != null && (result['address'] as String).isNotEmpty) {
          _addressController.text = result['address'];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).editProfile),
        centerTitle: true,
        backgroundColor: context.themePrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewPadding.bottom),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile Picture
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: const Icon(
                        Icons.person,
                        size: 60,
                        color: AppColors.primary,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                          onPressed: () {
                            // TODO: Implement image picker
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLocalizations.of(context).featureComingSoon),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),

              // Name Field
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(color: context.themeTextPrimary),
                        decoration: InputDecoration(
                          labelText: loc.name,
                          prefixIcon: Icon(Icons.person_outline, color: context.themeTextSecondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: context.themeSurfaceVariant,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return loc.nameRequired;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Store Name Field
                      TextFormField(
                        controller: _storeNameController,
                        style: TextStyle(color: context.themeTextPrimary),
                        decoration: InputDecoration(
                          labelText: loc.storeName,
                          prefixIcon: Icon(Icons.store_outlined, color: context.themeTextSecondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: context.themeSurfaceVariant,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return loc.storeNameRequired;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Phone Field (Read-only)
                      TextFormField(
                        controller: _phoneController,
                        style: TextStyle(color: context.themeTextTertiary),
                        decoration: InputDecoration(
                          labelText: loc.phoneNumberLabel,
                          prefixIcon: Icon(Icons.phone_outlined, color: context.themeTextTertiary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: context.themeSurfaceVariant.withOpacity(0.5),
                          enabled: false,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Address Field with Map Picker
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _addressController,
                            maxLines: 3,
                            style: TextStyle(color: context.themeTextPrimary),
                            decoration: InputDecoration(
                              labelText: loc.address,
                              prefixIcon: Icon(Icons.location_on_outlined, color: context.themeTextSecondary),
                              suffixIcon: IconButton(
                                icon: Icon(Icons.map_outlined, color: context.themePrimary),
                                onPressed: _pickLocationOnMap,
                                tooltip: loc.pickOnMap,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: context.themeSurfaceVariant,
                              alignLabelWithHint: true,
                              hintText: loc.storeLocationPlaceholder, 
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return loc.addressRequired;
                              }
                              return null;
                            },
                          ),
                          if (_latitude != null && _longitude != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0, left: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                                  const SizedBox(width: 4),
                                  Text(
                                    loc.locationSavedOnMap,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          text: loc.saveChanges,
                          onPressed: _isLoading ? null : _saveProfile,
                          isLoading: _isLoading,
                        ),
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
}

