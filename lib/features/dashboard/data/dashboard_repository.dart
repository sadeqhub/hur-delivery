import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/api_client.dart';
import '../../../core/errors/app_failure.dart';

class DashboardRepository {
  DashboardRepository._();
  static final DashboardRepository instance = DashboardRepository._();

  // ---------------------------------------------------------------------------
  // Merchant dashboard queries
  // ---------------------------------------------------------------------------

  /// Returns the city string for the given merchant, or empty string if absent.
  Future<String> getMerchantCity(String merchantId) async {
    try {
      final row = await ApiClient.instance
          .from('users')
          .select('city')
          .eq('id', merchantId)
          .maybeSingle();
      return (row?['city'] ?? '').toString();
    } catch (e) {
      throw AppFailure('Failed to fetch merchant city', cause: e);
    }
  }

  /// Returns a list of driver-ID strings that are online in [city].
  Future<List<String>> getOnlineDriversInCity(String city) async {
    try {
      final rows = await ApiClient.instance
          .from('users')
          .select('id')
          .eq('role', 'driver')
          .eq('is_online', true)
          .ilike('city', city);
      return (rows as List<dynamic>)
          .map((d) => d['id'] as String?)
          .whereType<String>()
          .toList();
    } catch (e) {
      throw AppFailure('Failed to fetch online drivers in city', cause: e);
    }
  }

  /// Returns a list of driver_id strings from orders that are currently active
  /// for the provided set of [driverIds].
  Future<List<String>> getActiveOrderDriverIds(List<String> driverIds) async {
    try {
      final rows = await ApiClient.instance
          .from('orders')
          .select('driver_id')
          .inFilter('driver_id', driverIds)
          .inFilter(
              'status', ['pending', 'assigned', 'accepted', 'on_the_way']);
      return (rows as List<dynamic>)
          .map((o) => o['driver_id'] as String?)
          .whereType<String>()
          .toList();
    } catch (e) {
      throw AppFailure('Failed to fetch active order driver IDs', cause: e);
    }
  }

  // ---------------------------------------------------------------------------
  // Driver dashboard queries
  // ---------------------------------------------------------------------------

  /// Fetches the merchant user row (id, phone, name, store_name) by [merchantId].
  /// Returns null if no matching row is found.
  Future<Map<String, dynamic>?> getMerchantDetails(String merchantId) async {
    try {
      final row = await ApiClient.instance
          .from('users')
          .select('id, phone, name, store_name')
          .eq('id', merchantId)
          .maybeSingle();
      return row;
    } catch (e) {
      throw AppFailure('Failed to fetch merchant details', cause: e);
    }
  }

  /// Calls the `check_dropoff_proximity` RPC and returns the raw result map.
  Future<dynamic> checkDropoffProximity({
    required String orderId,
    required String driverId,
    required double driverLatitude,
    required double driverLongitude,
  }) async {
    try {
      return await ApiClient.instance.rpc(
        'check_dropoff_proximity',
        params: {
          'p_order_id': orderId,
          'p_driver_id': driverId,
          'p_driver_latitude': driverLatitude,
          'p_driver_longitude': driverLongitude,
        },
      );
    } catch (e) {
      throw AppFailure('Failed to check dropoff proximity', cause: e);
    }
  }

  // ---------------------------------------------------------------------------
  // Merchant map widget queries
  // ---------------------------------------------------------------------------

  /// Fetches the most recent location row for [driverId] from the
  /// `recent_driver_locations` materialized view.
  Future<Map<String, dynamic>?> getRecentDriverLocation(
      String driverId) async {
    try {
      final row = await ApiClient.instance
          .from('recent_driver_locations')
          .select()
          .eq('driver_id', driverId)
          .maybeSingle();
      return row;
    } catch (e) {
      throw AppFailure('Failed to fetch driver location', cause: e);
    }
  }
}
