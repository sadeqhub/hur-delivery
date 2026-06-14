import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/voice_recording_model.dart';
import '../utils/logger.dart';

class VoiceRecordingState {
  final List<VoiceRecording> recordings;
  final bool isLoading;
  final String? error;

  const VoiceRecordingState({
    this.recordings = const [],
    this.isLoading = false,
    this.error,
  });

  List<VoiceRecording> get activeRecordings =>
      recordings.where((r) => !r.isArchived).toList();

  VoiceRecordingState copyWith({
    List<VoiceRecording>? recordings,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return VoiceRecordingState(
      recordings: recordings ?? this.recordings,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class VoiceRecordingNotifier extends AsyncNotifier<VoiceRecordingState> {
  final _supabase = Supabase.instance.client;

  @override
  Future<VoiceRecordingState> build() async {
    return const VoiceRecordingState();
  }

  /// Load all recordings for the current merchant
  Future<void> loadRecordings() async {
    final current = state.valueOrNull ?? const VoiceRecordingState();
    state = AsyncData(current.copyWith(isLoading: true, clearError: true));

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('voice_recordings')
          .select()
          .eq('merchant_id', userId)
          .eq('is_archived', false)
          .order('created_at', ascending: false);

      final recordings = (response as List)
          .map((json) => VoiceRecording.fromJson(json))
          .toList();

      Logger.d('Loaded ${recordings.length} voice recordings');

      state = AsyncData(VoiceRecordingState(recordings: recordings));
    } catch (e) {
      Logger.d('Error loading recordings: $e');
      state = AsyncData(current.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Upload a voice recording to storage and save metadata
  Future<VoiceRecording?> uploadRecording({
    required File audioFile,
    required String filename,
    int? durationSeconds,
    String? transcription,
    Map<String, dynamic>? extractedData,
    String? notes,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      Logger.d('Uploading voice recording: $filename');

      final fileSizeBytes = await audioFile.length();
      final storagePath = '$userId/${DateTime.now().millisecondsSinceEpoch}_$filename';

      final storageResponse = await _supabase.storage
          .from('voice-orders')
          .upload(
            storagePath,
            audioFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      Logger.d('Uploaded to storage: $storageResponse');

      final metadata = {
        'merchant_id': userId,
        'storage_path': storagePath,
        'filename': filename,
        'duration_seconds': durationSeconds,
        'file_size_bytes': fileSizeBytes,
        'transcription': transcription,
        'extracted_data': extractedData,
        'notes': notes,
      };

      final response = await _supabase
          .from('voice_recordings')
          .insert(metadata)
          .select()
          .single();

      final recording = VoiceRecording.fromJson(response);

      final current = state.valueOrNull ?? const VoiceRecordingState();
      final updated = [recording, ...current.recordings];
      state = AsyncData(current.copyWith(recordings: updated));

      Logger.d('Saved recording metadata: ${recording.id}');
      return recording;
    } catch (e) {
      Logger.d('Error uploading recording: $e');
      final current = state.valueOrNull ?? const VoiceRecordingState();
      state = AsyncData(current.copyWith(error: e.toString()));
      return null;
    }
  }

  /// Update recording metadata
  Future<bool> updateRecording({
    required String recordingId,
    String? transcription,
    Map<String, dynamic>? extractedData,
    String? notes,
    bool? markAsUsed,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (transcription != null) updates['transcription'] = transcription;
      if (extractedData != null) updates['extracted_data'] = extractedData;
      if (notes != null) updates['notes'] = notes;
      if (markAsUsed == true) updates['last_used_at'] = DateTime.now().toIso8601String();

      if (updates.isEmpty) return true;

      await _supabase
          .from('voice_recordings')
          .update(updates)
          .eq('id', recordingId);

      final current = state.valueOrNull ?? const VoiceRecordingState();
      final index = current.recordings.indexWhere((r) => r.id == recordingId);
      if (index != -1) {
        final updated = List<VoiceRecording>.from(current.recordings);
        updated[index] = updated[index].copyWith(
          transcription: transcription ?? updated[index].transcription,
          extractedData: extractedData ?? updated[index].extractedData,
          notes: notes ?? updated[index].notes,
          lastUsedAt: markAsUsed == true ? DateTime.now() : updated[index].lastUsedAt,
        );
        state = AsyncData(current.copyWith(recordings: updated));
      }

      return true;
    } catch (e) {
      Logger.d('Error updating recording: $e');
      final current = state.valueOrNull ?? const VoiceRecordingState();
      state = AsyncData(current.copyWith(error: e.toString()));
      return false;
    }
  }

  /// Archive a recording (soft delete)
  Future<bool> archiveRecording(String recordingId) async {
    try {
      await _supabase
          .from('voice_recordings')
          .update({'is_archived': true})
          .eq('id', recordingId);

      final current = state.valueOrNull ?? const VoiceRecordingState();
      final updated = current.recordings.where((r) => r.id != recordingId).toList();
      state = AsyncData(current.copyWith(recordings: updated));

      Logger.d('Archived recording: $recordingId');
      return true;
    } catch (e) {
      Logger.d('Error archiving recording: $e');
      final current = state.valueOrNull ?? const VoiceRecordingState();
      state = AsyncData(current.copyWith(error: e.toString()));
      return false;
    }
  }

  /// Permanently delete a recording
  Future<bool> deleteRecording(String recordingId) async {
    try {
      final current = state.valueOrNull ?? const VoiceRecordingState();
      final recording = current.recordings.firstWhere((r) => r.id == recordingId);

      await _supabase.storage.from('voice-orders').remove([recording.storagePath]);

      await _supabase.from('voice_recordings').delete().eq('id', recordingId);

      final updated = current.recordings.where((r) => r.id != recordingId).toList();
      state = AsyncData(current.copyWith(recordings: updated));

      Logger.d('Deleted recording: $recordingId');
      return true;
    } catch (e) {
      Logger.d('Error deleting recording: $e');
      final current = state.valueOrNull ?? const VoiceRecordingState();
      state = AsyncData(current.copyWith(error: e.toString()));
      return false;
    }
  }

  /// Get signed URL for playing audio
  Future<String?> getAudioUrl(String storagePath) async {
    try {
      final response = await _supabase.storage
          .from('voice-orders')
          .createSignedUrl(storagePath, 3600); // Valid for 1 hour

      return response;
    } catch (e) {
      Logger.d('Error getting audio URL: $e');
      return null;
    }
  }

  /// Download audio file to local storage
  Future<File?> downloadAudio(VoiceRecording recording) async {
    try {
      final bytes = await _supabase.storage
          .from('voice-orders')
          .download(recording.storagePath);

      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/${recording.filename}');
      await tempFile.writeAsBytes(bytes);

      Logger.d('Downloaded audio: ${tempFile.path}');
      return tempFile;
    } catch (e) {
      Logger.d('Error downloading audio: $e');
      return null;
    }
  }

  void clearError() {
    final current = state.valueOrNull ?? const VoiceRecordingState();
    state = AsyncData(current.copyWith(clearError: true));
  }
}

final voiceRecordingProvider =
    AsyncNotifierProvider<VoiceRecordingNotifier, VoiceRecordingState>(
        VoiceRecordingNotifier.new);
