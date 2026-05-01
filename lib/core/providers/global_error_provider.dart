import 'dart:async';
import 'package:flutter/material.dart';
import '../services/error_manager.dart';
import '../localization/app_localizations.dart';

enum ErrorSeverity { error, warning, info, success }

class GlobalErrorEntry {
  final AppError? appError;
  final String? message;
  final ErrorSeverity severity;
  final bool isRetryable;
  final VoidCallback? onRetry;
  final DateTime timestamp;

  GlobalErrorEntry({
    this.appError,
    this.message,
    required this.severity,
    required this.isRetryable,
    this.onRetry,
  }) : timestamp = DateTime.now();
}

/// Central error display bus. Call [showAppError] or [showMessage] from anywhere —
/// the overlay in main.dart renders the toast in the current language automatically.
class GlobalErrorProvider extends ChangeNotifier {
  static final GlobalErrorProvider _instance = GlobalErrorProvider._internal();
  factory GlobalErrorProvider() => _instance;
  GlobalErrorProvider._internal();

  GlobalErrorEntry? _current;
  Timer? _dismissTimer;

  GlobalErrorEntry? get current => _current;
  bool get hasError => _current != null;

  /// Show a typed [AppError] from ErrorManager. Message resolved at render time
  /// using the current locale, so language switches are handled automatically.
  void showAppError(AppError error, {VoidCallback? onRetry}) {
    _show(GlobalErrorEntry(
      appError: error,
      severity: _severityForType(error.type),
      isRetryable: error.isRetryable,
      onRetry: onRetry,
    ));
  }

  /// Show an already-localized string (e.g. from a provider's error field).
  void showMessage(
    String message, {
    ErrorSeverity severity = ErrorSeverity.error,
    bool isRetryable = false,
    VoidCallback? onRetry,
  }) {
    _show(GlobalErrorEntry(
      message: message,
      severity: severity,
      isRetryable: isRetryable,
      onRetry: onRetry,
    ));
  }

  void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _current = null;
    notifyListeners();
  }

  void _show(GlobalErrorEntry entry) {
    _dismissTimer?.cancel();
    _current = entry;
    notifyListeners();
    final duration = entry.isRetryable ? 6000 : 4500;
    _dismissTimer = Timer(Duration(milliseconds: duration), () {
      if (_current == entry) dismiss();
    });
  }

  // ── Helpers used by the overlay ──────────────────────────────────────────

  static String titleForEntry(GlobalErrorEntry entry, AppLocalizations loc) {
    if (entry.appError != null) return _titleForType(entry.appError!.type, loc);
    return '';
  }

  static String bodyForEntry(GlobalErrorEntry entry, AppLocalizations loc) {
    if (entry.appError != null) return _bodyForType(entry.appError!.type, loc);
    return entry.message ?? '';
  }

  static IconData iconForEntry(GlobalErrorEntry entry) {
    if (entry.appError != null) return _iconForType(entry.appError!.type);
    return _iconForSeverity(entry.severity);
  }

  // ── Private mapping helpers ───────────────────────────────────────────────

  static String _titleForType(ErrorType type, AppLocalizations loc) {
    switch (type) {
      case ErrorType.networkConnection:
        return loc.errNetworkTitle;
      case ErrorType.networkTimeout:
        return loc.errTimeoutTitle;
      case ErrorType.networkHandshake:
      case ErrorType.networkClosed:
        return loc.errServerConnTitle;
      case ErrorType.authExpired:
        return loc.errAuthExpiredTitle;
      case ErrorType.authInvalid:
        return loc.errAuthInvalidTitle;
      case ErrorType.serverError:
        return loc.errServerTitle;
      case ErrorType.rateLimit:
        return loc.errRateLimitTitle;
      case ErrorType.notFound:
        return loc.errNotFoundTitle;
      case ErrorType.permissionDenied:
        return loc.errPermissionTitle;
      case ErrorType.unknown:
        return loc.errUnknownTitle;
    }
  }

  static String _bodyForType(ErrorType type, AppLocalizations loc) {
    switch (type) {
      case ErrorType.networkConnection:
        return loc.errNetworkBody;
      case ErrorType.networkTimeout:
        return loc.errTimeoutBody;
      case ErrorType.networkHandshake:
      case ErrorType.networkClosed:
        return loc.errServerConnBody;
      case ErrorType.authExpired:
        return loc.errAuthExpiredBody;
      case ErrorType.authInvalid:
        return loc.errAuthInvalidBody;
      case ErrorType.serverError:
        return loc.errServerBody;
      case ErrorType.rateLimit:
        return loc.errRateLimitBody;
      case ErrorType.notFound:
        return loc.errNotFoundBody;
      case ErrorType.permissionDenied:
        return loc.errPermissionBody;
      case ErrorType.unknown:
        return loc.errUnknownBody;
    }
  }

  static ErrorSeverity _severityForType(ErrorType type) {
    switch (type) {
      case ErrorType.networkConnection:
      case ErrorType.networkTimeout:
      case ErrorType.networkHandshake:
      case ErrorType.networkClosed:
      case ErrorType.notFound:
        return ErrorSeverity.warning;
      case ErrorType.authExpired:
      case ErrorType.authInvalid:
      case ErrorType.permissionDenied:
      case ErrorType.serverError:
      case ErrorType.rateLimit:
      case ErrorType.unknown:
        return ErrorSeverity.error;
    }
  }

  static IconData _iconForType(ErrorType type) {
    switch (type) {
      case ErrorType.networkConnection:
        return Icons.wifi_off_rounded;
      case ErrorType.networkTimeout:
        return Icons.timer_off_rounded;
      case ErrorType.networkHandshake:
      case ErrorType.networkClosed:
        return Icons.sync_problem_rounded;
      case ErrorType.authExpired:
      case ErrorType.authInvalid:
        return Icons.lock_outline_rounded;
      case ErrorType.serverError:
        return Icons.cloud_off_rounded;
      case ErrorType.rateLimit:
        return Icons.hourglass_top_rounded;
      case ErrorType.notFound:
        return Icons.search_off_rounded;
      case ErrorType.permissionDenied:
        return Icons.block_rounded;
      case ErrorType.unknown:
        return Icons.error_outline_rounded;
    }
  }

  static IconData _iconForSeverity(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.error:
        return Icons.error_outline_rounded;
      case ErrorSeverity.warning:
        return Icons.warning_amber_rounded;
      case ErrorSeverity.info:
        return Icons.info_outline_rounded;
      case ErrorSeverity.success:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }
}
