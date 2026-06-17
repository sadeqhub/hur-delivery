import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Single choke-point for all Supabase data access.
/// Use this instead of Supabase.instance.client directly.
class ApiClient {
  ApiClient._();

  /// Constructor for test subclasses only — does not touch Supabase.
  // ignore: unused_element
  @visibleForTesting
  ApiClient.forTest();

  static final ApiClient instance = ApiClient._();

  SupabaseClient get _client => Supabase.instance.client;

  SupabaseQueryBuilder from(String table) => _client.from(table);

  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    Duration? timeout,
  }) =>
      _client.rpc<T>(fn, params: params);

  /// Invokes a Supabase Edge Function by name.
  Future<dynamic> invoke(
    String fn, {
    Map<String, dynamic>? body,
    Duration? timeout,
  }) =>
      _client.functions
          .invoke(fn, body: body)
          .then((r) => r.data)
          .timeout(timeout ?? const Duration(seconds: 30));

  /// Returns a [RealtimeChannel] for a given channel name.
  dynamic channel(String name) => _client.channel(name);
}
