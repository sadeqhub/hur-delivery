// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'announcement_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AnnouncementModelImpl _$$AnnouncementModelImplFromJson(
        Map<String, dynamic> json) =>
    _$AnnouncementModelImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: _announcementTypeFromJson(json['type'] as String),
      isActive: json['is_active'] as bool? ?? true,
      isDismissable: json['is_dismissable'] as bool? ?? true,
      targetRoles: (json['target_roles'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      startTime: _nullableDateTimeFromJson(json['start_time']),
      endTime: _nullableDateTimeFromJson(json['end_time']),
      createdBy: json['created_by'] as String?,
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _dateTimeFromJson(json['updated_at']),
    );

Map<String, dynamic> _$$AnnouncementModelImplToJson(
        _$AnnouncementModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'message': instance.message,
      'type': _announcementTypeToJson(instance.type),
      'is_active': instance.isActive,
      'is_dismissable': instance.isDismissable,
      'target_roles': instance.targetRoles,
      'start_time': _nullableDateTimeToJson(instance.startTime),
      'end_time': _nullableDateTimeToJson(instance.endTime),
      'created_by': instance.createdBy,
      'created_at': _dateTimeToJson(instance.createdAt),
      'updated_at': _dateTimeToJson(instance.updatedAt),
    };
