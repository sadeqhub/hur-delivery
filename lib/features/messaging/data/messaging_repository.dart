import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/logging/logger.dart';
import '../../../core/network/api_client.dart';

/// Data layer for in-app messaging (conversations + messages).
///
/// Replaces direct `Supabase.instance.client` calls from [MessagingService].
/// All chat and notification messaging operations go through here.
///
/// Pattern: MessagingService → MessagingRepository → ApiClient → Supabase
class MessagingRepository {
  MessagingRepository({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;
  static const String _tag = 'MessagingRepository';

  // ─── Conversations ─────────────────────────────────────────────────────────

  /// Returns all conversations the current user participates in.
  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    Logger.d(_tag, 'getConversations: ${Logger.redactId(userId)}');
    try {
      // Get conversation IDs for user
      final participantRows = await _client
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 15));

      final ids = (participantRows as List)
          .map((r) => r['conversation_id'] as String)
          .toList();

      if (ids.isEmpty) return [];

      final rows = await _client
          .from('conversations')
          .select('*, conversation_participants(*), messages(order_by: created_at.desc, limit: 1)')
          .inFilter('id', ids)
          .order('updated_at', ascending: false)
          .timeout(const Duration(seconds: 15));

      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e, st) {
      Logger.e(_tag, 'getConversations failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  /// Returns messages for a conversation, newest first.
  Future<List<Map<String, dynamic>>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    Logger.d(_tag, 'getMessages: ${Logger.redactId(conversationId)}');
    try {
      final rows = await _client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1)
          .timeout(const Duration(seconds: 15));
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e, st) {
      Logger.e(_tag, 'getMessages failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  /// Finds an existing conversation for an order, or creates one.
  ///
  /// [isDemoMode] — if true, returns a fake conversation ID ('demo_conv') without
  /// touching Supabase.
  Future<String> getOrCreateOrderConversation(
    String orderId, {
    bool isDemoMode = false,
  }) async {
    if (isDemoMode) {
      Logger.d(_tag, 'getOrCreateOrderConversation blocked in demo mode');
      return 'demo_conversation_${orderId.hashCode}';
    }
    Logger.d(_tag, 'getOrCreateOrderConversation: ${Logger.redactId(orderId)}');
    try {
      final result = await _client.rpc<dynamic>(
        'get_or_create_order_conversation',
        params: {'p_order_id': orderId},
        timeout: const Duration(seconds: 15),
      );
      return result as String;
    } catch (e, st) {
      Logger.e(_tag, 'getOrCreateOrderConversation failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  // ─── Sending messages ─────────────────────────────────────────────────────

  /// Sends a text message to a conversation.
  ///
  /// [isDemoMode] — if true, returns a canned fixture message without hitting Supabase.
  Future<Map<String, dynamic>> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String content,
    bool isDemoMode = false,
  }) async {
    if (isDemoMode) {
      Logger.d(_tag, 'sendTextMessage blocked in demo mode — returning fixture');
      return {
        'id': 'demo_msg_${DateTime.now().millisecondsSinceEpoch}',
        'conversation_id': conversationId,
        'sender_id': senderId,
        'content': content,
        'type': 'text',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
    }
    Logger.d(_tag, 'sendTextMessage to conv ${Logger.redactId(conversationId)}');
    try {
      final rows = await _client
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': senderId,
            'content': content,
            'type': 'text',
            'created_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single()
          .timeout(const Duration(seconds: 15));
      return rows;
    } catch (e, st) {
      Logger.e(_tag, 'sendTextMessage failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  /// Sends a voice message (audio file) to a conversation.
  Future<Map<String, dynamic>> sendVoiceMessage({
    required String conversationId,
    required String senderId,
    required File audioFile,
    required int durationSeconds,
    bool isDemoMode = false,
  }) async {
    if (isDemoMode) {
      Logger.d(_tag, 'sendVoiceMessage blocked in demo mode');
      throw const AppFailure.unauthorized();
    }
    Logger.d(_tag, 'sendVoiceMessage: conv ${Logger.redactId(conversationId)}');
    try {
      return await _client.uploadMultipart(
        'send-voice-message',
        fields: {
          'conversation_id': conversationId,
          'sender_id': senderId,
          'duration_seconds': durationSeconds.toString(),
        },
        files: {'audio': audioFile},
      );
    } on AppFailure {
      rethrow;
    } catch (e, st) {
      Logger.e(_tag, 'sendVoiceMessage failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  // ─── Notifications ─────────────────────────────────────────────────────────

  /// Marks all messages in a conversation as read for a user.
  Future<void> markConversationRead(
    String conversationId,
    String userId,
  ) async {
    try {
      await _client
          .from('conversation_participants')
          .update({'last_read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('conversation_id', conversationId)
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      Logger.w(_tag, 'markConversationRead failed (non-critical): $e');
    }
  }

  // ─── Cleanup ──────────────────────────────────────────────────────────────

  /// Cleans up empty conversations (no messages).
  Future<void> purgeEmptyConversations(String userId) async {
    try {
      await _client.rpc<dynamic>(
        'purge_empty_conversations',
        params: {'p_user_id': userId},
        timeout: const Duration(seconds: 15),
      );
    } catch (e) {
      Logger.w(_tag, 'purgeEmptyConversations failed (non-critical): $e');
    }
  }

  // ─── Storage (attachments) ────────────────────────────────────────────────

  /// Uploads [bytes] to the 'files' bucket at [objectPath] with [contentType].
  /// Returns the public URL on success.
  Future<String> uploadAttachment({
    required String objectPath,
    required Uint8List bytes,
    required String contentType,
  }) async {
    Logger.d(_tag, 'uploadAttachment: $objectPath');
    try {
      await Supabase.instance.client.storage.from('files').uploadBinary(
        objectPath,
        bytes,
        fileOptions: FileOptions(upsert: true, contentType: contentType),
      );
      return Supabase.instance.client.storage
          .from('files')
          .getPublicUrl(objectPath);
    } catch (e, st) {
      Logger.e(_tag, 'uploadAttachment failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  /// Returns the current authenticated user's ID from the in-memory auth state.
  String? get currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;

  /// Fetches the most recent message in [conversationId] from [senderId]
  /// sent at or after [startedAt] (with a 2 s grace window).
  /// Used to resolve optimistic messages after send.
  Future<Map<String, dynamic>?> resolveRecentMessage({
    required String conversationId,
    required String senderId,
    required DateTime startedAt,
  }) async {
    Logger.d(_tag, 'resolveRecentMessage: conv ${Logger.redactId(conversationId)}');
    try {
      final row = await _client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .eq('sender_id', senderId)
          .gte(
            'created_at',
            startedAt.subtract(const Duration(seconds: 2)).toIso8601String(),
          )
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));
      return row;
    } catch (e) {
      Logger.w(_tag, 'resolveRecentMessage failed (non-critical)', error: e);
      return null;
    }
  }

  // ─── Realtime ─────────────────────────────────────────────────────────────

  /// Returns a live stream of messages in a conversation.
  Stream<List<Map<String, dynamic>>> messageStream(String conversationId) =>
      _client
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('conversation_id', conversationId)
          .order('created_at')
          .limit(100);

  /// Returns a live stream of conversations for a user.
  Stream<List<Map<String, dynamic>>> conversationStream(String userId) =>
      _client
          .from('conversation_participants')
          .stream(primaryKey: ['conversation_id', 'user_id'])
          .eq('user_id', userId);
}
