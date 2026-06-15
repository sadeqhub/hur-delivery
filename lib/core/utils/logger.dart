import 'package:flutter/foundation.dart';

/// Thin logging wrapper. In release mode, debugPrint is a no-op so these
/// calls are automatically stripped from output.
class Logger {
  Logger._();

  static void d(Object? message) => debugPrint(message?.toString());
  static void e(Object? message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[ERROR] ${message?.toString()}');
    if (error != null) debugPrint('  cause: $error');
    if (stackTrace != null) debugPrint('  $stackTrace');
  }

  static Map<String, dynamic> redactPayload(Map<String, dynamic> payload) {
    const sensitiveKeys = {
      'access_token', 'refresh_token', 'password', 'code', 'otp', 'token'
    };
    return payload.map(
      (k, v) => MapEntry(k, sensitiveKeys.contains(k) ? '[REDACTED]' : v),
    );
  }
}
