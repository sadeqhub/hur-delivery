import 'package:freezed_annotation/freezed_annotation.dart';

part 'voice_recording_model.freezed.dart';
part 'voice_recording_model.g.dart';

DateTime _dateTimeFromJson(dynamic v) => DateTime.parse(v as String);
DateTime? _nullableDateTimeFromJson(dynamic v) =>
    v == null ? null : DateTime.parse(v as String);
String _dateTimeToJson(DateTime dt) => dt.toIso8601String();
String? _nullableDateTimeToJson(DateTime? dt) => dt?.toIso8601String();

@freezed
class VoiceRecording with _$VoiceRecording {
  const VoiceRecording._();

  const factory VoiceRecording({
    required String id,
    required String merchantId,
    required String storagePath,
    required String filename,
    int? durationSeconds,
    int? fileSizeBytes,
    String? transcription,
    Map<String, dynamic>? extractedData,
    String? notes,
    @Default(false) bool isArchived,
    @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
    required DateTime createdAt,
    @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
    required DateTime updatedAt,
    @JsonKey(fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
    DateTime? lastUsedAt,
  }) = _VoiceRecording;

  factory VoiceRecording.fromJson(Map<String, dynamic> json) =>
      _$VoiceRecordingFromJson(json);

  String get formattedDuration {
    if (durationSeconds == null) return '--:--';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedFileSize {
    if (fileSizeBytes == null) return '--';
    if (fileSizeBytes! < 1024) return '${fileSizeBytes}B';
    if (fileSizeBytes! < 1024 * 1024) {
      return '${(fileSizeBytes! / 1024).toStringAsFixed(1)}KB';
    }
    return '${(fileSizeBytes! / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} دقيقة';
      }
      return '${difference.inHours} ساعة';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} أيام';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  bool get hasTranscription =>
      transcription != null && transcription!.isNotEmpty;
  bool get hasExtractedData =>
      extractedData != null && extractedData!.isNotEmpty;
}
