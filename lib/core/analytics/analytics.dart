import '../logging/logger.dart';

/// Typed analytics facade for Hur Delivery.
///
/// NOTE: Firebase Analytics and Performance are not yet wired up in this
/// build — all methods are no-ops that log via [Logger].
abstract final class Analytics {
  Analytics._();

  static const String _tag = 'Analytics';

  // ─── Identity ─────────────────────────────────────────────────────────────

  static Future<void> onLogin({
    required String userId,
    required String role,
  }) async {
    Logger.d(_tag, 'onLogin: role=$role');
  }

  static Future<void> onLogout() async {
    Logger.d(_tag, 'onLogout');
  }

  // ─── Auth funnel ──────────────────────────────────────────────────────────

  static Future<void> otpRequested({required bool isRegistration}) async {
    Logger.d(_tag, 'otpRequested: isRegistration=$isRegistration');
  }

  static Future<void> otpVerified() async => Logger.d(_tag, 'otpVerified');

  static Future<void> otpFailed({required String reason}) async {
    Logger.d(_tag, 'otpFailed: reason=$reason');
  }

  static Future<void> registered({required String role}) async {
    Logger.d(_tag, 'registered: role=$role');
  }

  static Future<void> loggedIn({required String role}) async {
    Logger.d(_tag, 'loggedIn: role=$role');
  }

  // ─── Order funnel ─────────────────────────────────────────────────────────

  static Future<void> orderCreated({
    required String orderId,
    required String distanceBand,
    required String feeBand,
  }) async {
    Logger.d(_tag, 'orderCreated: orderId=${orderId.hashCode} band=$distanceBand fee=$feeBand');
  }

  static Future<void> driverAssigned({required String orderId}) async {
    Logger.d(_tag, 'driverAssigned');
  }

  static Future<void> orderAccepted({required String orderId}) async {
    Logger.d(_tag, 'orderAccepted');
  }

  static Future<void> orderPickedUp({required String orderId}) async {
    Logger.d(_tag, 'orderPickedUp');
  }

  static Future<void> orderDelivered({
    required String orderId,
    required String feeBand,
  }) async {
    Logger.d(_tag, 'orderDelivered: feeBand=$feeBand');
  }

  static Future<void> orderCancelled({
    required String orderId,
    required String reason,
    required String cancelledBy,
  }) async {
    Logger.d(_tag, 'orderCancelled: reason=$reason by=$cancelledBy');
  }

  static Future<void> recordNonFatal(
    Object error, {
    StackTrace? stack,
    String? context,
  }) async {
    Logger.w(_tag, 'recordNonFatal: context=$context error=$error');
  }

  // ─── Band helpers ─────────────────────────────────────────────────────────

  static String distanceBand(double km) {
    if (km < 1) return '0-1km';
    if (km < 3) return '1-3km';
    if (km < 6) return '3-6km';
    if (km < 10) return '6-10km';
    return '10km+';
  }

  static String feeBand(double iqd) {
    if (iqd < 2000) return 'low';
    if (iqd < 3500) return 'medium';
    if (iqd < 5000) return 'high';
    return 'very_high';
  }
}
