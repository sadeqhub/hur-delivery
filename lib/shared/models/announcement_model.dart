import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'announcement_model.freezed.dart';
part 'announcement_model.g.dart';

DateTime _dateTimeFromJson(dynamic v) => DateTime.parse(v as String);
DateTime? _nullableDateTimeFromJson(dynamic v) =>
    v == null ? null : DateTime.parse(v as String);
String _dateTimeToJson(DateTime dt) => dt.toIso8601String();
String? _nullableDateTimeToJson(DateTime? dt) => dt?.toIso8601String();

AnnouncementType _announcementTypeFromJson(String v) =>
    AnnouncementType.fromString(v);
String _announcementTypeToJson(AnnouncementType t) => t.value;

@freezed
class AnnouncementModel with _$AnnouncementModel {
  const AnnouncementModel._();

  const factory AnnouncementModel({
    required String id,
    required String title,
    required String message,
    @JsonKey(fromJson: _announcementTypeFromJson, toJson: _announcementTypeToJson)
    required AnnouncementType type,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'is_dismissable') @Default(true) bool isDismissable,
    @JsonKey(name: 'target_roles') @Default([]) List<String> targetRoles,
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
    required DateTime createdAt,
    @JsonKey(
        name: 'updated_at',
        fromJson: _dateTimeFromJson,
        toJson: _dateTimeToJson)
    required DateTime updatedAt,
  }) = _AnnouncementModel;

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementModelFromJson(json);

  bool get isCurrentlyActive {
    if (!isActive) return false;
    final now = DateTime.now();
    if (startTime != null && now.isBefore(startTime!)) return false;
    if (endTime != null && now.isAfter(endTime!)) return false;
    return true;
  }
}

enum AnnouncementType {
  maintenance('maintenance'),
  event('event'),
  update('update'),
  info('info'),
  warning('warning'),
  success('success');

  const AnnouncementType(this.value);
  final String value;

  static AnnouncementType fromString(String value) {
    return AnnouncementType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AnnouncementType.info,
    );
  }

  Color getColor() {
    switch (this) {
      case AnnouncementType.maintenance:
        return Colors.orange;
      case AnnouncementType.event:
        return Colors.purple;
      case AnnouncementType.update:
        return Colors.blue;
      case AnnouncementType.info:
        return Colors.cyan;
      case AnnouncementType.warning:
        return Colors.red;
      case AnnouncementType.success:
        return Colors.green;
    }
  }

  IconData getIcon() {
    switch (this) {
      case AnnouncementType.maintenance:
        return Icons.build;
      case AnnouncementType.event:
        return Icons.celebration;
      case AnnouncementType.update:
        return Icons.system_update;
      case AnnouncementType.info:
        return Icons.info;
      case AnnouncementType.warning:
        return Icons.warning;
      case AnnouncementType.success:
        return Icons.check_circle;
    }
  }

  String getArabicLabel() {
    switch (this) {
      case AnnouncementType.maintenance:
        return 'صيانة';
      case AnnouncementType.event:
        return 'حدث';
      case AnnouncementType.update:
        return 'تحديث';
      case AnnouncementType.info:
        return 'معلومات';
      case AnnouncementType.warning:
        return 'تحذير';
      case AnnouncementType.success:
        return 'نجاح';
    }
  }
}
