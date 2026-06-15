// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduled_order_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ScheduledOrderModelImpl _$$ScheduledOrderModelImplFromJson(
        Map<String, dynamic> json) =>
    _$ScheduledOrderModelImpl(
      id: json['id'] as String,
      merchantId: json['merchant_id'] as String,
      customerName: json['customer_name'] as String,
      customerPhone: json['customer_phone'] as String,
      pickupAddress: json['pickup_address'] as String,
      pickupLatitude: _doubleFromJson(json['pickup_latitude']),
      pickupLongitude: _doubleFromJson(json['pickup_longitude']),
      deliveryAddress: json['delivery_address'] as String,
      deliveryLatitude: _doubleFromJson(json['delivery_latitude']),
      deliveryLongitude: _doubleFromJson(json['delivery_longitude']),
      totalAmount: _doubleFromJson(json['total_amount']),
      deliveryFee: _doubleFromJson(json['delivery_fee']),
      notes: json['notes'] as String?,
      vehicleType: json['vehicle_type'] as String? ?? 'motorcycle',
      scheduledDate: _dateTimeFromJson(json['scheduled_date']),
      scheduledTime: _durationFromJson(json['scheduled_time']),
      status: json['status'] as String? ?? 'scheduled',
      createdOrderId: json['created_order_id'] as String?,
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _nullableDateTimeFromJson(json['updated_at']),
    );

Map<String, dynamic> _$$ScheduledOrderModelImplToJson(
        _$ScheduledOrderModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'merchant_id': instance.merchantId,
      'customer_name': instance.customerName,
      'customer_phone': instance.customerPhone,
      'pickup_address': instance.pickupAddress,
      'pickup_latitude': instance.pickupLatitude,
      'pickup_longitude': instance.pickupLongitude,
      'delivery_address': instance.deliveryAddress,
      'delivery_latitude': instance.deliveryLatitude,
      'delivery_longitude': instance.deliveryLongitude,
      'total_amount': instance.totalAmount,
      'delivery_fee': instance.deliveryFee,
      'notes': instance.notes,
      'vehicle_type': instance.vehicleType,
      'scheduled_date': _dateOnlyToJson(instance.scheduledDate),
      'scheduled_time': _durationToJson(instance.scheduledTime),
      'status': instance.status,
      'created_order_id': instance.createdOrderId,
      'created_at': _dateTimeToJson(instance.createdAt),
      'updated_at': _nullableDateTimeToJson(instance.updatedAt),
    };
