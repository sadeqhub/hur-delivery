// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OrderModelImpl _$$OrderModelImplFromJson(Map<String, dynamic> json) =>
    _$OrderModelImpl(
      id: json['id'] as String,
      merchantId: json['merchant_id'] as String,
      merchantName: json['merchant_name'] as String?,
      merchantPhone: json['merchant_phone'] as String?,
      driverId: json['driver_id'] as String?,
      driverName: json['driver_name'] as String?,
      driverPhone: json['driver_phone'] as String?,
      customerName: json['customer_name'] as String,
      customerPhone: json['customer_phone'] as String?,
      pickupAddress: json['pickup_address'] as String,
      pickupLatitude: _doubleFromJson(json['pickup_latitude']),
      pickupLongitude: _doubleFromJson(json['pickup_longitude']),
      deliveryAddress: json['delivery_address'] as String,
      deliveryLatitude: _doubleFromJson(json['delivery_latitude']),
      deliveryLongitude: _doubleFromJson(json['delivery_longitude']),
      status: json['status'] as String? ?? 'pending',
      totalAmount: json['total_amount'] == null
          ? 0.0
          : _doubleFromJson(json['total_amount']),
      deliveryFee: json['delivery_fee'] == null
          ? 0.0
          : _doubleFromJson(json['delivery_fee']),
      notes: json['notes'] as String?,
      vehicleType: json['vehicle_type'] as String? ?? 'motorbike',
      bulkOrderId: json['bulk_order_id'] as String?,
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _nullableDateTimeFromJson(json['updated_at']),
      driverAssignedAt: _nullableDateTimeFromJson(json['driver_assigned_at']),
      acceptedAt: _nullableDateTimeFromJson(json['accepted_at']),
      rejectedAt: _nullableDateTimeFromJson(json['rejected_at']),
      timeoutRemainingSeconds:
          (json['timeout_remaining_seconds'] as num?)?.toInt(),
      readyAt: _nullableDateTimeFromJson(json['ready_at']),
      readyCountdown: (json['ready_countdown'] as num?)?.toInt(),
      customerLocationProvided: json['customer_location_provided'] as bool?,
      userFriendlyCode: json['user_friendly_code'] as String?,
      deliveryTimeLimitSeconds:
          (json['delivery_time_limit_seconds'] as num?)?.toInt(),
      deliveryTimerStartedAt:
          _nullableDateTimeFromJson(json['delivery_timer_started_at']),
      deliveryTimerStoppedAt:
          _nullableDateTimeFromJson(json['delivery_timer_stopped_at']),
      deliveryTimerExpiresAt:
          _nullableDateTimeFromJson(json['delivery_timer_expires_at']),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$OrderModelImplToJson(_$OrderModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'merchant_id': instance.merchantId,
      'merchant_name': instance.merchantName,
      'merchant_phone': instance.merchantPhone,
      'driver_id': instance.driverId,
      'driver_name': instance.driverName,
      'driver_phone': instance.driverPhone,
      'customer_name': instance.customerName,
      'customer_phone': instance.customerPhone,
      'pickup_address': instance.pickupAddress,
      'pickup_latitude': instance.pickupLatitude,
      'pickup_longitude': instance.pickupLongitude,
      'delivery_address': instance.deliveryAddress,
      'delivery_latitude': instance.deliveryLatitude,
      'delivery_longitude': instance.deliveryLongitude,
      'status': instance.status,
      'total_amount': instance.totalAmount,
      'delivery_fee': instance.deliveryFee,
      'notes': instance.notes,
      'vehicle_type': instance.vehicleType,
      'bulk_order_id': instance.bulkOrderId,
      'created_at': _dateTimeToJson(instance.createdAt),
      'updated_at': _nullableDateTimeToJson(instance.updatedAt),
      'driver_assigned_at': _nullableDateTimeToJson(instance.driverAssignedAt),
      'accepted_at': _nullableDateTimeToJson(instance.acceptedAt),
      'rejected_at': _nullableDateTimeToJson(instance.rejectedAt),
      'timeout_remaining_seconds': instance.timeoutRemainingSeconds,
      'ready_at': _nullableDateTimeToJson(instance.readyAt),
      'ready_countdown': instance.readyCountdown,
      'customer_location_provided': instance.customerLocationProvided,
      'user_friendly_code': instance.userFriendlyCode,
      'delivery_time_limit_seconds': instance.deliveryTimeLimitSeconds,
      'delivery_timer_started_at':
          _nullableDateTimeToJson(instance.deliveryTimerStartedAt),
      'delivery_timer_stopped_at':
          _nullableDateTimeToJson(instance.deliveryTimerStoppedAt),
      'delivery_timer_expires_at':
          _nullableDateTimeToJson(instance.deliveryTimerExpiresAt),
      'items': instance.items,
    };

_$OrderItemModelImpl _$$OrderItemModelImplFromJson(Map<String, dynamic> json) =>
    _$OrderItemModelImpl(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      price: json['price'] == null ? 0.0 : _doubleFromJson(json['price']),
    );

Map<String, dynamic> _$$OrderItemModelImplToJson(
        _$OrderItemModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'order_id': instance.orderId,
      'name': instance.name,
      'quantity': instance.quantity,
      'price': instance.price,
    };
