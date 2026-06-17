/// Typed failure returned from repository methods instead of throwing.
class AppFailure implements Exception {
  const AppFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  // ── Named factory constructors ──────────────────────────────────────────
  const AppFailure.network()
      : message = 'network',
        cause = null;

  const AppFailure.timeout()
      : message = 'timeout',
        cause = null;

  const AppFailure.authExpired()
      : message = 'auth_expired',
        cause = null;

  const AppFailure.unauthorized()
      : message = 'unauthorized',
        cause = null;

  const AppFailure.rateLimited()
      : message = 'rate_limited',
        cause = null;

  const AppFailure.maintenance()
      : message = 'maintenance',
        cause = null;

  const AppFailure.notFound(String resource)
      : message = 'not_found',
        cause = resource;

  AppFailure.validation(String code, {String? hint})
      : message = 'validation',
        cause = hint ?? code;

  AppFailure.unknown(Object error)
      : message = 'unknown',
        cause = error;

  @override
  String toString() => cause != null ? 'AppFailure($message, cause: $cause)' : 'AppFailure($message)';
}
