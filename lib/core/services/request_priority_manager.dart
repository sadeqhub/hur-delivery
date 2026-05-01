import 'dart:async';
import 'package:flutter/foundation.dart';

/// Priority levels for network requests
enum RequestPriority {
  critical,    // Visible screen data - must load immediately
  high,        // Important data for current screen
  normal,      // Standard requests
  low,         // Background/prefetch data
  deferred,    // Can be deferred until connection improves
}

/// Request queue item
class QueuedRequest {
  final String id;
  final Future<void> Function() operation;
  final RequestPriority priority;
  final String description;
  final Completer<void> completer;
  DateTime queuedAt;
  int retryCount = 0;
  static const maxRetries = 2;

  QueuedRequest({
    required this.id,
    required this.operation,
    required this.priority,
    required this.description,
  }) : queuedAt = DateTime.now(),
       completer = Completer<void>();

  int get priorityValue {
    switch (priority) {
      case RequestPriority.critical:
        return 0;
      case RequestPriority.high:
        return 1;
      case RequestPriority.normal:
        return 2;
      case RequestPriority.low:
        return 3;
      case RequestPriority.deferred:
        return 4;
    }
  }
}

/// Manages request prioritization and queuing for optimal performance
class RequestPriorityManager {
  static final RequestPriorityManager _instance = RequestPriorityManager._internal();
  factory RequestPriorityManager() => _instance;
  RequestPriorityManager._internal();

  final List<QueuedRequest> _queue = [];
  final Set<String> _activeRequests = {};
  bool _isProcessing = false;
  int _maxConcurrentRequests = 3; // Limit concurrent requests on slow connections
  
  // Statistics
  int _totalProcessed = 0;
  int _totalFailed = 0;
  DateTime? _lastProcessTime;

  /// Execute a request with priority
  Future<T?> executeWithPriority<T>({
    required String requestId,
    required Future<T> Function() operation,
    required RequestPriority priority,
    required String description,
    bool isCritical = false,
  }) async {
    // If critical and queue is empty, execute immediately
    if (priority == RequestPriority.critical && _queue.isEmpty && _activeRequests.length < _maxConcurrentRequests) {
      return await _executeRequest(operation, requestId, description);
    }

    // Create completer to return result
    final resultCompleter = Completer<T?>();
    
    // Add to queue
    final queuedRequest = QueuedRequest(
      id: requestId,
      operation: () async {
        try {
          final result = await _executeRequest(operation, requestId, description);
          if (!resultCompleter.isCompleted) {
            resultCompleter.complete(result);
          }
        } catch (e) {
          if (!resultCompleter.isCompleted) {
            resultCompleter.completeError(e);
          }
        }
      },
      priority: priority,
      description: description,
    );

    _queue.add(queuedRequest);
    _queue.sort((a, b) {
      // Sort by priority first, then by queued time
      final priorityDiff = a.priorityValue.compareTo(b.priorityValue);
      if (priorityDiff != 0) return priorityDiff;
      return a.queuedAt.compareTo(b.queuedAt);
    });

    if (kDebugMode) {
      print('📋 Queued request: $description (priority: $priority, queue size: ${_queue.length})');
    }

    // Start processing if not already
    if (!_isProcessing) {
      _processQueue();
    }

    // Wait for completion and return result
    return await resultCompleter.future;
  }

  /// Execute a request immediately (bypass queue for critical operations)
  Future<T> executeImmediate<T>({
    required Future<T> Function() operation,
    required String requestId,
    required String description,
  }) async {
    return await _executeRequest(operation, requestId, description);
  }

  /// Execute a single request
  Future<T> _executeRequest<T>(
    Future<T> Function() operation,
    String requestId,
    String description,
  ) async {
    _activeRequests.add(requestId);
    
    try {
      if (kDebugMode) {
        print('🚀 Executing: $description');
      }
      
      final result = await operation();
      _totalProcessed++;
      _lastProcessTime = DateTime.now();
      
      if (kDebugMode) {
        print('✅ Completed: $description');
      }
      
      return result;
    } catch (e) {
      _totalFailed++;
      if (kDebugMode) {
        print('❌ Failed: $description - $e');
      }
      rethrow;
    } finally {
      _activeRequests.remove(requestId);
    }
  }

  /// Process the request queue
  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (_queue.isNotEmpty) {
      // Wait if we're at max concurrent requests
      while (_activeRequests.length >= _maxConcurrentRequests) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Get next request from queue
      final request = _queue.removeAt(0);
      
      // Skip deferred requests if connection is slow (they'll be processed later)
      if (request.priority == RequestPriority.deferred) {
        // Check if we should process deferred requests
        // For now, process them but with lower priority
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Execute request
      unawaited(request.operation().then((_) {
        if (!request.completer.isCompleted) {
          request.completer.complete();
        }
      }).catchError((e) {
        // Retry logic
        if (request.retryCount < QueuedRequest.maxRetries) {
          request.retryCount++;
          request.queuedAt = DateTime.now();
          _queue.add(request);
          _queue.sort((a, b) {
            final priorityDiff = a.priorityValue.compareTo(b.priorityValue);
            if (priorityDiff != 0) return priorityDiff;
            return a.queuedAt.compareTo(b.queuedAt);
          });
          if (kDebugMode) {
            print('🔄 Retrying: ${request.description} (attempt ${request.retryCount})');
          }
        } else {
          if (!request.completer.isCompleted) {
            request.completer.completeError(e);
          }
        }
      }));
    }

    _isProcessing = false;
  }

  /// Adjust max concurrent requests based on network quality
  void setMaxConcurrentRequests(int max) {
    _maxConcurrentRequests = max.clamp(1, 5);
    if (kDebugMode) {
      print('⚙️ Max concurrent requests set to: $_maxConcurrentRequests');
    }
  }

  /// Clear deferred requests from queue
  void clearDeferredRequests() {
    _queue.removeWhere((req) => req.priority == RequestPriority.deferred);
  }

  /// Get queue statistics
  Map<String, dynamic> getStats() {
    return {
      'queueSize': _queue.length,
      'activeRequests': _activeRequests.length,
      'totalProcessed': _totalProcessed,
      'totalFailed': _totalFailed,
      'lastProcessTime': _lastProcessTime?.toIso8601String(),
    };
  }

  /// Clear all queued requests
  void clearQueue() {
    for (var request in _queue) {
      if (!request.completer.isCompleted) {
        request.completer.completeError('Queue cleared');
      }
    }
    _queue.clear();
  }
}

