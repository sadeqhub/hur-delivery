import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// City-specific settings model
class CitySettings {
  final String city;
  final bool driverWalletEnabled;
  final String driverCommissionType; // 'fixed' or 'percentage_delivery_fee'
  final double? driverCommissionValue;
  final Map<String, double> driverCommissionByRank; // {"trial": 0, "bronze": 10, ...}
  final bool merchantWalletEnabled;
  final String merchantCommissionType; // 'fixed', 'percentage_order_fee', or 'percentage_delivery_fee'
  final double merchantCommissionValue;

  CitySettings({
    required this.city,
    required this.driverWalletEnabled,
    required this.driverCommissionType,
    this.driverCommissionValue,
    required this.driverCommissionByRank,
    required this.merchantWalletEnabled,
    required this.merchantCommissionType,
    required this.merchantCommissionValue,
  });

  factory CitySettings.fromJson(Map<String, dynamic> json) {
    final commissionByRank = json['driver_commission_by_rank'] as Map<String, dynamic>? ?? {};
    final commissionByRankMap = <String, double>{};
    commissionByRank.forEach((key, value) {
      if (value is num) {
        commissionByRankMap[key] = value.toDouble();
      }
    });

    return CitySettings(
      city: json['city'] as String,
      driverWalletEnabled: json['driver_wallet_enabled'] as bool? ?? true,
      driverCommissionType: json['driver_commission_type'] as String? ?? 'percentage_delivery_fee',
      driverCommissionValue: json['driver_commission_value'] != null
          ? (json['driver_commission_value'] as num).toDouble()
          : null,
      driverCommissionByRank: commissionByRankMap,
      merchantWalletEnabled: json['merchant_wallet_enabled'] as bool? ?? true,
      merchantCommissionType: json['merchant_commission_type'] as String? ?? 'fixed',
      merchantCommissionValue: json['merchant_commission_value'] != null
          ? (json['merchant_commission_value'] as num).toDouble()
          : 500.0,
    );
  }
}

/// Provider for city-specific settings
class CitySettingsProvider extends ChangeNotifier {
  final Map<String, CitySettings> _settingsCache = {};
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get city settings for a specific city
  CitySettings? getSettingsForCity(String? city) {
    if (city == null) return null;
    return _settingsCache[city.toLowerCase()];
  }

  /// Check if merchant wallet is enabled for a city
  bool isMerchantWalletEnabled(String? city) {
    final settings = getSettingsForCity(city);
    return settings?.merchantWalletEnabled ?? true; // Default to enabled
  }

  /// Check if driver wallet is enabled for a city
  bool isDriverWalletEnabled(String? city) {
    final settings = getSettingsForCity(city);
    return settings?.driverWalletEnabled ?? true; // Default to enabled
  }

  /// Get merchant commission type for a city
  String getMerchantCommissionType(String? city) {
    final settings = getSettingsForCity(city);
    return settings?.merchantCommissionType ?? 'fixed';
  }

  /// Get merchant commission value for a city
  double getMerchantCommissionValue(String? city) {
    final settings = getSettingsForCity(city);
    return settings?.merchantCommissionValue ?? 500.0;
  }

  /// Get driver commission type for a city
  String getDriverCommissionType(String? city) {
    final settings = getSettingsForCity(city);
    return settings?.driverCommissionType ?? 'percentage_delivery_fee';
  }

  /// Get driver commission percentage for a specific rank in a city
  double getDriverCommissionForRank(String? city, String rank) {
    if (city == null || city.isEmpty) {
      // No city specified, use defaults
      switch (rank.toLowerCase()) {
        case 'trial':
          return 0.0;
        case 'bronze':
          return 10.0;
        case 'silver':
          return 7.0;
        case 'gold':
          return 5.0;
        default:
          return 10.0;
      }
    }
    
    final normalizedCity = city.toLowerCase().trim();
    final settings = getSettingsForCity(normalizedCity);
    if (settings == null) {
      // City settings not loaded, use defaults
      switch (rank.toLowerCase()) {
        case 'trial':
          return 0.0;
        case 'bronze':
          return 10.0;
        case 'silver':
          return 7.0;
        case 'gold':
          return 5.0;
        default:
          return 10.0;
      }
    }
    final commissionRate = settings.driverCommissionByRank[rank.toLowerCase()];
    if (commissionRate == null) {
      // Rank not found in settings, use default
      return 10.0;
    }
    return commissionRate;
  }

  /// Load city settings from database
  Future<void> loadCitySettings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await Supabase.instance.client
          .from('city_settings')
          .select('*');

      if (response.isEmpty) {
        _error = 'No city settings found';
        _isLoading = false;
        notifyListeners();
        return;
      }

      _settingsCache.clear();
      for (final row in response) {
        final settings = CitySettings.fromJson(row);
        _settingsCache[settings.city.toLowerCase()] = settings;
      }

      _error = null;
    } catch (e) {
      _error = 'Failed to load city settings: $e';
      print('Error loading city settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load settings for a specific city using RPC function
  Future<CitySettings?> loadSettingsForCity(String city) async {
    try {
      final normalizedCity = city.toLowerCase().trim();
      final response = await Supabase.instance.client.rpc(
        'get_city_settings',
        params: {'p_city': normalizedCity},
      );

      if (response == null || response.isEmpty) {
        print('⚠️ No city settings found for city: $normalizedCity');
        return null;
      }

      // RPC returns a list of rows, but doesn't include the city field
      // So we need to add it manually
      final row = response is List ? response.first : response;
      final rowMap = row as Map<String, dynamic>;
      
      // Add city field to the response since RPC doesn't return it
      rowMap['city'] = normalizedCity;
      
      final settings = CitySettings.fromJson(rowMap);
      _settingsCache[normalizedCity] = settings;
      notifyListeners();
      print('✅ Successfully loaded city settings for $normalizedCity');
      return settings;
    } catch (e) {
      print('❌ Error loading city settings for $city: $e');
      return null;
    }
  }

  /// Clear cache
  void clearCache() {
    _settingsCache.clear();
    notifyListeners();
  }
}

