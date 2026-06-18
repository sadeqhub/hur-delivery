import '../../../core/network/api_client.dart';

class DriverRepository {
  DriverRepository._();
  static final DriverRepository instance = DriverRepository._();

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

  /// Calls the `check_dropoff_proximity` RPC to evaluate whether the driver
  /// has reached the delivery drop-off point and should stop the delivery timer.
  ///
  /// Returns `true` if the timer was stopped, `false` otherwise.
  Future<bool> checkDropoffProximity({
    required String orderId,
    required String driverId,
    required double driverLatitude,
    required double driverLongitude,
  }) async {
    final result = await ApiClient.instance.rpc<dynamic>(
      'check_dropoff_proximity',
      params: {
        'p_order_id': orderId,
        'p_driver_id': driverId,
        'p_driver_latitude': driverLatitude,
        'p_driver_longitude': driverLongitude,
      },
    );
    return result is Map && result['timer_stopped'] == true;
  }
}
