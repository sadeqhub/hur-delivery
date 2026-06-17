import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import '../logging/logger.dart';

/// Typed analytics facade for Hur Delivery.
///
/// All event names and parameter keys are defined here — no stringly-typed
/// calls at the call sites. Events are bucketed into three funnels:
///   • Order funnel  (orderCreated → delivered / cancelled)
///   • Auth funnel   (otpRequested → loggedIn / registered)
///   • [Performance traces] via [startTrace]
///
/// No raw PII is sent: order IDs are redacted, phone numbers are never logged.
/// Fee / distance values are sent as anonymised bands (e.g. "0-10km", "low").
///
/// ## Usage
/// ```dart
/// Analytics.instance.orderCreated(orderId: 'xxx', distanceBand: '1-5km', feeBand: 'medium');
/// ```
abstract final class Analytics {
  Analytics._();

  static final _analytics = FirebaseAnalytics.instance;
  static final _crashlytics = FirebaseCrashlytics.instance;
  static final _performance = FirebasePerformance.instance;
  static const String _tag = 'Analytics';

  // ─── Identity ─────────────────────────────────────────────────────────────

  /// Call after successful login. Sets Crashlytics user ID and a role key.
  /// The user ID is hashed before being sent (no raw phone / email).
  static Future<void> onLogin({
    required String userId,
    required String role,
  }) async {
    try {
      // Use a stable hashed identifier — never send raw auth UID to analytics
      await Future.wait([
        _analytics.setUserId(id: userId.hashCode.toRadixString(16)),
        _analytics.setUserProperty(name: 'role', value: role),
        _crashlytics.setUserIdentifier(userId.hashCode.toRadixString(16)),
        _crashlytics.setCustomKey('role', role),
      ]);
      Logger.d(_tag, 'Analytics identity set: role=$role');
    } catch (e) {
      Logger.w(_tag, 'Analytics.onLogin failed (non-critical): $e');
    }
  }

  /// Clear identity on logout.
  static Future<void> onLogout() async {
    try {
      await Future.wait([
        _analytics.setUserId(id: null),
        _crashlytics.setUserIdentifier(''),
        _crashlytics.setCustomKey('role', 'none'),
      ]);
    } catch (e) {
      Logger.w(_tag, 'Analytics.onLogout failed (non-critical): $e');
    }
  }

  // ─── Auth funnel ──────────────────────────────────────────────────────────

  /// OTP requested (login or registration).
  static Future<void> otpRequested({required bool isRegistration}) =>
      _log('otp_requested', {'is_registration': isRegistration.toString()});

  /// OTP verified successfully.
  static Future<void> otpVerified() => _log('otp_verified', {});

  /// OTP verification failed (wrong code, expired, locked out).
  static Future<void> otpFailed({required String reason}) =>
      _log('otp_failed', {'reason': reason});

  /// New user registered.
  static Future<void> registered({required String role}) =>
      _log('user_registered', {'role': role});

  /// Existing user logged in successfully.
  static Future<void> loggedIn({required String role}) =>
      _log('user_logged_in', {'role': role});

  // ─── Order funnel ─────────────────────────────────────────────────────────

  /// Merchant created a new order.
  static Future<void> orderCreated({
    required String orderId,
    required String distanceBand,
    required String feeBand,
  }) =>
      _log('order_created', {
        'order_id': orderId.hashCode.toRadixString(16),
        'distance_band': distanceBand,
        'fee_band': feeBand,
      });

  /// A driver was assigned to an order.
  static Future<void> driverAssigned({required String orderId}) =>
      _log('driver_assigned', {'order_id': orderId.hashCode.toRadixString(16)});

  /// Driver accepted the order (within accept window).
  static Future<void> orderAccepted({required String orderId}) =>
      _log('order_accepted', {'order_id': orderId.hashCode.toRadixString(16)});

  /// Driver picked up the order.
  static Future<void> orderPickedUp({required String orderId}) =>
      _log('order_picked_up', {'order_id': orderId.hashCode.toRadixString(16)});

  /// Order delivered successfully.
  static Future<void> orderDelivered({
    required String orderId,
    required String feeBand,
  }) =>
      _log('order_delivered', {
        'order_id': orderId.hashCode.toRadixString(16),
        'fee_band': feeBand,
      });

  /// Order cancelled.
  static Future<void> orderCancelled({
    required String orderId,
    required String reason,
    required String cancelledBy, // 'merchant' | 'driver' | 'system'
  }) =>
      _log('order_cancelled', {
        'order_id': orderId.hashCode.toRadixString(16),
        'reason': reason,
        'cancelled_by': cancelledBy,
      });

  // ─── Errors / non-fatals ──────────────────────────────────────────────────

  /// Record a non-fatal error (e.g. from ErrorManager) to Crashlytics.
  static Future<void> recordNonFatal(
    Object error, {
    StackTrace? stack,
    String? context,
  }) async {
    try {
      if (context != null) {
        await _crashlytics.log(context);
      }
      await _crashlytics.recordError(error, stack, fatal: false);
    } catch (e) {
      Logger.w(_tag, 'recordNonFatal failed (non-critical): $e');
    }
  }

  // ─── Performance traces ───────────────────────────────────────────────────

  /// Starts a named performance trace. Call [HttpMetric.stop] when done.
  ///
  /// ```dart
  /// final trace = Analytics.startTrace('order_creation_round_trip');
  /// trace.start();
  /// ... // do the work
  /// await trace.stop();
  /// ```
  static Trace startTrace(String name) => _performance.newTrace(name);

  // ─── Internal ─────────────────────────────────────────────────────────────

  static Future<void> _log(
    String event,
    Map<String, String> params,
  ) async {
    try {
      await _analytics.logEvent(
        name: event,
        parameters: params.isEmpty ? null : params,
      );
      Logger.d(_tag, 'Event: $event ${params.isEmpty ? '' : params}');
    } catch (e) {
      Logger.w(_tag, '_log($event) failed (non-critical): $e');
    }
  }

  // ─── Band helpers (no PII, anonymised ranges) ─────────────────────────────

  /// Converts a distance in km to an anonymised band string.
  static String distanceBand(double km) {
    if (km < 1) return '0-1km';
    if (km < 3) return '1-3km';
    if (km < 6) return '3-6km';
    if (km < 10) return '6-10km';
    return '10km+';
  }

  /// Converts a fee in IQD to an anonymised band string.
  static String feeBand(double iqd) {
    if (iqd < 2000) return 'low';
    if (iqd < 3500) return 'medium';
    if (iqd < 5000) return 'high';
    return 'very_high';
  }
}
