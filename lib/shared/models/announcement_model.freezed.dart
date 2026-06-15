// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'announcement_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AnnouncementModel _$AnnouncementModelFromJson(Map<String, dynamic> json) {
  return _AnnouncementModel.fromJson(json);
}

/// @nodoc
mixin _$AnnouncementModel {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get message => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _announcementTypeFromJson, toJson: _announcementTypeToJson)
  AnnouncementType get type => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_dismissable')
  bool get isDismissable => throw _privateConstructorUsedError;
  @JsonKey(name: 'target_roles')
  List<String> get targetRoles => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'start_time',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get startTime => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'end_time',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get endTime => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_by')
  String? get createdBy => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'created_at', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'updated_at', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this AnnouncementModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AnnouncementModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AnnouncementModelCopyWith<AnnouncementModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AnnouncementModelCopyWith<$Res> {
  factory $AnnouncementModelCopyWith(
          AnnouncementModel value, $Res Function(AnnouncementModel) then) =
      _$AnnouncementModelCopyWithImpl<$Res, AnnouncementModel>;
  @useResult
  $Res call(
      {String id,
      String title,
      String message,
      @JsonKey(
          fromJson: _announcementTypeFromJson, toJson: _announcementTypeToJson)
      AnnouncementType type,
      @JsonKey(name: 'is_active') bool isActive,
      @JsonKey(name: 'is_dismissable') bool isDismissable,
      @JsonKey(name: 'target_roles') List<String> targetRoles,
      @JsonKey(
          name: 'start_time',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? startTime,
      @JsonKey(
          name: 'end_time',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? endTime,
      @JsonKey(name: 'created_by') String? createdBy,
      @JsonKey(
          name: 'created_at',
          fromJson: _dateTimeFromJson,
          toJson: _dateTimeToJson)
      DateTime createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _dateTimeFromJson,
          toJson: _dateTimeToJson)
      DateTime updatedAt});
}

/// @nodoc
class _$AnnouncementModelCopyWithImpl<$Res, $Val extends AnnouncementModel>
    implements $AnnouncementModelCopyWith<$Res> {
  _$AnnouncementModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AnnouncementModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? message = null,
    Object? type = null,
    Object? isActive = null,
    Object? isDismissable = null,
    Object? targetRoles = null,
    Object? startTime = freezed,
    Object? endTime = freezed,
    Object? createdBy = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as AnnouncementType,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      isDismissable: null == isDismissable
          ? _value.isDismissable
          : isDismissable // ignore: cast_nullable_to_non_nullable
              as bool,
      targetRoles: null == targetRoles
          ? _value.targetRoles
          : targetRoles // ignore: cast_nullable_to_non_nullable
              as List<String>,
      startTime: freezed == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      endTime: freezed == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdBy: freezed == createdBy
          ? _value.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AnnouncementModelImplCopyWith<$Res>
    implements $AnnouncementModelCopyWith<$Res> {
  factory _$$AnnouncementModelImplCopyWith(_$AnnouncementModelImpl value,
          $Res Function(_$AnnouncementModelImpl) then) =
      __$$AnnouncementModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String message,
      @JsonKey(
          fromJson: _announcementTypeFromJson, toJson: _announcementTypeToJson)
      AnnouncementType type,
      @JsonKey(name: 'is_active') bool isActive,
      @JsonKey(name: 'is_dismissable') bool isDismissable,
      @JsonKey(name: 'target_roles') List<String> targetRoles,
      @JsonKey(
          name: 'start_time',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? startTime,
      @JsonKey(
          name: 'end_time',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? endTime,
      @JsonKey(name: 'created_by') String? createdBy,
      @JsonKey(
          name: 'created_at',
          fromJson: _dateTimeFromJson,
          toJson: _dateTimeToJson)
      DateTime createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _dateTimeFromJson,
          toJson: _dateTimeToJson)
      DateTime updatedAt});
}

/// @nodoc
class __$$AnnouncementModelImplCopyWithImpl<$Res>
    extends _$AnnouncementModelCopyWithImpl<$Res, _$AnnouncementModelImpl>
    implements _$$AnnouncementModelImplCopyWith<$Res> {
  __$$AnnouncementModelImplCopyWithImpl(_$AnnouncementModelImpl _value,
      $Res Function(_$AnnouncementModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of AnnouncementModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? message = null,
    Object? type = null,
    Object? isActive = null,
    Object? isDismissable = null,
    Object? targetRoles = null,
    Object? startTime = freezed,
    Object? endTime = freezed,
    Object? createdBy = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$AnnouncementModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as AnnouncementType,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      isDismissable: null == isDismissable
          ? _value.isDismissable
          : isDismissable // ignore: cast_nullable_to_non_nullable
              as bool,
      targetRoles: null == targetRoles
          ? _value._targetRoles
          : targetRoles // ignore: cast_nullable_to_non_nullable
              as List<String>,
      startTime: freezed == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      endTime: freezed == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdBy: freezed == createdBy
          ? _value.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AnnouncementModelImpl extends _AnnouncementModel {
  const _$AnnouncementModelImpl(
      {required this.id,
      required this.title,
      required this.message,
      @JsonKey(
          fromJson: _announcementTypeFromJson, toJson: _announcementTypeToJson)
      required this.type,
      @JsonKey(name: 'is_active') this.isActive = true,
      @JsonKey(name: 'is_dismissable') this.isDismissable = true,
      @JsonKey(name: 'target_roles') final List<String> targetRoles = const [],
      @JsonKey(
          name: 'start_time',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      this.startTime,
      @JsonKey(
          name: 'end_time',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      this.endTime,
      @JsonKey(name: 'created_by') this.createdBy,
      @JsonKey(
          name: 'created_at',
          fromJson: _dateTimeFromJson,
          toJson: _dateTimeToJson)
      required this.createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _dateTimeFromJson,
          toJson: _dateTimeToJson)
      required this.updatedAt})
      : _targetRoles = targetRoles,
        super._();

  factory _$AnnouncementModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$AnnouncementModelImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String message;
  @override
  @JsonKey(fromJson: _announcementTypeFromJson, toJson: _announcementTypeToJson)
  final AnnouncementType type;
  @override
  @JsonKey(name: 'is_active')
  final bool isActive;
  @override
  @JsonKey(name: 'is_dismissable')
  final bool isDismissable;
  final List<String> _targetRoles;
  @override
  @JsonKey(name: 'target_roles')
  List<String> get targetRoles {
    if (_targetRoles is EqualUnmodifiableListView) return _targetRoles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_targetRoles);
  }

  @override
  @JsonKey(
      name: 'start_time',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  final DateTime? startTime;
  @override
  @JsonKey(
      name: 'end_time',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  final DateTime? endTime;
  @override
  @JsonKey(name: 'created_by')
  final String? createdBy;
  @override
  @JsonKey(
      name: 'created_at', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime createdAt;
  @override
  @JsonKey(
      name: 'updated_at', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime updatedAt;

  @override
  String toString() {
    return 'AnnouncementModel(id: $id, title: $title, message: $message, type: $type, isActive: $isActive, isDismissable: $isDismissable, targetRoles: $targetRoles, startTime: $startTime, endTime: $endTime, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AnnouncementModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.isDismissable, isDismissable) ||
                other.isDismissable == isDismissable) &&
            const DeepCollectionEquality()
                .equals(other._targetRoles, _targetRoles) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      message,
      type,
      isActive,
      isDismissable,
      const DeepCollectionEquality().hash(_targetRoles),
      startTime,
      endTime,
      createdBy,
      createdAt,
      updatedAt);

  /// Create a copy of AnnouncementModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AnnouncementModelImplCopyWith<_$AnnouncementModelImpl> get copyWith =>
      __$$AnnouncementModelImplCopyWithImpl<_$AnnouncementModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AnnouncementModelImplToJson(
      this,
    );
  }
}

abstract class _AnnouncementModel extends AnnouncementModel {
  const factory _AnnouncementModel(
      {required final String id,
      required final String title,
      required final String message,
      @JsonKey(
          fromJson: _announcementTypeFromJson, toJson: _announcementTypeToJson)
      required final AnnouncementType type,
      @JsonKey(name: 'is_active') final bool isActive,
      @JsonKey(name: 'is_dismissable') final bool isDismissable,
      @JsonKey(name: 'target_roles') final List<String> targetRoles,
      @JsonKey(
          name: 'start_time',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      final DateTime? startTime,
      @JsonKey(
          name: 'end_time',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      final DateTime? endTime,
      @JsonKey(name: 'created_by') final String? createdBy,
      @JsonKey(
          name: 'created_at',
          fromJson: _dateTimeFromJson,
          toJson: _dateTimeToJson)
      required final DateTime createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _dateTimeFromJson,
          toJson: _dateTimeToJson)
      required final DateTime updatedAt}) = _$AnnouncementModelImpl;
  const _AnnouncementModel._() : super._();

  factory _AnnouncementModel.fromJson(Map<String, dynamic> json) =
      _$AnnouncementModelImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get message;
  @override
  @JsonKey(fromJson: _announcementTypeFromJson, toJson: _announcementTypeToJson)
  AnnouncementType get type;
  @override
  @JsonKey(name: 'is_active')
  bool get isActive;
  @override
  @JsonKey(name: 'is_dismissable')
  bool get isDismissable;
  @override
  @JsonKey(name: 'target_roles')
  List<String> get targetRoles;
  @override
  @JsonKey(
      name: 'start_time',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get startTime;
  @override
  @JsonKey(
      name: 'end_time',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get endTime;
  @override
  @JsonKey(name: 'created_by')
  String? get createdBy;
  @override
  @JsonKey(
      name: 'created_at', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  DateTime get createdAt;
  @override
  @JsonKey(
      name: 'updated_at', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  DateTime get updatedAt;

  /// Create a copy of AnnouncementModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AnnouncementModelImplCopyWith<_$AnnouncementModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
