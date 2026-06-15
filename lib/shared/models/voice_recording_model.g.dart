// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_recording_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VoiceRecordingImpl _$$VoiceRecordingImplFromJson(Map<String, dynamic> json) =>
    _$VoiceRecordingImpl(
      id: json['id'] as String,
      merchantId: json['merchant_id'] as String,
      storagePath: json['storage_path'] as String,
      filename: json['filename'] as String,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt(),
      transcription: json['transcription'] as String?,
      extractedData: json['extracted_data'] as Map<String, dynamic>?,
      notes: json['notes'] as String?,
      isArchived: json['is_archived'] as bool? ?? false,
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _dateTimeFromJson(json['updated_at']),
      lastUsedAt: _nullableDateTimeFromJson(json['last_used_at']),
    );

Map<String, dynamic> _$$VoiceRecordingImplToJson(
        _$VoiceRecordingImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'merchant_id': instance.merchantId,
      'storage_path': instance.storagePath,
      'filename': instance.filename,
      'duration_seconds': instance.durationSeconds,
      'file_size_bytes': instance.fileSizeBytes,
      'transcription': instance.transcription,
      'extracted_data': instance.extractedData,
      'notes': instance.notes,
      'is_archived': instance.isArchived,
      'created_at': _dateTimeToJson(instance.createdAt),
      'updated_at': _dateTimeToJson(instance.updatedAt),
      'last_used_at': _nullableDateTimeToJson(instance.lastUsedAt),
    };
