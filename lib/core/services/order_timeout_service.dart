import '../constants/app_constants.dart';

/// Provides a stateless accept-window countdown.
/// All enforcement is handled server-side by the Postgres auto-reject function.
/// This class only does arithmetic: elapsed = now - driverAssignedAt.
class OrderTimeoutService {
  OrderTimeoutService._();
  static final OrderTimeoutService instance = OrderTimeoutService._();

  /// Returns seconds remaining in the accept window, clamped to [0, timeout].
  /// Returns 0 when [assignedAt] is null.
  int getLiveAcceptCountdownSeconds(String orderId, DateTime? assignedAt) {
    if (assignedAt == null) return 0;
    final elapsed = DateTime.now().toUtc().difference(assignedAt.toUtc()).inSeconds;
    return (AppConstants.driverAcceptTimeoutSeconds - elapsed)
        .clamp(0, AppConstants.driverAcceptTimeoutSeconds);
  }

  void dispose() {}
}
