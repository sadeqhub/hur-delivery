// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bulk_order_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BulkOrderModelImpl _$$BulkOrderModelImplFromJson(Map<String, dynamic> json) =>
    _$BulkOrderModelImpl(
      id: json['id'] as String,
      merchantId: json['merchant_id'] as String,
      driverId: json['driver_id'] as String?,
      pickupAddress: json['pickup_address'] as String,
      pickupLatitude: _doubleFromJson(json['pickup_latitude']),
      pickupLongitude: _doubleFromJson(json['pickup_longitude']),
      neighborhoods: (json['neighborhoods'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      neighborhoodItems: (json['neighborhood_items'] as List<dynamic>?)
          ?.map((e) => BulkOrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      perDeliveryFee: _doubleFromJson(json['per_delivery_fee']),
      bulkOrderFee: json['bulk_order_fee'] == null
          ? 1000.0
          : _doubleFromJson(json['bulk_order_fee']),
      vehicleType: json['vehicle_type'] as String?,
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'pending',
      orderDate: _dateTimeFromJson(json['order_date']),
      createdAt: _dateTimeFromJson(json['created_at']),
      assignedAt: _nullableDateTimeFromJson(json['assigned_at']),
      acceptedAt: _nullableDateTimeFromJson(json['accepted_at']),
      merchantName: json['merchant_name'] as String?,
      merchantPhone: json['merchant_phone'] as String?,
    );

Map<String, dynamic> _$$BulkOrderModelImplToJson(
        _$BulkOrderModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'merchant_id': instance.merchantId,
      'driver_id': instance.driverId,
      'pickup_address': instance.pickupAddress,
      'pickup_latitude': instance.pickupLatitude,
      'pickup_longitude': instance.pickupLongitude,
      'neighborhoods': instance.neighborhoods,
      'neighborhood_items': instance.neighborhoodItems,
      'per_delivery_fee': instance.perDeliveryFee,
      'bulk_order_fee': instance.bulkOrderFee,
      'vehicle_type': instance.vehicleType,
      'notes': instance.notes,
      'status': instance.status,
      'order_date': _dateTimeToJson(instance.orderDate),
      'created_at': _dateTimeToJson(instance.createdAt),
      'assigned_at': _nullableDateTimeToJson(instance.assignedAt),
      'accepted_at': _nullableDateTimeToJson(instance.acceptedAt),
      'merchant_name': instance.merchantName,
      'merchant_phone': instance.merchantPhone,
    };
