// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bulk_order_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BulkOrderItemImpl _$$BulkOrderItemImplFromJson(Map<String, dynamic> json) =>
    _$BulkOrderItemImpl(
      neighborhood: _neighborhoodFromJson(json['neighborhood']),
      customerPhone: json['customer_phone'] as String?,
    );

Map<String, dynamic> _$$BulkOrderItemImplToJson(_$BulkOrderItemImpl instance) =>
    <String, dynamic>{
      'neighborhood': _neighborhoodToJson(instance.neighborhood),
      'customer_phone': instance.customerPhone,
    };
