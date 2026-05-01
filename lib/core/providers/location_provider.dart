import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class LocationProvider extends ChangeNotifier {
  Position? _currentPosition;
  bool _isTracking = false;
  bool _isLoading = false;
  String? _error;
  final List<Position> _locationHistory = [];
  
  // Callback for when location updates (to update database)
  Function(Position)? onLocationUpdate;
  
  // Stream subscription for location updates
  StreamSubscription<Position>? _positionSubscription;
  
  // Timer for periodic updates when stationary
  Timer? _periodicUpdateTimer;

  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Position> get locationHistory => _locationHistory;

  // Initialize location service
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Check permissions
      final hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        _error = 'إذن الموقع مطلوب لتشغيل التطبيق';
        return;
      }

      // Get current position
      await getCurrentLocation();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Check location permission
  Future<bool> _checkLocationPermission() async {
    final status = await Permission.location.status;
    
    if (status.isGranted) {
      return true;
    } else if (status.isDenied) {
      final result = await Permission.location.request();
      return result.isGranted;
    } else if (status.isPermanentlyDenied) {
      // Show dialog to open settings
      return false;
    }
    
    return false;
  }

  // Get current location
  Future<Position?> getCurrentLocation() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _error = 'خدمات الموقع غير مفعلة';
        return null;
      }

      // Check permissions
      final hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        _error = 'إذن الموقع مطلوب';
        return null;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _currentPosition = position;
      _addToHistory(position);
      return position;
    } catch (e) {
      _error = _getErrorMessage(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Start location tracking
  Future<void> startLocationTracking() async {
    if (_isTracking) return;

    try {
      // Check permissions
      final hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        _error = 'إذن الموقع مطلوب';
        return;
      }

      _isTracking = true;
      notifyListeners();

      // Cancel existing subscription if any
      await _positionSubscription?.cancel();

      // Start position stream
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen(
        (position) {
          _currentPosition = position;
          _addToHistory(position);
          notifyListeners();
          onLocationUpdate?.call(position);
        },
        onError: (error) {
          _error = _getErrorMessage(error);
          _isTracking = false;
          notifyListeners();
        },
      );
      
      // Periodic timer: fires every 30s as a "heartbeat" database update for
      // stationary drivers (the stream only fires on 10m+ movement).
      // We do NOT call notifyListeners() here — the stream already handles UI
      // updates. The timer solely keeps the server-side location fresh.
      _periodicUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        if (!_isTracking) {
          timer.cancel();
          return;
        }

        if (onLocationUpdate != null && _currentPosition != null) {
          // Re-send the last known position as a heartbeat — no GPS query needed.
          onLocationUpdate!(_currentPosition!);
        }
      });
    } catch (e) {
      print('❌ LocationProvider: Error starting location tracking: $e');
      _error = _getErrorMessage(e);
      _isTracking = false;
      notifyListeners();
    }
  }

  // Stop location tracking
  void stopLocationTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _periodicUpdateTimer?.cancel();
    _periodicUpdateTimer = null;
    _isTracking = false;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _positionSubscription?.cancel();
    _periodicUpdateTimer?.cancel();
    super.dispose();
  }

  // Add position to history
  void _addToHistory(Position position) {
    _locationHistory.add(position);
    
    // Keep only last 100 positions
    if (_locationHistory.length > 100) {
      _locationHistory.removeAt(0);
    }
  }

  // Calculate distance between two points
  double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // Calculate bearing between two points
  double calculateBearing(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    return Geolocator.bearingBetween(lat1, lon1, lat2, lon2);
  }

  // Get distance to a specific location
  double? getDistanceTo(double latitude, double longitude) {
    if (_currentPosition == null) return null;
    
    return calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      latitude,
      longitude,
    );
  }

  // Check if location is within radius
  bool isWithinRadius(
    double latitude,
    double longitude,
    double radiusInMeters,
  ) {
    final distance = getDistanceTo(latitude, longitude);
    if (distance == null) return false;
    
    return distance <= radiusInMeters;
  }

  // Get formatted address (placeholder - would need geocoding service)
  Future<String> getFormattedAddress(double latitude, double longitude) async {
    // This would typically use a geocoding service
    return 'العنوان: $latitude, $longitude';
  }

  // Clear location history
  void clearLocationHistory() {
    _locationHistory.clear();
    notifyListeners();
  }

  // Get error message
  String _getErrorMessage(dynamic error) {
    if (error.toString().contains('Location services disabled')) {
      return 'خدمات الموقع معطلة';
    } else if (error.toString().contains('Location permission denied')) {
      return 'إذن الموقع مرفوض';
    } else if (error.toString().contains('Location timeout')) {
      return 'انتهت مهلة الحصول على الموقع';
    } else if (error.toString().contains('Location unavailable')) {
      return 'الموقع غير متاح';
    } else {
      return 'خطأ في الحصول على الموقع';
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Check if location is available
  bool get isLocationAvailable => _currentPosition != null;

  // Get location accuracy
  double? get locationAccuracy => _currentPosition?.accuracy;

  // Get location timestamp
  DateTime? get locationTimestamp => _currentPosition?.timestamp;

  // Update current position from external source (e.g., database)
  void updateCurrentPosition(dynamic position) {
    if (position != null) {
      // Create a Position object from the provided data
      _currentPosition = Position(
        latitude: position['latitude'] ?? 0.0,
        longitude: position['longitude'] ?? 0.0,
        timestamp: position['timestamp'] ?? DateTime.now(),
        accuracy: 5.0, // Default accuracy
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      notifyListeners();
    }
  }
}
