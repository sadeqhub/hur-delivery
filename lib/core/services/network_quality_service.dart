import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Network quality levels based on connection speed
enum NetworkQuality {
  excellent,  // WiFi or fast 4G/5G (> 5 Mbps)
  good,       // 4G (> 1 Mbps)
  fair,       // Slow 4G or 3G (> 0.5 Mbps)
  poor,       // Very slow connection (< 0.5 Mbps)
  offline,    // No connection
}

/// Network quality service that detects connection speed and adjusts behavior
class NetworkQualityService {
  static final NetworkQualityService _instance = NetworkQualityService._internal();
  factory NetworkQualityService() => _instance;
  NetworkQualityService._internal();

  NetworkQuality _currentQuality = NetworkQuality.good;
  ConnectivityResult _connectivityType = ConnectivityResult.mobile;
  Timer? _qualityCheckTimer;
  
  // Quality thresholds (in milliseconds for a small request)
  static const int excellentThreshold = 200;  // < 200ms = excellent
  static const int goodThreshold = 500;        // < 500ms = good
  static const int fairThreshold = 1500;       // < 1500ms = fair
  // > 1500ms = poor

  NetworkQuality get currentQuality => _currentQuality;
  ConnectivityResult get connectivityType => _connectivityType;
  
  bool get isSlowConnection => 
      _currentQuality == NetworkQuality.fair || 
      _currentQuality == NetworkQuality.poor;
  
  bool get isFastConnection => 
      _currentQuality == NetworkQuality.excellent || 
      _currentQuality == NetworkQuality.good;

  /// Initialize and start monitoring network quality
  Future<void> initialize() async {
    await _checkConnectivity();
    await _measureNetworkQuality();
    
    // Monitor connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      _connectivityType = result;
      if (result == ConnectivityResult.none) {
        _currentQuality = NetworkQuality.offline;
      } else {
        _measureNetworkQuality();
      }
    });
    
    // Periodically check quality (every 30 seconds)
    _qualityCheckTimer?.cancel();
    _qualityCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _measureNetworkQuality();
    });
  }

  /// Check basic connectivity
  Future<void> _checkConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _connectivityType = result;
      if (result == ConnectivityResult.none) {
        _currentQuality = NetworkQuality.offline;
        return;
      }
    } catch (e) {
      print('⚠️ Error checking connectivity: $e');
    }
  }

  /// Measure network quality by timing a small database query
  Future<void> _measureNetworkQuality() async {
    try {
      final startTime = DateTime.now();
      
      // Perform a lightweight query to measure latency
      await Supabase.instance.client
          .from('users')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 5));
      
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      
      // Determine quality based on response time
      if (duration < excellentThreshold) {
        _currentQuality = NetworkQuality.excellent;
      } else if (duration < goodThreshold) {
        _currentQuality = NetworkQuality.good;
      } else if (duration < fairThreshold) {
        _currentQuality = NetworkQuality.fair;
      } else {
        _currentQuality = NetworkQuality.poor;
      }
      
      print('📊 Network quality: $_currentQuality (${duration}ms, $_connectivityType)');
    } catch (e) {
      // If query fails, assume poor connection
      _currentQuality = NetworkQuality.poor;
      print('⚠️ Network quality check failed: $e');
    }
  }

  /// Get recommended timeout for requests based on quality
  Duration getRecommendedTimeout() {
    switch (_currentQuality) {
      case NetworkQuality.excellent:
        return const Duration(seconds: 10);
      case NetworkQuality.good:
        return const Duration(seconds: 15);
      case NetworkQuality.fair:
        return const Duration(seconds: 30);
      case NetworkQuality.poor:
        return const Duration(seconds: 45);
      case NetworkQuality.offline:
        return const Duration(seconds: 5);
    }
  }

  /// Get recommended batch size for pagination
  int getRecommendedBatchSize() {
    switch (_currentQuality) {
      case NetworkQuality.excellent:
        return 50;
      case NetworkQuality.good:
        return 30;
      case NetworkQuality.fair:
        return 20;
      case NetworkQuality.poor:
        return 10;
      case NetworkQuality.offline:
        return 0;
    }
  }

  /// Should we use aggressive caching?
  bool shouldUseAggressiveCaching() {
    return isSlowConnection;
  }

  /// Should we defer non-critical requests?
  bool shouldDeferNonCriticalRequests() {
    return isSlowConnection;
  }

  /// Should we reduce real-time subscription frequency?
  bool shouldReduceRealtimeFrequency() {
    return _currentQuality == NetworkQuality.poor;
  }

  void dispose() {
    _qualityCheckTimer?.cancel();
  }
}

