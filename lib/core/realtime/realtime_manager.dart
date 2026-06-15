import 'package:supabase_flutter/supabase_flutter.dart';

/// Minimal facade for Supabase Realtime health checks.
///
/// Check [isDisabled] to gate timer-based fallback polling:
/// ```dart
/// if (RealtimeManager.instance.isDisabled) {
///   _timer = Timer.periodic(const Duration(seconds: 30), (_) => _poll());
/// }
/// ```
class RealtimeManager {
  static final RealtimeManager instance = RealtimeManager._();
  RealtimeManager._();

  /// Returns true when the Supabase Realtime WebSocket is not open.
  /// Callers should activate timer-based fallback polling when this is true.
  bool get isDisabled {
    try {
      return Supabase.instance.client.realtime.connState != 'open';
    } catch (_) {
      return true;
    }
  }
}
