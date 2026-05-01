/// Event to notify when customer location is updated
/// This is broadcast when a location update announcement is received
class LocationUpdateEvent {
  final String orderId;
  final double newLatitude;
  final double newLongitude;
  final DateTime timestamp;

  LocationUpdateEvent({
    required this.orderId,
    required this.newLatitude,
    required this.newLongitude,
    required this.timestamp,
  });
}

