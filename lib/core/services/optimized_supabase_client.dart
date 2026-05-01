import 'package:supabase_flutter/supabase_flutter.dart';
import 'response_cache_service.dart';
import 'network_quality_service.dart';

/// Optimized Supabase client wrapper that adds:
/// 1. Response compression support
/// 2. Response caching
/// 3. Selective field queries (only requested fields)
/// 4. Network-aware behavior
class OptimizedSupabaseClient {
  static final OptimizedSupabaseClient _instance = OptimizedSupabaseClient._internal();
  factory OptimizedSupabaseClient() => _instance;
  OptimizedSupabaseClient._internal();

  final _cache = ResponseCacheService();
  final _networkQuality = NetworkQualityService();

  /// Get the base Supabase client
  SupabaseClient get client => Supabase.instance.client;

  /// Execute a query with caching and optimization
  Future<List<Map<String, dynamic>>> queryWithCache({
    required String table,
    required String cacheKey,
    required dynamic Function(SupabaseQueryBuilder) queryBuilder,
    Duration? cacheDuration,
    bool useCache = true,
  }) async {
    if (useCache && _networkQuality.shouldUseAggressiveCaching()) {
      final cached = await _cache.getCachedResponse<List<Map<String, dynamic>>>(cacheKey);
      if (cached != null) return cached;
    }

    final response = await queryBuilder(client.from(table)) as List<Map<String, dynamic>>;

    if (useCache && _networkQuality.shouldUseAggressiveCaching()) {
      await _cache.cacheResponse(
        key: cacheKey,
        data: response,
        cacheDuration: cacheDuration ?? const Duration(minutes: 2),
      );
    }

    return response;
  }

  /// Select only required fields (reduces response size)
  PostgrestTransformBuilder<PostgrestList> selectFields(
    SupabaseQueryBuilder query,
    List<String> fields,
  ) {
    return query.select(fields.isEmpty ? '*' : fields.join(', '));
  }

  /// Get optimized query builder
  SupabaseQueryBuilder getOptimizedQuery(String table) {
    return client.from(table);
  }
}

