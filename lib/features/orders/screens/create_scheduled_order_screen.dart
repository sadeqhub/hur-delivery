import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/driver_availability_service.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/services/delivery_fee_calculator.dart';
import '../../../core/data/neighborhoods_data.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/neighborhood_dropdown.dart';
import '../../../shared/widgets/delivery_fee_dropdown.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/navigation_overlay_system.dart';
import '../screens/location_picker_screen.dart';

class CreateScheduledOrderScreen extends StatefulWidget {
  final bool embedded;

  const CreateScheduledOrderScreen({super.key, this.embedded = false});

  @override
  State<CreateScheduledOrderScreen> createState() =>
      _CreateScheduledOrderScreenState();
}

class _CreateScheduledOrderScreenState extends State<CreateScheduledOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Order details
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final FocusNode _customerPhoneFocusNode = FocusNode();
  final _pickupAddressController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  double? _pickupLatitude;
  double? _pickupLongitude;
  double? _deliveryLatitude;
  double? _deliveryLongitude;
  String _selectedVehicleType = 'any'; // Default to any vehicle type
  final _totalAmountController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _notesController = TextEditingController();

  // Scheduling details
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();

  // Phone lookup
  Timer? _phoneDebounce;
  List<String> _phoneSuggestions = [];
  bool _showPhoneSuggestions = false;
  bool _phoneLocked = false;

  // Advanced settings
  bool _showAdvancedSettings = false;
  
  // Selected neighborhood for delivery
  Neighborhood? _selectedNeighborhood;
  
  // Recommended delivery fee based on distance
  double? _recommendedDeliveryFee;

  @override
  void initState() {
    super.initState();
    _loadMerchantLocation();
    _initializePhoneListeners();
  }

  void _initializePhoneListeners() {
    // Phone field behaviors: strip leading zero and fetch suggestions
    _customerPhoneController.addListener(() {
      final text = _customerPhoneController.text;
      if (text.startsWith('0')) {
        final withoutZero = text.replaceFirst(RegExp('^0+'), '');
        if (withoutZero != text) {
          final selectionIndex = _customerPhoneController.selection.baseOffset - (text.length - withoutZero.length);
          _customerPhoneController.value = TextEditingValue(
            text: withoutZero,
            selection: TextSelection.collapsed(offset: selectionIndex.clamp(0, withoutZero.length)),
          );
        }
      }

      // Debounced fetch after 3+ digits
      if (!_phoneLocked && _customerPhoneController.text.replaceAll(RegExp(r'\D'), '').length >= 3 && _customerPhoneFocusNode.hasFocus) {
        _debouncedFetchPhoneSuggestions(_customerPhoneController.text);
      } else {
        setState(() {
          _phoneSuggestions = [];
          _showPhoneSuggestions = false;
        });
      }

      // Lock when valid Iraqi local number (10 digits starting with 7)
      final digits = _customerPhoneController.text.replaceAll(RegExp(r'\D'), '');
      if (digits.length == 10 && digits.startsWith('7')) {
        _phoneLocked = true;
      }
    });

    _customerPhoneFocusNode.addListener(() {
      if (!_customerPhoneFocusNode.hasFocus) {
        setState(() {
          _showPhoneSuggestions = false;
        });
      } else {
        if (!_phoneLocked && _customerPhoneController.text.replaceAll(RegExp(r'\D'), '').length >= 3) {
          _debouncedFetchPhoneSuggestions(_customerPhoneController.text);
        }
      }
    });
  }

  void _debouncedFetchPhoneSuggestions(String input) {
    _phoneDebounce?.cancel();
    _phoneDebounce = Timer(const Duration(milliseconds: 250), () async {
      await _fetchCustomerPhoneSuggestions(input);
    });
  }

  Future<void> _fetchCustomerPhoneSuggestions(String input) async {
    try {
      final auth = context.read<AuthProvider>();
      final merchantId = auth.user?.id;
      if (merchantId == null) return;

      final digits = input.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 3) return;

      // Query distinct customer_phone for this merchant starting with typed digits
      final patterns = <String>[
        '$digits%',
        '+964$digits%',
        '964$digits%',
      ];

      final results = <String>{};
      for (final p in patterns) {
        final rows = await Supabase.instance.client
            .from('orders')
            .select('customer_phone')
            .eq('merchant_id', merchantId)
            .ilike('customer_phone', p)
            .limit(10);
        for (final r in rows) {
          final ph = (r['customer_phone'] ?? '').toString();
          if (ph.isNotEmpty) results.add(ph);
        }
      }

      setState(() {
        _phoneSuggestions = results.take(10).toList();
        _showPhoneSuggestions = _phoneSuggestions.isNotEmpty && _customerPhoneFocusNode.hasFocus;
      });
    } catch (e) {
      // Silently ignore
    }
  }

  Future<void> _loadMerchantLocation() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.user;
      final merchantId = user?.id;

      if (merchantId == null) {
        final loc = AppLocalizations.of(context);
        setState(() {
          _pickupLatitude = 33.3152; // Default Najaf latitude
          _pickupLongitude = 44.3661; // Default Najaf longitude
          _pickupAddressController.text = loc.storeLocation;
        });
        return;
      }

      double? lat;
      double? lng;
      String? address;
      String? storeName;

      // First, try to use cached user data if it has location
      if (user != null && user.latitude != null && user.longitude != null) {
        lat = user.latitude;
        lng = user.longitude;
        address = user.address;
        storeName = user.storeName;
      } else {
        // If cached data doesn't have location, fetch from database
        final merchantData = await Supabase.instance.client
            .from('users')
            .select('latitude, longitude, address, store_name')
            .eq('id', merchantId)
            .single();

        final latValue = merchantData['latitude'];
        final lngValue = merchantData['longitude'];
        if (latValue != null && lngValue != null) {
          lat = double.parse(latValue.toString());
          lng = double.parse(lngValue.toString());
        }
        address = merchantData['address'] as String?;
        storeName = merchantData['store_name'] as String?;
            }

      // Set coordinates
      if (lat != null && lng != null) {
        setState(() {
          _pickupLatitude = lat;
          _pickupLongitude = lng;
        });

        final loc = AppLocalizations.of(context);
        String displayAddress = storeName ?? address ?? loc.storeLocation;

        // If address is missing or is just the placeholder, reverse geocode
        if (address == null || address.isEmpty || address == loc.storeLocation) {
          // Reverse geocode the coordinates to get a real address
          final geocodedAddress = await GeocodingService.reverseGeocode(lat, lng);

          if (geocodedAddress != null && geocodedAddress.isNotEmpty) {
            displayAddress = geocodedAddress;

            // Cache the geocoded address in the database
            try {
              await Supabase.instance.client
                  .from('users')
                  .update({'address': geocodedAddress})
                  .eq('id', merchantId);

              // Refresh the user object to get the updated address
              await authProvider.refreshUser();

              print('✅ Cached geocoded address: $geocodedAddress');
            } catch (e) {
              print('⚠️ Failed to cache address: $e');
              // Continue anyway - we have the address to display
            }
          }
        }

        setState(() {
          _pickupAddressController.text = displayAddress;
        });
        return;
      }

      // Fallback to default location
      final loc = AppLocalizations.of(context);
      setState(() {
        _pickupLatitude = 33.3152;
        _pickupLongitude = 44.3661;
        _pickupAddressController.text = loc.storeLocation;
      });
    } catch (e) {
      print('Error loading merchant location: $e');
      final loc = AppLocalizations.of(context);
      setState(() {
        _pickupLatitude = 33.3152;
        _pickupLongitude = 44.3661;
        _pickupAddressController.text = loc.storeLocation;
      });
    }
  }

  /// Calculate and update delivery fee based on pickup and delivery locations
  void _calculateAndUpdateDeliveryFee() {
    if (_pickupLatitude != null &&
        _pickupLongitude != null &&
        _deliveryLatitude != null &&
        _deliveryLongitude != null) {
      final calculatedFee = DeliveryFeeCalculator.calculateFeeFromCoordinates(
        _pickupLatitude!,
        _pickupLongitude!,
        _deliveryLatitude!,
        _deliveryLongitude!,
      );
      
      // Store recommended fee
      setState(() {
        _recommendedDeliveryFee = calculatedFee;
      });
      
      // Update the delivery fee controller
      _deliveryFeeController.text = calculatedFee.toStringAsFixed(0);
      
      print('💰 Calculated delivery fee: $calculatedFee IQD');
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerPhoneFocusNode.dispose();
    _pickupAddressController.dispose();
    _deliveryAddressController.dispose();
    _totalAmountController.dispose();
    _deliveryFeeController.dispose();
    _notesController.dispose();
    _phoneDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final headerGradient = LinearGradient(
      colors: [cs.primary, cs.primaryContainer],
    );

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(AppLocalizations.of(context).scheduledOrder),
              centerTitle: true,
            ),
      body: NavigationOverlayScope(
        child: Builder(
          builder: (context) {
            final controller = NavigationOverlayScope.of(context);
            final bottomInset = controller?.bottomInset ?? MediaQuery.of(context).viewPadding.bottom;
            
            return Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.disabled,
              child: ListView(
                padding: EdgeInsets.only(
                  left: MediaQuery.sizeOf(context).width * 0.04,
                  right: MediaQuery.sizeOf(context).width * 0.04,
                  top: MediaQuery.sizeOf(context).width * 0.04,
                  bottom: MediaQuery.sizeOf(context).width * 0.04 + bottomInset,
                ),
                children: [
            // Header
            Container(
              padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.04),
              decoration: BoxDecoration(
                gradient: headerGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.schedule, size: 48, color: cs.onPrimary),
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.01),
                  Text(
                    AppLocalizations.of(context).scheduleOrderLater,
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            SizedBox(height: MediaQuery.sizeOf(context).height * 0.03),

            // Schedule Day and Time Section
            Builder(
              builder: (context) {
                final loc = AppLocalizations.of(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(loc.dateTime),
                    SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),

                    // Date Picker
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() => _selectedDate = date);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: loc.date,
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: const OutlineInputBorder(),
                        ),
                        child: Text(
                          DateFormat('yyyy-MM-dd', 'ar').format(_selectedDate),
                          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
                        ),
                      ),
                    ),

                    SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),

                    // Time Picker
                    InkWell(
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                        );
                        if (time != null) {
                          setState(() => _selectedTime = time);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: loc.time,
                          prefixIcon: const Icon(Icons.access_time),
                          border: const OutlineInputBorder(),
                        ),
                        child: Text(
                          _selectedTime.format(context),
                          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
                        ),
                      ),
                    ),

                    SizedBox(height: MediaQuery.sizeOf(context).height * 0.03),

                    // Customer Phone Number (with lookup)
                    _buildPhoneField(),
                    if (_showPhoneSuggestions && _phoneSuggestions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.themeSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.themeBorder),
                            boxShadow: [
                              BoxShadow(
                                color: context.themeColor(
                                  light: Colors.black.withOpacity(0.05),
                                  dark: Colors.black.withOpacity(0.25),
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _phoneSuggestions.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: context.themeBorder.withOpacity(0.7),
                            ),
                            itemBuilder: (context, index) {
                              final suggestion = _phoneSuggestions[index];
                              return ListTile(
                                dense: true,
                                leading: Icon(Icons.history, color: context.themeTextSecondary, size: 18),
                                title: Text(
                                  suggestion,
                                  style: AppTextStyles.bodyMedium.copyWith(color: context.themeTextPrimary),
                                ),
                                onTap: () {
                                  final normalized = suggestion.replaceFirst(RegExp(r'^\+?964'), '');
                                  _customerPhoneController.text = normalized;
                                  _customerPhoneController.selection = TextSelection.collapsed(offset: _customerPhoneController.text.length);
                                  final digits = normalized.replaceAll(RegExp(r'\D'), '');
                                  if (digits.length == 10 && digits.startsWith('7')) {
                                    _phoneLocked = true;
                                    _customerPhoneFocusNode.unfocus();
                                  }
                                  setState(() => _showPhoneSuggestions = false);
                                },
                              );
                            },
                          ),
                        ),
                      ),

                    SizedBox(height: MediaQuery.sizeOf(context).height * 0.03),

                    // Delivery Address - Neighborhood Dropdown
                    NeighborhoodDropdown(
                      selectedNeighborhood: _selectedNeighborhood,
                      onChanged: (Neighborhood? neighborhood) {
                        setState(() {
                          _selectedNeighborhood = neighborhood;
                          if (neighborhood != null) {
                            _deliveryAddressController.text = neighborhood.name;
                            _deliveryLatitude = neighborhood.latitude;
                            _deliveryLongitude = neighborhood.longitude;
                          } else {
                            _deliveryAddressController.clear();
                            _deliveryLatitude = null;
                            _deliveryLongitude = null;
                          }
                        });
                        // Calculate delivery fee when neighborhood is selected
                        _calculateAndUpdateDeliveryFee();
                      },
                      label: loc.deliveryLocation,
                      hint: loc.deliveryLocationHint,
                      isRequired: true,
                      storeLatitude: _pickupLatitude,
                      storeLongitude: _pickupLongitude,
                      onLocationPickerTap: () async {
                        final result = await Navigator.push<Map<String, dynamic>>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LocationPickerScreen(
                              title: loc.deliveryLocation,
                              initialLatitude: _deliveryLatitude,
                              initialLongitude: _deliveryLongitude,
                            ),
                          ),
                        );

                        if (result != null) {
                          setState(() {
                            _deliveryAddressController.text = result['address'] ?? '';
                            _deliveryLatitude = result['latitude'];
                            _deliveryLongitude = result['longitude'];
                            // Clear neighborhood selection when using location picker
                            _selectedNeighborhood = null;
                          });
                          // Recalculate delivery fee when location is picked
                          _calculateAndUpdateDeliveryFee();
                        }
                      },
                    ),

                    SizedBox(height: MediaQuery.sizeOf(context).height * 0.03),

                    // Order Fee and Delivery Fee (side by side)
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _totalAmountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: loc.totalAmountIqd,
                              prefixIcon: const Icon(Icons.attach_money),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.isEmpty ? loc.required : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: DeliveryFeeDropdown(
                            controller: _deliveryFeeController,
                            label: loc.deliveryFeeIqd,
                            isRequired: true,
                            recommendedFee: _recommendedDeliveryFee,
                            validator: (v) => v == null || v.isEmpty ? loc.required : null,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: MediaQuery.sizeOf(context).height * 0.03),

                    // Advanced Settings (Expandable)
                    Container(
                      decoration: BoxDecoration(
                        color: context.themeSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.themeBorder),
                      ),
                      child: ExpansionTile(
                        title: Row(
                          children: [
                            Icon(
                              Icons.settings_outlined,
                              color: context.themePrimary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              loc.advancedSettings,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: context.themeTextPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        initiallyExpanded: false,
                        onExpansionChanged: (expanded) {
                          setState(() {
                            _showAdvancedSettings = expanded;
                          });
                        },
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Customer Name (Optional)
                                TextFormField(
                                  controller: _customerNameController,
                                  decoration: InputDecoration(
                                    labelText: loc.customerNameOptional,
                                    prefixIcon: const Icon(Icons.person),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),

                                SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),

                                // Pickup Address (defaults to store location)
                                _buildLocationField(
                                  label: loc.pickupLocation,
                                  controller: _pickupAddressController,
                                  latitude: _pickupLatitude,
                                  longitude: _pickupLongitude,
                                  onLocationSelected: (address, lat, lng) {
                                    setState(() {
                                      _pickupAddressController.text = address;
                                      _pickupLatitude = lat;
                                      _pickupLongitude = lng;
                                    });
                                  },
                                ),

                                SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),

                                // Vehicle Type
                                _buildVehicleTypeSelector(),

                                SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),

                                // Notes
                                TextFormField(
                                  controller: _notesController,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    labelText: loc.notesOptional,
                                    prefixIcon: const Icon(Icons.note),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: MediaQuery.sizeOf(context).height * 0.03),

                    // Submit Button
                    PrimaryButton(
                      text: loc.scheduleOrder,
                      onPressed: _submitScheduledOrder,
                      isLoading: _isLoading,
                    ),
                  ],
                );
              },
            ),
          ],
            ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: context.themeTextPrimary,
      ),
    );
  }

  Widget _buildPhoneField() {
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
                const Text(' *', style: TextStyle(color: AppColors.error)),
              ],
            ),
            const SizedBox(height: 8),
            Directionality(
              textDirection: ui.TextDirection.ltr,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Country code prefix
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Phone input field
                  Expanded(
                    child: TextFormField(
                      controller: _customerPhoneController,
                      focusNode: _customerPhoneFocusNode,
                      keyboardType: TextInputType.phone,
                      maxLines: 1,
                      validator: (value) {
                        // Phone is now optional, but if provided, must be valid
                        if (value != null && value.trim().isNotEmpty) {
                        final digits = value.replaceAll(RegExp(r'\D'), '');
                        if (!(digits.length == 10 && digits.startsWith('7'))) {
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
                        prefixIcon: const Icon(Icons.phone, color: AppColors.primary),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      onTap: () {
                        if (!_phoneLocked && _customerPhoneController.text.replaceAll(RegExp(r'\D'), '').length >= 3) {
                          _debouncedFetchPhoneSuggestions(_customerPhoneController.text);
                          setState(() {
                            _showPhoneSuggestions = true;
                          });
                        }
                      },
                      onChanged: (val) {
                        if (!_phoneLocked && val.replaceAll(RegExp(r'\D'), '').length >= 3) {
                          setState(() {
                            _showPhoneSuggestions = true;
                          });
                        } else {
                          setState(() {
                            _showPhoneSuggestions = false;
                          });
                        }
                      },
                      onFieldSubmitted: (_) {
                        final digits = _customerPhoneController.text.replaceAll(RegExp(r'\D'), '');
                        if (digits.length == 10 && digits.startsWith('7')) {
                          _phoneLocked = true;
                          _customerPhoneFocusNode.unfocus();
                          setState(() => _showPhoneSuggestions = false);
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

  Widget _buildLocationField({
    required String label,
    required TextEditingController controller,
    required double? latitude,
    required double? longitude,
    required Function(String, double, double) onLocationSelected,
  }) {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (context) => LocationPickerScreen(
              title: label,
              initialLatitude: latitude,
              initialLongitude: longitude,
            ),
          ),
        );

        if (result != null) {
          onLocationSelected(
            result['address'],
            result['latitude'],
            result['longitude'],
          );
        }
      },
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.location_on),
            suffixIcon: const Icon(Icons.map),
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return AppLocalizations.of(context).pleaseSelect(label);
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildVehicleTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (context) {
            final loc = AppLocalizations.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.vehicleTypeLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildVehicleOption(
                        'any', Icons.widgets_outlined, loc.anyVehicle),
                    const SizedBox(width: 8),
                    _buildVehicleOption(
                        'motorcycle', Icons.two_wheeler, loc.motorbike),
                    const SizedBox(width: 8),
                    _buildVehicleOption('car', Icons.directions_car, loc.car),
                    const SizedBox(width: 8),
                    _buildVehicleOption('truck', Icons.local_shipping, loc.truck),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildVehicleOption(String type, IconData icon, String label) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isSelected = _selectedVehicleType == type;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedVehicleType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? cs.primaryContainer : cs.surface,
            border: Border.all(
              color: isSelected ? cs.primary : cs.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: isSelected ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitScheduledOrder() async {
    if (!_formKey.currentState!.validate()) return;
    final loc = AppLocalizations.of(context);
    
    // Prevent order posting in demo mode
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن نشر الطلبات في وضع التجربة. يمكنك استكشاف شاشات إنشاء الطلبات ولكن لا يمكنك إرسالها.'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_pickupLatitude == null || _pickupLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.pleaseSelectPickupLocation)),
      );
      return;
    }
    if (_deliveryLatitude == null || _deliveryLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.pleaseSelectDeliveryLocation)),
      );
      return;
    }

    final merchantId = Supabase.instance.client.auth.currentUser?.id;
    if (merchantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.merchantDataErrorLoginAgain),
        ),
      );
      return;
    }

    final availabilityResult = await DriverAvailabilityService.checkAvailability(
      merchantId: merchantId,
      vehicleType: _selectedVehicleType,
    );

    if (!availabilityResult.available) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.info_outline, color: cs.primary),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context).alert),
              ],
            ),
            content: Builder(
              builder: (context) {
                final loc = AppLocalizations.of(context);
                return Text(
                  '${availabilityResult.userMessage(context)}\n\n${loc.canContinueScheduledOrder}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppLocalizations.of(context).cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                ),
                child: Text(AppLocalizations.of(context).continueText),
              ),
            ],
          );
        },
      );
      if (proceed != true) return;
    }

    setState(() => _isLoading = true);

    try {
      final merchantId = context.read<AuthProvider>().user!.id;

      // Format phone number with +964 prefix
      final phoneDigits = _customerPhoneController.text.replaceAll(RegExp(r'\D'), '');
      final customerPhone = '+964$phoneDigits';

      // Combine date and time
      final scheduledDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );

      // Normalize vehicle type (motorcycle -> motorbike)
      String vehicleType = _selectedVehicleType;
      if (vehicleType == 'motorcycle') {
        vehicleType = 'motorbike';
      }

      await Supabase.instance.client.from('scheduled_orders').insert({
        'merchant_id': merchantId,
        'customer_name': _customerNameController.text.trim().isNotEmpty 
            ? _customerNameController.text.trim() 
            : loc.customerNameFallback,
        'customer_phone': customerPhone,
        'pickup_address': _pickupAddressController.text,
        'delivery_address': _deliveryAddressController.text,
        'pickup_latitude': _pickupLatitude,
        'pickup_longitude': _pickupLongitude,
        'delivery_latitude': _deliveryLatitude,
        'delivery_longitude': _deliveryLongitude,
        'vehicle_type': vehicleType,
        'total_amount': double.parse(_totalAmountController.text),
        'delivery_fee': double.parse(_deliveryFeeController.text),
        'notes': _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        'scheduled_date': scheduledDate.toIso8601String().split('T')[0],
        'scheduled_time':
            '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}:00',
        'status': 'scheduled',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).orderScheduledSuccess),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
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
}
