import 'dart:async';
import 'network_quality_service.dart';
import 'request_priority_manager.dart';
import 'screen_visibility_tracker.dart';

/// Main performance optimizer that coordinates all optimization services
class PerformanceOptimizer {
  static final PerformanceOptimizer _instance = PerformanceOptimizer._internal();
  factory PerformanceOptimizer() => _instance;
  PerformanceOptimizer._internal();

  final NetworkQualityService _networkQuality = NetworkQualityService();
  final RequestPriorityManager _priorityManager = RequestPriorityManager();
  final ScreenVisibilityTracker _visibilityTracker = ScreenVisibilityTracker();

  /// Initialize all optimization services
  Future<void> initialize() async {
    print('🚀 Initializing performance optimizer...');
    
    // Initialize network quality monitoring
    await _networkQuality.initialize();
    
    // Adjust request concurrency based on network quality
    _updateConcurrencySettings();
    
    // Monitor network quality changes and update settings
    Timer.periodic(const Duration(seconds: 30), (_) {
      _updateConcurrencySettings();
    });
    
    print('✅ Performance optimizer initialized');
    print('   Network quality: ${_networkQuality.currentQuality}');
    print('   Max concurrent requests: ${_priorityManager.getStats()['activeRequests']}');
  }

  /// Update concurrency settings based on network quality
  void _updateConcurrencySettings() {
    final quality = _networkQuality.currentQuality;
    
    switch (quality) {
      case NetworkQuality.excellent:
        _priorityManager.setMaxConcurrentRequests(5);
        break;
      case NetworkQuality.good:
        _priorityManager.setMaxConcurrentRequests(3);
        break;
      case NetworkQuality.fair:
        _priorityManager.setMaxConcurrentRequests(2);
        break;
      case NetworkQuality.poor:
        _priorityManager.setMaxConcurrentRequests(1);
        break;
      case NetworkQuality.offline:
        _priorityManager.setMaxConcurrentRequests(0);
        break;
    }
  }

  /// Get priority for a request based on current screen
  RequestPriority getPriorityForRequest({
    required String requestType,
    String? screenName,
  }) {
    // If request is for currently visible screen, it's critical
    if (screenName != null && _visibilityTracker.isScreenVisible(screenName)) {
      return RequestPriority.critical;
    }

    // Determine priority based on request type
    switch (requestType) {
      case 'orders_list':
      case 'order_details':
      case 'wallet_balance':
        return RequestPriority.high;
      case 'order_items':
      case 'driver_info':
        return RequestPriority.normal;
      case 'notifications':
      case 'announcements':
        return _networkQuality.isSlowConnection 
            ? RequestPriority.low 
            : RequestPriority.normal;
      default:
        return RequestPriority.normal;
    }
  }

  /// Should we defer this request?
  bool shouldDeferRequest(String requestType) {
    if (!_networkQuality.shouldDeferNonCriticalRequests()) {
      return false;
    }

    // Defer non-critical requests on slow connections
    final deferrableTypes = [
      'notifications',
      'announcements',
      'scheduled_orders',
      'order_history',
    ];

    return deferrableTypes.contains(requestType);
  }

  /// Get recommended timeout for a request
  Duration getRecommendedTimeout(String requestType) {
    final baseTimeout = _networkQuality.getRecommendedTimeout();
    
    // Adjust based on request type
    switch (requestType) {
      case 'orders_list':
      case 'order_details':
        return baseTimeout;
      case 'wallet_balance':
        return Duration(milliseconds: baseTimeout.inMilliseconds ~/ 2);
      default:
        return baseTimeout;
    }
  }

  /// Get network quality
  NetworkQuality get networkQuality => _networkQuality.currentQuality;

  /// Get visibility tracker
  ScreenVisibilityTracker get visibilityTracker => _visibilityTracker;

  /// Get priority manager
  RequestPriorityManager get priorityManager => _priorityManager;

  void dispose() {
    _networkQuality.dispose();
  }
}

