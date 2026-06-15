import 'package:supabase_flutter/supabase_flutter.dart';

/// Single choke-point for all Supabase data access.
/// Use this instead of Supabase.instance.client directly.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  SupabaseClient get _client => Supabase.instance.client;

  SupabaseQueryBuilder from(String table) => _client.from(table);

  PostgrestFilterBuilder<dynamic> rpc(
    String fn, {
    Map<String, dynamic>? params,
  }) =>
      _client.rpc(fn, params: params);
}
