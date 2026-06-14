import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/najaf_districts_service.dart';
import '../../../core/services/delivery_fee_calculator.dart';

class CreateOrderController extends ChangeNotifier {
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController customerPhoneController = TextEditingController();
  final TextEditingController pickupAddressController = TextEditingController();
  final TextEditingController deliveryAddressController = TextEditingController();
  final TextEditingController totalAmountController = TextEditingController();
  final TextEditingController deliveryFeeController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  final FocusNode customerPhoneFocusNode = FocusNode();
  final FocusNode pickupAddressFocusNode = FocusNode();
  final FocusNode deliveryAddressFocusNode = FocusNode();

  double? pickupLatitude;
  double? pickupLongitude;
  double? deliveryLatitude;
  double? deliveryLongitude;

  bool isLoading = false;
  int onlineDriversCount = 0;
  bool checkingDrivers = true;

  List<String> phoneSuggestions = [];
  bool showPhoneSuggestions = false;
  bool phoneLocked = false;

  List<NajafDistrict> pickupAddressSuggestions = [];
  List<NajafDistrict> deliveryAddressSuggestions = [];
  bool showPickupSuggestions = false;
  bool showDeliverySuggestions = false;

  double scheduledMinutes = 0;
  String selectedVehicleType = 'any';
  bool showAdvancedSettings = false;
  double? recommendedDeliveryFee;

  bool assignToSameDriver = false;
  String? activeOrderDriverId;
  String? activeOrderDriverName;
  List<Map<String, String>> availableDrivers = [];

  late final ValueNotifier<String> totalAmountNotifier;
  late final ValueNotifier<String> deliveryFeeNotifier;

  RealtimeChannel? driversChannel;
  Timer? refreshTimer;
  Timer? phoneDebounce;
  Timer? addressDebounce;

  void init() {
    totalAmountNotifier = ValueNotifier(totalAmountController.text);
    deliveryFeeNotifier = ValueNotifier(deliveryFeeController.text);
    totalAmountController
        .addListener(() => totalAmountNotifier.value = totalAmountController.text);
    deliveryFeeController
        .addListener(() => deliveryFeeNotifier.value = deliveryFeeController.text);
    NajafDistrictsService.loadDistricts();
  }

  void setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  void setOnlineDriversCount(int count, {bool checkingDone = true}) {
    onlineDriversCount = count;
    if (checkingDone) checkingDrivers = false;
    notifyListeners();
  }

  void setCheckingDriversDone() {
    checkingDrivers = false;
    notifyListeners();
  }

  void setPhoneSuggestions(List<String> suggestions, {bool show = true}) {
    phoneSuggestions = suggestions;
    showPhoneSuggestions = show && suggestions.isNotEmpty;
    notifyListeners();
  }

  void setShowPhoneSuggestions(bool show) {
    showPhoneSuggestions = show;
    notifyListeners();
  }

  void setPickupLocation(double lat, double lng, String address) {
    pickupLatitude = lat;
    pickupLongitude = lng;
    pickupAddressController.text = address;
    _calculateAndUpdateDeliveryFee();
    notifyListeners();
  }

  void setDeliveryLocation(double lat, double lng, String address) {
    deliveryLatitude = lat;
    deliveryLongitude = lng;
    deliveryAddressController.text = address;
    _calculateAndUpdateDeliveryFee();
    notifyListeners();
  }

  void clearDeliveryLocation() {
    deliveryAddressController.clear();
    deliveryLatitude = null;
    deliveryLongitude = null;
    notifyListeners();
  }

  void setPickupSuggestions(List<NajafDistrict> suggestions, {bool show = true}) {
    pickupAddressSuggestions = suggestions;
    showPickupSuggestions = show && suggestions.isNotEmpty;
    notifyListeners();
  }

  void setDeliverySuggestions(List<NajafDistrict> suggestions, {bool show = true}) {
    deliveryAddressSuggestions = suggestions;
    showDeliverySuggestions = show && suggestions.isNotEmpty;
    notifyListeners();
  }

  void setShowPickupSuggestions(bool show) {
    showPickupSuggestions = show;
    notifyListeners();
  }

  void setShowDeliverySuggestions(bool show) {
    showDeliverySuggestions = show;
    notifyListeners();
  }

  void setAssignToSameDriver(bool value) {
    assignToSameDriver = value;
    notifyListeners();
  }

  void setActiveDriver(String? id, String? name) {
    activeOrderDriverId = id;
    activeOrderDriverName = name;
    notifyListeners();
  }

  void setAvailableDrivers(List<Map<String, String>> drivers) {
    availableDrivers = drivers;
    if (drivers.isNotEmpty) {
      activeOrderDriverId = drivers.first['id'];
      activeOrderDriverName = drivers.first['name'];
    } else {
      activeOrderDriverId = null;
      activeOrderDriverName = null;
    }
    notifyListeners();
  }

  void setVehicleType(String type) {
    selectedVehicleType = type;
    notifyListeners();
  }

  void setScheduledMinutes(double minutes) {
    scheduledMinutes = minutes;
    notifyListeners();
  }

  void setShowAdvancedSettings(bool show) {
    showAdvancedSettings = show;
    notifyListeners();
  }

  void setPhoneLocked(bool value) {
    phoneLocked = value;
    notifyListeners();
  }

  void _calculateAndUpdateDeliveryFee() {
    if (pickupLatitude != null &&
        pickupLongitude != null &&
        deliveryLatitude != null &&
        deliveryLongitude != null) {
      final fee = DeliveryFeeCalculator.calculateFeeFromCoordinates(
        pickupLatitude!,
        pickupLongitude!,
        deliveryLatitude!,
        deliveryLongitude!,
      );
      recommendedDeliveryFee = fee;
      deliveryFeeController.text = fee.toStringAsFixed(0);
    }
  }

  bool get hasEnoughInfoToCreateOrder =>
      customerPhoneController.text.trim().isNotEmpty &&
      pickupLatitude != null &&
      pickupLongitude != null &&
      deliveryLatitude != null &&
      deliveryLongitude != null &&
      totalAmountController.text.trim().isNotEmpty &&
      deliveryFeeController.text.trim().isNotEmpty &&
      !isLoading;

  bool get hasUnsavedData =>
      customerNameController.text.isNotEmpty ||
      customerPhoneController.text.isNotEmpty ||
      totalAmountController.text.isNotEmpty ||
      deliveryFeeController.text.isNotEmpty ||
      notesController.text.isNotEmpty ||
      pickupLatitude != null ||
      deliveryLatitude != null;

  String formatCustomerPhoneForSave(String input) {
    String digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('964')) digits = digits.substring(3);
    digits = digits.replaceFirst(RegExp(r'^0+'), '');
    return '+964$digits';
  }

  String calculateGrandTotal() {
    final total = double.tryParse(totalAmountController.text.trim()) ?? 0.0;
    final delivery = double.tryParse(deliveryFeeController.text.trim()) ?? 0.0;
    return (total + delivery).toStringAsFixed(0);
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    driversChannel?.unsubscribe();
    phoneDebounce?.cancel();
    addressDebounce?.cancel();
    customerNameController.dispose();
    customerPhoneController.dispose();
    customerPhoneFocusNode.dispose();
    pickupAddressController.dispose();
    pickupAddressFocusNode.dispose();
    deliveryAddressController.dispose();
    deliveryAddressFocusNode.dispose();
    totalAmountController.dispose();
    deliveryFeeController.dispose();
    notesController.dispose();
    totalAmountNotifier.dispose();
    deliveryFeeNotifier.dispose();
    super.dispose();
  }
}
