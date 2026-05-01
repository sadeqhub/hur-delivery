import 'package:supabase_flutter/supabase_flutter.dart';

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
      print('🌐 Calculating route time...');
      print('   Pickup: ($pickupLatitude, $pickupLongitude)');
      print('   Dropoff: ($dropoffLatitude, $dropoffLongitude)');

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
        print('❌ Failed to calculate route time: ${response.status}');
        print('   Error: ${response.data}');
        return null;
      }

      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        print('❌ Route calculation failed: ${data?['error'] ?? 'Unknown error'}');
        return null;
      }

      final result = RouteTimeResult(
        durationSeconds: data['durationSeconds'] as int? ?? 0,
        distanceMeters: data['distanceMeters'] as int? ?? 0,
        timeLimitSeconds: data['timeLimitSeconds'] as int? ?? 0,
        durationMinutes: data['durationMinutes'] as int? ?? 0,
        timeLimitMinutes: data['timeLimitMinutes'] as int? ?? 0,
      );

      print('✅ Route time calculated:');
      print('   Duration: ${result.durationSeconds}s (${result.durationMinutes} min)');
      print('   Distance: ${result.distanceMeters}m');
      print('   Time limit: ${result.timeLimitSeconds}s (${result.timeLimitMinutes} min)');

      return result;
    } catch (e) {
      print('❌ Error calculating route time: $e');
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

