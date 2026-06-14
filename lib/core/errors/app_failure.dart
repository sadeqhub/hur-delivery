/// Typed failure returned from repository methods instead of throwing.
class AppFailure implements Exception {
  const AppFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause != null ? 'AppFailure($message, cause: $cause)' : 'AppFailure($message)';
}
