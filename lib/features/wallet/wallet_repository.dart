import 'dart:async';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/logging/logger.dart';
import '../../../core/network/api_client.dart';

/// Data layer for merchant and driver wallet operations.
///
/// Replaces direct `Supabase.instance.client` calls from [WalletProvider]
/// and [DriverWalletProvider].
///
/// Pattern: WalletProvider → WalletRepository → ApiClient → Supabase
class WalletRepository {
  WalletRepository({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;
  static const String _tag = 'WalletRepository';

  // ─── Merchant wallet ───────────────────────────────────────────────────────

  /// Returns the merchant wallet row for the authenticated user.
  Future<Map<String, dynamic>?> getMerchantWallet(String merchantId) async {
    Logger.d(_tag, 'getMerchantWallet: ${Logger.redactId(merchantId)}');
    try {
      return await _client
          .from('merchant_wallets')
          .select()
          .eq('merchant_id', merchantId)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));
    } catch (e, st) {
      Logger.e(_tag, 'getMerchantWallet failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  /// Returns the latest N wallet transactions for a merchant.
  Future<List<Map<String, dynamic>>> getMerchantTransactions(
    String merchantId, {
    int limit = 50,
    int offset = 0,
  }) async {
    Logger.d(_tag, 'getMerchantTransactions: ${Logger.redactId(merchantId)} limit=$limit offset=$offset');
    try {
      final rows = await _client
          .from('wallet_transactions')
          .select()
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1)
          .timeout(const Duration(seconds: 15));
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e, st) {
      Logger.e(_tag, 'getMerchantTransactions failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  // ─── Driver wallet ─────────────────────────────────────────────────────────

  /// Returns the driver wallet / earnings data for the authenticated driver.
  Future<Map<String, dynamic>?> getDriverEarnings(String driverId) async {
    Logger.d(_tag, 'getDriverEarnings: ${Logger.redactId(driverId)}');
    try {
      return await _client
          .from('driver_earnings')
          .select()
          .eq('driver_id', driverId)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));
    } catch (e, st) {
      Logger.e(_tag, 'getDriverEarnings failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  /// Returns the latest N earnings transactions for a driver.
  Future<List<Map<String, dynamic>>> getDriverTransactions(
    String driverId, {
    int limit = 50,
    int offset = 0,
  }) async {
    Logger.d(_tag, 'getDriverTransactions: ${Logger.redactId(driverId)} limit=$limit offset=$offset');
    try {
      final rows = await _client
          .from('driver_transactions')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1)
          .timeout(const Duration(seconds: 15));
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e, st) {
      Logger.e(_tag, 'getDriverTransactions failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  // ─── Withdrawal ────────────────────────────────────────────────────────────

  /// Submits a withdrawal request via the edge function.
  ///
  /// [isDemoMode] — if true, blocks the request and throws [AppFailure.unauthorized].
  Future<Map<String, dynamic>> requestWithdrawal({
    required String userId,
    required double amount,
    required String role, // 'merchant' | 'driver'
    bool isDemoMode = false,
  }) async {
    if (isDemoMode) {
      Logger.d(_tag, 'requestWithdrawal blocked in demo mode');
      throw const AppFailure.unauthorized();
    }
    Logger.i(_tag, 'requestWithdrawal: role=$role amount=$amount');
    try {
      return await _client.invoke(
        'process-withdrawal',
        body: {
          'user_id': userId,
          'amount': amount,
          'role': role,
        },
      );
    } on AppFailure {
      rethrow;
    } catch (e, st) {
      Logger.e(_tag, 'requestWithdrawal failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  // ─── City / fee settings ──────────────────────────────────────────────────

  /// Returns the current city settings (delivery fee caps, percentages, etc.).
  Future<Map<String, dynamic>?> getCitySettings() async {
    Logger.d(_tag, 'getCitySettings');
    try {
      return await _client
          .from('city_settings')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));
    } catch (e, st) {
      Logger.e(_tag, 'getCitySettings failed', error: e, stack: st);
      throw ErrorMapper.map(e);
    }
  }

  // ─── Realtime ─────────────────────────────────────────────────────────────

  /// Returns a realtime stream of merchant wallet changes.
  Stream<List<Map<String, dynamic>>> merchantWalletStream(String merchantId) =>
      _client
          .from('merchant_wallets')
          .stream(primaryKey: ['id'])
          .eq('merchant_id', merchantId);

  /// Returns a realtime stream of wallet transaction changes for a merchant.
  Stream<List<Map<String, dynamic>>> merchantTransactionStream(String merchantId) =>
      _client
          .from('wallet_transactions')
          .stream(primaryKey: ['id'])
          .eq('merchant_id', merchantId)
          .order('created_at')
          .limit(50);

  /// Returns a realtime stream of driver earning changes.
  Stream<List<Map<String, dynamic>>> driverEarningsStream(String driverId) =>
      _client
          .from('driver_earnings')
          .stream(primaryKey: ['driver_id'])
          .eq('driver_id', driverId);
}
