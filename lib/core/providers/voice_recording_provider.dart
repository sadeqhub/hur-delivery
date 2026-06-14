import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/voice_recording_model.dart';
import '../utils/logger.dart';

class VoiceRecordingProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  
  List<VoiceRecording> _recordings = [];
  bool _isLoading = false;
  String? _error;

  List<VoiceRecording> get recordings => _recordings;
  List<VoiceRecording> get activeRecordings => 
      _recordings.where((r) => !r.isArchived).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all recordings for the current merchant
  Future<void> loadRecordings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

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

      _recordings = (response as List)
          .map((json) => VoiceRecording.fromJson(json))
          .toList();

      Logger.d('✅ Loaded ${_recordings.length} voice recordings');
    } catch (e) {
      _error = e.toString();
      Logger.d('❌ Error loading recordings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
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

      Logger.d('📤 Uploading voice recording: $filename');

      // Get file size
      final fileSizeBytes = await audioFile.length();

      // Upload to storage (organized by user ID)
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

      Logger.d('✅ Uploaded to storage: $storageResponse');

      // Save metadata to database
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
      
      // Add to local list
      _recordings.insert(0, recording);
      notifyListeners();

      Logger.d('✅ Saved recording metadata: ${recording.id}');
      return recording;
    } catch (e) {
      Logger.d('❌ Error uploading recording: $e');
      _error = e.toString();
      notifyListeners();
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

      // Update local copy
      final index = _recordings.indexWhere((r) => r.id == recordingId);
      if (index != -1) {
        _recordings[index] = _recordings[index].copyWith(
          transcription: transcription ?? _recordings[index].transcription,
          extractedData: extractedData ?? _recordings[index].extractedData,
          notes: notes ?? _recordings[index].notes,
          lastUsedAt: markAsUsed == true ? DateTime.now() : _recordings[index].lastUsedAt,
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      Logger.d('❌ Error updating recording: $e');
      _error = e.toString();
      notifyListeners();
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

      _recordings.removeWhere((r) => r.id == recordingId);
      notifyListeners();

      Logger.d('✅ Archived recording: $recordingId');
      return true;
    } catch (e) {
      Logger.d('❌ Error archiving recording: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Permanently delete a recording
  Future<bool> deleteRecording(String recordingId) async {
    try {
      final recording = _recordings.firstWhere((r) => r.id == recordingId);

      // Delete from storage
      await _supabase.storage
          .from('voice-orders')
          .remove([recording.storagePath]);

      // Delete from database
      await _supabase
          .from('voice_recordings')
          .delete()
          .eq('id', recordingId);

      _recordings.removeWhere((r) => r.id == recordingId);
      notifyListeners();

      Logger.d('✅ Deleted recording: $recordingId');
      return true;
    } catch (e) {
      Logger.d('❌ Error deleting recording: $e');
      _error = e.toString();
      notifyListeners();
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
      Logger.d('❌ Error getting audio URL: $e');
      return null;
    }
  }

  /// Download audio file to local storage
  Future<File?> downloadAudio(VoiceRecording recording) async {
    try {
      final bytes = await _supabase.storage
          .from('voice-orders')
          .download(recording.storagePath);

      // Save to temporary directory
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/${recording.filename}');
      await tempFile.writeAsBytes(bytes);

      Logger.d('✅ Downloaded audio: ${tempFile.path}');
      return tempFile;
    } catch (e) {
      Logger.d('❌ Error downloading audio: $e');
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

