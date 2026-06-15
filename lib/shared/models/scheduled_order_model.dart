import 'package:freezed_annotation/freezed_annotation.dart';

part 'scheduled_order_model.freezed.dart';
part 'scheduled_order_model.g.dart';

DateTime _dateTimeFromJson(dynamic v) => DateTime.parse(v as String);
DateTime? _nullableDateTimeFromJson(dynamic v) =>
    v == null ? null : DateTime.parse(v as String);
String _dateTimeToJson(DateTime dt) => dt.toIso8601String();
String? _nullableDateTimeToJson(DateTime? dt) => dt?.toIso8601String();
double _doubleFromJson(dynamic v) =>
    v == null ? 0.0 : double.parse(v.toString());

String _dateOnlyToJson(DateTime dt) => dt.toIso8601String().split('T')[0];

Duration _durationFromJson(dynamic v) {
  final parts = (v as String).split(':');
  return Duration(
    hours: int.parse(parts[0]),
    minutes: int.parse(parts[1]),
    seconds: parts.length > 2 ? int.parse(parts[2]) : 0,
  );
}

String _durationToJson(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

@freezed
class ScheduledOrderModel with _$ScheduledOrderModel {
  const ScheduledOrderModel._();

  const factory ScheduledOrderModel({
    required String id,
    @JsonKey(name: 'merchant_id') required String merchantId,
    @JsonKey(name: 'customer_name') required String customerName,
    @JsonKey(name: 'customer_phone') required String customerPhone,
    @JsonKey(name: 'pickup_address') required String pickupAddress,
    @JsonKey(name: 'pickup_latitude', fromJson: _doubleFromJson)
    required double pickupLatitude,
    @JsonKey(name: 'pickup_longitude', fromJson: _doubleFromJson)
    required double pickupLongitude,
    @JsonKey(name: 'delivery_address') required String deliveryAddress,
    @JsonKey(name: 'delivery_latitude', fromJson: _doubleFromJson)
    required double deliveryLatitude,
    @JsonKey(name: 'delivery_longitude', fromJson: _doubleFromJson)
    required double deliveryLongitude,
    @JsonKey(name: 'total_amount', fromJson: _doubleFromJson)
    required double totalAmount,
    @JsonKey(name: 'delivery_fee', fromJson: _doubleFromJson)
    required double deliveryFee,
    String? notes,
    @JsonKey(name: 'vehicle_type') @Default('motorcycle') String vehicleType,
    @JsonKey(
        name: 'scheduled_date',
        fromJson: _dateTimeFromJson,
        toJson: _dateOnlyToJson)
    required DateTime scheduledDate,
    @JsonKey(
        name: 'scheduled_time',
        fromJson: _durationFromJson,
        toJson: _durationToJson)
    required Duration scheduledTime,
    @Default('scheduled') String status,
    @JsonKey(name: 'created_order_id') String? createdOrderId,
    @JsonKey(
        name: 'created_at',
        fromJson: _dateTimeFromJson,
        toJson: _dateTimeToJson)
    required DateTime createdAt,
    @JsonKey(
        name: 'updated_at',
        fromJson: _nullableDateTimeFromJson,
        toJson: _nullableDateTimeToJson)
    DateTime? updatedAt,
  }) = _ScheduledOrderModel;

  factory ScheduledOrderModel.fromJson(Map<String, dynamic> json) =>
      _$ScheduledOrderModelFromJson(json);

  DateTime get scheduledDateTime => scheduledDate.add(scheduledTime);

  Duration get timeUntilPosted {
    final now = DateTime.now();
    final scheduled = scheduledDateTime;
    return scheduled.difference(now);
  }

  bool get isDue => DateTime.now().isAfter(scheduledDateTime);

  int get secondsRemaining =>
      timeUntilPosted.inSeconds.clamp(0, double.infinity).toInt();

  double get grandTotal => totalAmount + deliveryFee;

  String get statusDisplay {
    switch (status) {
      case 'scheduled':
        return 'مجدول';
      case 'posted':
        return 'تم النشر';
      case 'failed':
        return 'فشل';
      case 'cancelled':
        return 'ملغي';
      default:
        return 'غير معروف';
    }
  }
}
