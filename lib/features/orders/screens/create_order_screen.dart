import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/header_notification.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/services/driver_availability_service.dart';
import '../../../core/services/najaf_districts_service.dart';
import '../../../core/services/delivery_fee_calculator.dart';
import '../../../core/data/neighborhoods_data.dart';
import '../../../shared/widgets/neighborhood_dropdown.dart';
import '../../../shared/widgets/delivery_fee_dropdown.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/navigation_overlay_system.dart';
import 'location_picker_screen.dart';

class CreateOrderScreen extends StatefulWidget {
  final bool embedded;
  final Map<String, dynamic>? initialData;
  
  const CreateOrderScreen({
    super.key, 
    this.embedded = false,
    this.initialData,
  });

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final FocusNode _customerPhoneFocusNode = FocusNode();
  final _pickupAddressController = TextEditingController();
  final FocusNode _pickupAddressFocusNode = FocusNode();
  final _deliveryAddressController = TextEditingController();
  final FocusNode _deliveryAddressFocusNode = FocusNode();
  final _totalAmountController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _notesController = TextEditingController();
  
  double? _pickupLatitude;
  double? _pickupLongitude;
  double? _deliveryLatitude;
  double? _deliveryLongitude;
  
  bool _isLoading = false;
  int _onlineDriversCount = 0;
  bool _checkingDrivers = true;
  RealtimeChannel? _driversChannel;
  Timer? _refreshTimer;
  Timer? _phoneDebounce;
  List<String> _phoneSuggestions = [];
  bool _showPhoneSuggestions = false;
  Timer? _addressDebounce;
  List<NajafDistrict> _pickupAddressSuggestions = [];
  List<NajafDistrict> _deliveryAddressSuggestions = [];
  bool _showPickupSuggestions = false;
  bool _showDeliverySuggestions = false;
  bool _phoneLocked = false;
  
  // Scheduling slider
  double _scheduledMinutes = 0; // 0 = now, 10, 20, 30, 40, 50, 60
  
  // Vehicle type selection
  String _selectedVehicleType = 'any'; // Default to any vehicle type

  // Advanced settings expansion
  bool _showAdvancedSettings = false;
  
  // Selected neighborhood for delivery
  Neighborhood? _selectedNeighborhood;
  
  // Recommended delivery fee based on distance
  double? _recommendedDeliveryFee;

  // ValueNotifiers for fields that drive the cost summary — avoids full setState rebuilds
  late final ValueNotifier<String> _totalAmountNotifier;
  late final ValueNotifier<String> _deliveryFeeNotifier;

  // Option to assign to same driver as active order
  bool _assignToSameDriver = false;
  String? _activeOrderDriverId;
  String? _activeOrderDriverName;
  // Support multiple drivers if merchant has multiple active orders
  List<Map<String, String>> _availableDrivers = []; // List of {id, name}

  @override
  void initState() {
    super.initState();
    
    // Pre-fill form if initialData is provided (e.g., from voice order)
    if (widget.initialData != null) {
      _prefillFormFromVoiceData(widget.initialData!);
    }
    
    // Check credit limit immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
        final loc = AppLocalizations.of(context);
      final walletProvider = context.read<WalletProvider>();
      if (walletProvider.balance <= walletProvider.creditLimit) {
        // Redirect back and show message
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.insufficientBalanceCreate),
            backgroundColor: AppColors.error,
              duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
      
      // Show info about voice-filled data
      if (widget.initialData != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.formFilledFromVoice),
            backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
          ),
        );
      }
    });
    
    _loadMerchantLocation();
    _checkOnlineDrivers();
    _checkActiveOrderForSameDriver();
    _subscribeToDriverUpdates();
    _startPeriodicRefresh();

    // ValueNotifiers mirror the text controllers — only the summary widget
    // subscribes to these, so keystrokes no longer rebuild the entire form.
    _totalAmountNotifier = ValueNotifier(_totalAmountController.text);
    _deliveryFeeNotifier = ValueNotifier(_deliveryFeeController.text);
    _totalAmountController.addListener(
        () => _totalAmountNotifier.value = _totalAmountController.text);
    _deliveryFeeController.addListener(
        () => _deliveryFeeNotifier.value = _deliveryFeeController.text);

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
    
    // Initialize address suggestions
    _initializeAddressListeners();
    NajafDistrictsService.loadDistricts();
  }
  
  /// Helper method to find neighborhood with improved matching
  Neighborhood? _findNeighborhoodByName(String name) {
    if (name.isEmpty) return null;
    
    final normalizedName = name.trim();
    final allNeighborhoods = NeighborhoodsData.getAll();
    
    // 1. Try exact match first
    try {
      return allNeighborhoods.firstWhere((n) => n.name == normalizedName);
    } catch (e) {
      // Continue to fuzzy matching
    }
    
    // 2. Normalize the search name (remove common prefixes/suffixes)
    String searchName = normalizedName
        .replaceAll('، النجف', '')
        .replaceAll(', النجف', '')
        .replaceAll('النجف', '')
        .trim();
    
    // Remove "حي" prefix if present (but keep it for neighborhoods that start with it)
    if (searchName.startsWith('حي ')) {
      // Try with "حي" prefix
      try {
        return allNeighborhoods.firstWhere((n) => n.name == searchName);
      } catch (e) {
        // Try without "حي" prefix
        searchName = searchName.substring(3).trim();
      }
    }
    
    // 3. Try exact match with normalized name
    try {
      return allNeighborhoods.firstWhere((n) => n.name == searchName);
    } catch (e) {
      // Continue to partial matching
    }
    
    // 4. Try partial matching - check if neighborhood name contains search term or vice versa
    for (final neighborhood in allNeighborhoods) {
      final nName = neighborhood.name.trim();
      if (nName == searchName || 
          nName.contains(searchName) || 
          searchName.contains(nName) ||
          nName.replaceAll('حي ', '').trim() == searchName ||
          searchName.replaceAll('حي ', '').trim() == nName.replaceAll('حي ', '').trim()) {
        return neighborhood;
      }
    }
    
    // 5. Try case-insensitive partial matching (for Arabic, this is less relevant but still useful)
    final searchLower = searchName.toLowerCase();
    for (final neighborhood in allNeighborhoods) {
      final nNameLower = neighborhood.name.toLowerCase();
      if (nNameLower.contains(searchLower) || searchLower.contains(nNameLower)) {
        return neighborhood;
      }
    }
    
    return null;
  }
  
  void _prefillFormFromVoiceData(Map<String, dynamic> data) {
    print('📝 Pre-filling form from voice data: $data');
    
    if (data['customer_name'] != null) {
      _customerNameController.text = data['customer_name'];
    }
    if (data['customer_phone'] != null) {
      // Normalize phone number: if 11 digits starting with 0, remove the leading zero
      String phone = data['customer_phone'].toString();
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      if (digits.length == 11 && digits.startsWith('0')) {
        phone = digits.substring(1);
        print('📞 Normalized phone number: removed leading zero');
      }
      _customerPhoneController.text = phone;
    }
    
    // Prioritize neighborhood field if provided (from voice transcription)
    if (data['neighborhood'] != null) {
      final neighborhoodName = data['neighborhood'].toString();
      print('🏘️ Looking for neighborhood: $neighborhoodName');
      final neighborhood = _findNeighborhoodByName(neighborhoodName);
      if (neighborhood != null) {
        print('✅ Found neighborhood: ${neighborhood.name}');
        setState(() {
          _selectedNeighborhood = neighborhood;
          _deliveryAddressController.text = neighborhood.name;
          _deliveryLatitude = neighborhood.latitude;
          _deliveryLongitude = neighborhood.longitude;
        });
      } else {
        print('❌ Neighborhood not found: $neighborhoodName');
      }
    }
    
    // If neighborhood not set yet, try to detect from delivery address
    if (_selectedNeighborhood == null && data['delivery_address'] != null) {
      _deliveryAddressController.text = data['delivery_address'];
      
      // Try to detect neighborhood from delivery address
      final deliveryAddress = data['delivery_address'].toString();
      final detectedNeighborhood = _findNeighborhoodByName(deliveryAddress);
      if (detectedNeighborhood != null) {
        setState(() {
          _selectedNeighborhood = detectedNeighborhood;
          _deliveryLatitude = detectedNeighborhood.latitude;
          _deliveryLongitude = detectedNeighborhood.longitude;
        });
      }
      
      // If neighborhood still not found, try geocoding
      if (_selectedNeighborhood == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _geocodeAddress('delivery');
        });
      }
    }
    if (data['delivery_fee'] != null) {
      _deliveryFeeController.text = data['delivery_fee'].toString();
    }
    if (data['grand_total'] != null) {
      _totalAmountController.text = data['grand_total'].toString();
    }
    if (data['notes'] != null) {
      _notesController.text = data['notes'];
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _driversChannel?.unsubscribe();
    _phoneDebounce?.cancel();
    _addressDebounce?.cancel();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerPhoneFocusNode.dispose();
    _pickupAddressController.dispose();
    _pickupAddressFocusNode.dispose();
    _deliveryAddressController.dispose();
    _deliveryAddressFocusNode.dispose();
    _totalAmountController.dispose();
    _deliveryFeeController.dispose();
    _notesController.dispose();
    _totalAmountNotifier.dispose();
    _deliveryFeeNotifier.dispose();
    super.dispose();
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

      // Query distinct customer_phone for this merchant starting with typed digits (ignoring +964 if present)
      // Normalize search by allowing both with and without +964
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

  void _initializeAddressListeners() {
    // Pickup address listener
    _pickupAddressController.addListener(() {
      if (_pickupAddressFocusNode.hasFocus) {
        _debouncedFetchAddressSuggestions('pickup');
      }
    });

    _pickupAddressFocusNode.addListener(() {
      if (!_pickupAddressFocusNode.hasFocus) {
        setState(() {
          _showPickupSuggestions = false;
        });
      } else if (_pickupAddressController.text.isNotEmpty) {
        _debouncedFetchAddressSuggestions('pickup');
      }
    });

    // Delivery address listener
    _deliveryAddressController.addListener(() {
      if (_deliveryAddressFocusNode.hasFocus) {
        _debouncedFetchAddressSuggestions('delivery');
      }
    });

    _deliveryAddressFocusNode.addListener(() {
      if (!_deliveryAddressFocusNode.hasFocus) {
        setState(() {
          _showDeliverySuggestions = false;
        });
      } else if (_deliveryAddressController.text.isNotEmpty) {
        _debouncedFetchAddressSuggestions('delivery');
      }
    });
  }

  void _debouncedFetchAddressSuggestions(String type) {
    _addressDebounce?.cancel();
    _addressDebounce = Timer(const Duration(milliseconds: 300), () async {
      await _fetchAddressSuggestions(type);
    });
  }

  Future<void> _fetchAddressSuggestions(String type) async {
    final controller = type == 'pickup' ? _pickupAddressController : _deliveryAddressController;
    final query = controller.text.trim();

    if (query.isEmpty) {
      setState(() {
        if (type == 'pickup') {
          _pickupAddressSuggestions = [];
          _showPickupSuggestions = false;
        } else {
          _deliveryAddressSuggestions = [];
          _showDeliverySuggestions = false;
        }
      });
      return;
    }

    try {
      final suggestions = await NajafDistrictsService.searchDistricts(query);

      if (mounted) {
        setState(() {
          if (type == 'pickup') {
            _pickupAddressSuggestions = suggestions.take(8).toList();
            _showPickupSuggestions = _pickupAddressSuggestions.isNotEmpty && _pickupAddressFocusNode.hasFocus;
          } else {
            _deliveryAddressSuggestions = suggestions.take(8).toList();
            _showDeliverySuggestions = _deliveryAddressSuggestions.isNotEmpty && _deliveryAddressFocusNode.hasFocus;
          }
        });
      }
    } catch (e) {
      print('Error fetching address suggestions: $e');
    }
  }

  void _selectDistrict(NajafDistrict district, String type) {
    setState(() {
      if (type == 'pickup') {
        _pickupAddressController.text = district.name;
        _pickupLatitude = district.latitude;
        _pickupLongitude = district.longitude;
        _showPickupSuggestions = false;
        _pickupAddressFocusNode.unfocus();
      } else {
        _deliveryAddressController.text = district.name;
        _deliveryLatitude = district.latitude;
        _deliveryLongitude = district.longitude;
        _showDeliverySuggestions = false;
        _deliveryAddressFocusNode.unfocus();
      }
    });
    // Recalculate delivery fee when location changes
    _calculateAndUpdateDeliveryFee();
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

  Future<void> _loadMerchantLocation() async {
    try {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
      final merchantId = user?.id;
      
      if (merchantId == null) {
        // No merchant ID, use defaults
        final loc = AppLocalizations.of(context);
        setState(() {
          _pickupLatitude = AppConstants.defaultLatitude;
          _pickupLongitude = AppConstants.defaultLongitude;
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
      
      if (lat != null && lng != null) {
      setState(() {
          _pickupLatitude = lat;
          _pickupLongitude = lng;
        });
        
        final loc = AppLocalizations.of(context);
        String displayAddress;
        
        // PRIORITIZE STORE NAME
        // If we have a store name, use it as the pickup address.
        // The lat/long will still be used for routing.
        if (storeName != null && storeName.isNotEmpty) {
          displayAddress = storeName;
          print('✅ Using Store Name as pickup address: $displayAddress');
        } else {
          // Fallback logic
          final storeLocationText = loc.storeLocation;
          final needsGeocoding = address == null || 
                                 address.isEmpty || 
                                 address.trim().isEmpty ||
                                 address == storeLocationText ||
                                 address.toLowerCase().contains('store location') ||
                                 address.toLowerCase().contains('موقع المتجر');
          
          if (needsGeocoding) {
            // Only geocode if we really don't have a name or address
             print('🔄 Reverse geocoding merchant location...');
             final geocodedAddress = await GeocodingService.reverseGeocode(lat, lng);
             displayAddress = geocodedAddress ?? storeLocationText;
          } else {
            displayAddress = address ?? storeLocationText;
          }
        }
        
        setState(() {
          _pickupAddressController.text = displayAddress;
        });
        return;
      }
      
      // Fallback to default location if no merchant location found
      final loc = AppLocalizations.of(context);
      setState(() {
        _pickupLatitude = AppConstants.defaultLatitude;
        _pickupLongitude = AppConstants.defaultLongitude;
        _pickupAddressController.text = loc.storeLocation;
      });
    } catch (e) {
      print('Error loading merchant location: $e');
      // On error, use defaults
        final loc = AppLocalizations.of(context);
      setState(() {
        _pickupLatitude = AppConstants.defaultLatitude;
        _pickupLongitude = AppConstants.defaultLongitude;
        _pickupAddressController.text = loc.storeLocation;
      });
    }
  }

  void _startPeriodicRefresh() {
    // Refresh driver count every 10 seconds as fallback
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkOnlineDrivers();
    });
  }

  void _subscribeToDriverUpdates() {
    try {
      // Optimized: Subscribe only to UPDATE events (not INSERT/DELETE) and filter by role + is_online changes
      // This reduces Realtime query load by filtering at the database level instead of processing all user changes
      _driversChannel = Supabase.instance.client
          .channel('driver_status_changes_optimized')
          .onPostgresChanges(
            event: PostgresChangeEvent.update, // Only updates, not all events
            schema: 'public',
            table: 'users',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'role',
              value: 'driver',
            ),
            callback: (payload) {
              final oldRecord = payload.oldRecord;
              final newRecord = payload.newRecord;
              
              // Only process if is_online actually changed (filters out other field updates)
              final oldIsOnline = oldRecord['is_online'] as bool?;
              final newIsOnline = newRecord['is_online'] as bool?;
              
              if (oldIsOnline != newIsOnline) {
                print('🔄 Driver online status changed: $oldIsOnline -> $newIsOnline');
                _checkOnlineDrivers();
              } else {
                // Silently ignore other field updates (name, phone, etc.) to reduce processing
                print('🔄 Driver update detected but is_online unchanged - skipping');
              }
            },
          )
          .subscribe((status, error) {
            if (error != null) {
              print('❌ Subscription error: $error');
            } else {
              print('✅ Subscribed to driver status updates (optimized)');
            }
          });
      
      print('✅ Subscribed to driver status updates (optimized - only is_online changes)');
    } catch (e) {
      print('❌ Failed to subscribe to driver updates: $e');
    }
  }

  Future<void> _checkOnlineDrivers() async {
    try {
      print('');
      print('═══════════════════════════════════════');
      print('🔍 CHECKING FOR AVAILABLE DRIVERS (ONLINE & FREE)');
      print('═══════════════════════════════════════');

      final merchantId = Supabase.instance.client.auth.currentUser?.id;
      final merchantCityRow = merchantId == null
          ? null
          : await Supabase.instance.client
              .from('users')
              .select('city')
              .eq('id', merchantId)
              .maybeSingle();
      final merchantCity = (merchantCityRow?['city'] ?? '').toString();
      if (merchantCity.isEmpty) {
        if (mounted) {
          setState(() {
            _onlineDriversCount = 0;
            _checkingDrivers = false;
          });
        }
        return;
      }
      
      // First check all drivers to see their status
      final allDrivers = await Supabase.instance.client
          .from('users')
          .select('id, name, is_online, manual_verified, role')
          .eq('role', 'driver')
          .ilike('city', merchantCity);
      
      print('📊 Total drivers: ${allDrivers.length}');
      for (var driver in allDrivers) {
        final online = driver['is_online'] ?? false;
        final verified = driver['manual_verified'] ?? false;
        print('   ${driver['name']}: online=$online, verified=$verified');
      }
      
      // Get only online drivers — ilike for case-insensitive city matching.
      final onlineDrivers = await Supabase.instance.client
          .from('users')
          .select('id, name, is_online, manual_verified')
          .eq('role', 'driver')
          .eq('is_online', true)
          .ilike('city', merchantCity);
      
      print('');
      print('📋 Online drivers: ${onlineDrivers.length}');
      
      if (onlineDrivers.isEmpty) {
        print('❌ NO ONLINE DRIVERS FOUND!');
        if (mounted) {
          setState(() {
            _onlineDriversCount = 0;
            _checkingDrivers = false;
          });
        }
        return;
      }
      
      // Get driver IDs
      final driverIds = (onlineDrivers as List<dynamic>)
          .map((driver) => driver['id'] as String?)
          .whereType<String>()
          .toList();
      
      // Check for active orders
      final activeOrders = await Supabase.instance.client
          .from('orders')
          .select('driver_id')
          .inFilter('driver_id', driverIds)
          .inFilter('status', ['pending', 'assigned', 'accepted', 'on_the_way']);
      
      // Get drivers with active orders
      final busyDriverIds = (activeOrders as List<dynamic>)
          .map((order) => order['driver_id'] as String?)
          .whereType<String>()
          .toSet();
      
      // Calculate free drivers
      final freeDriverCount = driverIds.where((id) => !busyDriverIds.contains(id)).length;
      
      print('');
      print('📊 Driver Status:');
      print('   Online: ${driverIds.length}');
      print('   Busy: ${busyDriverIds.length}');
      print('   Free: $freeDriverCount');
      
      for (var driver in onlineDrivers) {
        final id = driver['id'] as String;
        final name = driver['name'];
        final isBusy = busyDriverIds.contains(id);
        print('   ${isBusy ? "🔴" : "🟢"} $name - ${isBusy ? "BUSY" : "FREE"}');
      }
      
      print('');
      print('🔄 Updating UI state...');
      print('   Current count: $_onlineDriversCount');
      print('   New count: $freeDriverCount');
      print('   Mounted: $mounted');
      
      if (mounted) {
        setState(() {
          _onlineDriversCount = freeDriverCount;
          _checkingDrivers = false;
        });
        print('✅ UI STATE UPDATED to $_onlineDriversCount drivers');
      } else {
        print('❌ Widget not mounted - UI NOT updated');
      }
      
      print('═══════════════════════════════════════');
      print('');
    } catch (e, stackTrace) {
      print('');
      print('❌❌❌ ERROR CHECKING DRIVERS ❌❌❌');
      print('Error: $e');
      print('Type: ${e.runtimeType}');
      print('Stack: $stackTrace');
      print('');
      
      if (mounted) {
        setState(() {
          _checkingDrivers = false;
        });
      }
    }
  }

  Future<void> _checkActiveOrderForSameDriver() async {
    try {
      final merchantId = Supabase.instance.client.auth.currentUser?.id;
      if (merchantId == null) return;

      // Check if merchant has active orders with assigned drivers
      final activeOrders = await Supabase.instance.client
          .from('orders')
          .select('id, driver_id, driver:users!driver_id(id, name)')
          .eq('merchant_id', merchantId)
          .inFilter('status', ['pending', 'accepted', 'on_the_way'])
          .not('driver_id', 'is', null)
          .order('created_at', ascending: false);

      if (mounted && activeOrders.isNotEmpty) {
        // Extract unique drivers (in case merchant has multiple orders with same driver)
        final Map<String, String> uniqueDrivers = {};
        
        for (var order in activeOrders) {
          final driverId = order['driver_id'] as String?;
          if (driverId != null) {
            final driver = order['driver'] as Map<String, dynamic>?;
            final driverName = driver?['name'] as String? ?? 'السائق';
            
            // Only add if not already in map (to avoid duplicates)
            if (!uniqueDrivers.containsKey(driverId)) {
              uniqueDrivers[driverId] = driverName;
            }
          }
        }

        final driversList = uniqueDrivers.entries
            .map((e) => {'id': e.key, 'name': e.value})
            .toList();

        setState(() {
          _availableDrivers = driversList;
          // Set default to first driver if available
          if (driversList.isNotEmpty) {
            _activeOrderDriverId = driversList.first['id'];
            _activeOrderDriverName = driversList.first['name'];
          }
        });
      } else {
        setState(() {
          _availableDrivers = [];
          _activeOrderDriverId = null;
          _activeOrderDriverName = null;
        });
      }
    } catch (e) {
      print('⚠️ Error checking active order for same driver: $e');
      if (mounted) {
        setState(() {
          _availableDrivers = [];
          _activeOrderDriverId = null;
          _activeOrderDriverName = null;
        });
      }
    }
  }

  Future<void> _pickLocation(String type) async {
    final loc = AppLocalizations.of(context);
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLatitude: type == 'pickup' ? _pickupLatitude : _deliveryLatitude,
          initialLongitude: type == 'pickup' ? _pickupLongitude : _deliveryLongitude,
          title: type == 'pickup' ? loc.pickLocationPickup : loc.pickLocationDelivery,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (type == 'pickup') {
          _pickupLatitude = result['latitude'];
          _pickupLongitude = result['longitude'];
          _pickupAddressController.text = result['address'] ?? loc.locationSelected;
        } else {
          _deliveryLatitude = result['latitude'];
          _deliveryLongitude = result['longitude'];
          _deliveryAddressController.text = result['address'] ?? loc.locationSelected;
        }
      });
        // Recalculate delivery fee when location is picked
        _calculateAndUpdateDeliveryFee();
    }
  }

  Future<void> _geocodeAddress(String type) async {
    final address = type == 'pickup' 
        ? _pickupAddressController.text.trim()
        : _deliveryAddressController.text.trim();

    if (address.isEmpty) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // Get merchant's city
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.user;
      final merchantCity = user?.city;

      final result = await GeocodingService.geocodeAddress(address, city: merchantCity);

      if (result != null && mounted) {
        setState(() {
          if (type == 'pickup') {
            _pickupLatitude = result['latitude'];
            _pickupLongitude = result['longitude'];
            // Use 'address' field from v6 API response (which now returns 'address' instead of 'formatted_address')
            if (result['address'] != null) {
              _pickupAddressController.text = result['address'];
            } else if (result['formatted_address'] != null) {
              _pickupAddressController.text = result['formatted_address'];
            }
            // Recalculate delivery fee when pickup location is geocoded
            _calculateAndUpdateDeliveryFee();
          } else {
            _deliveryLatitude = result['latitude'];
            _deliveryLongitude = result['longitude'];
            // Use 'address' field from v6 API response
            if (result['address'] != null) {
              _deliveryAddressController.text = result['address'];
            } else if (result['formatted_address'] != null) {
              _deliveryAddressController.text = result['formatted_address'];
            }
          }
          _isLoading = false;
        });
        
        // Recalculate delivery fee after geocoding
        _calculateAndUpdateDeliveryFee();

        if (mounted) {
          final loc = AppLocalizations.of(context);
          showHeaderNotification(
            context,
            title: loc.locationSuccess,
            message: loc.locationSuccessMessage,
            type: NotificationType.success,
          );
        }
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final loc = AppLocalizations.of(context);
        showHeaderNotification(
          context,
          title: loc.error,
          message: loc.locationNotFound,
          type: NotificationType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final loc = AppLocalizations.of(context);
        showHeaderNotification(
          context,
          title: loc.error,
          message: loc.locationError,
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _submitOrder() async {
    // Validate form and show errors if validation fails
    if (!_formKey.currentState!.validate()) {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.pleaseFillAllRequired),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: loc.ok,
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
      return;
    }
    
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
    
    // Check credit limit first
    final walletProvider = context.read<WalletProvider>();
    if (walletProvider.balance <= walletProvider.creditLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.insufficientBalanceCreate),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Check for online drivers (bypass if assigning to same driver)
    if (_onlineDriversCount == 0 && !(_assignToSameDriver && _activeOrderDriverId != null)) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: AppColors.warning, size: context.ri(24)),
              SizedBox(width: context.rs(8)),
              ResponsiveText(loc.noDriversOnline, style: TextStyle(fontSize: context.rf(16))),
            ],
          ),
          content: ResponsiveText(
            loc.cannotCreateOrder,
            style: TextStyle(fontSize: context.rf(16)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.ok),
            ),
          ],
        ),
      );
      return;
    }
    
    final merchantId = Supabase.instance.client.auth.currentUser?.id;
    if (merchantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.userDataError),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Check driver availability (bypass if assigning to same driver)
    if (!(_assignToSameDriver && _activeOrderDriverId != null)) {
      final availabilityResult = await DriverAvailabilityService.checkAvailability(
        merchantId: merchantId,
        vehicleType: _selectedVehicleType,
      );

      if (!availabilityResult.available) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: AppColors.warning, size: context.ri(24)),
                SizedBox(width: context.rs(8)),
                ResponsiveText(loc.noDriversAvailable, style: TextStyle(fontSize: context.rf(16))),
              ],
            ),
            content: ResponsiveText(
              availabilityResult.userMessage(context),
              style: TextStyle(fontSize: context.rf(16)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(loc.ok),
              ),
            ],
          ),
        );
        return;
      }
    }
    
    if (_pickupLatitude == null || _pickupLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc.pickLocationPickup} - ${loc.required}'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_deliveryLatitude == null || _deliveryLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc.pickLocationDelivery} - ${loc.required}'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Normalize phone to always save with +964 prefix (if provided)
      final customerPhone = _customerPhoneController.text.trim().isNotEmpty
          ? _formatCustomerPhoneForSave(_customerPhoneController.text)
          : null;
      final totalAmount = double.tryParse(_totalAmountController.text.trim()) ?? 0.0;
      final deliveryFee = double.tryParse(_deliveryFeeController.text.trim()) ?? 0.0;

      // Calculate ready_at time if countdown is set
      DateTime? readyAt;
      int readyCountdown = _scheduledMinutes.toInt();
      
      if (_scheduledMinutes > 0) {
        readyAt = DateTime.now().add(Duration(minutes: readyCountdown));
      }

      // Create order (always immediate, but with ready countdown if set)
      final orderProvider = context.read<OrderProvider>();
      final authProvider = context.read<AuthProvider>();
      final orderData = await orderProvider.createOrder(
        customerName: _customerNameController.text.trim().isEmpty 
            ? loc.customerNameFallback
            : _customerNameController.text.trim(),
        customerPhone: customerPhone,
        pickupAddress: _pickupAddressController.text.trim(),
        pickupLatitude: _pickupLatitude!,
        pickupLongitude: _pickupLongitude!,
        deliveryAddress: _deliveryAddressController.text.trim(),
        deliveryLatitude: _deliveryLatitude!,
        deliveryLongitude: _deliveryLongitude!,
        totalAmount: totalAmount,
        deliveryFee: deliveryFee,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        vehicleType: _selectedVehicleType,
        readyAt: readyAt,
        readyCountdown: readyCountdown > 0 ? readyCountdown : null,
        assignedDriverId: _assignToSameDriver ? _activeOrderDriverId : null,
      );

      // Send WhatsApp location request (non-blocking, fire-and-forget) - only if phone is provided
      if (orderData != null && customerPhone != null) {
        _sendWhatsAppLocationRequest(
          orderId: orderData['id'],
          customerPhone: customerPhone,
          customerName: _customerNameController.text.trim().isEmpty 
              ? loc.customerNameFallback
              : _customerNameController.text.trim(),
          merchantName: authProvider.user?.storeName ?? authProvider.user?.name ?? 'متجرنا',
        );
      }

      if (orderData != null && mounted) {
        HapticFeedback.heavyImpact(); // Satisfying confirmation on success
        showHeaderNotification(
          context,
          title: loc.orderCreated,
          message: readyCountdown > 0
              ? loc.orderCreatedReadyAfter(readyCountdown)
              : loc.orderCreatedSuccess,
          type: NotificationType.success,
        );
        Navigator.pop(context);
      } else if (mounted) {
        HapticFeedback.vibrate(); // Alert vibration on failure
        showHeaderNotification(
          context,
          title: loc.error,
          message: orderProvider.error ?? loc.orderCreateError,
          type: NotificationType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        showHeaderNotification(
          context,
          title: loc.error,
          message: loc.orderCreateError,
          type: NotificationType.error,
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

  String _formatCustomerPhoneForSave(String input) {
    // Keep only digits
    String digits = input.replaceAll(RegExp(r'\D'), '');
    // Remove leading country code if user typed it
    if (digits.startsWith('964')) {
      digits = digits.substring(3);
    }
    // Strip leading zeros
    digits = digits.replaceFirst(RegExp('^0+'), '');
    // Compose
    return '+964$digits';
  }

  // Send WhatsApp location request (fire-and-forget, non-blocking)
  void _sendWhatsAppLocationRequest({
    required String orderId,
    required String customerPhone,
    required String customerName,
    required String merchantName,
  }) {
    // Fire-and-forget - don't await, don't block UI
    Supabase.instance.client.functions.invoke(
      'send-location-request',
      body: {
        'order_id': orderId,
        'customer_phone': customerPhone,
        'customer_name': customerName,
        'merchant_name': merchantName,
      },
    ).then((response) {
      if (response.status == 200) {
        print('✅ WhatsApp location request sent successfully');
      } else {
        print('⚠️ WhatsApp location request failed: ${response.status}');
      }
    }).catchError((error) {
      print('⚠️ Failed to send WhatsApp location request (non-critical): $error');
      // Don't show error to user - this is a background operation
    });
  }

  // Check if form has enough information to enable floating button
  bool get _hasEnoughInfoToCreateOrder {
    return _customerPhoneController.text.trim().isNotEmpty &&
           _pickupLatitude != null &&
           _pickupLongitude != null &&
           _deliveryLatitude != null &&
           _deliveryLongitude != null &&
           _totalAmountController.text.trim().isNotEmpty &&
           _deliveryFeeController.text.trim().isNotEmpty &&
           !_isLoading;
  }

  bool get _hasUnsavedData =>
      _customerNameController.text.isNotEmpty ||
      _customerPhoneController.text.isNotEmpty ||
      _totalAmountController.text.isNotEmpty ||
      _deliveryFeeController.text.isNotEmpty ||
      _notesController.text.isNotEmpty ||
      _pickupLatitude != null ||
      _deliveryLatitude != null;

  Future<bool> _confirmDiscard(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.discardChangesTitle),
        content: Text(loc.discardChangesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(loc.discardButton),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedData,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldDiscard = await _confirmDiscard(context);
        if (shouldDiscard && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      resizeToAvoidBottomInset: true,
      appBar: widget.embedded ? null : AppBar(
        title: Text(AppLocalizations.of(context).createNewOrder),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () async {
            if (_hasUnsavedData) {
              final shouldDiscard = await _confirmDiscard(context);
              if (shouldDiscard && context.mounted) Navigator.of(context).pop();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: NavigationOverlayScope(
        child: Builder(
          builder: (context) {
            final controller = NavigationOverlayScope.of(context);
            final bottomInset = controller?.bottomInset ?? MediaQuery.of(context).viewPadding.bottom;
            
            return Stack(
              children: [
                Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction, // Show errors after user interaction
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: ResponsiveHelper.getResponsiveSpacing(context, 20),
                      right: ResponsiveHelper.getResponsiveSpacing(context, 20),
                      top: ResponsiveHelper.getResponsiveSpacing(context, 20),
                      bottom: 100 + bottomInset,  // Always add padding for button
                    ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Fields: Customer Location (Delivery Address) - Dropdown
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
                label: AppLocalizations.of(context).deliveryLocation,
                hint: AppLocalizations.of(context).deliveryLocationHint,
                isRequired: true,
                storeLatitude: _pickupLatitude,
                storeLongitude: _pickupLongitude,
                onLocationPickerTap: () => _pickLocation('delivery'),
              ),
              
              const SizedBox(height: 24),
              
              // Pricing Section — grouped card
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Container(
                    decoration: BoxDecoration(
                      color: context.themeColor(
                        light: const Color(0xFFF0FAF7),
                        dark: const Color(0xFF0D2B22),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.themePrimary.withValues(alpha: 0.15),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.payments_outlined,
                              size: 18,
                              color: context.themePrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              loc.prices,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: context.themePrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Order Fee (Total Amount)
                        _buildTextField(
                          controller: _totalAmountController,
                          label: loc.totalAmount,
                          hint: '0',
                          icon: Icons.money,
                          keyboardType: TextInputType.number,
                          isRequired: true,
                          suffix: loc.currencySymbol,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return loc.amountRequired;
                            }
                            if (double.tryParse(value) == null) {
                              return loc.enterValidNumber;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        // Delivery Fee
                        DeliveryFeeDropdown(
                          controller: _deliveryFeeController,
                          label: loc.deliveryFee,
                          isRequired: true,
                          recommendedFee: _recommendedDeliveryFee,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return loc.deliveryFeeRequired;
                            }
                            if (double.tryParse(value) == null) {
                              return loc.enterValidNumber;
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              // Customer Phone Field (Optional) - Right above Advanced Settings
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
                            textDirection: TextDirection.ltr,
                          ),
                          onTap: () {
                            // Put selected suggestion into input (without country code prefix if duplicated visually)
                            final normalized = suggestion.replaceFirst(RegExp(r'^\+?964'), '');
                            _customerPhoneController.text = normalized;
                            _customerPhoneController.selection = TextSelection.collapsed(offset: _customerPhoneController.text.length);
                            // Validate and lock/unfocus
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
              
              // Option to assign to same driver if merchant has active order
              if (_availableDrivers.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _assignToSameDriver,
                            onChanged: (value) {
                              setState(() {
                                _assignToSameDriver = value ?? false;
                              });
                            },
                            activeColor: AppColors.primary,
                          ),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context).assignToSameDriver,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: context.themeTextPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_assignToSameDriver) ...[
                        const SizedBox(height: 12),
                        if (_availableDrivers.length == 1)
                          // Single driver - just show name
                          Text(
                            '${AppLocalizations.of(context).currentDriver}: ${_activeOrderDriverName ?? 'غير معروف'}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: context.themeTextSecondary,
                            ),
                          )
                        else
                          // Multiple drivers - show dropdown
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _activeOrderDriverId,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: context.themeTextPrimary,
                                ),
                                items: _availableDrivers.map((driver) {
                                  return DropdownMenuItem<String>(
                                    value: driver['id'],
                                    child: Text(driver['name'] ?? ''),
                                  );
                                }).toList(),
                                onChanged: (String? newDriverId) {
                                  if (newDriverId != null) {
                                    setState(() {
                                      _activeOrderDriverId = newDriverId;
                                      _activeOrderDriverName = _availableDrivers
                                          .firstWhere((d) => d['id'] == newDriverId)['name'];
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Advanced Settings Expandable Section
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
                        AppLocalizations.of(context).advancedSettings,
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
                          _buildTextField(
                            controller: _customerNameController,
                            label: AppLocalizations.of(context).customerNameOptional,
                            hint: AppLocalizations.of(context).enterCustomerName,
                            icon: Icons.person_outline,
                            isRequired: false,
                          ),
                          
              const SizedBox(height: 16),
              
                          // Pickup Location (Auto-set to merchant location, but editable)
              _buildLocationField(
                controller: _pickupAddressController,
                label: AppLocalizations.of(context).pickupLocation,
                hint: AppLocalizations.of(context).pickupLocationHint,
                icon: Icons.store,
                onTap: () => _pickLocation('pickup'),
                hasLocation: _pickupLatitude != null && _pickupLongitude != null,
                type: 'pickup',
              ),
              
                          const SizedBox(height: 24),
                          
                          // Vehicle Type Section
                          Builder(
                            builder: (context) {
                              final loc = AppLocalizations.of(context);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeader(loc.vehicleType, Icons.directions_car),
              const SizedBox(height: 16),
                                  Container(
                                    padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, 16)),
                                    decoration: BoxDecoration(
                                      color: context.themeBackground,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: context.themeBorder),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          loc.selectVehicleType,
                                          style: AppTextStyles.bodyMedium.copyWith(
                                            color: context.themeTextSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        // Any Vehicle Option (Default)
                                        Container(
                                          decoration: BoxDecoration(
                                            color: _selectedVehicleType == 'any' ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: _selectedVehicleType == 'any' ? AppColors.primary : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                          child: RadioListTile<String>(
                                            title: Row(
                                              children: [
                                                Icon(
                                                  Icons.widgets_outlined,
                                                  color: _selectedVehicleType == 'any' ? AppColors.primary : AppColors.textSecondary,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  loc.anyVehicle,
                                                  style: AppTextStyles.bodyMedium.copyWith(
                                                    color: context.themeTextPrimary,
                                                    fontWeight: _selectedVehicleType == 'any' ? FontWeight.w600 : FontWeight.w400,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                if (_selectedVehicleType == 'any')
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.success,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      loc.defaultText,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            subtitle: Padding(
                                              padding: const EdgeInsets.only(right: 28, top: 4),
                                              child: Text(
                                                loc.anyVehicleHint,
                                                style: TextStyle(fontSize: 11, color: context.themeTextTertiary),
                                              ),
                                            ),
                                            value: 'any',
                                            groupValue: _selectedVehicleType,
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedVehicleType = value!;
                                              });
                                            },
                                            activeColor: AppColors.primary,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Motorbike Radio Button
                                        Container(
                                          decoration: BoxDecoration(
                                            color: _selectedVehicleType == 'motorbike' ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: _selectedVehicleType == 'motorbike' ? AppColors.primary : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                          child: RadioListTile<String>(
                                            title: Row(
                                              children: [
                                                Icon(
                                                  Icons.two_wheeler,
                                                  color: _selectedVehicleType == 'motorbike' ? AppColors.primary : AppColors.textSecondary,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  loc.motorbike,
                                                  style: AppTextStyles.bodyMedium.copyWith(
                                                    color: context.themeTextPrimary,
                                                    fontWeight: _selectedVehicleType == 'motorbike' ? FontWeight.w600 : FontWeight.w400,
                                                  ),
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
                                            activeColor: AppColors.primary,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Car Radio Button
                                        Container(
                                          decoration: BoxDecoration(
                                            color: _selectedVehicleType == 'car' ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: _selectedVehicleType == 'car' ? AppColors.primary : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                          child: RadioListTile<String>(
                                            title: Row(
                                              children: [
                                                Icon(
                                                  Icons.directions_car,
                                                  color: _selectedVehicleType == 'car' ? AppColors.primary : AppColors.textSecondary,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  loc.car,
                                                  style: AppTextStyles.bodyMedium.copyWith(
                                                    color: context.themeTextPrimary,
                                                    fontWeight: _selectedVehicleType == 'car' ? FontWeight.w600 : FontWeight.w400,
                                                  ),
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
                                            activeColor: AppColors.primary,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Truck Radio Button
                                        Container(
                                          decoration: BoxDecoration(
                                            color: _selectedVehicleType == 'truck' ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: _selectedVehicleType == 'truck' ? AppColors.primary : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                          child: RadioListTile<String>(
                                            title: Row(
                                              children: [
                                                Icon(
                                                  Icons.local_shipping,
                                                  color: _selectedVehicleType == 'truck' ? AppColors.primary : AppColors.textSecondary,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  loc.truck,
                                                  style: AppTextStyles.bodyMedium.copyWith(
                                                    color: context.themeTextPrimary,
                                                    fontWeight: _selectedVehicleType == 'truck' ? FontWeight.w600 : FontWeight.w400,
                                                  ),
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
                                            activeColor: AppColors.primary,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Notes Section
                          Builder(
                            builder: (context) {
                              final loc = AppLocalizations.of(context);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeader(loc.notesOptional, Icons.note),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _notesController,
                                    label: loc.additionalNotes,
                                    hint: loc.addNotesHint,
                                    icon: Icons.edit_note,
                                    maxLines: 4,
                                    isRequired: false,
                                  ),
                                ],
                              );
                            },
              ),
              
              const SizedBox(height: 24),
              
                          // Scheduling Section
                          Builder(
                            builder: (context) {
                              final loc = AppLocalizations.of(context);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeader(loc.whenReady, Icons.access_time),
              const SizedBox(height: 16),
                                  Container(
                                    padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, 20)),
                                    decoration: BoxDecoration(
                                      color: context.themeBackground,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: context.themeBorder),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _scheduledMinutes == 0 
                                              ? loc.readyNow
                                              : loc.readyAfterMinutes(_scheduledMinutes.toInt()),
                                          style: AppTextStyles.heading3.copyWith(
                                            color: context.themePrimary,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        SliderTheme(
                                          data: SliderThemeData(
                                            activeTrackColor: AppColors.primary,
                                            inactiveTrackColor: AppColors.primary.withOpacity(0.2),
                                            thumbColor: AppColors.primary,
                                            overlayColor: AppColors.primary.withOpacity(0.2),
                                            valueIndicatorColor: AppColors.primary,
                                            trackHeight: 4,
                                          ),
                                          child: Slider(
                                            value: _scheduledMinutes,
                                            min: 0,
                                            max: 60,
                                            divisions: 6,
                                            label: _scheduledMinutes == 0 
                                                ? loc.nowText
                                                : '${_scheduledMinutes.toInt()} ${loc.minutesText}',
                                            onChanged: (value) {
                                              setState(() {
                                                _scheduledMinutes = value;
                                              });
                                            },
                                          ),
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              loc.nowText,
                                              style: TextStyle(
                                                color: context.themeTextTertiary,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              loc.sixtyMinutes,
                                              style: TextStyle(
                                                color: context.themeTextTertiary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              // Total Summary Card — uses ValueListenableBuilder so only
              // this card rebuilds when amounts change, not the whole form.
              ValueListenableBuilder<String>(
                valueListenable: _totalAmountNotifier,
                builder: (context, _, __) => ValueListenableBuilder<String>(
                  valueListenable: _deliveryFeeNotifier,
                  builder: (context, __, ___) {
                    final loc2 = AppLocalizations.of(context);
                    return Container(
                padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, 20)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            loc2.totalAmount,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_totalAmountController.text.isEmpty ? "0" : _totalAmountController.text} ${loc2.currencySymbol}',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            loc2.deliveryFee,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_deliveryFeeController.text.isEmpty ? "0" : _deliveryFeeController.text} ${loc2.currencySymbol}',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Divider(color: Colors.white.withOpacity(0.3), height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            loc2.grandTotalLabel,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.heading3.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${_calculateGrandTotal()} ${loc2.currencySymbol}',
                            style: AppTextStyles.heading2.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
                ),
          // Floating Create Order Button - always visible
          AdaptivePositioned(
              bottomOffset: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.themeSurface,
                  boxShadow: [
                    BoxShadow(
                      color: context.themeColor(
                        light: Colors.black.withOpacity(0.1),
                        dark: Colors.black.withOpacity(0.35),
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                width: double.infinity,
                    height: 56,
                        child: Builder(
                          builder: (context) {
                        final loc = AppLocalizations.of(context);
                        final hasDrivers = _onlineDriversCount > 0;
                        // Bypass driver check if assigning to same driver
                        final canCreateOrder = hasDrivers || (_assignToSameDriver && _activeOrderDriverId != null);
                        
                        // If no drivers and not assigning to same driver, show red non-clickable button
                        if (!_checkingDrivers && !hasDrivers && !(_assignToSameDriver && _activeOrderDriverId != null)) {
                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.warning, color: Colors.white, size: 22),
                                  const SizedBox(width: 12),
                                  Text(
                                    loc.allDriversBusy,
                                    style: AppTextStyles.buttonLarge.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        
                            return ElevatedButton.icon(
                  onPressed: (_isLoading || _checkingDrivers || !canCreateOrder) ? null : _submitOrder,
                  icon: _isLoading 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.add_shopping_cart, color: Colors.white, size: 22),
                  label: Text(
                            _isLoading ? loc.creatingOrder : loc.createOrder,
                    style: AppTextStyles.buttonLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    disabledBackgroundColor: AppColors.textTertiary,
                  ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      ), // end Scaffold
    ); // end PopScope
  }

  Widget _buildSectionHeader(String title, IconData icon) {
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

  Widget _buildTextField({
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
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
              // Country code prefix with spacing
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
                  textDirection: TextDirection.ltr,
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
              // Enforce Iraqi local format: 7XXXXXXXXX (10 digits)
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
              if (!_phoneLocked && _customerPhoneController.text.replaceAll(RegExp(r'\\D'), '').length >= 3) {
                _debouncedFetchPhoneSuggestions(_customerPhoneController.text);
                setState(() {
                  _showPhoneSuggestions = true;
                });
              }
            },
            onChanged: (val) {
              // Ensure suggestions panel visibility while typing
              if (!_phoneLocked && val.replaceAll(RegExp(r'\\D'), '').length >= 3) {
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
              // Lock and unfocus on accept
              final digits = _customerPhoneController.text.replaceAll(RegExp(r'\\D'), '');
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
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required VoidCallback onTap,
    required bool hasLocation,
    required String type,
    bool isRequired = false,
  }) {
    final focusNode = type == 'pickup' ? _pickupAddressFocusNode : _deliveryAddressFocusNode;
    final showSuggestions = type == 'pickup' ? _showPickupSuggestions : _showDeliverySuggestions;
    final suggestions = type == 'pickup' ? _pickupAddressSuggestions : _deliveryAddressSuggestions;
    
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
                    color: (hasLocation ? AppColors.success : AppColors.primary).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: hasLocation ? AppColors.success : AppColors.primary,
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
                        ? const Icon(Icons.check_circle, color: AppColors.success, size: 20)
                        : null,
                  ),
                  onSubmitted: (_) => _geocodeAddress(type),
                ),
              ),
              // Map Button
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return IconButton(
                onPressed: onTap,
                icon: const Icon(Icons.map, color: AppColors.primary),
                    tooltip: loc.openMap,
                  );
                },
              ),
              // Geocode Button
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return IconButton(
                onPressed: () => _geocodeAddress(type),
                icon: const Icon(Icons.search, color: AppColors.success),
                    tooltip: loc.searchAddress,
                  );
                },
              ),
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
                  separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.border.withOpacity(0.5)),
                  itemBuilder: (context, index) {
                    final district = suggestions[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                      title: Text(
                        district.name,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () => _selectDistrict(district, type),
                    );
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _calculateGrandTotal() {
    final total = double.tryParse(_totalAmountController.text.trim()) ?? 0.0;
    final delivery = double.tryParse(_deliveryFeeController.text.trim()) ?? 0.0;
    return (total + delivery).toStringAsFixed(0);
  }
}