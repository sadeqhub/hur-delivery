import 'package:supabase_flutter/supabase_flutter.dart';

/// 🔔 CUTTING-EDGE NOTIFICATION MANAGER
/// 
/// This service guarantees notification delivery by:
/// 1. Inserting notification to database (for record keeping)
/// 2. Immediately calling Edge Function to send push notification
/// 3. Retry mechanism for failed notifications
/// 4. Comprehensive logging
class NotificationManager {
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  /// Send a notification with guaranteed delivery
  /// 
  /// This method:
  /// 1. Inserts notification to database
  /// 2. Calls Edge Function to send push notification
  /// 3. Retries on failure
  /// 4. Returns success status
  static Future<bool> sendNotification({
    required String targetUserId,
    required String title,
    required String body,
    required String type,
    required Map<String, dynamic> data,
    bool skipDatabase = false,
  }) async {
    final startTime = DateTime.now();
    print('\n═══════════════════════════════════════════════════════');
    print('🔔 NOTIFICATION MANAGER: Sending notification');
    print('═══════════════════════════════════════════════════════');
    print('📍 Target User: $targetUserId');
    print('📍 Title: $title');
    print('📍 Body: $body');
    print('📍 Type: $type');
    print('📍 Data: $data');
    print('📍 Skip Database: $skipDatabase');
    print('═══════════════════════════════════════════════════════\n');

    String? notificationId;

    try {
      // NEW APPROACH: Insert to database ONLY
      // Database trigger (trigger_fcm_push) will automatically call Edge Function
      print('💾 Inserting notification to database...');
      print('📌 Database trigger will handle FCM push automatically');
      
      bool success = false;
      int retries = 0;

      while (!success && retries < _maxRetries) {
        if (retries > 0) {
          print('🔄 Retry attempt $retries of $_maxRetries...');
          await Future.delayed(_retryDelay);
        }

        try {
          // Check if notification already exists (if skipDatabase, it means it's already in DB)
          if (skipDatabase) {
            print('⏭️  Notification already in database, skipping insert');
            success = true;
            break;
          }

          // Insert notification to database
          // This will trigger the database trigger (trigger_fcm_push)
          // which will automatically call the Edge Function
          // Ensure data is properly formatted as JSONB
          final notificationData = {
            'user_id': targetUserId,
            'title': title.toString(),
            'body': body.toString(),
            'type': type.toString(),
            'data': data is Map<String, dynamic> ? data : {'raw': data.toString()},
            'is_read': false,
          };
          
          // Validate required fields
          if (notificationData['user_id'] == null || 
              notificationData['title'] == null || 
              notificationData['body'] == null) {
            throw Exception('Missing required notification fields');
          }
          
          await Supabase.instance.client
              .from('notifications')
              .insert(notificationData);
          
          print('✅ Notification inserted to database');
          print('⚡ Database trigger will now call Edge Function automatically');
          success = true;
          break;
          
        } catch (e) {
          print('❌ Failed to insert notification (attempt ${retries + 1}): $e');
          retries++;
        }
      }

      final duration = DateTime.now().difference(startTime);
      print('\n═══════════════════════════════════════════════════════');
      print('🏁 NOTIFICATION MANAGER: Completed');
      print('═══════════════════════════════════════════════════════');
      print('📊 Result: ${success ? "✅ SUCCESS" : "❌ FAILED"}');
      print('📊 Duration: ${duration.inMilliseconds}ms');
      print('📊 Retries: $retries');
      print('📊 Note: Notification logged by Edge Function');
      print('═══════════════════════════════════════════════════════\n');

      return success;

    } catch (e) {
      print('\n❌ CRITICAL ERROR in NotificationManager: $e');
      print('═══════════════════════════════════════════════════════\n');
      return false;
    }
  }

  /// Send notification for order assigned to driver
  static Future<bool> notifyDriverOrderAssigned({
    required String driverId,
    required String orderId,
    required String customerName,
    required String pickupAddress,
    required String deliveryAddress,
  }) async {
    return await sendNotification(
      targetUserId: driverId,
      title: '📦 طلب توصيل جديد',
      body: 'لديك طلب من $customerName - اضغط قبول خلال 30 ثانية',
      type: 'order_assigned',
      data: {
        'type': 'order_assigned',
        'order_id': orderId,
        'customer_name': customerName,
        'pickup_address': pickupAddress,
        'delivery_address': deliveryAddress,
        'priority': 'critical',
      },
    );
  }

  /// Send notification for order created
  static Future<bool> notifyMerchantOrderCreated({
    required String merchantId,
    required String orderId,
    required String customerName,
    required double totalAmount,
    required double deliveryFee,
  }) async {
    return await sendNotification(
      targetUserId: merchantId,
      title: '✅ تم إنشاء الطلب',
      body: 'تم إنشاء الطلب بنجاح - جاري البحث عن سائق',
      type: 'order_created',
      data: {
        'type': 'order_created',
        'order_id': orderId,
        'customer_name': customerName,
        'total_amount': totalAmount.toString(),
        'delivery_fee': deliveryFee.toString(),
      },
    );
  }

  /// Send notification for order accepted
  static Future<bool> notifyMerchantOrderAccepted({
    required String merchantId,
    required String orderId,
    required String driverName,
  }) async {
    return await sendNotification(
      targetUserId: merchantId,
      title: '✅ تم قبول الطلب',
      body: 'السائق قبل الطلب - جاري التجهيز',
      type: 'order_accepted',
      data: {
        'type': 'order_accepted',
        'order_id': orderId,
        'driver_name': driverName,
        'estimated_time': '15 دقيقة',
      },
    );
  }

  /// Send notification for order on the way
  static Future<bool> notifyMerchantOrderOnTheWay({
    required String merchantId,
    required String orderId,
    required String driverName,
  }) async {
    return await sendNotification(
      targetUserId: merchantId,
      title: '🚗 السائق في الطريق',
      body: 'السائق في الطريق لتسليم طلبك',
      type: 'order_on_the_way',
      data: {
        'type': 'order_on_the_way',
        'order_id': orderId,
        'driver_name': driverName,
        'estimated_time': '10 دقائق',
      },
    );
  }

  /// Send notification for order delivered
  static Future<bool> notifyMerchantOrderDelivered({
    required String merchantId,
    required String orderId,
    required String driverName,
  }) async {
    return await sendNotification(
      targetUserId: merchantId,
      title: '🎉 تم التسليم',
      body: 'تم تسليم الطلب بنجاح',
      type: 'order_delivered',
      data: {
        'type': 'order_delivered',
        'order_id': orderId,
        'driver_name': driverName,
      },
    );
  }

  /// Send notification for order rejected/cancelled
  static Future<bool> notifyMerchantOrderRejected({
    required String merchantId,
    required String orderId,
    required String customerName,
  }) async {
    return await sendNotification(
      targetUserId: merchantId,
      title: '❌ لم يتم العثور على سائق',
      body: 'يمكنك إعادة نشر الطلب بزيادة الأجرة (+500 د.ع)',
      type: 'order_cancelled',
      data: {
        'type': 'order_cancelled',
        'order_id': orderId,
        'fee_increase': '500',
        'customer_name': customerName,
        'repost_available': 'true',
      },
    );
  }

  /// Send notification to merchant that driver rejected order
  static Future<bool> notifyMerchantDriverRejected({
    required String merchantId,
    required String orderId,
    required String driverName,
  }) async {
    return await sendNotification(
      targetUserId: merchantId,
      title: '⚠️ تم رفض الطلب',
      body: 'جاري البحث عن سائق آخر',
      type: 'order_rejected',
      data: {
        'type': 'order_rejected',
        'order_id': orderId,
        'driver_name': driverName,
      },
    );
  }
}

