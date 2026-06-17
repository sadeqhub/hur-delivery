import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Centralised logging facade for the Hur Delivery app.
///
/// ## Usage
///   Logger.d('AuthProvider', 'OTP sent to ${Logger.redactPhone(phone)}');
///   Logger.e('OrderProvider', 'Failed to update status', error: e, stack: st);
///
/// ## Levels
///   d — debug: dropped in release builds
///   i — info:  dropped in release builds
///   w — warn:  forwarded to Crashlytics as a breadcrumb in release
///   e — error: forwarded to Crashlytics as a non-fatal in release
///
/// ## PII redaction helpers
///   Logger.redactPhone('9647812345678') → '9647•••••678'
///   Logger.redactCoords(33.3152, 44.3661) → '33.31, 44.36'
///   Logger.redactId('uuid-string') → 'uuid…'
///
/// ## Conventions (enforced by scripts/check_conventions.sh)
///   - Never use raw `print()` in lib/ — avoid_print is set to error
///   - Never log tokens, OTPs, passwords, or full HTTP payloads
///   - Use redact helpers for all phone numbers, coordinates, and user IDs
class Logger {
  const Logger._();

  // ─── Public API ─────────────────────────────────────────────────────────

  /// Debug log — dropped entirely in release builds.
  static void d(String tag, String message) {
    if (kReleaseMode) return;
    _log('D', tag, message);
  }

  /// Info log — dropped entirely in release builds.
  static void i(String tag, String message) {
    if (kReleaseMode) return;
    _log('I', tag, message);
  }

  /// Warning log — forwarded to Crashlytics as a breadcrumb in release.
  static void w(String tag, String message, {Object? error}) {
    if (!kReleaseMode) {
      _log('W', tag, message, error: error);
    } else {
      try {
        FirebaseCrashlytics.instance.log('[$tag] $message');
      } catch (_) {}
    }
  }

  /// Error log — forwarded to Crashlytics as a non-fatal in release.
  /// [error] and [stack] are attached to the Crashlytics report when provided.
  static void e(
    String tag,
    String message, {
    Object? error,
    StackTrace? stack,
  }) {
    if (!kReleaseMode) {
      _log('E', tag, message, error: error);
      if (stack != null) {
        developer.log(stack.toString(), name: tag);
      }
    } else {
      try {
        FirebaseCrashlytics.instance.log('[$tag] $message');
        if (error != null) {
          FirebaseCrashlytics.instance.recordError(
            error,
            stack,
            reason: '[$tag] $message',
            fatal: false,
          );
        }
      } catch (_) {}
    }
  }

  // ─── PII Redaction Helpers ───────────────────────────────────────────────

  /// Redacts the middle digits of a phone number.
  /// '9647812345678' → '9647•••••678'
  /// Works for any E.164-style number ≥ 10 digits.
  static String redactPhone(String? phone) {
    if (phone == null || phone.isEmpty) return '[no phone]';
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 8) return '•••';
    final prefix = digits.substring(0, digits.length - 3);
    final suffix = digits.substring(digits.length - 3);
    final redacted = '•' * (prefix.length - 4).clamp(1, 8);
    final visiblePrefix = digits.length > 7 ? digits.substring(0, 4) : '';
    return '$visiblePrefix$redacted$suffix';
  }

  /// Truncates coordinates to 2 decimal places (≈ 1.1 km precision).
  /// Never logs precise GPS.
  static String redactCoords(double? lat, double? lng) {
    if (lat == null || lng == null) return '[no location]';
    return '${lat.toStringAsFixed(2)}, ${lng.toStringAsFixed(2)}';
  }

  /// Truncates a UUID/ID string to first 8 chars + ellipsis.
  static String redactId(String? id) {
    if (id == null || id.isEmpty) return '[no id]';
    return id.length > 8 ? '${id.substring(0, 8)}…' : id;
  }

  // ─── Internal ────────────────────────────────────────────────────────────

  static void _log(String level, String tag, String message, {Object? error}) {
    final prefix = '[$level/$tag]';
    if (error != null) {
      developer.log('$prefix $message | error: $error', name: tag);
    } else {
      developer.log('$prefix $message', name: tag);
    }
  }
}
