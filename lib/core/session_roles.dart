import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads the user's role from the server-issued JWT claim `app_role`.
///
/// The claim is injected by the `custom_access_token_hook` SQL function on every
/// token issue/refresh, reading from `public.users.role`. Because it comes from
/// the server, it cannot be elevated by calling `auth.updateUser` on the client.
///
/// Usage:
///   final role = SessionRoles.fromSession(Supabase.instance.client.auth.currentSession);
class SessionRoles {
  SessionRoles._();

  /// Returns the role string from the JWT `app_role` claim, or null if the
  /// claim is absent (token predates the hook — caller should re-authenticate
  /// or fetch the users row directly as a fallback).
  static String? fromSession(Session? session) {
    if (session == null) return null;
    // Custom access token hook writes app_role into claims → appMetadata in Flutter SDK.
    final role = session.user.appMetadata['app_role'] as String?;
    if (role != null && role.isNotEmpty) return role;
    return null;
  }

  /// Convenience wrapper that reads the current session automatically.
  static String? current() =>
      fromSession(Supabase.instance.client.auth.currentSession);
}
