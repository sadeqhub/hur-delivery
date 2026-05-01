import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../../shared/models/order_model.dart';
import '../../../core/utils/map_style_helper.dart';
import '../widgets/state_of_the_art_navigation.dart';

/// Map widget for merchant dashboard showing all orders and driver locations
class MerchantMapWidget extends StatefulWidget {
  final List<OrderModel> orders;
  final OrderModel? selectedOrder;
  final Function(OrderModel)? onOrderSelected;

  const MerchantMapWidget({
    super.key,
    required this.orders,
    this.selectedOrder,
    this.onOrderSelected,
  });

  @override
  State<MerchantMapWidget> createState() => _MerchantMapWidgetState();
}

class _MerchantMapWidgetState extends State<MerchantMapWidget> {
  MapboxMap? _mapboxMap;
  String? _mapboxAccessToken;
  final StateOfTheArtNavigation _navigationSystem = StateOfTheArtNavigation();
  
  bool _isInitialized = false;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;
  
  // Track markers for orders and drivers
  final Map<String, PointAnnotation> _orderMarkers = {};
  final Map<String, PointAnnotation> _driverMarkers = {};
  final Map<String, PolylineAnnotation> _orderRoutes = {};
  
  // Driver location tracking
  Timer? _driverLocationTimer;
  final Map<String, Map<String, dynamic>> _driverLocations = {};
  
  bool _customIconsLoaded = false;

  @override
  void initState() {
    super.initState();
    _mapboxAccessToken = const String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
    _startDriverLocationTracking();
  }

  @override
  void dispose() {
    _driverLocationTimer?.cancel();
    _navigationSystem.dispose();
    super.dispose();
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    setState(() {
      _mapboxMap = mapboxMap;
    });
    print('🗺️ Merchant map created');
    
    // Create annotation managers
    try {
      _pointAnnotationManager =
          await mapboxMap.annotations.createPointAnnotationManager();
      _polylineAnnotationManager =
          await mapboxMap.annotations.createPolylineAnnotationManager();
      print('✅ Merchant map annotation managers created');
    } catch (e) {
      print('⚠️ Error creating annotation managers: $e');
    }
    
    // Initialize navigation system first (this loads pin images)
    try {
      final initialized = await _navigationSystem.initialize(mapboxMap);
      if (initialized) {
        print('✅ Merchant map navigation system ready');
        // Pin images are now loaded by navigation system
      }
    } catch (e) {
      print('❌ Error initializing navigation system: $e');
    }
    
    // Load custom icons (driver marker)
    await _loadCustomIcons();
    
    _isInitialized = true;
    
    // Update map with orders
    _updateMapAnnotations();
  }

  @override
  void didUpdateWidget(MerchantMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update if orders changed
    if (widget.orders.length != oldWidget.orders.length ||
        widget.selectedOrder?.id != oldWidget.selectedOrder?.id) {
      _updateMapAnnotations();
    }
  }

  Future<void> _loadCustomIcons() async {
    if (_mapboxMap == null || _customIconsLoaded) return;
    
    try {
      // Load driver bike icon
      final driverBikeBytes = await _createBikeIcon();
      await _mapboxMap!.style.addStyleImage(
        'driver-bike',
        1.0,
        MbxImage(width: 96, height: 96, data: driverBikeBytes),
        false,
        [],
        [],
        null,
      );
      
      _customIconsLoaded = true;
      print('✅ Merchant map custom icons loaded');
    } catch (e) {
      print('❌ Error loading custom icons: $e');
    }
  }

  Future<Uint8List> _createBikeIcon({double? heading}) async {
    const double iconSize = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    const center = Offset(iconSize / 2, iconSize / 2);
    const radius = iconSize / 2 - 6;
    
    // Draw blue circle background
    final blueCirclePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, blueCirclePaint);
    
    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, radius, borderPaint);
    
    // Draw arrowhead
    const arrowSize = radius * 0.6;
    final arrowPath = ui.Path();
    
    final arrowTop = Offset(center.dx, center.dy - arrowSize);
    final arrowBottomLeft =
        Offset(center.dx - arrowSize * 0.5, center.dy + arrowSize * 0.3);
    final arrowBottomRight =
        Offset(center.dx + arrowSize * 0.5, center.dy + arrowSize * 0.3);
    
    arrowPath.moveTo(arrowTop.dx, arrowTop.dy);
    arrowPath.lineTo(arrowBottomLeft.dx, arrowBottomLeft.dy);
    arrowPath.lineTo(arrowBottomRight.dx, arrowBottomRight.dy);
    arrowPath.close();
    
    if (heading != null && !heading.isNaN && !heading.isInfinite) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate((heading * 3.14159265359 / 180.0));
      canvas.translate(-center.dx, -center.dy);
    }
    
    final arrowPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawPath(arrowPath, arrowPaint);
    
    if (heading != null) {
      canvas.restore();
    }
    
    final picture = recorder.endRecording();
    final img = await picture.toImage(iconSize.toInt(), iconSize.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }

  void _startDriverLocationTracking() {
    _driverLocationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchDriverLocations();
    });
    _fetchDriverLocations();
  }

  Future<void> _fetchDriverLocations() async {
    if (!_isInitialized || _pointAnnotationManager == null) return;
    
    // Get all driver IDs from active orders
    final driverIds = widget.orders
        .where((o) => o.driverId != null && 
                     o.status != 'delivered' && 
                     o.status != 'cancelled')
        .map((o) => o.driverId!)
        .toSet();
    
    if (driverIds.isEmpty) return;
    
    try {
      for (final driverId in driverIds) {
        // PERFORMANCE: Use materialized view (215ms → <10ms, 95% faster)
        final response = await Supabase.instance.client
            .from('recent_driver_locations')
            .select()
            .eq('driver_id', driverId)
            .maybeSingle();
        
        if (response != null && mounted) {
          final lat = (response['latitude'] as num?)?.toDouble();
          final lng = (response['longitude'] as num?)?.toDouble();
          final heading = (response['heading'] as num?)?.toDouble();
          
          if (lat != null && lng != null) {
            _driverLocations[driverId] = {
              'latitude': lat,
              'longitude': lng,
              'heading': heading,
            };
            _updateDriverMarker(driverId, lat, lng, heading);
          }
        }
      }
    } catch (e) {
      print('❌ Error fetching driver locations: $e');
    }
  }

  Future<void> _updateDriverMarker(
      String driverId, double lat, double lng, double? heading) async {
    if (_pointAnnotationManager == null || !_customIconsLoaded) return;
    
    try {
      // Remove old marker
      if (_driverMarkers.containsKey(driverId)) {
        await _pointAnnotationManager!.delete(_driverMarkers[driverId]!);
      }
      
      // Update icon if heading changed
      if (heading != null && !heading.isNaN && !heading.isInfinite) {
        final driverIconBytes = await _createBikeIcon(heading: heading);
        await _mapboxMap!.style.addStyleImage(
          'driver-bike',
          1.0,
          MbxImage(width: 96, height: 96, data: driverIconBytes),
          false,
          [],
          [],
          null,
        );
      }
      
      // Create new marker
      final marker = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(lng, lat),
          ),
          iconImage: 'driver-bike',
          iconSize: 0.2,
        ),
      );
      
      _driverMarkers[driverId] = marker;
    } catch (e) {
      print('❌ Error updating driver marker: $e');
    }
  }

  Future<void> _updateMapAnnotations() async {
    if (!_isInitialized || _mapboxMap == null) return;
    
    try {
      // Clear existing order markers (keep driver markers)
      for (final marker in _orderMarkers.values) {
        try {
          await _pointAnnotationManager?.delete(marker);
        } catch (e) {
          print('⚠️ Error deleting order marker: $e');
        }
      }
      _orderMarkers.clear();
      
      // Clear existing routes
      for (final route in _orderRoutes.values) {
        try {
          await _polylineAnnotationManager?.delete(route);
        } catch (e) {
          print('⚠️ Error deleting route: $e');
        }
      }
      _orderRoutes.clear();
      
      // Add markers and routes for each order
      for (final order in widget.orders) {
        if (order.status == 'delivered' || order.status == 'cancelled') {
          continue;
        }
        
        // Create markers for this order
        await _createOrderMarkers(order);
        
        // Create route for this order
        await _createOrderRoute(order);
      }
      
      // Fit camera to show all markers
      _fitCameraToContent();
    } catch (e) {
      print('❌ Error updating map annotations: $e');
    }
  }

  Future<void> _createOrderMarkers(OrderModel order) async {
    if (_pointAnnotationManager == null) return;
    
    try {
      // Pickup marker
      final pickupMarker = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              order.pickupLongitude,
              order.pickupLatitude,
            ),
          ),
          iconImage: 'pin-1',
          iconSize: 0.33,
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );
      _orderMarkers['${order.id}_pickup'] = pickupMarker;
          
      // Dropoff marker
      final dropoffMarker = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              order.deliveryLongitude,
              order.deliveryLatitude,
            ),
          ),
          iconImage: 'pin-2',
          iconSize: 0.33,
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );
      _orderMarkers['${order.id}_dropoff'] = dropoffMarker;
        } catch (e) {
      print('❌ Error creating order markers: $e');
    }
  }

  Future<void> _createOrderRoute(OrderModel order) async {
    if (_polylineAnnotationManager == null) return;
    
    try {
      // Use Mapbox Directions API to get route
      final routeUrl = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '${order.pickupLongitude},${order.pickupLatitude};'
        '${order.deliveryLongitude},${order.deliveryLatitude}'
        '?access_token=$_mapboxAccessToken'
        '&geometries=geojson'
        '&overview=simplified',
      );
      
      final response = await http.get(routeUrl);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final geometry = data['routes'][0]['geometry'];
        final coordinates = geometry['coordinates'] as List;
        
        // Convert to Position list
        final positions = coordinates
            .map((coord) => Position(coord[0] as double, coord[1] as double))
            .toList();
        
        // Create polyline
        final route = await _polylineAnnotationManager!.create(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: positions),
            lineColor: Colors.blue.value,
            lineWidth: 4.0,
            lineOpacity: 0.6,
          ),
        );
        
        _orderRoutes['${order.id}_route'] = route;
      }
    } catch (e) {
      print('❌ Error creating route for order ${order.id}: $e');
    }
  }

  void _fitCameraToContent() {
    if (_mapboxMap == null || widget.orders.isEmpty) return;
    
    try {
      final coordinates = <Position>[];
      
      // Add order coordinates
      for (final order in widget.orders) {
        coordinates.add(Position(
          order.pickupLongitude,
          order.pickupLatitude,
        ));
              coordinates.add(Position(
          order.deliveryLongitude,
          order.deliveryLatitude,
        ));
            }
      
      // Add driver coordinates
      for (final location in _driverLocations.values) {
        coordinates.add(Position(
          location['longitude'] as double,
          location['latitude'] as double,
        ));
      }
      
      if (coordinates.isEmpty) return;
      
      // Calculate bounds
      // Position is a list: [longitude, latitude]
      double minLat = coordinates.first[1] as double;
      double maxLat = coordinates.first[1] as double;
      double minLng = coordinates.first[0] as double;
      double maxLng = coordinates.first[0] as double;
      
      for (final coord in coordinates) {
        final lat = coord[1] as double;
        final lng = coord[0] as double;
        minLat = minLat < lat ? minLat : lat;
        maxLat = maxLat > lat ? maxLat : lat;
        minLng = minLng < lng ? minLng : lng;
        maxLng = maxLng > lng ? maxLng : lng;
      }
      
      // Fit camera to bounds
      _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              (minLng + maxLng) / 2,
              (minLat + maxLat) / 2,
            ),
          ),
          zoom: 12.0,
        ),
        MapAnimationOptions(duration: 1000),
      );
    } catch (e) {
      print('❌ Error fitting camera: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: MapWidget(
        key: const ValueKey("merchant_map_widget"),
        cameraOptions: CameraOptions(
          center: Point(
            coordinates: Position(44.3661, 33.3152), // Baghdad default
          ),
          zoom: 12.0,
        ),
        styleUri: MapStyleHelper.getMapStyle(context),
        onMapCreated: _onMapCreated,
        onStyleLoadedListener: null,
      ),
    );
  }
}
