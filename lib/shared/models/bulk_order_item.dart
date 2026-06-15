import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/data/neighborhoods_data.dart';

part 'bulk_order_item.freezed.dart';
part 'bulk_order_item.g.dart';

Neighborhood _neighborhoodFromJson(dynamic v) {
  final name = v as String;
  return NeighborhoodsData.neighborhoods.firstWhere(
    (n) => n.name == name,
    orElse: () => Neighborhood(name: name, latitude: 0.0, longitude: 0.0),
  );
}

String _neighborhoodToJson(Neighborhood n) => n.name;

@freezed
class BulkOrderItem with _$BulkOrderItem {
  const factory BulkOrderItem({
    @JsonKey(
        name: 'neighborhood',
        fromJson: _neighborhoodFromJson,
        toJson: _neighborhoodToJson)
    required Neighborhood neighborhood,
    @JsonKey(name: 'customer_phone') String? customerPhone,
  }) = _BulkOrderItem;

  factory BulkOrderItem.fromJson(Map<String, dynamic> json) =>
      _$BulkOrderItemFromJson(json);
}
