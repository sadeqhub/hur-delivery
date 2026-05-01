import '../../core/data/neighborhoods_data.dart';

/// Represents a neighborhood with optional customer phone number for bulk orders
class BulkOrderItem {
  final Neighborhood neighborhood;
  final String? customerPhone; // Optional customer phone number

  BulkOrderItem({
    required this.neighborhood,
    this.customerPhone,
  });

  Map<String, dynamic> toJson() {
    return {
      'neighborhood': neighborhood.name,
      'customer_phone': customerPhone,
    };
  }

  factory BulkOrderItem.fromJson(Map<String, dynamic> json, List<Neighborhood> allNeighborhoods) {
    // Find the neighborhood from the list
    final neighborhood = allNeighborhoods.firstWhere(
      (n) => n.name == json['neighborhood'],
      orElse: () => Neighborhood(
        name: json['neighborhood'] as String,
        latitude: 0.0,
        longitude: 0.0,
      ),
    );
    
    return BulkOrderItem(
      neighborhood: neighborhood,
      customerPhone: json['customer_phone'] as String?,
    );
  }
}

