import 'package:geolocator/geolocator.dart' as geo;

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../driver/data/driver_repository.dart';

/// Owns dropoff-proximity checking for a driver session.
///
/// The 5 s GPS→DB location push that previously lived here has been removed:
/// the foreground background-service already owns that write and keeping a
/// second competing timer caused positional spikes and double-writes.
///
/// This class now only:
///   1. Ensures the foreground location stream is running (for map display).
///   2. Checks dropoff proximity on each location update from [LocationProvider].
class DriverLocationManager {
  bool _running = false;

  AuthProvider? _authProvider;
  LocationProvider? _locationProvider;
  OrderProvider? _orderProvider;

  bool get isRunning => _running;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Start proximity checking.
  ///
  /// Idempotent — calling start() while already running is a no-op.
  void start({
    required AuthProvider authProvider,
    required LocationProvider locationProvider,
    required OrderProvider orderProvider,
  }) {
    if (_running) return;
    _running = true;

    _authProvider = authProvider;
    _locationProvider = locationProvider;
    _orderProvider = orderProvider;

    // Ensure the foreground position stream is running (for map display).
    if (!locationProvider.isTracking) {
      locationProvider.startLocationTracking();
    }
  }

  /// Stop proximity checking.  Foreground location tracking in
  /// [LocationProvider] is intentionally kept running so the driver can
  /// still see their position on the map while offline.
  void stop() {
    _running = false;
  }

  void dispose() => stop();

  // ---------------------------------------------------------------------------
  // Public — called by the foreground location service after each GPS fix
  // ---------------------------------------------------------------------------

  /// Check dropoff proximity for active on_the_way orders.
  ///
  /// Call this after each GPS fix from the background service to avoid
  /// spawning a separate timer.
  Future<void> checkDropoffProximity(geo.Position driverPosition) async {
    if (!_running) return;
    await _checkDropoffProximity(driverPosition);
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<void> _checkDropoffProximity(geo.Position driverPosition) async {
    final auth = _authProvider;
    final orders = _orderProvider;
    if (auth == null || orders == null || auth.user == null) return;

    final activeOrders = orders.orders.where((order) =>
        order.isOnTheWay &&
        order.driverId == auth.user!.id &&
        order.deliveryTimerStartedAt != null &&
        order.deliveryTimerStoppedAt == null);

    for (final order in activeOrders) {
      try {
        final timerStopped = await DriverRepository.instance.checkDropoffProximity(
          orderId: order.id,
          driverId: auth.user!.id,
          driverLatitude: driverPosition.latitude,
          driverLongitude: driverPosition.longitude,
        );

        if (timerStopped) {
          // Reload orders to reflect the updated timer status.
          await orders.initialize();
        }
      } catch (_) {}
    }
  }
}
