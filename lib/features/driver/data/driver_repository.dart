import '../../../core/errors/error_mapper.dart';
import '../../../core/logging/logger.dart';
import '../../../core/network/api_client.dart';

class DriverRepository {
  DriverRepository._();
  static final DriverRepository instance = DriverRepository._();

  static const _tag = 'DriverRepository';

  Future<Map<String, dynamic>?> getDriverRankAndCity(String driverId) =>
      ApiClient.instance
          .from('users')
          .select('rank, city')
          .eq('id', driverId)
          .maybeSingle();

  Future<double> getDriverMonthlyOnlineHours(String driverId) async {
    final result = await ApiClient.instance.rpc(
      'get_driver_monthly_online_hours',
      params: {'p_driver_id': driverId},
    );
    return (result as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getActiveOrdersWithPendingLocation(
      String driverId) async {
    final response = await ApiClient.instance
        .from('orders')
        .select(
            'id, customer_location_provided, driver_notified_location, delivery_latitude, delivery_longitude, customer_name, delivery_address, coordinates_auto_updated')
        .eq('driver_id', driverId)
        .inFilter('status', ['assigned', 'accepted', 'on_the_way', 'picked_up'])
        .eq('customer_location_provided', true)
        .eq('driver_notified_location', false)
        .eq('coordinates_auto_updated', false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Fetches name/phone for a merchant so the driver can initiate a call.
  Future<Map<String, dynamic>?> getMerchantContactInfo(
      String merchantId) async {
    Logger.d(_tag, 'getMerchantContactInfo: ${Logger.redactId(merchantId)}');
    try {
      return await ApiClient.instance
          .from('users')
          .select('id, phone, name, store_name')
          .eq('id', merchantId)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));
    } catch (e, st) {
      Logger.e(_tag, 'getMerchantContactInfo failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  /// Calls the `check_dropoff_proximity` RPC to stop the delivery timer when
  /// the driver is near the drop-off point.
  ///
  /// Returns the RPC result map, or null if the call fails (non-fatal).
  Future<Map<String, dynamic>?> checkDropoffProximity({
    required String orderId,
    required String driverId,
    required double driverLatitude,
    required double driverLongitude,
  }) async {
    Logger.d(
        _tag,
        'checkDropoffProximity: order=${Logger.redactId(orderId)}'
        ' driver=${Logger.redactId(driverId)}');
    try {
      final result = await ApiClient.instance.rpc<dynamic>(
        'check_dropoff_proximity',
        params: {
          'p_order_id': orderId,
          'p_driver_id': driverId,
          'p_driver_latitude': driverLatitude,
          'p_driver_longitude': driverLongitude,
        },
      ).timeout(const Duration(seconds: 10));
      return result is Map ? Map<String, dynamic>.from(result) : null;
    } catch (e, st) {
      Logger.e(_tag, 'checkDropoffProximity failed', error: e, stack: st);
      // Non-fatal: proximity check failure must not crash the dashboard.
      return null;
    }
  }
}
