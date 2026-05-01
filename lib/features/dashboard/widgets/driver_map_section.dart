import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/location_provider.dart';
import '../../../shared/models/order_model.dart';
import '../providers/active_order_provider.dart';
import 'state_of_the_art_map_widget.dart';

/// Full-screen Mapbox map section for the driver dashboard.
///
/// **Architecture improvement over the old `Consumer3`:**
///   The monolith used `Consumer3<LocationProvider, AuthProvider, OrderProvider>`
///   which rebuilt the entire map on every location tick (every 5 s), every auth
///   change, and every unrelated order update.
///
///   This widget uses two nested `Selector`s:
///   1. `Selector<LocationProvider, ({double lat, double lng})>` — rebuilds only
///      when the driver position coordinate pair changes (needed for map marker).
///   2. `Selector<ActiveOrderProvider, (List<OrderModel>, int)>` — rebuilds only
///      when the active order list or current page index changes (not on every
///      `OrderProvider.notifyListeners()`).
///
///   Auth data is read once via `context.read<AuthProvider>()` inside the builder
///   (no subscription) so auth changes don't trigger map rebuilds.
///
///   The [bottomOverlay] widget is built by the dashboard shell and passed in so
///   complex card-building logic doesn't need to live here.
class DriverMapSection extends StatefulWidget {
  final bool hasLocationPermission;
  final GlobalKey<StateOfTheArtMapWidgetState> mapKey;
  final bool isOrderCardExpanded;
  final double bottomOverlayInset;

  /// The order-card pager built by the shell, rendered inside the map's Stack.
  final Widget bottomOverlay;

  /// Notified when the user pans / zooms the map (for debounced outer setState).
  final void Function(double lat, double lng)? onCameraMoved;

  const DriverMapSection({
    super.key,
    required this.hasLocationPermission,
    required this.mapKey,
    required this.isOrderCardExpanded,
    required this.bottomOverlayInset,
    required this.bottomOverlay,
    this.onCameraMoved,
  });

  @override
  State<DriverMapSection> createState() => _DriverMapSectionState();
}

class _DriverMapSectionState extends State<DriverMapSection> {
  Timer? _gestureDebounce;

  @override
  void dispose() {
    _gestureDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.hasLocationPermission) {
      return const _PermissionPlaceholder();
    }

    if (kIsWeb) {
      return const _WebMapPlaceholder();
    }

    // ── Outer Selector: position ────────────────────────────────────────────
    return Selector<LocationProvider, ({double lat, double lng})>(
      selector: (_, lp) {
        final pos = lp.currentPosition;
        final auth = context.read<AuthProvider>();
        return (
          lat: pos?.latitude ?? auth.user?.latitude ?? 33.3152,
          lng: pos?.longitude ?? auth.user?.longitude ?? 44.3661,
        );
      },
      builder: (context, position, _) {
        // ── Inner Selector: active orders ───────────────────────────────────
        return Selector<ActiveOrderProvider, (List<OrderModel>, int)>(
          selector: (_, ap) => (ap.orders, ap.currentIndex),
          builder: (context, orderData, _) {
            final (orders, currentIndex) = orderData;

            final currentOrder =
                orders.isNotEmpty ? orders[currentIndex] : null;

            final driverLocationMap = {
              'latitude': position.lat,
              'longitude': position.lng,
            };

            // Only wire a camera-change callback to the platform view when
            // the parent actually wants notifications. Otherwise we'd pay the
            // per-frame debounce-timer allocation for nothing — and on iOS
            // every fired callback hops the platform channel.
            final outer = widget.onCameraMoved;
            final cameraCb = outer == null
                ? null
                : (double lat, double lng) {
                    _gestureDebounce?.cancel();
                    _gestureDebounce = Timer(
                      const Duration(milliseconds: 100),
                      () {
                        if (mounted) outer(lat, lng);
                      },
                    );
                  };

            return StateOfTheArtMapWidget(
              key: widget.mapKey,
              centerLat: position.lat,
              centerLng: position.lng,
              activeOrder: currentOrder,
              driverLocation: driverLocationMap,
              isOrderCardExpanded: widget.isOrderCardExpanded,
              bottomOverlayInset: widget.bottomOverlayInset,
              allActiveOrderIds: orders.map((o) => o.id).toList(),
              onCameraMoved: cameraCb,
              bottomOverlay: widget.bottomOverlay,
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholders
// ---------------------------------------------------------------------------

class _PermissionPlaceholder extends StatelessWidget {
  const _PermissionPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 12),
          Text(
            'في انتظار إذن الموقع…',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _WebMapPlaceholder extends StatelessWidget {
  const _WebMapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'الخريطة غير متاحة على الويب',
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}
