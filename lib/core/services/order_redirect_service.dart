import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../utils/logger.dart';

/// Global Order Redirect Service
/// 
/// Monitors for new active orders assigned to drivers and redirects them
/// to the dashboard ONCE per new order (not repeatedly)
class OrderRedirectService {
  static Timer? _monitorTimer;
  static String? _currentDriverId;
  static String? _lastSeenOrderId;
  static bool _isMonitoring = false;
  static BuildContext? _context;

  /// Start monitoring for new orders (for drivers only)
  static Future<void> startMonitoring(BuildContext context, String driverId) async {
    _context = context;
    _currentDriverId = driverId;
    
    if (_isMonitoring) {
      Logger.d('ℹ️ Order redirect service already monitoring');
      return;
    }
    
    Logger.d('\n═══════════════════════════════════════');
    Logger.d('🔔 STARTING ORDER REDIRECT SERVICE');
    Logger.d('═══════════════════════════════════════');
    Logger.d('Driver ID: $driverId');
    
    // Load last seen order from storage
    await _loadLastSeenOrder();
    
    // Start monitoring every 3 seconds
    _isMonitoring = true;
    _monitorTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _checkForNewOrders();
    });
    
    Logger.d('✅ Order redirect service started (checking every 3 seconds)');
    Logger.d('═══════════════════════════════════════\n');
  }

  /// Load last seen order from SharedPreferences
  static Future<void> _loadLastSeenOrder() async {
    try {
      if (_currentDriverId == null) return;
      
      final prefs = await SharedPreferences.getInstance();
      _lastSeenOrderId = prefs.getString('last_seen_order_id_$_currentDriverId');
      
      if (_lastSeenOrderId != null) {
        Logger.d('📋 Last seen order loaded: $_lastSeenOrderId');
      } else {
        Logger.d('📋 No previous order found in storage');
      }
    } catch (e) {
      Logger.d('❌ Error loading last seen order: $e');
    }
  }

  /// Check for new orders
  static Future<void> _checkForNewOrders() async {
    if (_currentDriverId == null || _context == null) return;
    
    try {
      // Get current active order (most recent)
      final response = await Supabase.instance.client
          .from('orders')
          .select('id, status, created_at')
          .eq('driver_id', _currentDriverId!)
          .inFilter('status', ['assigned', 'accepted', 'on_the_way'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      // No active orders
      if (response == null) {
        return;
      }
      
      final currentOrderId = response['id'] as String;
      final orderStatus = response['status'] as String;
      
      // Check if this is a NEW order (different from last seen)
      if (_lastSeenOrderId != currentOrderId) {
        Logger.d('\n🚨 NEW ORDER DETECTED!');
        Logger.d('═══════════════════════════════════════');
        Logger.d('Order ID: $currentOrderId');
        Logger.d('Status: $orderStatus');
        Logger.d('Last seen: $_lastSeenOrderId');
        
        // Only redirect for newly ASSIGNED orders (not accepted/on_the_way)
        if (orderStatus == 'assigned') {
          Logger.d('🎯 Redirecting driver to dashboard...');
          
          // Mark as seen BEFORE redirecting to prevent loops
          _lastSeenOrderId = currentOrderId;
          await _saveLastSeenOrder(currentOrderId);
          
          // Redirect to dashboard
          if (_context != null && _context!.mounted) {
            _context!.go('/driver-dashboard');
            Logger.d('✅ Driver redirected to dashboard');
          }
        } else {
          // For accepted/on_the_way, just mark as seen (driver already knows about it)
          _lastSeenOrderId = currentOrderId;
          await _saveLastSeenOrder(currentOrderId);
          Logger.d('ℹ️ Order marked as seen (status: $orderStatus)');
        }
        
        Logger.d('═══════════════════════════════════════\n');
      }
    } catch (e) {
      Logger.d('❌ Error checking for new orders: $e');
    }
  }

  /// Save last seen order to SharedPreferences
  static Future<void> _saveLastSeenOrder(String orderId) async {
    try {
      if (_currentDriverId == null) return;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_seen_order_id_$_currentDriverId', orderId);
      Logger.d('💾 Last seen order saved: $orderId');
    } catch (e) {
      Logger.d('❌ Error saving last seen order: $e');
    }
  }

  /// Update context (call when navigating)
  static void updateContext(BuildContext context) {
    _context = context;
  }

  /// Stop monitoring
  static void stopMonitoring() {
    Logger.d('🛑 Stopping order redirect service');
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isMonitoring = false;
    _context = null;
    _currentDriverId = null;
    _lastSeenOrderId = null;
  }

  /// Check if currently monitoring
  static bool get isMonitoring => _isMonitoring;
}


