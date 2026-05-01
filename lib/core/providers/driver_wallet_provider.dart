import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/response_cache_service.dart';
import '../services/network_quality_service.dart';

class DriverWalletProvider extends ChangeNotifier {
  double _balance = 0.0;
  bool _isLoading = false;
  String? _error;
  bool _isEnabled = true;

  List<DriverWalletTransaction> _transactions = [];
  final Map<String, DriverWalletOrderSummary> _orderSummaries = {};

  // Realtime subscriptions
  StreamSubscription? _walletSubscription;
  StreamSubscription? _transactionsSubscription;
  StreamSubscription? _settingsSubscription;
  String? _currentDriverId;

  // PERFORMANCE: Cache service for 4G optimization (same as WalletProvider)
  final _responseCache = ResponseCacheService();
  final _networkQuality = NetworkQualityService();
  
  // Getters
  double get balance => _balance;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<DriverWalletTransaction> get transactions => _transactions;
  Map<String, DriverWalletOrderSummary> get orderSummaries => _orderSummaries;
  bool get isEnabled => _isEnabled;
  
  // Format balance for display
  String get formattedBalance => '${_balance.toStringAsFixed(0)} IQD';
  
  // Initialize wallet data
  Future<void> initialize(String driverId) async {
    _isLoading = true;
    _error = null;
    _currentDriverId = driverId;
    notifyListeners();
    
    try {
      // Check if driver wallet is enabled
      await _checkWalletEnabled();
      
      if (_isEnabled) {
        await loadWalletData(driverId);
        await loadTransactions(driverId);
        
        // Set up realtime listeners
        _setupRealtimeListeners(driverId);
      }
    } catch (e) {
      _error = 'فشل تحميل بيانات المحفظة: $e';
      print('Error initializing driver wallet: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Check if driver wallet is enabled
  // PERFORMANCE: Cache for 5 minutes (configuration rarely changes)
  Future<void> _checkWalletEnabled() async {
    final cacheKey = 'driver_wallet_enabled_${_currentDriverId ?? "global"}';

    // Check cache first
    final cached = _responseCache.get<bool>(cacheKey);
    if (cached != null) {
      _isEnabled = cached;
      print('✅ Using cached wallet enabled status: $cached');
      return;
    }

    try {
      // Use city-specific function if we have a driver ID
      if (_currentDriverId != null) {
        final response = await Supabase.instance.client.rpc(
          'is_driver_wallet_enabled',
          params: {'p_driver_id': _currentDriverId},
        );

        if (response != null) {
          _isEnabled = response as bool;
          // Cache for 5 minutes
          _responseCache.set(cacheKey, _isEnabled, const Duration(minutes: 5));
          print('💾 Cached wallet enabled status: $_isEnabled');
        } else {
          _isEnabled = true; // Default to enabled if function returns null
        }
      } else {
        // Fallback to global setting if no driver ID
        final response = await Supabase.instance.client
            .from('system_settings')
            .select('value')
            .eq('key', 'driver_wallet')
            .maybeSingle();
        
        if (response != null) {
          _isEnabled = response['value'] == 'enabled';
        } else {
          _isEnabled = true; // Default to enabled if setting not found
        }
      }
      
      // Listen to city_settings changes (if driver has city)
      if (_currentDriverId != null) {
        // Get driver city first
        final userResponse = await Supabase.instance.client
            .from('users')
            .select('city')
            .eq('id', _currentDriverId!)
            .maybeSingle();
        
        final city = userResponse?['city'] as String?;
        
        if (city != null) {
          _settingsSubscription?.cancel();
          _settingsSubscription = Supabase.instance.client
              .from('city_settings')
              .stream(primaryKey: ['id'])
              .eq('city', city)
              .listen(
            (data) {
              if (data.isNotEmpty) {
                _isEnabled = data.first['driver_wallet_enabled'] as bool? ?? true;
                notifyListeners();
              }
            },
            onError: (error) {
              print('❌ City settings realtime error: $error');
            },
          );
        } else {
          // Fallback to global settings stream
          _settingsSubscription?.cancel();
          _settingsSubscription = Supabase.instance.client
              .from('system_settings')
              .stream(primaryKey: ['id'])
              .eq('key', 'driver_wallet')
              .listen(
            (data) {
              if (data.isNotEmpty) {
                _isEnabled = data.first['value'] == 'enabled';
                notifyListeners();
              }
            },
            onError: (error) {
              print('❌ Settings realtime error: $error');
            },
          );
        }
      } else {
        // Listen to global settings changes
        _settingsSubscription?.cancel();
        _settingsSubscription = Supabase.instance.client
            .from('system_settings')
            .stream(primaryKey: ['id'])
            .eq('key', 'driver_wallet')
            .listen(
          (data) {
            if (data.isNotEmpty) {
              _isEnabled = data.first['value'] == 'enabled';
              notifyListeners();
            }
          },
          onError: (error) {
            print('❌ Settings realtime error: $error');
          },
        );
      }
    } catch (e) {
      print('Error checking wallet enabled status: $e');
      _isEnabled = true; // Default to enabled on error
    }
  }
  
  // Set up realtime listeners
  void _setupRealtimeListeners(String driverId) {
    // Cancel existing subscriptions
    _walletSubscription?.cancel();
    _transactionsSubscription?.cancel();
    
    // Listen to wallet balance changes
    _walletSubscription = Supabase.instance.client
        .from('driver_wallets')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .listen(
      (data) {
        if (data.isNotEmpty) {
          final walletData = data.first;
          _balance = (walletData['balance'] as num).toDouble();
          notifyListeners();
          print('💰 Driver wallet updated via realtime: $_balance IQD');
        }
      },
      onError: (error) {
        print('❌ Driver wallet realtime error: $error');
      },
    );
    
    // Listen to transaction changes
    _transactionsSubscription = Supabase.instance.client
        .from('driver_wallet_transactions')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .order('created_at', ascending: false)
        .limit(50)
        .listen(
      (data) {
        _transactions = data
            .map((json) => DriverWalletTransaction.fromJson(json))
            .toList();
        notifyListeners();
        print('📝 Driver transactions updated via realtime: ${_transactions.length} transactions');
      },
      onError: (error) {
        print('❌ Driver transactions realtime error: $error');
      },
    );
  }
  
  // Load wallet data
  // PERFORMANCE: Dual-load strategy - return cache first, refresh in background
  Future<void> loadWalletData(String driverId) async {
    final cacheKey = 'driver_wallet_$driverId';

    try {
      // On slow connections, return cached data immediately
      if (_networkQuality.isSlowConnection) {
        final cached = _responseCache.get<double>(cacheKey);
        if (cached != null) {
          _balance = cached;
          print('✅ Using cached driver wallet balance: $cached IQD (slow connection)');
          notifyListeners();
          // Continue to refresh in background
        }
      }

      final response = await Supabase.instance.client
          .from('driver_wallets')
          .select()
          .eq('driver_id', driverId)
          .maybeSingle();

      if (response != null) {
        _balance = (response['balance'] as num).toDouble();

        // Cache for 1 minute
        _responseCache.set(cacheKey, _balance, const Duration(minutes: 1));
        notifyListeners();
      } else {
        // Wallet doesn't exist yet, it will be created automatically
        _balance = 0.0;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading driver wallet data: $e');
      rethrow;
    }
  }
  
  // Load transactions
  // PERFORMANCE: Cache for 2-3 minutes on slow connections, return cached first
  Future<void> loadTransactions(String driverId, {int limit = 50}) async {
    final cacheKey = 'driver_wallet_transactions_$driverId';

    try {
      // On slow connections, return cached data immediately
      if (_networkQuality.isSlowConnection) {
        final cached = _responseCache.get<List<DriverWalletTransaction>>(cacheKey);
        if (cached != null) {
          _transactions = cached;
          print('✅ Using cached driver transactions (${cached.length} items) - slow connection');
          notifyListeners();
          // Continue to refresh in background
        }
      }

      final response = await Supabase.instance.client
          .from('driver_wallet_transactions')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false)
          .limit(limit);

      _transactions = (response as List)
          .map((json) => DriverWalletTransaction.fromJson(json))
          .toList();

      // Cache for 2 minutes
      _responseCache.set(cacheKey, _transactions, const Duration(minutes: 2));

      // PERFORMANCE: Defer order summaries on poor connections
      if (_networkQuality.currentQuality != NetworkQuality.poor) {
        await _loadOrderSummariesForTransactions(driverId, _transactions);
      } else {
        print('⏭️ Deferring order summaries load - poor connection');
      }

      notifyListeners();
    } catch (e) {
      print('Error loading driver transactions: $e');
      rethrow;
    }
  }

  // PERFORMANCE: Cache order summaries for 3 minutes
  Future<void> _loadOrderSummariesForTransactions(
    String driverId,
    List<DriverWalletTransaction> txs,
  ) async {
    final orderIds = txs
        .map((t) => t.orderId)
        .whereType<String>()
        .toSet()
        .difference(_orderSummaries.keys.toSet())
        .toList();

    if (orderIds.isEmpty) return;

    // Check cache for each order
    final uncachedOrderIds = <String>[];
    for (final orderId in orderIds) {
      final cacheKey = 'driver_order_summary_$orderId';
      final cached = _responseCache.get<DriverWalletOrderSummary>(cacheKey);
      if (cached != null) {
        _orderSummaries[orderId] = cached;
      } else {
        uncachedOrderIds.add(orderId);
      }
    }

    if (uncachedOrderIds.isEmpty) {
      print('✅ All order summaries loaded from cache');
      return;
    }

    final response = await Supabase.instance.client
        .from('orders')
        .select('id, driver_id, status, customer_name, total_amount, delivery_fee, merchant_name')
        .inFilter('id', uncachedOrderIds)
        .eq('driver_id', driverId);

    for (final row in (response as List<dynamic>)) {
      final map = row as Map<String, dynamic>;
      final id = map['id'] as String?;
      if (id == null) continue;

      final summary = DriverWalletOrderSummary.fromJson(map);
      _orderSummaries[id] = summary;

      // Cache for 3 minutes
      final cacheKey = 'driver_order_summary_$id';
      _responseCache.set(cacheKey, summary, const Duration(minutes: 3));
    }
  }
  
  // Refresh wallet data
  Future<void> refresh(String driverId) async {
    await initialize(driverId);
  }

  Future<Map<String, dynamic>?> createWaylPaymentLink({
    required String driverId,
    required double amount,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'wayl-payment',
        body: {
          'driver_id': driverId,
          'amount': amount,
          'notes': notes,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );

      if (response.status == 200) {
        if (response.data != null) {
          return response.data as Map<String, dynamic>;
        }
        _error = 'Received empty response from server';
        return null;
      }

      final errorData = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};
      _error = (errorData['error'] as String?) ??
          'فشل إنشاء رابط الدفع (Status: ${response.status})';
      return null;
    } on TimeoutException {
      _error = 'انتهت مهلة الطلب. يرجى المحاولة مرة أخرى';
      return null;
    } catch (e) {
      _error = 'فشل إنشاء رابط الدفع: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  // Dispose and cleanup
  @override
  void dispose() {
    _walletSubscription?.cancel();
    _transactionsSubscription?.cancel();
    _settingsSubscription?.cancel();
    super.dispose();
  }
}

// Driver Wallet Transaction Model
class DriverWalletTransaction {
  final String id;
  final String driverId;
  final String transactionType;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String? orderId;
  final String? paymentMethod;
  final String? notes;
  final DateTime createdAt;
  
  DriverWalletTransaction({
    required this.id,
    required this.driverId,
    required this.transactionType,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.orderId,
    this.paymentMethod,
    this.notes,
    required this.createdAt,
  });
  
  factory DriverWalletTransaction.fromJson(Map<String, dynamic> json) {
    return DriverWalletTransaction(
      id: json['id'],
      driverId: json['driver_id'],
      transactionType: json['transaction_type'],
      amount: (json['amount'] as num).toDouble(),
      balanceBefore: (json['balance_before'] as num).toDouble(),
      balanceAfter: (json['balance_after'] as num).toDouble(),
      orderId: json['order_id'],
      paymentMethod: json['payment_method'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  
  // Get display title based on transaction type
  String get title {
    switch (transactionType) {
      case 'top_up':
        return 'شحن المحفظة';
      case 'earning':
        return 'أرباح من طلب';
      case 'withdrawal':
        return 'سحب';
      case 'adjustment':
        return 'تعديل';
      case 'commission_deduction':
        return 'خصم عمولة';
      default:
        return 'معاملة';
    }
  }
  
  // Get icon based on transaction type
  IconData get icon {
    switch (transactionType) {
      case 'top_up':
        return Icons.add_circle;
      case 'earning':
        return Icons.monetization_on;
      case 'withdrawal':
        return Icons.account_balance_wallet;
      case 'adjustment':
        return Icons.tune;
      case 'commission_deduction':
        return Icons.remove_circle;
      default:
        return Icons.receipt;
    }
  }
  
  // Get color based on transaction type
  Color get color {
    return amount >= 0 
        ? Colors.green 
        : Colors.red;
  }
  
  // Get formatted amount
  String get formattedAmount {
    final absAmount = amount.abs().toStringAsFixed(0);
    final sign = amount >= 0 ? '+' : '-';
    return '$sign $absAmount IQD';
  }
  
  // Get payment method display name
  String get paymentMethodDisplay {
    switch (paymentMethod) {
      case 'zain_cash':
        return 'زين كاش';
      case 'qi_card':
        return 'بطاقة كي';
      case 'hur_representative':
        return 'ممثل حر';
      case 'admin_adjustment':
        return 'تعديل إداري';
      case 'bank_transfer':
        return 'تحويل بنكي';
      default:
        return paymentMethod ?? 'غير محدد';
    }
  }
}

class DriverWalletOrderSummary {
  final String id;
  final String status;
  final String customerName;
  final double totalAmount;
  final double deliveryFee;
  final String? merchantName;

  DriverWalletOrderSummary({
    required this.id,
    required this.status,
    required this.customerName,
    required this.totalAmount,
    required this.deliveryFee,
    required this.merchantName,
  });

  factory DriverWalletOrderSummary.fromJson(Map<String, dynamic> json) {
    return DriverWalletOrderSummary(
      id: json['id'] as String,
      status: (json['status'] as String?) ?? 'unknown',
      customerName: (json['customer_name'] as String?) ?? '',
      totalAmount: double.parse(json['total_amount']?.toString() ?? '0'),
      deliveryFee: double.parse(json['delivery_fee']?.toString() ?? '0'),
      merchantName: json['merchant_name'] as String?,
    );
  }
}

