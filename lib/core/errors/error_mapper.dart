import 'dart:async' show TimeoutException;
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_failure.dart';

/// Maps raw exceptions from Supabase, Dart I/O, and edge functions to
/// typed [AppFailure] values.
///
/// ## Usage
///   } catch (e, st) {
///     final failure = ErrorMapper.map(e);
///     Logger.e('OrderRepository', 'createOrder failed', error: e, stack: st);
///     throw failure;
///   }
abstract final class ErrorMapper {
  const ErrorMapper._();

  /// Maps any caught [error] to an [AppFailure].
  /// Never returns null; always falls through to [UnknownFailure].
  static AppFailure map(Object error) {
    // ── Dart I/O ──────────────────────────────────────────────────────────
    if (error is SocketException) {
      return const AppFailure.network();
    }
    if (error is TimeoutException) {
      return const AppFailure.timeout();
    }

    // ── Supabase Auth ─────────────────────────────────────────────────────
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      final statusCode = error.statusCode ?? '';

      if (statusCode == '401' || msg.contains('jwt expired') ||
          msg.contains('invalid refresh token') ||
          msg.contains('token expired') ||
          msg.contains('session expired')) {
        return const AppFailure.authExpired();
      }
      if (statusCode == '403' || msg.contains('not authorized') ||
          msg.contains('forbidden')) {
        return const AppFailure.unauthorized();
      }
      if (statusCode == '429' || msg.contains('rate limit') ||
          msg.contains('too many requests')) {
        return const AppFailure.rateLimited();
      }
      // Maintenance mode signalled via AuthException message
      if (msg.contains('maintenance') || msg.contains('system_disabled')) {
        return const AppFailure.maintenance();
      }
    }

    // ── Supabase PostgREST ─────────────────────────────────────────────────
    if (error is PostgrestException) {
      final code = error.code ?? '';
      final msg = (error.message).toLowerCase();

      // PGRST116 = "not found" (empty result from single())
      if (code == 'PGRST116' || code == '404') {
        return const AppFailure.notFound('المورد');
      }
      // 401 / 403 access errors
      if (code == '401' || msg.contains('jwt')) {
        return const AppFailure.authExpired();
      }
      if (code == '403' || msg.contains('rls') || msg.contains('permission denied')) {
        return const AppFailure.unauthorized();
      }
      // 23xxx = integrity constraint violations (validation)
      if (code.startsWith('23') || code.startsWith('22')) {
        return AppFailure.validation(code, hint: error.hint);
      }
      // Maintenance via system_settings check
      if (msg.contains('system_disabled') || msg.contains('maintenance')) {
        return const AppFailure.maintenance();
      }
      // Network errors tunnelled via PostgREST
      if (msg.contains('connection') || msg.contains('network') ||
          msg.contains('timeout')) {
        return const AppFailure.network();
      }
    }

    // ── Supabase Functions (edge function) ─────────────────────────────────
    if (error is FunctionException) {
      final status = error.status ?? 0;
      if (status == 401) return const AppFailure.authExpired();
      if (status == 403) return const AppFailure.unauthorized();
      if (status == 404) return const AppFailure.notFound('Edge function');
      if (status == 429) {
        // Try to extract retry_after from response details
        return const AppFailure.rateLimited();
      }
      if (status == 503) return const AppFailure.maintenance();
    }

    // ── String-based last resort (for exceptions we can't type more precisely)
    final msg = error.toString().toLowerCase();
    if (msg.contains('socketexception') || msg.contains('no address associated') ||
        msg.contains('network is unreachable')) {
      return const AppFailure.network();
    }
    if (msg.contains('timeoutexception') || msg.contains('timed out')) {
      return const AppFailure.timeout();
    }
    if (msg.contains('jwt expired') || msg.contains('session expired')) {
      return const AppFailure.authExpired();
    }
    if (msg.contains('system_disabled') || msg.contains('maintenance')) {
      return const AppFailure.maintenance();
    }

    return AppFailure.unknown(error);
  }

  /// Convenience: map + rethrow as [AppFailure].
  static Never mapAndThrow(Object error) => throw map(error);
}
