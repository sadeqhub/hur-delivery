// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'voice_recording_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

VoiceRecording _$VoiceRecordingFromJson(Map<String, dynamic> json) {
  return _VoiceRecording.fromJson(json);
}

/// @nodoc
mixin _$VoiceRecording {
  String get id => throw _privateConstructorUsedError;
  String get merchantId => throw _privateConstructorUsedError;
  String get storagePath => throw _privateConstructorUsedError;
  String get filename => throw _privateConstructorUsedError;
  int? get durationSeconds => throw _privateConstructorUsedError;
  int? get fileSizeBytes => throw _privateConstructorUsedError;
  String? get transcription => throw _privateConstructorUsedError;
  Map<String, dynamic>? get extractedData => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  bool get isArchived => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  DateTime get updatedAt => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
  DateTime? get lastUsedAt => throw _privateConstructorUsedError;

  /// Serializes this VoiceRecording to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VoiceRecording
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VoiceRecordingCopyWith<VoiceRecording> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VoiceRecordingCopyWith<$Res> {
  factory $VoiceRecordingCopyWith(
          VoiceRecording value, $Res Function(VoiceRecording) then) =
      _$VoiceRecordingCopyWithImpl<$Res, VoiceRecording>;
  @useResult
  $Res call(
      {String id,
      String merchantId,
      String storagePath,
      String filename,
      int? durationSeconds,
      int? fileSizeBytes,
      String? transcription,
      Map<String, dynamic>? extractedData,
      String? notes,
      bool isArchived,
      @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
      DateTime createdAt,
      @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
      DateTime updatedAt,
      @JsonKey(
          fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
      DateTime? lastUsedAt});
}

/// @nodoc
class _$VoiceRecordingCopyWithImpl<$Res, $Val extends VoiceRecording>
    implements $VoiceRecordingCopyWith<$Res> {
  _$VoiceRecordingCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VoiceRecording
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? merchantId = null,
    Object? storagePath = null,
    Object? filename = null,
    Object? durationSeconds = freezed,
    Object? fileSizeBytes = freezed,
    Object? transcription = freezed,
    Object? extractedData = freezed,
    Object? notes = freezed,
    Object? isArchived = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? lastUsedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      merchantId: null == merchantId
          ? _value.merchantId
          : merchantId // ignore: cast_nullable_to_non_nullable
              as String,
      storagePath: null == storagePath
          ? _value.storagePath
          : storagePath // ignore: cast_nullable_to_non_nullable
              as String,
      filename: null == filename
          ? _value.filename
          : filename // ignore: cast_nullable_to_non_nullable
              as String,
      durationSeconds: freezed == durationSeconds
          ? _value.durationSeconds
          : durationSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
      fileSizeBytes: freezed == fileSizeBytes
          ? _value.fileSizeBytes
          : fileSizeBytes // ignore: cast_nullable_to_non_nullable
              as int?,
      transcription: freezed == transcription
          ? _value.transcription
          : transcription // ignore: cast_nullable_to_non_nullable
              as String?,
      extractedData: freezed == extractedData
          ? _value.extractedData
          : extractedData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      isArchived: null == isArchived
          ? _value.isArchived
          : isArchived // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastUsedAt: freezed == lastUsedAt
          ? _value.lastUsedAt
          : lastUsedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VoiceRecordingImplCopyWith<$Res>
    implements $VoiceRecordingCopyWith<$Res> {
  factory _$$VoiceRecordingImplCopyWith(_$VoiceRecordingImpl value,
          $Res Function(_$VoiceRecordingImpl) then) =
      __$$VoiceRecordingImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String merchantId,
      String storagePath,
      String filename,
      int? durationSeconds,
      int? fileSizeBytes,
      String? transcription,
      Map<String, dynamic>? extractedData,
      String? notes,
      bool isArchived,
      @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
      DateTime createdAt,
      @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
      DateTime updatedAt,
      @JsonKey(
          fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
      DateTime? lastUsedAt});
}

/// @nodoc
class __$$VoiceRecordingImplCopyWithImpl<$Res>
    extends _$VoiceRecordingCopyWithImpl<$Res, _$VoiceRecordingImpl>
    implements _$$VoiceRecordingImplCopyWith<$Res> {
  __$$VoiceRecordingImplCopyWithImpl(
      _$VoiceRecordingImpl _value, $Res Function(_$VoiceRecordingImpl) _then)
      : super(_value, _then);

  /// Create a copy of VoiceRecording
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? merchantId = null,
    Object? storagePath = null,
    Object? filename = null,
    Object? durationSeconds = freezed,
    Object? fileSizeBytes = freezed,
    Object? transcription = freezed,
    Object? extractedData = freezed,
    Object? notes = freezed,
    Object? isArchived = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? lastUsedAt = freezed,
  }) {
    return _then(_$VoiceRecordingImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      merchantId: null == merchantId
          ? _value.merchantId
          : merchantId // ignore: cast_nullable_to_non_nullable
              as String,
      storagePath: null == storagePath
          ? _value.storagePath
          : storagePath // ignore: cast_nullable_to_non_nullable
              as String,
      filename: null == filename
          ? _value.filename
          : filename // ignore: cast_nullable_to_non_nullable
              as String,
      durationSeconds: freezed == durationSeconds
          ? _value.durationSeconds
          : durationSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
      fileSizeBytes: freezed == fileSizeBytes
          ? _value.fileSizeBytes
          : fileSizeBytes // ignore: cast_nullable_to_non_nullable
              as int?,
      transcription: freezed == transcription
          ? _value.transcription
          : transcription // ignore: cast_nullable_to_non_nullable
              as String?,
      extractedData: freezed == extractedData
          ? _value._extractedData
          : extractedData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      isArchived: null == isArchived
          ? _value.isArchived
          : isArchived // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastUsedAt: freezed == lastUsedAt
          ? _value.lastUsedAt
          : lastUsedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$VoiceRecordingImpl extends _VoiceRecording {
  const _$VoiceRecordingImpl(
      {required this.id,
      required this.merchantId,
      required this.storagePath,
      required this.filename,
      this.durationSeconds,
      this.fileSizeBytes,
      this.transcription,
      final Map<String, dynamic>? extractedData,
      this.notes,
      this.isArchived = false,
      @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
      required this.createdAt,
      @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
      required this.updatedAt,
      @JsonKey(
          fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
      this.lastUsedAt})
      : _extractedData = extractedData,
        super._();

  factory _$VoiceRecordingImpl.fromJson(Map<String, dynamic> json) =>
      _$$VoiceRecordingImplFromJson(json);

  @override
  final String id;
  @override
  final String merchantId;
  @override
  final String storagePath;
  @override
  final String filename;
  @override
  final int? durationSeconds;
  @override
  final int? fileSizeBytes;
  @override
  final String? transcription;
  final Map<String, dynamic>? _extractedData;
  @override
  Map<String, dynamic>? get extractedData {
    final value = _extractedData;
    if (value == null) return null;
    if (_extractedData is EqualUnmodifiableMapView) return _extractedData;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final String? notes;
  @override
  @JsonKey()
  final bool isArchived;
  @override
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime createdAt;
  @override
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime updatedAt;
  @override
  @JsonKey(fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
  final DateTime? lastUsedAt;

  @override
  String toString() {
    return 'VoiceRecording(id: $id, merchantId: $merchantId, storagePath: $storagePath, filename: $filename, durationSeconds: $durationSeconds, fileSizeBytes: $fileSizeBytes, transcription: $transcription, extractedData: $extractedData, notes: $notes, isArchived: $isArchived, createdAt: $createdAt, updatedAt: $updatedAt, lastUsedAt: $lastUsedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VoiceRecordingImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.merchantId, merchantId) ||
                other.merchantId == merchantId) &&
            (identical(other.storagePath, storagePath) ||
                other.storagePath == storagePath) &&
            (identical(other.filename, filename) ||
                other.filename == filename) &&
            (identical(other.durationSeconds, durationSeconds) ||
                other.durationSeconds == durationSeconds) &&
            (identical(other.fileSizeBytes, fileSizeBytes) ||
                other.fileSizeBytes == fileSizeBytes) &&
            (identical(other.transcription, transcription) ||
                other.transcription == transcription) &&
            const DeepCollectionEquality()
                .equals(other._extractedData, _extractedData) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.isArchived, isArchived) ||
                other.isArchived == isArchived) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.lastUsedAt, lastUsedAt) ||
                other.lastUsedAt == lastUsedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      merchantId,
      storagePath,
      filename,
      durationSeconds,
      fileSizeBytes,
      transcription,
      const DeepCollectionEquality().hash(_extractedData),
      notes,
      isArchived,
      createdAt,
      updatedAt,
      lastUsedAt);

  /// Create a copy of VoiceRecording
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VoiceRecordingImplCopyWith<_$VoiceRecordingImpl> get copyWith =>
      __$$VoiceRecordingImplCopyWithImpl<_$VoiceRecordingImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VoiceRecordingImplToJson(
      this,
    );
  }
}

abstract class _VoiceRecording extends VoiceRecording {
  const factory _VoiceRecording(
      {required final String id,
      required final String merchantId,
      required final String storagePath,
      required final String filename,
      final int? durationSeconds,
      final int? fileSizeBytes,
      final String? transcription,
      final Map<String, dynamic>? extractedData,
      final String? notes,
      final bool isArchived,
      @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
      required final DateTime createdAt,
      @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
      required final DateTime updatedAt,
      @JsonKey(
          fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
      final DateTime? lastUsedAt}) = _$VoiceRecordingImpl;
  const _VoiceRecording._() : super._();

  factory _VoiceRecording.fromJson(Map<String, dynamic> json) =
      _$VoiceRecordingImpl.fromJson;

  @override
  String get id;
  @override
  String get merchantId;
  @override
  String get storagePath;
  @override
  String get filename;
  @override
  int? get durationSeconds;
  @override
  int? get fileSizeBytes;
  @override
  String? get transcription;
  @override
  Map<String, dynamic>? get extractedData;
  @override
  String? get notes;
  @override
  bool get isArchived;
  @override
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  DateTime get createdAt;
  @override
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  DateTime get updatedAt;
  @override
  @JsonKey(fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
  DateTime? get lastUsedAt;

  /// Create a copy of VoiceRecording
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VoiceRecordingImplCopyWith<_$VoiceRecordingImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
