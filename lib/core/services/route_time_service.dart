import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

/// Service to calculate route time using Mapbox API via Supabase Edge Function
class RouteTimeService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Calculate route time from pickup to dropoff
  /// Returns the time limit in seconds (Mapbox duration * 1.5)
  static Future<RouteTimeResult?> calculateRouteTime({
    required double pickupLatitude,
    required double pickupLongitude,
    required double dropoffLatitude,
    required double dropoffLongitude,
  }) async {
    try {
      Logger.d('🌐 Calculating route time...');
      Logger.d('   Pickup: ($pickupLatitude, $pickupLongitude)');
      Logger.d('   Dropoff: ($dropoffLatitude, $dropoffLongitude)');

      final response = await _supabase.functions.invoke(
        'calculate-route-time',
        body: {
          'pickupLatitude': pickupLatitude,
          'pickupLongitude': pickupLongitude,
          'dropoffLatitude': dropoffLatitude,
          'dropoffLongitude': dropoffLongitude,
        },
      );

      if (response.status != 200) {
        Logger.d('❌ Failed to calculate route time: ${response.status}');
        Logger.d('   Error: ${response.data}');
        return null;
      }

      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        Logger.d('❌ Route calculation failed: ${data?['error'] ?? 'Unknown error'}');
        return null;
      }

      final result = RouteTimeResult(
        durationSeconds: data['durationSeconds'] as int? ?? 0,
        distanceMeters: data['distanceMeters'] as int? ?? 0,
        timeLimitSeconds: data['timeLimitSeconds'] as int? ?? 0,
        durationMinutes: data['durationMinutes'] as int? ?? 0,
        timeLimitMinutes: data['timeLimitMinutes'] as int? ?? 0,
      );

      Logger.d('✅ Route time calculated:');
      Logger.d('   Duration: ${result.durationSeconds}s (${result.durationMinutes} min)');
      Logger.d('   Distance: ${result.distanceMeters}m');
      Logger.d('   Time limit: ${result.timeLimitSeconds}s (${result.timeLimitMinutes} min)');

      return result;
    } catch (e) {
      Logger.d('❌ Error calculating route time: $e');
      return null;
    }
  }
}

/// Result of route time calculation
class RouteTimeResult {
  final int durationSeconds;
  final int distanceMeters;
  final int timeLimitSeconds;
  final int durationMinutes;
  final int timeLimitMinutes;

  RouteTimeResult({
    required this.durationSeconds,
    required this.distanceMeters,
    required this.timeLimitSeconds,
    required this.durationMinutes,
    required this.timeLimitMinutes,
  });
}

