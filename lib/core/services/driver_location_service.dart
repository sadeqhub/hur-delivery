import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

class DriverLocationService {
  static const String _baseUrl = 'https://bvtoxmmiitznagsbubhg.supabase.co';
  static const String _apiKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2dG94bW1paXR6bmFnc2J1YmhnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwNzk5MTcsImV4cCI6MjA2NzY1NTkxN30.WjdQh_cvOebwL0TG0bzDLZimWCLC4YuP__jtvBD_xv0';

  /// Check for orders where customers have provided location updates
  /// Returns list of orders that need driver attention
  static Future<List<CustomerLocationUpdate>> checkForLocationUpdates() async {
    try {
      Logger.d('📍 ===========================================');
      Logger.d('📍 DRIVER LOCATION SERVICE - CHECKING UPDATES');
      Logger.d('📍 URL: $_baseUrl/functions/v1/check-customer-location-updates');
      Logger.d('📍 Time: ${DateTime.now()}');
      Logger.d('📍 ===========================================');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/functions/v1/check-customer-location-updates'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': _apiKey,
        },
      );

      Logger.d('📍 API Response Status: ${response.statusCode}');
      Logger.d('📍 API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Logger.d('📍 Parsed JSON data: $data');
        
        // Handle different response formats
        List<dynamic> orders = [];
        if (data is List) {
          orders = data;
          Logger.d('📍 Response is a List with ${orders.length} items');
        } else if (data is Map) {
          Logger.d('📍 Response is a Map with keys: ${data.keys.toList()}');
          if (data.containsKey('orders_with_updates')) {
            orders = data['orders_with_updates'] ?? [];
            Logger.d('📍 Found orders_with_updates key with ${orders.length} items');
          } else if (data.containsKey('data')) {
            orders = data['data'] ?? [];
            Logger.d('📍 Found data key with ${orders.length} items');
          } else {
            Logger.d('📍 No recognized keys found in response');
          }
        }
        
        Logger.d('📍 Final orders count: ${orders.length}');
        
        if (orders.isNotEmpty) {
          Logger.d('📍 ✅ SUCCESS: Found ${orders.length} orders with location updates:');
          for (int i = 0; i < orders.length; i++) {
            final order = orders[i];
            Logger.d('   📍 Order ${i + 1}:');
            Logger.d('      ID: ${order['order_id']}');
            Logger.d('      Customer: ${order['customer_name']}');
            Logger.d('      Phone: ${order['customer_phone']}');
            Logger.d('      Address: ${order['delivery_address']}');
            Logger.d('      Coordinates: ${order['delivery_latitude']}, ${order['delivery_longitude']}');
            Logger.d('      Merchant: ${order['merchant_name']}');
            Logger.d('      Status: ${order['status']}');
            Logger.d('      Updated: ${order['updated_at']}');
          }
        } else {
          Logger.d('📍 No orders with location updates found');
        }
        
        final result = orders.map((order) => CustomerLocationUpdate.fromJson(order)).toList();
        Logger.d('📍 Returning ${result.length} CustomerLocationUpdate objects');
        return result;
      } else {
        Logger.d('❌ API Error: ${response.statusCode}');
        Logger.d('❌ Error Response: ${response.body}');
        return [];
      }
    } catch (e) {
      Logger.d('❌ Exception in checkForLocationUpdates: $e');
      Logger.d('❌ Stack trace: ${StackTrace.current}');
      return [];
    } finally {
      Logger.d('📍 ===========================================');
      Logger.d('📍 DRIVER LOCATION SERVICE CHECK COMPLETE');
      Logger.d('📍 ===========================================');
    }
  }

  /// Mark that driver has been notified about customer location
  static Future<bool> markDriverNotified(String orderId) async {
    try {
      // Use the database function directly instead of edge function
      final response = await Supabase.instance.client.rpc(
        'mark_driver_notified_location',
        params: {'p_order_id': orderId},
      );

      if (response != null) {
        Logger.d('✅ Marked driver as notified for order $orderId');
        return true;
      } else {
        if (kDebugMode) {
          Logger.d('❌ Failed to mark driver as notified');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        Logger.d('❌ Error marking driver as notified: $e');
      }
      return false;
    }
  }

  /// Get location update notification message for driver
  static String getLocationUpdateMessage(CustomerLocationUpdate update) {
    final orderCode = update.userFriendlyCode ?? update.orderId.substring(0, 8);
    return '📍 العميل ${update.customerName} قد أرسل موقعه!\n\n'
           'الطلب: $orderCode...\n'
           'التاجر: ${update.merchantName}\n\n'
           '✅ لا حاجة للاتصال بالعميل - الموقع متوفر الآن';
  }

  static String _formatDateTime(String dateTime) {
    try {
      final date = DateTime.parse(dateTime);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime;
    }
  }
}

class CustomerLocationUpdate {
  final String orderId;
  final String? userFriendlyCode;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final String merchantName;
  final String status;
  final String createdAt;
  final String updatedAt;

  CustomerLocationUpdate({
    required this.orderId,
    this.userFriendlyCode,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    required this.merchantName,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomerLocationUpdate.fromJson(Map<String, dynamic> json) {
    return CustomerLocationUpdate(
      orderId: json['order_id'] ?? '',
      userFriendlyCode: json['user_friendly_code'] as String?,
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      deliveryAddress: json['delivery_address'] ?? '',
      deliveryLatitude: (json['delivery_latitude'] ?? 0.0).toDouble(),
      deliveryLongitude: (json['delivery_longitude'] ?? 0.0).toDouble(),
      merchantName: json['merchant_name'] ?? '',
      status: json['status'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'delivery_address': deliveryAddress,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'merchant_name': merchantName,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
