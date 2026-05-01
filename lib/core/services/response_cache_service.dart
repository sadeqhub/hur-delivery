import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for caching API responses to reduce network calls on 4G
class ResponseCacheService {
  static final ResponseCacheService _instance = ResponseCacheService._internal();
  factory ResponseCacheService() => _instance;
  ResponseCacheService._internal();

  static const String _cachePrefix = 'api_cache_';
  static const Duration _defaultCacheDuration = Duration(minutes: 5);
  
  SharedPreferences? _prefs;
  final Map<String, _CachedResponse> _memoryCache = {};

  Future<void> _ensurePrefsLoaded() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Cache a response
  Future<void> cacheResponse({
    required String key,
    required dynamic data,
    Duration? cacheDuration,
  }) async {
    final duration = cacheDuration ?? _defaultCacheDuration;
    final expiresAt = DateTime.now().add(duration);
    
    final cached = _CachedResponse(
      data: data,
      expiresAt: expiresAt,
    );
    
    // Store in memory cache
    _memoryCache[key] = cached;
    
    // Store in persistent cache
    await _ensurePrefsLoaded();
    final jsonData = jsonEncode({
      'data': data,
      'expiresAt': expiresAt.toIso8601String(),
    });
    await _prefs?.setString('$_cachePrefix$key', jsonData);
  }

  /// Get cached response
  Future<T?> getCachedResponse<T>(String key) async {
    // Check memory cache first
    final memoryCached = _memoryCache[key];
    if (memoryCached != null) {
      if (memoryCached.expiresAt.isAfter(DateTime.now())) {
        return memoryCached.data as T?;
      } else {
        _memoryCache.remove(key);
      }
    }
    
    // Check persistent cache
    await _ensurePrefsLoaded();
    final cachedJson = _prefs?.getString('$_cachePrefix$key');
    if (cachedJson != null) {
      try {
        final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
        final expiresAt = DateTime.parse(decoded['expiresAt'] as String);
        
        if (expiresAt.isAfter(DateTime.now())) {
          final data = decoded['data'] as T?;
          // Restore to memory cache
          _memoryCache[key] = _CachedResponse(
            data: data,
            expiresAt: expiresAt,
          );
          return data;
        } else {
          // Expired, remove it
          await _prefs?.remove('$_cachePrefix$key');
        }
      } catch (e) {
        // Invalid cache, remove it
        await _prefs?.remove('$_cachePrefix$key');
      }
    }
    
    return null;
  }

  /// Invalidate cache for a key
  Future<void> invalidate(String key) async {
    _memoryCache.remove(key);
    await _ensurePrefsLoaded();
    await _prefs?.remove('$_cachePrefix$key');
  }

  /// Invalidate all caches matching a pattern
  Future<void> invalidatePattern(String pattern) async {
    await _ensurePrefsLoaded();
    final keys = _prefs?.getKeys() ?? {};
    for (final key in keys) {
      if (key.startsWith(_cachePrefix) && key.contains(pattern)) {
        await _prefs?.remove(key);
        final cacheKey = key.replaceFirst(_cachePrefix, '');
        _memoryCache.remove(cacheKey);
      }
    }
  }

  /// Clear all caches
  Future<void> clearAll() async {
    _memoryCache.clear();
    await _ensurePrefsLoaded();
    final keys = _prefs?.getKeys() ?? {};
    for (final key in keys) {
      if (key.startsWith(_cachePrefix)) {
        await _prefs?.remove(key);
      }
    }
  }

  /// Synchronous getter used by existing code paths.
  /// Returns the value from in-memory cache if present and not expired.
  /// If SharedPreferences is already loaded, will try to return persisted value as well.
  T? get<T>(String key) {
    final memoryCached = _memoryCache[key];
    if (memoryCached != null) {
      if (memoryCached.expiresAt.isAfter(DateTime.now())) {
        return memoryCached.data as T?;
      } else {
        _memoryCache.remove(key);
      }
    }

    // If prefs already loaded, try to return persisted value synchronously
    try {
      final prefs = _prefs;
      if (prefs != null) {
        final cachedJson = prefs.getString('$_cachePrefix$key');
        if (cachedJson != null) {
          final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
          final expiresAt = DateTime.parse(decoded['expiresAt'] as String);
          if (expiresAt.isAfter(DateTime.now())) {
            final data = decoded['data'] as T?;
            _memoryCache[key] = _CachedResponse(data: data, expiresAt: expiresAt);
            return data;
          } else {
            // expired - remove asynchronously
            invalidate(key);
          }
        }
      }
    } catch (_) {
      // Ignore decode errors here; treat as cache miss
    }

    return null;
  }

  /// Synchronous setter used by existing code paths.
  /// Stores to in-memory cache immediately and persists asynchronously.
  void set(String key, dynamic data, Duration? cacheDuration) {
    final duration = cacheDuration ?? _defaultCacheDuration;
    final expiresAt = DateTime.now().add(duration);

    final cached = _CachedResponse(data: data, expiresAt: expiresAt);
    _memoryCache[key] = cached;

    // Persist asynchronously without awaiting to avoid blocking callers
    () async {
      try {
        await _ensurePrefsLoaded();
        final jsonData = jsonEncode({
          'data': data,
          'expiresAt': expiresAt.toIso8601String(),
        });
        await _prefs?.setString('$_cachePrefix$key', jsonData);
      } catch (_) {
        // ignore persistence errors
      }
    }();
  }
}

class _CachedResponse {
  final dynamic data;
  final DateTime expiresAt;

  _CachedResponse({
    required this.data,
    required this.expiresAt,
  });
}

