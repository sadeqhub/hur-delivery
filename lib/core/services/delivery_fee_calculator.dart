import 'dart:math' as math;

/// Service to calculate delivery fees based on distance
/// 
/// Formula designed to:
/// - Minimum fee: 1500 IQD
/// - Maximum fee: 5000 IQD
/// - Most orders fall in 2000-3000 IQD range (appealing to merchants and drivers)
class DeliveryFeeCalculator {
  // Fee constants
  static const double minFee = 1500.0;
  static const double maxFee = 5000.0;
  
  // Distance thresholds (in kilometers)
  static const double shortDistanceThreshold = 1.0;  // 0-1 km
  static const double mediumDistanceThreshold = 3.0;  // 1-3 km (most common)
  static const double longDistanceThreshold = 6.0;     // 3-6 km
  static const double veryLongDistanceThreshold = 10.0; // 6-10 km
  // 10+ km uses max fee
  
  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in kilometers
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final double distance = earthRadius * c;

    return distance;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Calculate delivery fee based on distance
  /// 
  /// Uses a piecewise linear formula:
  /// - 0-1 km: 1500-1800 IQD (base fee + small increment)
  /// - 1-3 km: 1800-2500 IQD (most common range starts)
  /// - 3-6 km: 2500-3500 IQD (most common range continues)
  /// - 6-10 km: 3500-4500 IQD
  /// - 10+ km: 4500-5000 IQD (capped at 5000)
  /// 
  /// This ensures:
  /// - Most orders (2-5 km typical distances) fall in 2000-3000 IQD range
  /// - Short distances are affordable (1500-2000 IQD)
  /// - Long distances are fairly compensated (up to 5000 IQD)
  /// - Formula is predictable and transparent
  static double calculateFee(double distanceInKm) {
    // Ensure minimum distance is 0
    if (distanceInKm < 0) {
      distanceInKm = 0;
    }

    double fee;

    if (distanceInKm <= shortDistanceThreshold) {
      // 0-1 km: 1500-1800 IQD
      // Linear interpolation: 1500 + (distance * 300)
      fee = minFee + (distanceInKm * 300);
    } else if (distanceInKm <= mediumDistanceThreshold) {
      // 1-3 km: 1800-2500 IQD
      // Linear interpolation: 1800 + ((distance - 1) * 350)
      fee = 1800 + ((distanceInKm - shortDistanceThreshold) * 350);
    } else if (distanceInKm <= longDistanceThreshold) {
      // 3-6 km: 2500-3500 IQD
      // Linear interpolation: 2500 + ((distance - 3) * 333.33)
      fee = 2500 + ((distanceInKm - mediumDistanceThreshold) * (1000 / 3));
    } else if (distanceInKm <= veryLongDistanceThreshold) {
      // 6-10 km: 3500-4500 IQD
      // Linear interpolation: 3500 + ((distance - 6) * 250)
      fee = 3500 + ((distanceInKm - longDistanceThreshold) * 250);
    } else {
      // 10+ km: 4500-5000 IQD
      // Linear interpolation: 4500 + ((distance - 10) * 100), capped at 5000
      // For very long distances, we use a slower rate to cap at 5000
      final excessDistance = distanceInKm - veryLongDistanceThreshold;
      // Cap the fee increase so it reaches 5000 at around 15 km
      fee = 4500 + (excessDistance * 100);
      if (fee > maxFee) {
        fee = maxFee;
      }
    }

    // Round to nearest 250 IQD (lowest currency denomination in IQD)
    fee = (fee / 250).round() * 250.0;

    // Ensure fee is within bounds
    if (fee < minFee) {
      fee = minFee;
    }
    if (fee > maxFee) {
      fee = maxFee;
    }

    return fee;
  }

  /// Calculate delivery fee from coordinates
  /// 
  /// Convenience method that calculates distance first, then fee
  static double calculateFeeFromCoordinates(
    double pickupLat,
    double pickupLon,
    double deliveryLat,
    double deliveryLon,
  ) {
    final distance = calculateDistance(
      pickupLat,
      pickupLon,
      deliveryLat,
      deliveryLon,
    );
    return calculateFee(distance);
  }

  /// Get fee breakdown for display purposes
  /// Returns a map with distance, calculated fee, and fee range info
  static Map<String, dynamic> getFeeBreakdown(
    double pickupLat,
    double pickupLon,
    double deliveryLat,
    double deliveryLon,
  ) {
    final distance = calculateDistance(
      pickupLat,
      pickupLon,
      deliveryLat,
      deliveryLon,
    );
    final fee = calculateFee(distance);
    
    String feeRange;
    if (fee <= 1800) {
      feeRange = 'قريب';
    } else if (fee <= 2500) {
      feeRange = 'متوسط';
    } else if (fee <= 3500) {
      feeRange = 'بعيد';
    } else {
      feeRange = 'بعيد جداً';
    }

    return {
      'distance': distance,
      'fee': fee,
      'feeRange': feeRange,
      'minFee': minFee,
      'maxFee': maxFee,
    };
  }
}

