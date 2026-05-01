import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/driver_wallet_provider.dart';
import '../../../core/providers/city_settings_provider.dart';
import '../../../core/localization/app_localizations.dart';

class DriverRankScreen extends StatefulWidget {
  const DriverRankScreen({super.key});

  @override
  State<DriverRankScreen> createState() => _DriverRankScreenState();
}

class _DriverRankScreenState extends State<DriverRankScreen> {
  String? _currentRank;
  String? _driverCity;
  double _monthlyHours = 0.0;
  bool _isLoading = true;
  final Map<String, double> _commissionRates = {};
  CitySettingsProvider? _citySettingsProvider;

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      final driverId = context.read<AuthProvider>().user?.id;
      if (driverId != null) {
        context.read<DriverWalletProvider>().initialize(driverId);
      }
      
      // Listen to city settings changes
      final citySettingsProvider = context.read<CitySettingsProvider>();
      _citySettingsProvider = citySettingsProvider;
      _citySettingsProvider?.addListener(_onCitySettingsChanged);
      
      // Load rank data first to get driver's city
      await _loadRankData();
      
      // Then load commission rates for the driver's city
      // This will use the RPC function which drivers have access to
      await _loadCommissionRates();
    });
  }

  @override
  void dispose() {
    // Remove listener when screen is disposed
    _citySettingsProvider?.removeListener(_onCitySettingsChanged);
    super.dispose();
  }

  void _onCitySettingsChanged() {
    // Reload commission rates when city settings change
    if (mounted && _driverCity != null) {
      _loadCommissionRates();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload data when screen becomes visible again
    _loadRankData();
  }

  Future<void> _loadRankData() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final driverId = authProvider.user?.id;
      
      if (driverId == null) return;

      // Get current rank and city from user model (more reliable)
      final user = authProvider.user;
      if (user != null) {
        final city = user.city?.trim().toLowerCase();
        _driverCity = city; // Store city for commission rate reloading
        _currentRank = user.rank ?? 'bronze';
      } else {
        // Fallback to database query if user model not available
        final userResponse = await Supabase.instance.client
            .from('users')
            .select('rank, city')
            .eq('id', driverId)
            .maybeSingle();
        
        if (userResponse != null) {
          final city = (userResponse['city'] as String?)?.trim().toLowerCase();
          _driverCity = city; // Store city for commission rate reloading
          _currentRank = userResponse['rank'] as String? ?? 'bronze';
        }
      }

      // Get monthly hours
      final hoursResponse = await Supabase.instance.client.rpc(
        'get_driver_monthly_online_hours',
        params: {'p_driver_id': driverId},
      );
      _monthlyHours = (hoursResponse as num?)?.toDouble() ?? 0.0;

      // Reload commission rates if city is available
      if (_driverCity != null) {
        await _loadCommissionRates();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading rank data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCommissionRates() async {
    try {
      final authProvider = context.read<AuthProvider>();
      // Get driver's city directly from user model (more reliable than DB query)
      final driverCity = authProvider.user?.city?.trim().toLowerCase();
      _driverCity = driverCity; // Store city for listener
      
      if (driverCity == null || driverCity.isEmpty) {
        // No city, use defaults
        debugPrint('⚠️ Driver has no city set, using default commission rates');
        _setDefaultCommissionRates();
        return;
      }

      debugPrint('📍 Loading commission rates for driver city: $driverCity');

      // Load city settings
      final citySettingsProvider = context.read<CitySettingsProvider>();
      
      // Always use RPC function to load city settings (drivers don't have direct table access)
      // This bypasses RLS and allows drivers to read their city's settings
      CitySettings? settings = citySettingsProvider.getSettingsForCity(driverCity);
      
      if (settings == null) {
        debugPrint('📥 City settings not in cache, loading via RPC for: $driverCity');
        settings = await citySettingsProvider.loadSettingsForCity(driverCity);
      }
      
      if (settings != null) {
        debugPrint('✅ Loaded city settings for $driverCity');
        // Use commission rates from city settings
        final citySettings = settings; // Promote to non-nullable
        setState(() {
          _commissionRates['trial'] = citySettings.driverCommissionByRank['trial'] ?? 0.0;
          _commissionRates['bronze'] = citySettings.driverCommissionByRank['bronze'] ?? 10.0;
          _commissionRates['silver'] = citySettings.driverCommissionByRank['silver'] ?? 7.0;
          _commissionRates['gold'] = citySettings.driverCommissionByRank['gold'] ?? 5.0;
        });
        debugPrint('💰 Commission rates: trial=${_commissionRates['trial']}, bronze=${_commissionRates['bronze']}, silver=${_commissionRates['silver']}, gold=${_commissionRates['gold']}');
      } else {
        debugPrint('⚠️ City settings not found for $driverCity, using defaults');
        // Fallback to defaults if city settings not found
        _setDefaultCommissionRates();
      }
    } catch (e) {
      debugPrint('❌ Error loading commission rates: $e');
      _setDefaultCommissionRates();
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _setDefaultCommissionRates() {
    // Default commission percentages (fallback)
    setState(() {
      _commissionRates['trial'] = 0.0;
      _commissionRates['bronze'] = 10.0;
      _commissionRates['silver'] = 7.0;
      _commissionRates['gold'] = 5.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.driverRankTitle),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });
              // Reload rank data first to get driver's city
              await _loadRankData();
              // Then reload commission rates (will use RPC function)
              await _loadCommissionRates();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Current Rank Card
                  _buildCurrentRankCard(),
                  const SizedBox(height: 12),
                  _buildWalletBalanceCard(),
                  const SizedBox(height: 24),
                  
                  // Rank Benefits
                  _buildRankBenefits(),
                  const SizedBox(height: 24),
                  
                  // Progress to Next Rank
                  _buildProgressToNextRank(),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentRankCard() {
    final loc = AppLocalizations.of(context);
    Color rankColor;
    String rankName;
    IconData rankIcon;
    final rankCode = (_currentRank ?? 'bronze').toLowerCase();
    
    switch (rankCode) {
      case 'gold':
        rankColor = const Color(0xFFC5A059);
        rankName = loc.goldRank;
        rankIcon = Icons.star;
        break;
      case 'silver':
        rankColor = Colors.blueGrey;
        rankName = loc.silverRank;
        rankIcon = Icons.star_border;
        break;
      case 'bronze':
        rankColor = Colors.brown.shade400;
        rankName = loc.bronzeRank;
        rankIcon = Icons.star_outline;
        break;
      case 'trial':
        rankColor = Colors.green;
        rankName = loc.trialRank;
        rankIcon = Icons.verified_user;
        break;
      default:
        rankColor = Colors.brown.shade400;
        rankName = loc.bronzeRank;
        rankIcon = Icons.star_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            rankColor,
            rankColor.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: rankColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(rankIcon, size: 64, color: Colors.white),
          const SizedBox(height: 16),
          Text(
            loc.currentRank,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            rankName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Consumer2<CitySettingsProvider, AuthProvider>(
            builder: (context, citySettingsProvider, authProvider, _) {
              // Get driver's city from user model, normalized to lowercase
              final driverCity = authProvider.user?.city?.trim().toLowerCase();
              final commissionRate = citySettingsProvider.getDriverCommissionForRank(driverCity, rankCode);
              return Text(
                '${loc.commissionLabel}: ${commissionRate.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWalletBalanceCard() {
    final loc = AppLocalizations.of(context);
    return Consumer<DriverWalletProvider>(
      builder: (context, walletProvider, _) {
        if (!walletProvider.isEnabled) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.themeSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.themeBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.walletBalance,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.themeTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      walletProvider.isLoading ? '...' : walletProvider.formattedBalance,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.themeTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {
                  context.push('/driver/wallet');
                },
                child: Text(loc.details),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRankBenefits() {
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.rankBenefits,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: context.themeTextPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Consumer2<CitySettingsProvider, AuthProvider>(
          builder: (context, citySettingsProvider, authProvider, _) {
            // Get driver's city from user model, normalized to lowercase
            final driverCity = authProvider.user?.city?.trim().toLowerCase();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildRankBenefitCard(
                  'trial',
                  loc.trialRank,
                  Colors.green,
                  '${citySettingsProvider.getDriverCommissionForRank(driverCity, 'trial').toStringAsFixed(0)}% ${loc.commissionLabel}',
                  loc.trialRequirement,
                ),
                const SizedBox(height: 12),
                _buildRankBenefitCard(
                  'bronze',
                  loc.bronzeRank,
                  Colors.brown.shade400,
                  '${citySettingsProvider.getDriverCommissionForRank(driverCity, 'bronze').toStringAsFixed(0)}% ${loc.commissionLabel}',
                  loc.bronzeRequirement,
                ),
                const SizedBox(height: 12),
                _buildRankBenefitCard(
                  'silver',
                  loc.silverRank,
                  Colors.blueGrey,
                  '${citySettingsProvider.getDriverCommissionForRank(driverCity, 'silver').toStringAsFixed(0)}% ${loc.commissionLabel}',
                  loc.silverRequirement,
                ),
                const SizedBox(height: 12),
                _buildRankBenefitCard(
                  'gold',
                  loc.goldRank,
                  const Color(0xFFC5A059),
                  '${citySettingsProvider.getDriverCommissionForRank(driverCity, 'gold').toStringAsFixed(0)}% ${loc.commissionLabel}',
                  loc.goldRequirement,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildRankBenefitCard(
    String rankCode,
    String rankName,
    Color rankColor,
    String commission,
    String requirement,
  ) {
    final loc = AppLocalizations.of(context);
    final isCurrentRank = (_currentRank ?? 'bronze').toLowerCase() == rankCode;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentRank ? rankColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              rankCode == 'gold'
                  ? Icons.star
                  : rankCode == 'silver'
                      ? Icons.star_border
                      : Icons.star_outline,
              color: rankColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      rankName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.themeTextPrimary,
                      ),
                    ),
                    if (isCurrentRank) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: rankColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          loc.currentBadge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  commission,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.themeTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  requirement,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.themeTextTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressToNextRank() {
    final loc = AppLocalizations.of(context);
    String? nextRankName;
    double requiredHours = 0.0;
    double progress = 0.0;
    
    if (_currentRank == 'trial') {
      // Trial rank - show message about first month
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    loc.trialPeriodTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.themeTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              loc.trialPeriodMessage,
              style: TextStyle(
                fontSize: 14,
                color: context.themeTextSecondary,
              ),
            ),
          ],
        ),
      );
    } else if (_currentRank == 'bronze') {
      nextRankName = loc.silverRank;
      requiredHours = 250.0;
      progress = (_monthlyHours / requiredHours).clamp(0.0, 1.0);
    } else if (_currentRank == 'silver') {
      nextRankName = loc.goldRank;
      requiredHours = 300.0;
      progress = ((_monthlyHours - 250.0) / (requiredHours - 250.0)).clamp(0.0, 1.0);
    } else {
      // Already at gold
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber),
        ),
        child: Row(
          children: [
            const Icon(Icons.celebration, color: Colors.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                loc.topRankTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.themeTextPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.progressToRank(nextRankName),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.themeTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.hoursValue(_monthlyHours.toStringAsFixed(1)),
                style: TextStyle(
                  fontSize: 14,
                  color: context.themeTextSecondary,
                ),
              ),
              Text(
                loc.hoursRequired(requiredHours.toStringAsFixed(0)),
                style: TextStyle(
                  fontSize: 14,
                  color: context.themeTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade300,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.shade700,
                  Colors.amber.shade600,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.access_time_filled, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    loc.activeHoursNotice,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            loc.progressCompleted((progress * 100).toStringAsFixed(0)),
            style: TextStyle(
              fontSize: 12,
              color: context.themeTextTertiary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loc.ranksApplyMonthly,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.themeTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

