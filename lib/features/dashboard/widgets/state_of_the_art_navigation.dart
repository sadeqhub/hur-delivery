import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../shared/models/order_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/route_cache_service.dart';

/// State-of-the-art navigation system using best practices
class StateOfTheArtNavigation {
  static final StateOfTheArtNavigation _instance =
      StateOfTheArtNavigation._internal();
  factory StateOfTheArtNavigation() => _instance;
  StateOfTheArtNavigation._internal();

  // Core managers
  PolylineAnnotationManager? _polylineManager;
  PointAnnotationManager? _pointManager;
  PointAnnotationManager? _driverPointManager;
  CircleAnnotationManager? _circleManager;
  MapboxMap? _mapboxMap;

  // State
  bool _isInitialized = false;
  String? _currentOrderId;

  // Locks to prevent concurrent operations
  bool _isUpdatingRoute = false;
  bool _isSettingOrder = false; // prevents concurrent setActiveOrder calls

  // Annotations - cached per order
  final Map<String, PolylineAnnotation> _routes = {};
  final Map<String, PointAnnotation> _markers = {};
  final List<PointAnnotation> _neighborhoodLabels = [];

  // Cache order data needed to recreate annotations
  final Map<String, OrderModel> _cachedOrderData = {};

  // Track which orders have cached annotations and which is currently visible
  final Set<String> _cachedOrderIds = {};
  String? _visibleOrderId;

  /// Initialize the state-of-the-art system
  Future<bool> initialize(MapboxMap mapboxMap) async {
    try {
      print('🚀 State-of-the-Art: Initializing navigation system...');

      _mapboxMap = mapboxMap;

      // Create annotation managers and prepare pins in parallel for instant loading
      await Future.wait([
        _mapboxMap!.annotations
            .createPolylineAnnotationManager()
            .then((m) => _polylineManager = m),
        _mapboxMap!.annotations
            .createPointAnnotationManager()
            .then((m) => _pointManager = m),
        _mapboxMap!.annotations
            .createPointAnnotationManager()
            .then((m) => _driverPointManager = m),
        _mapboxMap!.annotations
            .createCircleAnnotationManager()
            .then((m) => _circleManager = m),
        _prepareSquarePinImages(), // Prepare pins in parallel
      ]);

      print('✅ State-of-the-Art: Annotation managers and pins ready');

      _isInitialized = true;
      print(
          '✅ State-of-the-Art: Navigation system initialized successfully - ready for instant annotations');
      return true;
    } catch (e) {
      print('❌ State-of-the-Art: Initialization failed: $e');
      // Retry once immediately (no delay)
      try {
        await Future.wait([
          _mapboxMap!.annotations
              .createPolylineAnnotationManager()
              .then((m) => _polylineManager = m),
          _mapboxMap!.annotations
              .createPointAnnotationManager()
              .then((m) => _pointManager = m),
          _mapboxMap!.annotations
              .createPointAnnotationManager()
              .then((m) => _driverPointManager = m),
          _mapboxMap!.annotations
              .createCircleAnnotationManager()
              .then((m) => _circleManager = m),
          _prepareSquarePinImages(),
        ]);
        _isInitialized = true;
        print('✅ State-of-the-Art: Navigation system initialized on retry');
        return true;
      } catch (retryError) {
        print(
            '❌ State-of-the-Art: Initialization retry also failed: $retryError');
        return false;
      }
    }
  }

  /// Set active order — shows only the focused order's annotations.
  ///
  /// Protected by [_isSettingOrder] so that a fast second call (e.g. from
  /// forceRefreshActiveOrder running in a post-frame callback) is dropped
  /// instead of racing with the first call and leaving stale markers visible.
  Future<void> setActiveOrder(OrderModel order) async {
    // Drop redundant / racing calls for the SAME order.
    if (_isSettingOrder) {
      print(
          '⚠️ State-of-the-Art: setActiveOrder already in progress, dropping duplicate call for ${order.id}');
      return;
    }
    _isSettingOrder = true;

    print('🎯 State-of-the-Art: Setting active order ${order.id}');

    // If not initialized, wait very briefly — initialization should be nearly instant.
    if (!_isInitialized) {
      print('⚠️ State-of-the-Art: Not initialized, waiting briefly...');
      int retries = 0;
      while (!_isInitialized && retries < 6) {
        await Future.delayed(const Duration(milliseconds: 50));
        retries++;
      }
      if (!_isInitialized) {
        print(
            '⚠️ State-of-the-Art: Not yet initialized, proceeding anyway (will retry)');
      } else {
        print(
            '✅ State-of-the-Art: Initialization completed, proceeding with order');
      }
    }

    try {
      // If a different order was visible, clear ALL its annotations from the map
      // before drawing the new one.
      if (_visibleOrderId != null && _visibleOrderId != order.id) {
        await _hideOrderAnnotations(_visibleOrderId!);
      }

      _currentOrderId = order.id;
      _visibleOrderId = order.id;
      _cachedOrderIds.add(order.id);
      _cachedOrderData[order.id] = order;

      // Always create fresh annotations for the newly focused order.
      // We never re-use cached annotation objects because deleted Mapbox
      // annotations become invalid — recreating is the safe path.
      print('🆕 State-of-the-Art: Creating annotations for order ${order.id}');

      await Future.wait([
        _createPickupMarker(order),
        _createDropoffMarker(order),
      ]);
      print('✅ State-of-the-Art: Pickup and dropoff markers created');

      await _createRoute(order);
      print('✅ State-of-the-Art: Order ${order.id} set successfully');
    } catch (e) {
      print('❌ State-of-the-Art: Error setting order: $e');
    } finally {
      _isSettingOrder = false;
    }
  }

  /// Hide the previous order's annotations by wiping ALL annotations from the
  /// managers and clearing the local cache.
  ///
  /// We use [deleteAll()] instead of per-annotation [delete()] because:
  ///  - Individual [delete()] calls can silently fail when the annotation
  ///    object is stale (e.g. after a Mapbox style change recreates managers),
  ///    which leaves orphaned markers visually on the map.
  ///  - Since only ONE order's annotations are ever rendered at a time the
  ///    managers only contain the previous order's items, so [deleteAll()] is
  ///    both safe and guaranteed to clear them.
  Future<void> _hideOrderAnnotations(String orderId) async {
    // Evict from local cache first (regardless of whether Mapbox calls succeed).
    _markers.remove('${orderId}_pickup');
    _markers.remove('${orderId}_dropoff');
    _routes.remove('${orderId}_route');

    // Wipe managers — this is unconditionally reliable.
    try {
      if (_pointManager != null) await _pointManager!.deleteAll();
    } catch (e) {
      print(
          '⚠️ State-of-the-Art: deleteAll() on pointManager failed hiding $orderId: $e');
    }
    try {
      if (_polylineManager != null) await _polylineManager!.deleteAll();
    } catch (e) {
      print(
          '⚠️ State-of-the-Art: deleteAll() on polylineManager failed hiding $orderId: $e');
    }

    // Clear any residual entries that might have leaked in from concurrent calls.
    _markers.clear();
    _routes.clear();

    print('👁️ Hidden ALL annotations (was showing order $orderId)');
  }

  /// Prepare and register square pin images with numbers (1, 2)
  Future<void> _prepareSquarePinImages() async {
    try {
      // HIGH RESOLUTION (3x scale) - 48 * 3 = 144px
      const int squareSize = 144; // pinhead size (3x for high resolution)
      const int needleHeight = 36; // pointer height (12 * 3)
      final pickupBytes = await _drawSquarePin(
        number: '1',
        background: const Color(0xFF011A47), // matches AppColors.primary
        text: Colors.white,
        squareSize: squareSize,
        needleHeight: needleHeight,
      );
      final dropoffBytes = await _drawSquarePin(
        number: '2',
        background:
            const Color(0xFFF59E0B), // Orange - matches AppColors.warning
        text: Colors.white,
        squareSize: squareSize,
        needleHeight: needleHeight,
      );

      // Add to style with correct signature: (name, pixelRatio, sdf, stretchX, stretchY, content, image)
      // HIGH RESOLUTION - 3x scale
      await _mapboxMap!.style.addStyleImage(
        'pin-1',
        1.0,
        MbxImage(
            width: squareSize,
            height: squareSize + needleHeight,
            data: pickupBytes),
        false,
        const <ImageStretches>[],
        const <ImageStretches>[],
        null,
      );

      await _mapboxMap!.style.addStyleImage(
        'pin-2',
        1.0,
        MbxImage(
            width: squareSize,
            height: squareSize + needleHeight,
            data: dropoffBytes),
        false,
        const <ImageStretches>[],
        const <ImageStretches>[],
        null,
      );
    } catch (e) {
      print('❌ State-of-the-Art: Failed preparing square pins: $e');
    }
  }

  /// Draw a square pin with centered number and a small needle underneath
  Future<Uint8List> _drawSquarePin({
    required String number,
    required Color background,
    required Color text,
    required int squareSize,
    required int needleHeight,
  }) async {
    final totalWidth = squareSize;
    final totalHeight = squareSize + needleHeight;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Square background
    final rect =
        Rect.fromLTWH(0, 0, squareSize.toDouble(), squareSize.toDouble());
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    final bgPaint = Paint()..color = background;
    canvas.drawRRect(rrect, bgPaint);

    // Needle (triangle) centered at bottom
    final double cx = squareSize / 2.0;
    final double base = squareSize * 0.28; // narrow base
    final Path needle = Path()
      ..moveTo(cx, totalHeight.toDouble())
      ..lineTo(cx - base / 2.0, squareSize.toDouble())
      ..lineTo(cx + base / 2.0, squareSize.toDouble())
      ..close();
    canvas.drawPath(needle, bgPaint);

    // Border around square and needle
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = squareSize * 0.06;
    canvas.drawRRect(rrect, border);
    canvas.drawPath(needle, border);

    // Number text centered inside square
    final textPainter = TextPainter(
      text: TextSpan(
        text: number,
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.w900,
          fontSize: squareSize * 0.46,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: squareSize.toDouble());

    final offset = Offset(
      (squareSize - textPainter.width) / 2,
      (squareSize - textPainter.height) / 2,
    );
    textPainter.paint(canvas, offset);

    final picture = recorder.endRecording();
    final image = await picture.toImage(totalWidth, totalHeight);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Create pickup marker using custom image
  Future<void> _createPickupMarker(OrderModel order) async {
    try {
      final markerId = '${order.id}_pickup';

      print(
          '📍 State-of-the-Art: Creating pickup marker at ${order.pickupLatitude}, ${order.pickupLongitude}');

      // Only remove if marker already exists (prevent flickering)
      if (_markers.containsKey(markerId)) {
        await _removeMarker(markerId);
      }

      // Create marker using custom square-numbered pin (1) - HIGH RES
      final marker = await _pointManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(order.pickupLongitude, order.pickupLatitude),
          ),
          iconImage: 'pin-1',
          iconSize: 0.33, // Scale to 1/3 for original size with 3x resolution
          iconAnchor: IconAnchor.BOTTOM,
          symbolSortKey: 1000.0,
        ),
      );

      _markers[markerId] = marker;
      print('✅ State-of-the-Art: Pickup marker created');
    } catch (e) {
      print('❌ State-of-the-Art: Error creating pickup marker: $e');
    }
  }

  /// Create dropoff marker using custom image
  Future<void> _createDropoffMarker(OrderModel order) async {
    try {
      final markerId = '${order.id}_dropoff';

      print(
          '📍 State-of-the-Art: Creating dropoff marker at ${order.deliveryLatitude}, ${order.deliveryLongitude}');

      // Only remove if marker already exists (prevent flickering)
      if (_markers.containsKey(markerId)) {
        await _removeMarker(markerId);
      }

      // Create marker using custom square-numbered pin (2) - HIGH RES
      final marker = await _pointManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates:
                Position(order.deliveryLongitude, order.deliveryLatitude),
          ),
          iconImage: 'pin-2',
          iconSize: 0.33, // Scale to 1/3 for original size with 3x resolution
          iconAnchor: IconAnchor.BOTTOM,
          symbolSortKey: 1000.0,
        ),
      );

      _markers[markerId] = marker;
      print('✅ State-of-the-Art: Dropoff marker created');
    } catch (e) {
      print('❌ State-of-the-Art: Error creating dropoff marker: $e');
    }
  }

  /// Create route using state-of-the-art Directions API
  /// NOTE: Does NOT remove existing route - caller is responsible for cleanup
  Future<void> _createRoute(OrderModel order) async {
    try {
      final routeId = '${order.id}_route';

      print('🛣️ State-of-the-Art: Creating route for order ${order.id}');

      // Get route coordinates using proper API format
      final coordinates = await _getRouteCoordinates(order);

      if (coordinates.isNotEmpty) {
        print(
            '🛣️ State-of-the-Art: Creating polyline with ${coordinates.length} points');

        final polyline = await _polylineManager!.create(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: coordinates),
            lineColor: Colors.blue.value,
            lineWidth: 4.0,
            lineOpacity: 0.8,
          ),
        );

        _routes[routeId] = polyline;
        print('✅ State-of-the-Art: Route created successfully');
      } else {
        print(
            '⚠️ State-of-the-Art: No route coordinates, creating straight line');
        await _createStraightLineRoute(order);
      }
    } catch (e) {
      print('❌ State-of-the-Art: Error creating route: $e');
      await _createStraightLineRoute(order);
    }
  }

  /// Force recalculation of route and dropoff marker for an updated order
  Future<void> recalculateRouteForOrder(OrderModel order) async {
    // Prevent concurrent updates
    if (_isUpdatingRoute) {
      print(
          '⚠️ State-of-the-Art: Route update already in progress, skipping...');
      return;
    }

    try {
      if (!_isInitialized || _mapboxMap == null) {
        print('⚠️ State-of-the-Art: Cannot recalculate - not initialized');
        return;
      }

      _isUpdatingRoute = true;

      print('🔄 State-of-the-Art: Recalculating route for order ${order.id}');
      print(
          '   New coordinates: (${order.deliveryLatitude}, ${order.deliveryLongitude})');

      _currentOrderId = order.id;

      // CRITICAL: Clear ALL annotations FIRST to prevent duplicates
      // This ensures we start completely fresh
      print('🧹 STEP 1: Clearing ALL existing annotations...');

      // Clear all polylines (routes) from manager
      if (_polylineManager != null) {
        try {
          await _polylineManager!.deleteAll();
          print('   ✅ All polylines cleared from manager');
        } catch (e) {
          print('   ⚠️ Error clearing polylines: $e');
        }
      }

      // Clear all point markers (dropoff markers) from manager
      if (_pointManager != null) {
        try {
          await _pointManager!.deleteAll();
          print('   ✅ All point markers cleared from manager');
        } catch (e) {
          print('   ⚠️ Error clearing point markers: $e');
        }
      }

      // Clear internal maps
      _routes.clear();
      _markers.clear();
      print('   ✅ Internal maps cleared');

      // Note: deleteAll() is awaited above, so no extra delay is needed.
      // The previous 200ms sleep was the dominant cost of route recalc and
      // contributed to perceived map lag on customer-location updates.

      print('🧹 STEP 2: Creating new annotations with updated coordinates...');

      // Create new annotations with updated coordinates
      print('   📍 Creating new dropoff marker...');
      await _createDropoffMarker(order);

      print('   🛣️ Creating new route...');
      await _createRoute(order);

      print('✅ State-of-the-Art: Route recalculated successfully');
      print('   Old annotations cleared, new ones created');
    } catch (e) {
      print('❌ State-of-the-Art: Error recalculating route: $e');
      print('   Stack trace: ${StackTrace.current}');
    } finally {
      _isUpdatingRoute = false;
    }
  }

  PointAnnotation? _driverMarker;
  bool _driverIconLoaded = false;

  /// Update or create the driver's blue dot on the map
  Future<void> updateDriverLocation(double latitude, double longitude,
      {double? heading}) async {
    if (_driverPointManager == null || _mapboxMap == null) return;

    try {
      // Ensure icon is loaded ONCE
      if (!_driverIconLoaded) {
        final driverBikeBytes = await _createBikeIcon();
        await _mapboxMap!.style.addStyleImage(
          'driver-bike',
          1.0,
          MbxImage(width: 144, height: 144, data: driverBikeBytes),
          false,
          [],
          [],
          null,
        );
        _driverIconLoaded = true;
      }

      if (_driverMarker == null) {
        _driverMarker = await _driverPointManager!.create(
          PointAnnotationOptions(
            geometry: Point(coordinates: Position(longitude, latitude)),
            iconImage: 'driver-bike',
            iconSize: 0.20,
            iconRotate: heading, // Use native Mapbox rotation
          ),
        );
      } else {
        _driverMarker!.geometry =
            Point(coordinates: Position(longitude, latitude));
        if (heading != null) {
          _driverMarker!.iconRotate = heading;
        }
        await _driverPointManager!.update(_driverMarker!);
      }
    } catch (e) {
      print('❌ State-of-the-Art: Error updating driver marker: $e');
    }
  }

  Future<Uint8List> _createBikeIcon() async {
    const double iconSize = 144.0;
    const double arrowIconSize = 90.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(iconSize / 2, iconSize / 2);
    const radius = iconSize / 2 - 4;

    final blueCirclePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, blueCirclePaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(center, radius, borderPaint);

    const iconData = Icons.navigation;
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontFamily: iconData.fontFamily,
          fontSize: arrowIconSize,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();

    final iconOffset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, iconOffset);

    final picture = recorder.endRecording();
    final img = await picture.toImage(iconSize.toInt(), iconSize.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Get route coordinates using state-of-the-art Directions API
  Future<List<Position>> _getRouteCoordinates(OrderModel order) async {
    try {
      const token = AppConstants.mapboxAccessToken;
      if (token.isEmpty) {
        print(
            '⚠️ State-of-the-Art: Mapbox token unavailable, skipping API call.');
        return [];
      }

      final cached = await RouteCacheService.getCachedRoute(
        orderId: order.id,
        pickupLat: order.pickupLatitude,
        pickupLng: order.pickupLongitude,
        dropoffLat: order.deliveryLatitude,
        dropoffLng: order.deliveryLongitude,
      );

      if (cached != null && cached.isNotEmpty) {
        print(
            '✅ State-of-the-Art: Loaded ${cached.length} cached route points for order ${order.id}');
        return cached.map((pair) => Position(pair[0], pair[1])).toList();
      }

      final coordinatesPath =
          '${order.pickupLongitude},${order.pickupLatitude};${order.deliveryLongitude},${order.deliveryLatitude}';

      List<List<double>>? coordinatePairs;

      // Try Mapbox Directions first (requires directions:read scope on token).
      // Falls back to OSRM if the token is unauthorized or the call fails.
      if (token.isNotEmpty) {
        try {
          final mapboxUri = Uri.parse(
            'https://api.mapbox.com/directions/v5/mapbox/driving/$coordinatesPath'
            '?alternatives=false&geometries=geojson&overview=full&access_token=$token',
          );
          print('🌐 Trying Mapbox Directions API...');
          final mapboxResponse =
              await http.get(mapboxUri).timeout(const Duration(seconds: 10));
          if (mapboxResponse.statusCode == 200) {
            coordinatePairs =
                _parseGeoJsonRouteBody(mapboxResponse.body, order.id);
            if (coordinatePairs != null) {
              print(
                  '✅ Mapbox route: ${coordinatePairs.length} points for order ${order.id}');
            }
          } else {
            print(
                '⚠️ Mapbox Directions: ${mapboxResponse.statusCode} – falling back to OSRM');
          }
        } catch (e) {
          print('⚠️ Mapbox Directions error: $e – falling back to OSRM');
        }
      }

      // OSRM fallback (free, no token needed, uses OpenStreetMap data).
      if (coordinatePairs == null) {
        try {
          final osrmUri = Uri.parse(
            'https://router.project-osrm.org/route/v1/driving/$coordinatesPath'
            '?overview=full&geometries=geojson',
          );
          print('🌐 Trying OSRM fallback...');
          final osrmResponse =
              await http.get(osrmUri).timeout(const Duration(seconds: 15));
          if (osrmResponse.statusCode == 200) {
            coordinatePairs =
                _parseGeoJsonRouteBody(osrmResponse.body, order.id);
            if (coordinatePairs != null) {
              print(
                  '✅ OSRM route: ${coordinatePairs.length} points for order ${order.id}');
            }
          } else {
            print('⚠️ OSRM: ${osrmResponse.statusCode} – ${osrmResponse.body}');
          }
        } catch (e) {
          print('⚠️ OSRM error: $e');
        }
      }

      if (coordinatePairs == null || coordinatePairs.isEmpty) {
        return [];
      }

      await RouteCacheService.cacheRoute(
        orderId: order.id,
        pickupLat: order.pickupLatitude,
        pickupLng: order.pickupLongitude,
        dropoffLat: order.deliveryLatitude,
        dropoffLng: order.deliveryLongitude,
        coordinates: coordinatePairs,
      );

      return coordinatePairs.map((pair) => Position(pair[0], pair[1])).toList();
    } catch (e) {
      print('❌ State-of-the-Art: Route fetch error: $e');
      return [];
    }
  }

  /// Parses a GeoJSON route response body (Mapbox or OSRM compatible).
  /// Returns null if parsing fails or the route is empty.
  List<List<double>>? _parseGeoJsonRouteBody(String body, String orderId) {
    try {
      final data = json.decode(body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final geometry = routes.first['geometry'];
      if (geometry is! Map || geometry['coordinates'] == null) return null;
      final coords = geometry['coordinates'] as List;
      final pairs = coords.map<List<double>>((coord) {
        final pt = coord as List;
        return [(pt[0] as num).toDouble(), (pt[1] as num).toDouble()];
      }).toList();
      return pairs.isEmpty ? null : pairs;
    } catch (e) {
      print('⚠️ Route body parse error for order $orderId: $e');
      return null;
    }
  }

  /// Decode polyline geometry into [lng, lat] coordinate pairs.
  List<List<double>> _decodePolyline(String encoded) {
    final coordinates = <List<double>>[];
    int index = 0;
    int latE5 = 0;
    int lngE5 = 0;

    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      latE5 += dLat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lngE5 += dLng;

      coordinates.add([
        lngE5 / 1e5,
        latE5 / 1e5,
      ]);
    }

    return coordinates;
  }

  /// Create straight line route as fallback
  Future<void> _createStraightLineRoute(OrderModel order) async {
    try {
      final routeId = '${order.id}_route';

      print('📏 State-of-the-Art: Creating straight line route');

      final polyline = await _polylineManager!.create(
        PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: [
              Position(order.pickupLongitude, order.pickupLatitude),
              Position(order.deliveryLongitude, order.deliveryLatitude),
            ],
          ),
          lineColor: Colors.blue.value,
          lineWidth: 4.0,
          lineOpacity: 0.8,
        ),
      );

      _routes[routeId] = polyline;
      print('✅ State-of-the-Art: Straight line route created');
    } catch (e) {
      print('❌ State-of-the-Art: Error creating straight line route: $e');
    }
  }

  /// Remove marker from map.
  /// The local-cache entry is **always** evicted, even when the Mapbox
  /// [delete] call throws.  Leaving a stale reference in [_markers] causes
  /// every subsequent [_createPickupMarker] / [_createDropoffMarker] call for
  /// the same order to attempt (and fail) to delete the same dead object,
  /// which means the orphaned annotation on the map is never cleaned up.
  Future<void> _removeMarker(String markerId) async {
    if (_markers.containsKey(markerId)) {
      final marker = _markers[markerId]!;
      // Always evict from cache first so subsequent calls don't re-use a
      // potentially invalid reference.
      _markers.remove(markerId);
      try {
        await _pointManager!.delete(marker);
        print('🗑️ State-of-the-Art: Marker removed - $markerId');
      } catch (e) {
        print(
            '⚠️ State-of-the-Art: Mapbox delete failed for $markerId (already evicted from cache): $e');
      }
    }
  }

  /// Remove route from map.
  /// See [_removeMarker] for rationale on always evicting the cache entry first.
  Future<void> _removeRoute(String routeId) async {
    if (_routes.containsKey(routeId)) {
      final route = _routes[routeId]!;
      // Always evict from cache first.
      _routes.remove(routeId);
      try {
        await _polylineManager!.delete(route);
        print('🗑️ State-of-the-Art: Route removed - $routeId');
      } catch (e) {
        print(
            '⚠️ State-of-the-Art: Mapbox delete failed for $routeId (already evicted from cache): $e');
      }
    }
  }

  /// Clear order (public method for immediate clearing)
  /// This removes the order from cache and clears its annotations completely
  Future<void> clearOrder(String orderId) async {
    try {
      // Remove from map and cache
      await _removeMarker('${orderId}_pickup');
      await _removeMarker('${orderId}_dropoff');
      await _removeRoute('${orderId}_route');

      // Remove from cache tracking
      _cachedOrderIds.remove(orderId);
      _cachedOrderData.remove(orderId);

      // Also clear current order ID if it matches
      if (_currentOrderId == orderId) {
        _currentOrderId = null;
      }

      // Clear visible order if it matches
      if (_visibleOrderId == orderId) {
        _visibleOrderId = null;
      }

      print(
          '🧹 State-of-the-Art: Order $orderId cleared and removed from cache');
    } catch (e) {
      print('❌ State-of-the-Art: Error clearing order: $e');
    }
  }

  /// Clear order (private method - kept for internal use)
  Future<void> _clearOrder(String orderId) async {
    await clearOrder(orderId);
  }

  /// Clear annotations for orders that are not in the provided active order IDs list
  /// This ensures orphaned annotations are removed when orders lose driver assignment
  Future<void> clearOrphanedAnnotations(List<String> activeOrderIds) async {
    try {
      final activeIdsSet = activeOrderIds.toSet();

      // Find markers and routes that belong to orders no longer active
      final markersToRemove = <String>[];
      final routesToRemove = <String>[];

      for (final markerId in _markers.keys) {
        // Marker IDs have the form "<orderId>_pickup" or "<orderId>_dropoff".
        // Strip the known suffix instead of splitting on '_', because order IDs
        // themselves may contain underscores (e.g. Supabase UUID variants).
        final orderId = markerId.endsWith('_pickup')
            ? markerId.substring(0, markerId.length - '_pickup'.length)
            : markerId.endsWith('_dropoff')
                ? markerId.substring(0, markerId.length - '_dropoff'.length)
                : markerId;
        if (!activeIdsSet.contains(orderId)) {
          markersToRemove.add(markerId);
        }
      }

      for (final routeId in _routes.keys) {
        // Route IDs have the form "<orderId>_route".
        final orderId = routeId.endsWith('_route')
            ? routeId.substring(0, routeId.length - '_route'.length)
            : routeId;
        if (!activeIdsSet.contains(orderId)) {
          routesToRemove.add(routeId);
        }
      }

      // Remove orphaned markers
      for (final markerId in markersToRemove) {
        await _removeMarker(markerId);
        print('🧹 State-of-the-Art: Removed orphaned marker - $markerId');
      }

      // Remove orphaned routes
      for (final routeId in routesToRemove) {
        await _removeRoute(routeId);
        print('🧹 State-of-the-Art: Removed orphaned route - $routeId');
      }

      // Clear current order ID if it's no longer active
      if (_currentOrderId != null && !activeIdsSet.contains(_currentOrderId!)) {
        print(
            '🧹 State-of-the-Art: Current order $_currentOrderId no longer active, clearing');
        _currentOrderId = null;
      }

      if (markersToRemove.isNotEmpty || routesToRemove.isNotEmpty) {
        print(
            '🧹 State-of-the-Art: Cleared ${markersToRemove.length} orphaned markers and ${routesToRemove.length} orphaned routes');
      }
    } catch (e) {
      print('❌ State-of-the-Art: Error clearing orphaned annotations: $e');
    }
  }

  Future<void> rebuildAnnotations() async {
    if (!_isInitialized) return;
    print('🔄 State-of-the-Art: Rebuilding annotations after style change...');
    try {
      // Re-create annotation managers
      _polylineManager =
          await _mapboxMap!.annotations.createPolylineAnnotationManager();
      _pointManager =
          await _mapboxMap!.annotations.createPointAnnotationManager();
      _driverPointManager =
          await _mapboxMap!.annotations.createPointAnnotationManager();
      _circleManager =
          await _mapboxMap!.annotations.createCircleAnnotationManager();

      // Clear internal state so they are forcefully recreated
      _visibleOrderId = null;
      _driverMarker = null;
      _driverIconLoaded =
          false; // Need to reload the icon image to the new style

      // Re-add custom images
      await _prepareSquarePinImages();

      // Restore order if one is active
      if (_currentOrderId != null &&
          _cachedOrderData.containsKey(_currentOrderId)) {
        await setActiveOrder(_cachedOrderData[_currentOrderId]!);
      }
    } catch (e) {
      print('❌ State-of-the-Art: Failed rebuilding annotations: $e');
    }
  }

  /// Clear all annotations (routes + markers) in a single sweep
  Future<void> clearAll() async {
    try {
      if (!_isInitialized) {
        print(
            '⚠️ State-of-the-Art: clearAll called before initialization (continuing best-effort)');
      }

      if (_pointManager != null) {
        try {
          await _pointManager!.deleteAll();
        } catch (e) {
          print('⚠️ State-of-the-Art: deleteAll on pointManager failed ($e)');
        }
      }
      if (_polylineManager != null) {
        try {
          await _polylineManager!.deleteAll();
        } catch (e) {
          print(
              '⚠️ State-of-the-Art: deleteAll on polylineManager failed ($e)');
        }
      }
      if (_circleManager != null) {
        try {
          await _circleManager!.deleteAll();
        } catch (e) {
          print('⚠️ State-of-the-Art: deleteAll on circleManager failed ($e)');
        }
      }

      _markers.clear();
      _routes.clear();
      _currentOrderId = null;
      _visibleOrderId = null;
      _cachedOrderIds.clear();
      _cachedOrderData.clear();
      print(
          '🧹 State-of-the-Art: All annotations cleared via manager deleteAll');
    } catch (e) {
      print('❌ State-of-the-Art: Error clearing all: $e');
    } finally {
      // Always clear local caches even if Mapbox calls fail (e.g., after style swaps).
      // Also reset the lock so the next setActiveOrder call isn't permanently blocked.
      _markers.clear();
      _routes.clear();
      _currentOrderId = null;
      _visibleOrderId = null;
      _cachedOrderIds.clear();
      _cachedOrderData.clear();
      _isSettingOrder = false;
    }
  }

  /// Get status
  Map<String, dynamic> getStatus() {
    return {
      'initialized': _isInitialized,
      'currentOrderId': _currentOrderId,
      'markers': _markers.length,
      'routes': _routes.length,
      'driverMarker': _driverMarker != null,
    };
  }

  /// Dispose
  void dispose() {
    clearAll();
    _isInitialized = false;
    print('🗑️ State-of-the-Art: Disposed');
  }
}
