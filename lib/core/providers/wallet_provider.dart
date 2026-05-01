import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/response_cache_service.dart';
import '../services/network_quality_service.dart';

class WalletProvider extends ChangeNotifier {
  double _balance = 0.0;
  double _orderFee = 500.0;
  double _creditLimit = -10000.0;
  bool _canPlaceOrder = true;
  bool _isLoading = false;
  String? _error;
  bool _isEnabled = true;
  bool _isFeeExempt = false;
  DateTime? _merchantCreatedAt;
  DateTime? _feeExemptionEndDate;
  
  List<WalletTransaction> _transactions = [];
  final Map<String, WalletOrderSummary> _orderSummaries = {};
  bool _hasMoreTransactions = true;
  bool _isLoadingMore = false;
  static const int _pageSize = 30;
  
  // Realtime subscriptions
  StreamSubscription? _walletSubscription;
  StreamSubscription? _transactionsSubscription;
  StreamSubscription? _settingsSubscription;
  String? _currentMerchantId;
  
  // Response cache service for 4G optimization
  final _responseCache = ResponseCacheService();
  final _networkQuality = NetworkQualityService();
  
  // Getters
  double get balance => _balance;
  double get orderFee => _orderFee;
  double get creditLimit => _creditLimit;
  bool get canPlaceOrder => _canPlaceOrder;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<WalletTransaction> get transactions => _transactions;
  Map<String, WalletOrderSummary> get orderSummaries => _orderSummaries;
  bool get hasMoreTransactions => _hasMoreTransactions;
  bool get isLoadingMore => _isLoadingMore;
  bool get isEnabled => _isEnabled;
  bool get isFeeExempt => _isFeeExempt;
  DateTime? get merchantCreatedAt => _merchantCreatedAt;
  DateTime? get feeExemptionEndDate => _feeExemptionEndDate;
  
  // Format balance for display
  String get formattedBalance => '${_balance.toStringAsFixed(0)} IQD';
  
  // Check if balance is low (within 20% of credit limit)
  bool get isBalanceLow {
    final threshold = _creditLimit + ((_creditLimit.abs()) * 0.2);
    return _balance <= threshold;
  }
  
  // Check if balance is critical (at or below credit limit)
  bool get isBalanceCritical => _balance <= _creditLimit;
  
  // Initialize wallet data
  Future<void> initialize(String merchantId) async {
    _isLoading = true;
    _error = null;
    _currentMerchantId = merchantId;
    notifyListeners();
    
    try {
      // Check if merchant wallet is enabled
      await _checkWalletEnabled();
      
      // Check fee exemption status
      await _checkFeeExemption(merchantId);
      
      // Always load wallet data and transactions to show balance and history
      // even if wallet feature is disabled (merchants should see their balance)
      await loadWalletData(merchantId);
      await loadTransactions(merchantId);
      
      print('📝 After initial load: ${_transactions.length} transactions, balance: $_balance');
      
      // Set up realtime listeners after initial load to avoid overwriting with empty data
      if (_isEnabled) {
        // Set up realtime listeners for both wallet and transactions
        _setupRealtimeListeners(merchantId);
      } else {
        // Even if wallet is disabled, set up transaction listener to show history
        _transactionsSubscription?.cancel();
        _transactionsSubscription = Supabase.instance.client
            .from('wallet_transactions')
            .stream(primaryKey: ['id'])
            .eq('merchant_id', merchantId)
            .order('created_at', ascending: false)
            .limit(50)
            .listen(
          (data) {
            print('📝 Realtime update received (wallet disabled): ${data.length} transactions');
            // Only update if we have data, otherwise keep existing transactions
            if (data.isNotEmpty) {
              try {
                final newTransactions = data
                    .map((json) {
                      // Ensure merchant_id is set
                      if (json['merchant_id'] == null) {
                        json['merchant_id'] = merchantId;
                      }
                      return WalletTransaction.fromJson(json);
                    })
                    .toList();
                _transactions = newTransactions;
                print('📝 Transactions updated via realtime: ${_transactions.length} transactions');
                notifyListeners();
              } catch (e) {
                print('❌ Error parsing realtime transactions: $e');
              }
            } else {
              print('⚠️ Realtime returned empty list - keeping existing ${_transactions.length} transactions');
            }
          },
          onError: (error) {
            print('❌ Transactions realtime error: $error');
          },
        );
        
        // Also listen to wallet balance changes even if disabled
        _walletSubscription?.cancel();
        _walletSubscription = Supabase.instance.client
            .from('merchant_wallets')
            .stream(primaryKey: ['id'])
            .eq('merchant_id', merchantId)
            .listen(
          (data) {
            if (data.isNotEmpty) {
              final walletData = data.first;
              _balance = (walletData['balance'] as num).toDouble();
              _orderFee = (walletData['order_fee'] as num).toDouble();
              _creditLimit = (walletData['credit_limit'] as num).toDouble();
              _canPlaceOrder = _balance >= _creditLimit;
              notifyListeners();
              print('💰 Wallet updated via realtime: $_balance IQD');
            }
          },
          onError: (error) {
            print('❌ Wallet realtime error: $error');
          },
        );
      }
    } catch (e) {
      _error = 'فشل تحميل بيانات المحفظة: $e';
      print('Error initializing wallet: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Check if merchant is exempt from fees (less than 30 days old)
  Future<void> _checkFeeExemption(String merchantId) async {
    try {
      // Call the database function to check exemption status
      final response = await Supabase.instance.client.rpc(
        'is_merchant_fee_exempt',
        params: {'p_merchant_id': merchantId},
      );
      
      _isFeeExempt = response as bool? ?? false;
      
      // Get merchant creation date for UI display
      if (_isFeeExempt) {
        final userResponse = await Supabase.instance.client
            .from('users')
            .select('created_at')
            .eq('id', merchantId)
            .maybeSingle();
        
        if (userResponse != null && userResponse['created_at'] != null) {
          _merchantCreatedAt = DateTime.parse(userResponse['created_at'] as String);
          // Calculate exemption end date (30 days from creation)
          _feeExemptionEndDate = _merchantCreatedAt!.add(const Duration(days: 30));
        }
      } else {
        _merchantCreatedAt = null;
        _feeExemptionEndDate = null;
      }
      
      notifyListeners();
    } catch (e) {
      print('Error checking fee exemption: $e');
      _isFeeExempt = false;
      _merchantCreatedAt = null;
      _feeExemptionEndDate = null;
    }
  }
  
  // Check if merchant wallet is enabled
  Future<void> _checkWalletEnabled() async {
    try {
      // Use city-specific function if we have a merchant ID
      if (_currentMerchantId != null) {
        final response = await Supabase.instance.client.rpc(
          'is_merchant_wallet_enabled',
          params: {'p_merchant_id': _currentMerchantId},
        );
        
        if (response != null) {
          _isEnabled = response as bool;
        } else {
          _isEnabled = true; // Default to enabled if function returns null
        }
      } else {
        // Fallback to global setting if no merchant ID
        final response = await Supabase.instance.client
            .from('system_settings')
            .select('value')
            .eq('key', 'merchant_wallet')
            .maybeSingle();
        
        if (response != null) {
          _isEnabled = response['value'] == 'enabled';
        } else {
          _isEnabled = true; // Default to enabled if setting not found
        }
      }
      
      // Listen to city_settings changes (if merchant has city)
      if (_currentMerchantId != null) {
        // Get merchant city first
        final userResponse = await Supabase.instance.client
            .from('users')
            .select('city')
            .eq('id', _currentMerchantId!)
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
                _isEnabled = data.first['merchant_wallet_enabled'] as bool? ?? true;
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
              .eq('key', 'merchant_wallet')
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
            .eq('key', 'merchant_wallet')
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
  void _setupRealtimeListeners(String merchantId) {
    // Cancel existing subscriptions
    _walletSubscription?.cancel();
    _transactionsSubscription?.cancel();
    
    // Listen to wallet balance changes
    _walletSubscription = Supabase.instance.client
        .from('merchant_wallets')
        .stream(primaryKey: ['id'])
        .eq('merchant_id', merchantId)
        .listen(
      (data) {
        if (data.isNotEmpty) {
          final walletData = data.first;
          _balance = (walletData['balance'] as num).toDouble();
          _orderFee = (walletData['order_fee'] as num).toDouble();
          _creditLimit = (walletData['credit_limit'] as num).toDouble();
          _canPlaceOrder = _balance >= _creditLimit;
          notifyListeners();
          print('💰 Wallet updated via realtime: $_balance IQD');
        }
      },
      onError: (error) {
        print('❌ Wallet realtime error: $error');
      },
    );
    
    // Listen to transaction changes
    _transactionsSubscription = Supabase.instance.client
        .from('wallet_transactions')
        .stream(primaryKey: ['id'])
        .eq('merchant_id', merchantId)
        .order('created_at', ascending: false)
        .limit(50)
        .listen(
      (data) {
        print('📝 Realtime update received: ${data.length} transactions');
        if (data.isEmpty) {
          print('⚠️ Realtime returned empty list - keeping existing transactions');
          return; // Don't overwrite with empty list
        }
        try {
          _transactions = data
              .map((json) {
                // Ensure merchant_id is set
                if (json['merchant_id'] == null) {
                  json['merchant_id'] = merchantId;
                }
                return WalletTransaction.fromJson(json);
              })
              .toList();
          print('📝 Transactions updated via realtime: ${_transactions.length} transactions');
          notifyListeners();
        } catch (e) {
          print('❌ Error parsing realtime transactions: $e');
        }
      },
      onError: (error) {
        print('❌ Transactions realtime error: $error');
      },
    );
  }
  
  // Load wallet data
  // 4G OPTIMIZATION: Uses caching on slow connections
  Future<void> loadWalletData(String merchantId) async {
    try {
      // Check cache first (if network is slow)
      final cacheKey = 'wallet_data_$merchantId';
      if (_networkQuality.isSlowConnection) {
        final cached = await _responseCache.getCachedResponse<Map<String, dynamic>>(cacheKey);
        if (cached != null) {
          _balance = (cached['balance'] as num?)?.toDouble() ?? 0.0;
          _orderFee = (cached['order_fee'] as num?)?.toDouble() ?? 500.0;
          _creditLimit = (cached['credit_limit'] as num?)?.toDouble() ?? -10000.0;
          _canPlaceOrder = _balance >= _creditLimit;
          notifyListeners();
          // Load fresh data in background
          unawaited(_loadFreshWalletData(merchantId, cacheKey));
          return; // Return early with cached data
        }
      }
      
      // Load from database
      final response = await Supabase.instance.client
          .from('merchant_wallets')
          .select('balance, order_fee, credit_limit') // 4G OPTIMIZATION: Select only needed fields
          .eq('merchant_id', merchantId)
          .maybeSingle();
      
      if (response != null) {
        _balance = (response['balance'] as num).toDouble();
        _orderFee = (response['order_fee'] as num).toDouble();
        _creditLimit = (response['credit_limit'] as num).toDouble();
        _canPlaceOrder = _balance >= _creditLimit;
        
        // Cache the response (if network is slow)
        if (_networkQuality.isSlowConnection) {
          await _responseCache.cacheResponse(
            key: cacheKey,
            data: {
              'balance': _balance,
              'order_fee': _orderFee,
              'credit_limit': _creditLimit,
            },
            cacheDuration: const Duration(minutes: 1), // Short cache for balance
          );
        }
        
        notifyListeners();
      }
    } catch (e) {
      print('Error loading wallet data: $e');
      rethrow;
    }
  }
  
  /// Load fresh wallet data and cache it (background operation)
  Future<void> _loadFreshWalletData(String merchantId, String cacheKey) async {
    try {
      final response = await Supabase.instance.client
          .from('merchant_wallets')
          .select('balance, order_fee, credit_limit')
          .eq('merchant_id', merchantId)
          .maybeSingle();
      
      if (response != null) {
        _balance = (response['balance'] as num).toDouble();
        _orderFee = (response['order_fee'] as num).toDouble();
        _creditLimit = (response['credit_limit'] as num).toDouble();
        _canPlaceOrder = _balance >= _creditLimit;
        
        await _responseCache.cacheResponse(
          key: cacheKey,
          data: {
            'balance': _balance,
            'order_fee': _orderFee,
            'credit_limit': _creditLimit,
          },
          cacheDuration: const Duration(minutes: 1),
        );
        
        notifyListeners();
      }
    } catch (e) {
      // Silently fail - we already have cached data
      print('⚠️ Background wallet refresh failed: $e');
    }
  }
  
  /// Load initial page of transactions (resets pagination state).
  // 4G OPTIMIZATION: Uses caching and selective fields
  Future<void> loadTransactions(String merchantId, {int limit = _pageSize}) async {
    try {
      print('📝 Loading transactions for merchant: $merchantId');
      
      // Check cache first (if network is slow)
      final cacheKey = 'wallet_transactions_$merchantId$limit';
      if (_networkQuality.isSlowConnection) {
        final cached = await _responseCache.getCachedResponse<List<WalletTransaction>>(cacheKey);
        if (cached != null && cached.isNotEmpty) {
          print('📝 Using cached transactions: ${cached.length} transactions');
          _transactions = cached;
          notifyListeners();
          // Load fresh data in background
          unawaited(_loadFreshTransactions(merchantId, limit, cacheKey));
          return; // Return early with cached data
        }
      }
      
      // 4G OPTIMIZATION: Select only essential fields to reduce response size
      // Include merchant_id for proper mapping
      final response = await Supabase.instance.client
          .from('wallet_transactions')
          .select('id, merchant_id, transaction_type, amount, balance_before, balance_after, order_id, payment_method, notes, created_at')
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false)
          .limit(limit);
      
      print('📝 Raw response from database: ${response.length} transactions');
      
      if (response.isEmpty) {
        print('⚠️ No transactions found for merchant: $merchantId');
        _transactions = [];
        notifyListeners();
        return;
      }
      
      _transactions = (response as List)
          .map((json) {
            try {
              // Ensure merchant_id is set if missing
              if (json['merchant_id'] == null) {
                json['merchant_id'] = merchantId;
              }
              return WalletTransaction.fromJson(json);
            } catch (e) {
              print('❌ Error parsing transaction: $e, JSON: $json');
              rethrow;
            }
          })
          .toList();

      print('📝 Successfully parsed ${_transactions.length} transactions');
      _hasMoreTransactions = _transactions.length >= limit;

      await _loadOrderSummariesForTransactions(merchantId, _transactions);
      
      // Cache the response (if network is slow)
      if (_networkQuality.isSlowConnection) {
        await _responseCache.cacheResponse(
          key: cacheKey,
          data: _transactions,
          cacheDuration: const Duration(minutes: 3), // Longer cache for transactions
        );
      }
      
      print('📝 Notifying listeners with ${_transactions.length} transactions');
      notifyListeners();
    } catch (e, stackTrace) {
      print('❌ Error loading transactions: $e');
      print('❌ Stack trace: $stackTrace');
      _transactions = [];
      _error = 'فشل تحميل المعاملات: $e';
      notifyListeners();
      // Don't rethrow - set empty list instead
    }
  }
  
  /// Appends the next page of transactions. Safe to call multiple times.
  Future<void> loadMoreTransactions(String merchantId) async {
    if (_isLoadingMore || !_hasMoreTransactions) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final response = await Supabase.instance.client
          .from('wallet_transactions')
          .select(
              'id, merchant_id, transaction_type, amount, balance_before, balance_after, order_id, payment_method, notes, created_at')
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false)
          .range(_transactions.length, _transactions.length + _pageSize - 1);

      final newItems = (response as List)
          .map((json) {
            if (json['merchant_id'] == null) json['merchant_id'] = merchantId;
            return WalletTransaction.fromJson(json);
          })
          .toList();

      _transactions = [..._transactions, ...newItems];
      _hasMoreTransactions = newItems.length >= _pageSize;
      await _loadOrderSummariesForTransactions(merchantId, newItems);
    } catch (_) {
      // Keep existing transactions; UI can offer retry
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Load fresh transactions and cache them (background operation)
  Future<void> _loadFreshTransactions(String merchantId, int limit, String cacheKey) async {
    try {
      final response = await Supabase.instance.client
          .from('wallet_transactions')
          .select('id, merchant_id, transaction_type, amount, balance_before, balance_after, order_id, payment_method, notes, created_at')
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false)
          .limit(limit);
      
      if (response.isEmpty) {
        _transactions = [];
        notifyListeners();
        return;
      }
      
      _transactions = (response as List)
          .map((json) {
            // Ensure merchant_id is set if missing
            if (json['merchant_id'] == null) {
              json['merchant_id'] = merchantId;
            }
            return WalletTransaction.fromJson(json);
          })
          .toList();

      await _loadOrderSummariesForTransactions(merchantId, _transactions);
      
      await _responseCache.cacheResponse(
        key: cacheKey,
        data: _transactions,
        cacheDuration: const Duration(minutes: 3),
      );
      
      notifyListeners();
    } catch (e) {
      // Silently fail - we already have cached data
      print('⚠️ Background transactions refresh failed: $e');
    }
  }

  Future<void> _loadOrderSummariesForTransactions(
    String merchantId,
    List<WalletTransaction> txs,
  ) async {
    final orderIds = txs
        .map((t) => t.orderId)
        .whereType<String>()
        .toSet()
        .difference(_orderSummaries.keys.toSet())
        .toList();

    if (orderIds.isEmpty) return;

    final response = await Supabase.instance.client
        .from('orders')
        .select(
            'id, merchant_id, status, customer_name, total_amount, delivery_fee, merchant_name')
        .inFilter('id', orderIds)
        .eq('merchant_id', merchantId);

    for (final row in (response as List<dynamic>)) {
      final map = row as Map<String, dynamic>;
      final id = map['id'] as String?;
      if (id == null) continue;
      _orderSummaries[id] = WalletOrderSummary.fromJson(map);
    }
  }
  
  // Top up wallet
  Future<bool> topUpWallet({
    required String merchantId,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await Supabase.instance.client.rpc(
        'add_wallet_balance',
        params: {
          'p_merchant_id': merchantId,
          'p_amount': amount,
          'p_payment_method': paymentMethod,
          'p_notes': notes,
        },
      );
      
      if (response != null && response['success'] == true) {
        // Reload wallet data
        await loadWalletData(merchantId);
        await loadTransactions(merchantId);
        return true;
      }
      
      return false;
    } catch (e) {
      _error = 'فشل شحن المحفظة: $e';
      print('Error topping up wallet: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Create Wayl payment link
  Future<Map<String, dynamic>?> createWaylPaymentLink({
    required String merchantId,
    required double amount,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('[WalletProvider] Creating Wayl payment link - merchantId: $merchantId, amount: $amount');
      
      final response = await Supabase.instance.client.functions.invoke(
        'wayl-payment',
        body: {
          'merchant_id': merchantId,
          'amount': amount,
          'notes': notes,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('[WalletProvider] Request timed out');
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      print('[WalletProvider] Response received');
      print('[WalletProvider] Response status: ${response.status}');
      print('[WalletProvider] Response data type: ${response.data.runtimeType}');
      print('[WalletProvider] Response data: ${response.data}');
      
      if (response.status == 200) {
        if (response.data != null) {
          final data = response.data as Map<String, dynamic>;
          print('[WalletProvider] Payment link created successfully');
          print('[WalletProvider] Payment URL: ${data['payment_url']}');
          return data;
        } else {
          print('[WalletProvider] Response status is 200 but data is null');
          _error = 'Received empty response from server';
          return null;
        }
      } else {
        // Handle error response (status 400, 500, etc.)
        final errorData = response.data is Map<String, dynamic> 
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        final errorMessage = errorData['error'] ?? 'فشل إنشاء رابط الدفع (Status: ${response.status})';
        _error = errorMessage;
        print('[WalletProvider] Error response: $errorMessage');
        print('[WalletProvider] Full error data: $errorData');
        return null;
      }
    } on TimeoutException catch (e) {
      _error = 'انتهت مهلة الطلب. يرجى المحاولة مرة أخرى';
      print('[WalletProvider] Timeout error: $e');
      return null;
    } catch (e, stackTrace) {
      _error = 'فشل إنشاء رابط الدفع: $e';
      print('[WalletProvider] Error creating Wayl payment link: $e');
      print('[WalletProvider] Error type: ${e.runtimeType}');
      print('[WalletProvider] Stack trace: $stackTrace');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
      print('[WalletProvider] Finally block executed - isLoading: $_isLoading');
    }
  }
  
  // Get wallet summary
  Future<Map<String, dynamic>?> getWalletSummary(String merchantId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_wallet_summary',
        params: {'p_merchant_id': merchantId},
      );
      
      return response as Map<String, dynamic>?;
    } catch (e) {
      print('Error getting wallet summary: $e');
      return null;
    }
  }
  
  // Refresh wallet data (invalidates cache)
  Future<void> refresh(String merchantId) async {
    // Invalidate cache to force fresh load
    await _responseCache.invalidatePattern('wallet_');
    await initialize(merchantId);
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

// Wallet Transaction Model
class WalletTransaction {
  final String id;
  final String merchantId;
  final String transactionType;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String? orderId;
  final String? paymentMethod;
  final String? notes;
  final DateTime createdAt;
  
  WalletTransaction({
    required this.id,
    required this.merchantId,
    required this.transactionType,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.orderId,
    this.paymentMethod,
    this.notes,
    required this.createdAt,
  });
  
  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'],
      merchantId: json['merchant_id'],
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
      case 'order_fee':
        return 'رسوم توصيل';
      case 'refund':
        return 'استرجاع';
      case 'adjustment':
        return 'تعديل';
      case 'initial_gift':
        return 'هدية ترحيبية';
      default:
        return 'معاملة';
    }
  }
  
  // Get icon based on transaction type
  IconData get icon {
    switch (transactionType) {
      case 'top_up':
        return Icons.add_circle;
      case 'order_fee':
        return Icons.shopping_bag;
      case 'refund':
        return Icons.replay;
      case 'adjustment':
        return Icons.tune;
      case 'initial_gift':
        return Icons.card_giftcard;
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
      case 'initial_gift':
        return 'هدية ترحيبية';
      case 'wayl':
        return 'Wayl';
      default:
        return paymentMethod ?? 'غير محدد';
    }
  }
}

class WalletOrderSummary {
  final String id;
  final String status;
  final String customerName;
  final double totalAmount;
  final double deliveryFee;
  final String? merchantName;

  WalletOrderSummary({
    required this.id,
    required this.status,
    required this.customerName,
    required this.totalAmount,
    required this.deliveryFee,
    required this.merchantName,
  });

  factory WalletOrderSummary.fromJson(Map<String, dynamic> json) {
    return WalletOrderSummary(
      id: json['id'] as String,
      status: (json['status'] as String?) ?? 'unknown',
      customerName: (json['customer_name'] as String?) ?? '',
      totalAmount: double.parse(json['total_amount']?.toString() ?? '0'),
      deliveryFee: double.parse(json['delivery_fee']?.toString() ?? '0'),
      merchantName: json['merchant_name'] as String?,
    );
  }
}
