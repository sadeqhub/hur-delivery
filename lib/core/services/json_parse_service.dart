import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Service for parsing large JSON responses in isolates to avoid blocking UI
class JsonParseService {
  static final JsonParseService _instance = JsonParseService._internal();
  factory JsonParseService() => _instance;
  JsonParseService._internal();

  /// Parse JSON in isolate (non-blocking)
  /// Use this for large JSON responses (> 100KB) to avoid blocking UI thread
  /// Note: For now, we parse directly since Supabase returns parsed data
  /// This service is ready for future use if we need to parse raw JSON strings
  static Future<Map<String, dynamic>> parseJson(String jsonString) async {
    // For small responses, parse directly (faster)
    if (jsonString.length < 100 * 1024) { // < 100KB
      return jsonDecode(jsonString) as Map<String, dynamic>;
    }

    // For large responses, use isolate
    return await compute(_parseJsonInIsolate, jsonString);
  }

  /// Parse list of JSON objects in isolate
  static Future<List<Map<String, dynamic>>> parseJsonList(String jsonString) async {
    // For small responses, parse directly
    if (jsonString.length < 100 * 1024) { // < 100KB
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    }

    // For large responses, use isolate
    return await compute(_parseJsonListInIsolate, jsonString);
  }
}

// Isolate functions (must be top-level)
Map<String, dynamic> _parseJsonInIsolate(String jsonString) {
  return jsonDecode(jsonString) as Map<String, dynamic>;
}

List<Map<String, dynamic>> _parseJsonListInIsolate(String jsonString) {
  final decoded = jsonDecode(jsonString) as List<dynamic>;
  return decoded.cast<Map<String, dynamic>>();
}

