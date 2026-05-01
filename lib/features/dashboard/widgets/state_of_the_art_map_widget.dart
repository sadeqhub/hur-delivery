import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../shared/models/order_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/map_style_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../shared/widgets/navigation_overlay_system.dart';
import 'state_of_the_art_navigation.dart';

/// State-of-the-art map widget with best practices
class StateOfTheArtMapWidget extends StatefulWidget {
  final OrderModel? activeOrder;
  final dynamic driverLocation;
  final double centerLat;
  final double centerLng;
  final bool isOrderCardExpanded;
  final double bottomOverlayInset;
  final Function(double lat, double lng)?
      onCameraMoved; // Callback when map is interacted with
  final List<String>?
      allActiveOrderIds; // All active order IDs for the driver (for cleanup)
  /// Widget rendered inside this widget's own Stack, directly above the Mapbox
  /// platform view.  Placing Flutter overlays here (instead of in an ancestor
  /// Stack) guarantees they receive a dedicated FlutterOverlayView on iOS,
  /// which prevents Mapbox's UIGestureRecognizer from absorbing touches after
  /// a pan/zoom gesture.
  final Widget? bottomOverlay;

  const StateOfTheArtMapWidget({
    super.key,
    this.activeOrder,
    this.driverLocation,
    required this.centerLat,
    required this.centerLng,
    this.isOrderCardExpanded = false,
    this.bottomOverlayInset = 0,
    this.onCameraMoved,
    this.allActiveOrderIds,
    this.bottomOverlay,
  });

  @override
  State<StateOfTheArtMapWidget> createState() => StateOfTheArtMapWidgetState();
}

class StateOfTheArtMapWidgetState extends State<StateOfTheArtMapWidget> {
  MapboxMap? _mapboxMap;
  final StateOfTheArtNavigation _navigationSystem = StateOfTheArtNavigation();
  bool _isMapReady = false;
  String? _currentMapStyle;
  String? _pendingMapStyle;
  String?
      _initialMapStyle; // Locked on first build; MapWidget.styleUri never changes after that
  bool _isProgrammaticCameraMove = false; // Track programmatic camera moves
  bool _shouldApplyActiveOrder = false; // Queue order until map ready
  OrderModel? _queuedOrder;
  String? _lastActiveOrderId; // Track last active order ID to detect changes
  bool _isChangingStyle =
      false; // Track if we're changing map style to preserve annotations
  OrderModel? _preservedOrder; // Preserve active order during style change

  // Public methods for external control
  void clearCoordinateCache() {
    print(
        '🧹 State-of-the-Art Map: Clearing coordinate cache (no-op in this widget)');
    // This widget doesn't have coordinate caching, but method is provided for compatibility
  }

  Future<void> forceRouteRecalculation(OrderModel order) async {
    print('🔄 State-of-the-Art Map: Force route recalculation requested');

    if (!_isMapReady) {
      print('⚠️  Map not ready, cannot recalculate route');
      return;
    }

    try {
      // Clear all existing routes and annotations first
      print('🧹 Clearing all existing annotations...');
      await _navigationSystem.clearAll();

      // Wait a moment for clearing to complete
      await Future.delayed(const Duration(milliseconds: 150));

      // Set the active order which will trigger route calculation
      print('📍 Setting active order with updated coordinates...');
      await _navigationSystem.setActiveOrder(order);

      print('✅ Route recalculation completed');
    } catch (e) {
      print('❌ Error in force route recalculation: $e');
    }
  }

  void _updateDriverMarkerFromWidget(dynamic location) {
    if (location == null) return;
    double? lat, lng, heading;
    if (location is Map) {
      lat = location['latitude'] as double?;
      lng = location['longitude'] as double?;
      heading = location['heading'] as double?;
    } else {
      try {
        final loc = location;
        lat = loc.latitude as double?;
        lng = loc.longitude as double?;
        heading = loc.heading as double?;
      } catch (_) {}
    }
    if (lat != null && lng != null) {
      _navigationSystem.updateDriverLocation(lat, lng, heading: heading);
    }
  }

  @override
  void initState() {
    super.initState();
    print('🚀 State-of-the-Art Map: Initializing...');

    // If driver location is already available, schedule marker creation
    if (widget.driverLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateDriverMarkerFromWidget(widget.driverLocation);
        }
      });
    }
  }

  @override
  void didUpdateWidget(StateOfTheArtMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if active order changed
    if (widget.activeOrder?.id != oldWidget.activeOrder?.id) {
      _handleOrderChange();
    }

    // Check if the list of all active orders changed (to clean up orphaned annotations)
    final oldOrderIdsString = oldWidget.allActiveOrderIds?.join(',') ?? '';
    final newOrderIdsString = widget.allActiveOrderIds?.join(',') ?? '';
    if (oldOrderIdsString != newOrderIdsString && _isMapReady) {
      print(
          '🔄 State-of-the-Art Map: Active orders list changed, cleaning up orphaned annotations');
      _cleanupOrphanedAnnotations();
    }

    // Driver location changed: update driver marker IMMEDIATELY (remove _isMapReady check)
    // Check if location actually changed (not just reference)
    bool locationChanged = false;
    if (widget.driverLocation != oldWidget.driverLocation) {
      if (widget.driverLocation == null || oldWidget.driverLocation == null) {
        locationChanged = true;
      } else {
        // Compare coordinates
        double? newLat, newLng, oldLat, oldLng;
        if (widget.driverLocation is Map) {
          newLat = widget.driverLocation['latitude'] as double?;
          newLng = widget.driverLocation['longitude'] as double?;
        }
        if (oldWidget.driverLocation is Map) {
          oldLat = oldWidget.driverLocation['latitude'] as double?;
          oldLng = oldWidget.driverLocation['longitude'] as double?;
        }
        locationChanged = (newLat != oldLat || newLng != oldLng);
      }
    }

    if (locationChanged && widget.driverLocation != null) {
      _updateDriverMarkerFromWidget(widget.driverLocation);
    }
  }

  void _handleOrderChange() {
    final currentOrderId = widget.activeOrder?.id;
    final lastOrderId = _lastActiveOrderId;

    // Detect order change
    if (currentOrderId != lastOrderId) {
      print(
          '🔄 State-of-the-Art Map: Order changed from $lastOrderId to $currentOrderId');
      _lastActiveOrderId = currentOrderId;

      // Clear orphaned annotations when order changes
      if (_isMapReady) {
        _cleanupOrphanedAnnotations();
      }
    }

    if (widget.activeOrder != null) {
      _queuedOrder = widget.activeOrder;
      if (_isMapReady) {
        _setActiveOrder(widget.activeOrder!);
      } else {
        _shouldApplyActiveOrder = true;
      }
    } else {
      _shouldApplyActiveOrder = false;
      _queuedOrder = null;
      // If the order is cleared while a style change is in-flight, do not restore it
      // when the new style finishes loading.
      if (_isChangingStyle) {
        _preservedOrder = null;
      }
      if (_isMapReady) {
        _clearAllAnnotations();
      }
    }
  }

  /// Clean up annotations for orders that are no longer active
  Future<void> _cleanupOrphanedAnnotations() async {
    try {
      // Use the provided list of all active order IDs, or fall back to current order
      final activeOrderIds = widget.allActiveOrderIds ??
          (widget.activeOrder != null ? [widget.activeOrder!.id] : <String>[]);

      print(
          '🧹 State-of-the-Art Map: Cleaning up annotations, keeping: $activeOrderIds');

      // Clear annotations for orders not in the active list
      await _navigationSystem.clearOrphanedAnnotations(activeOrderIds);
    } catch (e) {
      print(
          '❌ State-of-the-Art Map: Error cleaning up orphaned annotations: $e');
    }
  }

  Future<void> _setActiveOrder(OrderModel order) async {
    _queuedOrder = order;

    if (!_isMapReady) {
      _shouldApplyActiveOrder = true;
      return;
    }

    try {
      await _navigationSystem.setActiveOrder(order);
      print('✅ State-of-the-Art Map: Active order set - ${order.id}');

      if (!mounted) return;

      if (widget.activeOrder != null && widget.activeOrder!.id == order.id) {
        // Run immediately without arbitrary UI animation delays
        Future.microtask(() {
          if (mounted) _overviewFullRoute(order);
        });
      } else if (widget.activeOrder != null &&
          widget.activeOrder!.id != order.id) {
        _queuedOrder = widget.activeOrder;
        // Active order changed while we were processing; apply the new one immediately
        _applyPendingOrder();
      } else if (widget.activeOrder == null) {
        // Order removed while processing, ensure map is cleared
        _clearAllAnnotations();
      }
      _shouldApplyActiveOrder = false;
      _queuedOrder = null;
    } catch (e) {
      print('❌ State-of-the-Art Map: Error setting active order: $e');
    }
  }

  Future<void> forceRefreshActiveOrder([OrderModel? overrideOrder]) async {
    final targetOrder = overrideOrder ?? widget.activeOrder;
    if (targetOrder == null) {
      print(
          '⚠️ State-of-the-Art Map: forceRefreshActiveOrder called with null order');
      return;
    }

    _queuedOrder = targetOrder;

    if (!_isMapReady) {
      _shouldApplyActiveOrder = true;
      return;
    }

    try {
      await _navigationSystem.setActiveOrder(targetOrder);
      if (mounted) {
        // Run immediately
        Future.microtask(() {
          if (mounted) _overviewFullRoute(targetOrder);
        });
      }
    } catch (e) {
      print('❌ State-of-the-Art Map: forceRefreshActiveOrder failed: $e');
    }
  }

  // Public method to refocus camera on a specific location
  void refocusCamera(double latitude, double longitude, {double zoom = 16.0}) {
    if (_mapboxMap == null) return;

    // Set flag to prevent onCameraMoved from triggering
    _isProgrammaticCameraMove = true;

    _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(longitude, latitude)),
        zoom: zoom,
        bearing: 0.0,
        pitch: 0.0,
      ),
      MapAnimationOptions(duration: 1000),
    );

    // Reset flag after animation completes
    Future.delayed(const Duration(milliseconds: 1100), () {
      _isProgrammaticCameraMove = false;
    });
  }

  /// Public hook so parent widgets can force-clear annotations immediately
  Future<void> forceClearAnnotations() async {
    await _clearAllAnnotations();
  }

  void _overviewFullRoute([OrderModel? order]) {
    if (_mapboxMap == null) return;

    final targetOrder = order ?? widget.activeOrder;
    if (targetOrder == null) return;

    final pickupLat = targetOrder.pickupLatitude;
    final pickupLng = targetOrder.pickupLongitude;
    final deliveryLat = targetOrder.deliveryLatitude;
    final deliveryLng = targetOrder.deliveryLongitude;

    final centerLat = (pickupLat + deliveryLat) / 2;
    final centerLng = (pickupLng + deliveryLng) / 2;

    // Calculate distance to determine optimal zoom
    final latDiff = (pickupLat - deliveryLat).abs();
    final lngDiff = (pickupLng - deliveryLng).abs();
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    // Improved zoom calculation with padding to show both pins clearly
    double zoom = 13.0;
    if (maxDiff > 0.2) {
      zoom = 10.0; // Very far apart
    } else if (maxDiff > 0.1)
      zoom = 11.0;
    else if (maxDiff > 0.05)
      zoom = 12.0;
    else
      zoom = 13.0;

    // Use flyTo with animation to smoothly refocus on the route
    _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(centerLng, centerLat)),
        zoom: zoom,
        bearing: 0.0,
        pitch: 0.0,
      ),
      MapAnimationOptions(
          duration: 1500), // Slightly longer for smoother transition
    );

    print(
        '🗺️ Map refocused to show route: center=$centerLat,$centerLng, zoom=$zoom');
  }

  Future<void> _clearAllAnnotations() async {
    if (!_isMapReady) return;

    try {
      await _navigationSystem.clearAll();
      print('🧹 State-of-the-Art Map: All annotations cleared');
    } catch (e) {
      print('❌ State-of-the-Art Map: Error clearing annotations: $e');
    }
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    try {
      print('🗺️ State-of-the-Art Map: Map created, initializing...');

      // Disable compass
      try {
        await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
        print('✅ Compass disabled');
      } catch (e) {
        print('⚠️ Error disabling compass: $e');
      }


      // Initialize the state-of-the-art navigation system (in parallel)
      // Don't block marker creation on this
      _navigationSystem.initialize(mapboxMap).then((success) {
        if (success && mounted) {
          _isMapReady = true;
          print(
              '✅ State-of-the-Art Map: Map ready and navigation system initialized');

          // Ensure marker is created once navigation is ready
          if (widget.driverLocation != null) {
            _updateDriverMarkerFromWidget(widget.driverLocation);
          }

          _applyPendingOrder();
        } else if (!success && mounted) {
          print(
              '⚠️ Navigation system initialization failed, retrying immediately...');
          // Retry initialization immediately (no delay)
          _navigationSystem.initialize(_mapboxMap!).then((retrySuccess) {
            if (retrySuccess && mounted) {
              _isMapReady = true;
              _applyPendingOrder();
            }
          });
        }
      });
    } catch (e) {
      print('❌ State-of-the-Art Map: Error in _onMapCreated: $e');
    }
  }

  @override
  void _applyPendingOrder() {
    if (!_isMapReady) return;

    final orderToApply = widget.activeOrder ?? _queuedOrder;

    if (orderToApply != null) {
      _setActiveOrder(orderToApply);
    } else if (_shouldApplyActiveOrder) {
      _shouldApplyActiveOrder = false;
      _clearAllAnnotations();
    }
  }

  @override
  void dispose() {
    _navigationSystem.dispose();
    _isChangingStyle = false;
    _preservedOrder = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main Mapbox Map with dynamic theme-based styling
        Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            final mapStyle = MapStyleHelper.getMapStyle(context);

            // Lock the initial style once so MapWidget.styleUri never changes.
            // All style switches after the first load are handled imperatively via
            // loadStyleURI(). Letting styleUri change on an existing MapWidget causes
            // Mapbox to call loadStyleURI() internally a second time, which fires
            // onStyleLoadedListener twice and duplicates the driver marker.
            _initialMapStyle ??= mapStyle;

            // Handle map style changes
            if (_currentMapStyle != null &&
                _currentMapStyle != mapStyle &&
                _mapboxMap != null) {
              // Map style changed, preserve state and restore after style loads
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (_mapboxMap != null && mounted && !_isChangingStyle) {
                  _isChangingStyle = true;
                  _preservedOrder =
                      widget.activeOrder; // Preserve current order
                  _pendingMapStyle = mapStyle;
                  _currentMapStyle = mapStyle;

                  print(
                      '🔄 Map style changing to $mapStyle, preserving state...');

                  // Load new style - this will trigger onStyleLoadedListener
                  await _mapboxMap!.loadStyleURI(mapStyle);
                }
              });
            } else {
              _currentMapStyle ??= mapStyle;
            }

            // Always pass the locked initial style to MapWidget so styleUri never
            // changes and Mapbox does not fire a redundant second loadStyleURI.
            final effectiveStyle = _initialMapStyle!;

            return MapWidget(
              key: const ValueKey("driver_map_widget"),
              cameraOptions: CameraOptions(
                center: Point(
                    coordinates: Position(widget.centerLng, widget.centerLat)),
                zoom: 15.0,
              ),
              styleUri: effectiveStyle,
              // Explicitly declare which gestures this platform view claims.
              // This lets Flutter's gesture router keep taps in the Flutter
              // arena so they can reach overlaid widgets (e.g. the order card)
              // without competition from Mapbox's native UIGestureRecognizers.
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
                Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
              },
              onMapCreated: _onMapCreated,
              onStyleLoadedListener: (_) async {
                if (_mapboxMap != null) {

                  // If we're changing style, restore all annotations
                  if (_isChangingStyle) {
                    print(
                        '✅ Style loaded after change, restoring annotations...');
                    try {
                      _currentMapStyle = _pendingMapStyle ?? _currentMapStyle;
                      _pendingMapStyle = null;

                      await _navigationSystem.rebuildAnnotations();

                      if (widget.driverLocation != null) {
                        _updateDriverMarkerFromWidget(widget.driverLocation);
                      }

                      _isChangingStyle = false;
                      _preservedOrder = null;
                      print('✅ All annotations restored after style change');
                    } catch (e) {
                      print(
                          '❌ Error restoring annotations after style change: $e');
                      _isChangingStyle = false;
                      _preservedOrder = null;
                    }
                  }
                }
              },
              onCameraChangeListener: (cameraChangedEventData) {
                // Notify parent when map is interacted with (but not for programmatic moves)
                if (widget.onCameraMoved != null &&
                    !_isProgrammaticCameraMove) {
                  final center = cameraChangedEventData.cameraState.center;
                  widget.onCameraMoved!(center.coordinates.lat.toDouble(),
                      center.coordinates.lng.toDouble());
                }
              },
            );
          },
        ),
        // Order card overlay — placed inside this Stack (adjacent to the
        // platform view) so Flutter creates a FlutterOverlayView for it on
        // iOS, preventing Mapbox gesture recognisers from absorbing taps
        // after a pan. Rendered BEFORE the floating nav button so the button
        // always wins hit-tests over the card (otherwise the order-cards
        // subtree absorbs taps that visually land on the FAB).
        if (widget.bottomOverlay != null) widget.bottomOverlay!,
        // Floating Navigation Button.
        //
        // Sits relatively above whatever footer is currently active —
        // either the swipeable order cards (`order_cards`) or, when there is
        // no active order, the bottom tab bar (`bottom_nav`). Reading
        // `controller.bottomInset` (the max of all registered overlays)
        // guarantees the button is never "behind" a footer regardless of
        // which one is mounted, and falls back to the system safe-area inset
        // before the first layout pass reports an overlay height.
        Builder(
          builder: (context) {
            final controller = NavigationOverlayScope.of(context);
            final systemNavBar = MediaQuery.of(context).viewPadding.bottom;
            // Collapsed order-card height (60) + bottom margin (8). When the
            // user expands the card we don't want the button to ride up with
            // it, so we clamp to this value.
            const collapsedCardSize = 60.0 + 8.0;
            const gap = 8.0; // tiny gap between button bottom and footer top
            // Default-floor used if no overlay has reported yet — keeps the
            // button safely above the OS gesture bar on the first frame.
            final fallback = systemNavBar + collapsedCardSize;

            if (controller == null) {
              return Positioned(
                bottom: fallback + gap,
                right: 16.0,
                child: _StateOfTheArtNavigationButton(
                  mapboxMap: _mapboxMap,
                  activeOrder: widget.activeOrder,
                  driverLocation: widget.driverLocation,
                ),
              );
            }
            return ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final orderCardsHeight = controller.getHeight('order_cards');
                final clampedCards = orderCardsHeight > 0
                    ? math.min(
                        orderCardsHeight, collapsedCardSize + systemNavBar)
                    : 0.0;
                // bottomInset is the tallest reported overlay (whichever of
                // `bottom_nav` / `order_cards` / future footers is mounted).
                // Clamping the order-cards contribution above means an
                // expanded card doesn't push the button up.
                final effectiveInset = math.max(
                  clampedCards,
                  // Use bottom_nav directly so it isn't clamped — the tab
                  // bar's full reported height (incl. safe-area zone) is the
                  // amount we actually need to clear when no order is active.
                  controller.getHeight('bottom_nav'),
                );
                final bottom = math.max(effectiveInset, fallback) + gap;
                return AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  bottom: bottom,
                  right: 16.0,
                  child: _StateOfTheArtNavigationButton(
                    mapboxMap: _mapboxMap,
                    activeOrder: widget.activeOrder,
                    driverLocation: widget.driverLocation,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatusIndicator() {
    final status = _navigationSystem.getStatus();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                status['initialized'] ? Icons.check_circle : Icons.error,
                color: status['initialized'] ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'State-of-the-Art Navigation',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Status: ${status['initialized'] ? 'Ready' : 'Not Ready'}',
            style: TextStyle(
              fontSize: 10,
              color: status['initialized'] ? Colors.green : Colors.red,
            ),
          ),
          Text(
            'Markers: ${status['markers']}, Routes: ${status['routes']}',
            style: const TextStyle(fontSize: 10),
          ),
          if (status['currentOrderId'] != null)
            Text(
              'Order: ${status['currentOrderId']}',
              style: const TextStyle(fontSize: 10),
            ),
        ],
      ),
    );
  }
}

/// State-of-the-art navigation button
class _StateOfTheArtNavigationButton extends StatefulWidget {
  final MapboxMap? mapboxMap;
  final dynamic activeOrder;
  final dynamic driverLocation;

  const _StateOfTheArtNavigationButton({
    this.mapboxMap,
    this.activeOrder,
    this.driverLocation,
  });

  @override
  State<_StateOfTheArtNavigationButton> createState() =>
      _StateOfTheArtNavigationButtonState();
}

class _StateOfTheArtNavigationButtonState
    extends State<_StateOfTheArtNavigationButton>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    // If no active order, directly navigate to driver location
    if (widget.activeOrder == null &&
        widget.driverLocation != null &&
        widget.mapboxMap != null) {
      _navigateToDriverLocation();
      return;
    }

    // If there IS an active order, toggle the navigation list
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _navigateToLocation(double lat, double lng, String locationName) {
    if (widget.mapboxMap == null) return;

    widget.mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: 16.0,
        bearing: 0.0,
      ),
      MapAnimationOptions(duration: 1000),
    );

    if (_isExpanded) {
      _toggleExpansion();
    }
  }

  void _navigateToDriverLocation() {
    if (widget.driverLocation == null || widget.mapboxMap == null) return;

    try {
      double? lat;
      double? lng;

      if (widget.driverLocation is Map) {
        lat = (widget.driverLocation as Map)['latitude'] as double?;
        lng = (widget.driverLocation as Map)['longitude'] as double?;
      } else {
        try {
          final dynamic loc = widget.driverLocation;
          lat = loc.latitude as double?;
          lng = loc.longitude as double?;
        } catch (e) {
          return;
        }
      }

      if (lat != null && lng != null && lat.isFinite && lng.isFinite) {
        _navigateToLocation(
            lat, lng, AppLocalizations.of(context).yourCurrentLocationLabel);
      }
    } catch (e) {
      // Silently handle errors
    }
  }

  void _navigateToStoreLocation() {
    if (widget.activeOrder != null) {
      _navigateToLocation(
        widget.activeOrder.pickupLatitude,
        widget.activeOrder.pickupLongitude,
        AppLocalizations.of(context).storeLocation,
      );
    }
  }

  void _navigateToDeliveryLocation() {
    if (widget.activeOrder != null) {
      _navigateToLocation(
        widget.activeOrder.deliveryLatitude,
        widget.activeOrder.deliveryLongitude,
        AppLocalizations.of(context).deliveryLocation,
      );
    }
  }

  void _showFullRoute() {
    if (widget.mapboxMap == null || widget.activeOrder == null) return;

    final pickupLat = widget.activeOrder.pickupLatitude;
    final pickupLng = widget.activeOrder.pickupLongitude;
    final deliveryLat = widget.activeOrder.deliveryLatitude;
    final deliveryLng = widget.activeOrder.deliveryLongitude;

    final centerLat = (pickupLat + deliveryLat) / 2;
    final centerLng = (pickupLng + deliveryLng) / 2;

    widget.mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(centerLng, centerLat)),
        zoom: 13.0,
        bearing: 0.0,
      ),
      MapAnimationOptions(duration: 1500),
    );

    _toggleExpansion();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Expanded menu items
        if (_isExpanded) ...[
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.scale(
                scale: _animation.value,
                child: Opacity(
                  opacity: _animation.value,
                  child: Column(
                    children: [
                      // Show full route
                      if (widget.activeOrder != null) ...[
                        Builder(
                          builder: (context) {
                            final loc = AppLocalizations.of(context);
                            return Column(
                              children: [
                                _buildNavButton(
                                  icon: Icons.route,
                                  label: loc.showRoute,
                                  onTap: _showFullRoute,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 8),
                                // Navigate to store
                                _buildNavButton(
                                  icon: Icons.store,
                                  label: loc.store,
                                  onTap: _navigateToStoreLocation,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 8),
                                // Navigate to delivery
                                _buildNavButton(
                                  icon: Icons.flag,
                                  label: loc.delivery,
                                  onTap: _navigateToDeliveryLocation,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 8),
                                // Navigate to driver location
                                if (widget.driverLocation != null)
                                  _buildNavButton(
                                    icon: Icons.my_location,
                                    label: loc.yourLocation,
                                    onTap: _navigateToDriverLocation,
                                    color: Colors.orange,
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        // Main floating button
        FloatingActionButton(
          onPressed: _toggleExpansion,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          child: AnimatedRotation(
            turns: _isExpanded ? 0.125 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Icon(_isExpanded ? Icons.close : Icons.navigation),
          ),
        ),
      ],
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return SizedBox(
      width: 120,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
