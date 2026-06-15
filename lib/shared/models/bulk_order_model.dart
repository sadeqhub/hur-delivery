import 'package:freezed_annotation/freezed_annotation.dart';
import 'bulk_order_item.dart';

part 'bulk_order_model.freezed.dart';
part 'bulk_order_model.g.dart';

DateTime _dateTimeFromJson(dynamic v) => DateTime.parse(v as String);
DateTime? _nullableDateTimeFromJson(dynamic v) =>
    v == null ? null : DateTime.parse(v as String);
String _dateTimeToJson(DateTime dt) => dt.toIso8601String();
String? _nullableDateTimeToJson(DateTime? dt) => dt?.toIso8601String();
double _doubleFromJson(dynamic v) =>
    v == null ? 0.0 : double.parse(v.toString());

@freezed
class BulkOrderModel with _$BulkOrderModel {
  const BulkOrderModel._();

  const factory BulkOrderModel({
    required String id,
    @JsonKey(name: 'merchant_id') required String merchantId,
    @JsonKey(name: 'driver_id') String? driverId,
    @JsonKey(name: 'pickup_address') required String pickupAddress,
    @JsonKey(name: 'pickup_latitude', fromJson: _doubleFromJson)
    required double pickupLatitude,
    @JsonKey(name: 'pickup_longitude', fromJson: _doubleFromJson)
    required double pickupLongitude,
    @JsonKey(name: 'neighborhoods') @Default([]) List<String> neighborhoods,
    @JsonKey(name: 'neighborhood_items') List<BulkOrderItem>? neighborhoodItems,
    @JsonKey(name: 'per_delivery_fee', fromJson: _doubleFromJson)
    required double perDeliveryFee,
    @JsonKey(name: 'bulk_order_fee', fromJson: _doubleFromJson)
    @Default(1000.0)
    double bulkOrderFee,
    @JsonKey(name: 'vehicle_type') String? vehicleType,
    String? notes,
    @Default('pending') String status,
    @JsonKey(name: 'order_date', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
    required DateTime orderDate,
    @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
    required DateTime createdAt,
    @JsonKey(name: 'assigned_at', fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
    DateTime? assignedAt,
    @JsonKey(name: 'accepted_at', fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
    DateTime? acceptedAt,
    /// Populated from a nested merchant join: pass merchant_name top-level or
    /// call .copyWith() after creation when working with Supabase joined selects.
    @JsonKey(name: 'merchant_name') String? merchantName,
    @JsonKey(name: 'merchant_phone') String? merchantPhone,
  }) = _BulkOrderModel;

  factory BulkOrderModel.fromJson(Map<String, dynamic> json) =>
      _$BulkOrderModelFromJson(json);

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isPickedUp => status == 'picked_up';
  bool get isOnTheWay => status == 'on_the_way';
  bool get isDelivered => status == 'delivered';
  bool get isCancelled => status == 'cancelled';
  bool get isRejected => status == 'rejected';
}
