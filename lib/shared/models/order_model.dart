import 'package:freezed_annotation/freezed_annotation.dart';
import 'order_status.dart';

part 'order_model.freezed.dart';
part 'order_model.g.dart';

DateTime _dateTimeFromJson(dynamic v) => DateTime.parse(v as String);
DateTime? _nullableDateTimeFromJson(dynamic v) =>
    v == null ? null : DateTime.parse(v as String);
String _dateTimeToJson(DateTime dt) => dt.toIso8601String();
String? _nullableDateTimeToJson(DateTime? dt) => dt?.toIso8601String();
double _doubleFromJson(dynamic v) =>
    v == null ? 0.0 : double.parse(v.toString());

@freezed
class OrderModel with _$OrderModel {
  const OrderModel._();

  const factory OrderModel({
    required String id,
    @JsonKey(name: 'merchant_id') required String merchantId,
    @JsonKey(name: 'merchant_name') String? merchantName,
    @JsonKey(name: 'merchant_phone') String? merchantPhone,
    @JsonKey(name: 'driver_id') String? driverId,
    @JsonKey(name: 'driver_name') String? driverName,
    @JsonKey(name: 'driver_phone') String? driverPhone,
    @JsonKey(name: 'customer_name') required String customerName,
    @JsonKey(name: 'customer_phone') String? customerPhone,
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
    @Default('pending') String status,
    @JsonKey(name: 'total_amount', fromJson: _doubleFromJson)
    @Default(0.0)
    double totalAmount,
    @JsonKey(name: 'delivery_fee', fromJson: _doubleFromJson)
    @Default(0.0)
    double deliveryFee,
    String? notes,
    @JsonKey(name: 'vehicle_type') @Default('motorbike') String vehicleType,
    @JsonKey(name: 'bulk_order_id') String? bulkOrderId,
    @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
    required DateTime createdAt,
    @JsonKey(name: 'updated_at', fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
    DateTime? updatedAt,
    @JsonKey(name: 'driver_assigned_at', fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
    DateTime? driverAssignedAt,
    @JsonKey(name: 'accepted_at', fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
    DateTime? acceptedAt,
    @JsonKey(name: 'rejected_at', fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
    DateTime? rejectedAt,
    @JsonKey(name: 'timeout_remaining_seconds') int? timeoutRemainingSeconds,
    @JsonKey(name: 'ready_at', fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
    DateTime? readyAt,
    @JsonKey(name: 'ready_countdown') int? readyCountdown,
    @JsonKey(name: 'customer_location_provided') bool? customerLocationProvided,
    @JsonKey(name: 'user_friendly_code') String? userFriendlyCode,
    @JsonKey(name: 'delivery_time_limit_seconds') int? deliveryTimeLimitSeconds,
    @JsonKey(name: 'delivery_timer_started_at', fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
    DateTime? deliveryTimerStartedAt,
    @JsonKey(name: 'delivery_timer_stopped_at', fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
    DateTime? deliveryTimerStoppedAt,
    @JsonKey(name: 'delivery_timer_expires_at', fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
    DateTime? deliveryTimerExpiresAt,
    @Default([]) List<OrderItemModel> items,
  }) = _OrderModel;

  factory OrderModel.fromJson(Map<String, dynamic> json) =>
      _$OrderModelFromJson(json);

  OrderStatus get statusEnum => OrderStatus.fromDb(status);

  bool get isPending => status == 'pending';
  bool get isAssigned => status == 'assigned';
  bool get isAccepted => status == 'accepted';
  bool get isOnTheWay => status == 'on_the_way';
  bool get isDelivered => status == 'delivered';
  bool get isCancelled => status == 'cancelled';
  bool get isUnassigned => status == 'unassigned';
  bool get isRejected => status == 'rejected';

  bool get isActive => !isDelivered && !isCancelled && !isRejected;
  bool get isCompleted => isDelivered;
  bool get isFailed => isCancelled || isRejected;
  bool get isBulkOrder => bulkOrderId != null;

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'في الانتظار';
      case 'assigned':
        return 'تم التخصيص';
      case 'accepted':
        return 'تم القبول';
      case 'on_the_way':
        return 'في الطريق';
      case 'delivered':
        return 'تم التسليم';
      case 'cancelled':
        return 'ملغي';
      case 'unassigned':
        return 'غير مخصص';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'غير معروف';
    }
  }

  double get grandTotal => totalAmount + deliveryFee;

  bool get isReady {
    if (readyAt == null) return true;
    return DateTime.now().isAfter(readyAt!);
  }

  Duration get timeUntilReady {
    if (readyAt == null) return Duration.zero;
    final now = DateTime.now();
    final difference = readyAt!.difference(now);
    return difference.isNegative ? Duration.zero : difference;
  }

  int get secondsUntilReady => timeUntilReady.inSeconds;
}

@freezed
class OrderItemModel with _$OrderItemModel {
  const OrderItemModel._();

  const factory OrderItemModel({
    required String id,
    @JsonKey(name: 'order_id') required String orderId,
    required String name,
    @Default(1) int quantity,
    @JsonKey(fromJson: _doubleFromJson) @Default(0.0) double price,
  }) = _OrderItemModel;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) =>
      _$OrderItemModelFromJson(json);

  double get totalPrice => quantity * price;
}
