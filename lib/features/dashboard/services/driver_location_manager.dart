import 'dart:async';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/providers/order_provider.dart';

/// Owns all background location work for a driver session.
///
/// **Old architecture problems fixed here:**
///   - There were TWO competing timers: `_locationTimer` (5 s, push GPS→DB)
///     and `_driverLocationTimer` (10 s, read DB→local state).  The DB
///     read-back timer was redundant and caused positional spikes when the
///     reads arrived out of order.  This class keeps only the 5 s push.
///   - Both timers could be double-started because `_startLocationTracking()`
///     was called from 3 different call sites without a running-guard.
///     The [_running] flag prevents that.
///   - There was a fire-and-forget "aggressive init" loop (10 × 1 s retries
///     after init) that could overlap with the normal 5 s timer.  Removed.
class DriverLocationManager {
  bool _running = false;
  Timer? _timer;

  AuthProvider? _authProvider;
  LocationProvider? _locationProvider;
  OrderProvider? _orderProvider;

  bool get isRunning => _running;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Start pushing GPS location to the database every 5 seconds.
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

    // Ensure the foreground position stream is running (for map display and
    // for getCurrentLocation() calls below).
    if (!locationProvider.isTracking) {
      locationProvider.startLocationTracking();
    }

    // Immediate push on start so the driver's marker appears right away.
    unawaited(_pushLocation());

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_pushLocation());
    });
  }

  /// Stop background DB updates.  Foreground location tracking in
  /// [LocationProvider] is intentionally kept running so the driver can
  /// still see their position on the map while offline.
  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    // Do NOT call locationProvider.stopLocationTracking() here.
  }

  void dispose() => stop();

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<void> _pushLocation() async {
    final auth = _authProvider;
    final loc = _locationProvider;
    if (auth == null || loc == null || auth.user == null) return;

    try {
      final position = await loc
          .getCurrentLocation()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);

      if (position == null || !_running) return;

      await auth
          .updateUserLocation(
            position.latitude,
            position.longitude,
            accuracy: position.accuracy,
            heading: position.heading,
            speed: position.speed,
          )
          .timeout(const Duration(seconds: 5), onTimeout: () => false);

      // Check dropoff proximity for active on_the_way orders (non-blocking).
      unawaited(_checkDropoffProximity(position));
    } catch (_) {
      // Silent — location errors are transient and should not crash the session.
    }
  }

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
        final result = await Supabase.instance.client.rpc(
          'check_dropoff_proximity',
          params: {
            'p_order_id': order.id,
            'p_driver_id': auth.user!.id,
            'p_driver_latitude': driverPosition.latitude,
            'p_driver_longitude': driverPosition.longitude,
          },
        );

        if (result is Map && result['timer_stopped'] == true) {
          // Reload orders to reflect the updated timer status.
          await orders.initialize();
        }
      } catch (_) {}
    }
  }
}
