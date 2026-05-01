import 'bulk_order_item.dart';
import '../../core/data/neighborhoods_data.dart';

class BulkOrderModel {
  final String id;
  final String merchantId;
  final String? driverId;
  final String pickupAddress;
  final double pickupLatitude;
  final double pickupLongitude;
  final List<String> neighborhoods; // For backward compatibility
  final List<BulkOrderItem>? neighborhoodItems; // New: neighborhoods with phone numbers
  final double perDeliveryFee;
  final double bulkOrderFee;
  final String? vehicleType;
  final String? notes;
  final String status; // 'pending', 'accepted', 'picked_up', 'on_the_way', 'delivered', 'cancelled', 'rejected'
  final DateTime orderDate;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final DateTime? acceptedAt;
  final String? merchantName;
  final String? merchantPhone;

  BulkOrderModel({
    required this.id,
    required this.merchantId,
    this.driverId,
    required this.pickupAddress,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.neighborhoods,
    this.neighborhoodItems,
    required this.perDeliveryFee,
    required this.bulkOrderFee,
    this.vehicleType,
    this.notes,
    required this.status,
    required this.orderDate,
    required this.createdAt,
    this.assignedAt,
    this.acceptedAt,
    this.merchantName,
    this.merchantPhone,
  });

  factory BulkOrderModel.fromJson(Map<String, dynamic> json) {
    // Parse neighborhood items if available
    List<BulkOrderItem>? items;
    if (json['neighborhood_items'] != null) {
      try {
        final itemsData = json['neighborhood_items'] as List<dynamic>;
        items = itemsData.map((item) {
          return BulkOrderItem.fromJson(
            item as Map<String, dynamic>,
            NeighborhoodsData.neighborhoods,
          );
        }).toList();
      } catch (e) {
        print('⚠️ Error parsing neighborhood_items: $e');
        items = null;
      }
    }

    return BulkOrderModel(
      id: json['id'] as String,
      merchantId: json['merchant_id'] as String,
      driverId: json['driver_id'] as String?,
      pickupAddress: json['pickup_address'] as String,
      pickupLatitude: double.parse(json['pickup_latitude'].toString()),
      pickupLongitude: double.parse(json['pickup_longitude'].toString()),
      neighborhoods: (json['neighborhoods'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      neighborhoodItems: items,
      perDeliveryFee: double.parse(json['per_delivery_fee']?.toString() ?? '0'),
      bulkOrderFee: double.parse(json['bulk_order_fee']?.toString() ?? '1000'),
      vehicleType: json['vehicle_type'] as String?,
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'pending',
      orderDate: DateTime.parse(json['order_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'] as String)
          : null,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      merchantName: json['merchant']?['name'] as String?,
      merchantPhone: json['merchant']?['phone'] as String?,
    );
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isPickedUp => status == 'picked_up';
  bool get isOnTheWay => status == 'on_the_way';
  bool get isDelivered => status == 'delivered';
  bool get isCancelled => status == 'cancelled';
  bool get isRejected => status == 'rejected';
}

