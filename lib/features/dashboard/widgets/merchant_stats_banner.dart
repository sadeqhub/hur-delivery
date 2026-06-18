import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/icons/hur_icons.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/utils/logger.dart';

class MerchantAnalyticsBanner extends StatefulWidget {
  const MerchantAnalyticsBanner({super.key});

  @override
  State<MerchantAnalyticsBanner> createState() =>
      _MerchantAnalyticsBannerState();
}

class _MerchantAnalyticsBannerState extends State<MerchantAnalyticsBanner> {
  String _selectedTimePeriod = 'all'; // all, today, week, month
  String _selectedStatus = 'all'; // all, delivered, cancelled, rejected

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, _) {
        Logger.d('📊 Merchant Analytics - Building...');
        Logger.d('📦 Total orders: ${orderProvider.orders.length}');

        try {
          Logger.d('🔄 Starting time filter...');
          final filteredByTime =
              _filterOrdersByTimePeriod(orderProvider.orders);
          Logger.d('📅 After time filter: ${filteredByTime.length}');

          Logger.d('🔄 Starting status filter...');
          final filteredOrders = _selectedStatus == 'all'
              ? filteredByTime
              : filteredByTime
                  .where((o) => o.status == _selectedStatus)
                  .toList();
          Logger.d('🏷️  After status filter: ${filteredOrders.length}');

          Logger.d('🧮 Calculating statistics...');
          final stats = _calculateStatistics(filteredByTime);
          Logger.d('✅ Stats calculated: $stats');

          Logger.d('🎨 Building UI...');
          return Container(
            color: AppColors.surfaceVariant,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTimePeriodFilter(),
                  const SizedBox(height: 16),
                  _buildKeyMetricsSection(stats),
                  const SizedBox(height: 24),
                  _buildAverageDeliveryTimeCard(stats),
                  const SizedBox(height: 24),
                  Builder(
                    builder: (context) {
                      final loc = AppLocalizations.of(context);
                      return Text(
                        loc.ordersByStatus,
                        style: AppTextStyles.heading3,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildStatusFilter(),
                  const SizedBox(height: 16),
                  _buildStatusBreakdown(stats),
                  const SizedBox(height: 24),
                  _buildFinancialSummary(stats),
                  const SizedBox(height: 24),
                  Builder(
                    builder: (context) {
                      final loc = AppLocalizations.of(context);
                      return Text(
                        loc.recentOrders,
                        style: AppTextStyles.heading3,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  if (filteredOrders.isEmpty)
                    EmptyState(
                      hurIcon: HurIconKind.analytics,
                      title: AppLocalizations.of(context).noOrdersInPeriod,
                      accentColor: AppColors.primary,
                    )
                  else
                    ...filteredOrders
                        .take(5)
                        .map((order) => _buildRecentOrderItem(order)),
                ],
              ),
            ),
          );
        } catch (e, stackTrace) {
          Logger.d('❌ ERROR building merchant analytics UI: $e');
          Logger.d('📍 Stack trace: $stackTrace');
          return Container(
            color: AppColors.surfaceVariant,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: AppColors.error),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final loc = AppLocalizations.of(context);
                        return Text(
                          loc.errorLoadingStats,
                          style: AppTextStyles.heading3,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.toString(),
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }

  List<dynamic> _filterOrdersByTimePeriod(List orders) {
    final now = DateTime.now();

    switch (_selectedTimePeriod) {
      case 'today':
        final todayStart = DateTime(now.year, now.month, now.day);
        return orders.where((o) => o.createdAt.isAfter(todayStart)).toList();

      case 'week':
        final weekStart = now.subtract(const Duration(days: 7));
        return orders.where((o) => o.createdAt.isAfter(weekStart)).toList();

      case 'month':
        final monthStart = now.subtract(const Duration(days: 30));
        return orders.where((o) => o.createdAt.isAfter(monthStart)).toList();

      default:
        return orders;
    }
  }

  Map<String, dynamic> _calculateStatistics(List orders) {
    final totalOrders = orders.length;
    final deliveredOrders =
        orders.where((o) => o.isDelivered).toList();
    final cancelledOrders =
        orders.where((o) => o.isCancelled).toList();
    final rejectedOrders =
        orders.where((o) => o.isRejected).toList();
    final activeOrders = orders
        .where((o) => !o.isDelivered && !o.isCancelled)
        .toList();

    double avgDeliveryMinutes = 0;
    if (deliveredOrders.isNotEmpty) {
      double totalMinutes = 0;
      int validOrders = 0;

      for (var order in deliveredOrders) {
        if (order.deliveryTimerStartedAt != null &&
            order.deliveryTimerStoppedAt != null) {
          final duration = order.deliveryTimerStoppedAt!
              .difference(order.deliveryTimerStartedAt!);
          totalMinutes += duration.inMinutes.toDouble();
          validOrders++;
        }
      }

      if (validOrders > 0) {
        avgDeliveryMinutes = totalMinutes / validOrders;
      }
    }

    final totalRevenue =
        deliveredOrders.fold(0.0, (sum, order) => sum + order.grandTotal);
    final totalDeliveryFees =
        deliveredOrders.fold(0.0, (sum, order) => sum + order.deliveryFee);

    final successRate = totalOrders > 0
        ? (deliveredOrders.length / totalOrders * 100)
        : 0.0;

    return {
      'totalOrders': totalOrders,
      'deliveredOrders': deliveredOrders.length,
      'cancelledOrders': cancelledOrders.length,
      'rejectedOrders': rejectedOrders.length,
      'activeOrders': activeOrders.length,
      'avgDeliveryMinutes': avgDeliveryMinutes,
      'totalRevenue': totalRevenue,
      'totalDeliveryFees': totalDeliveryFees,
      'successRate': successRate,
    };
  }

  Widget _buildTimePeriodFilter() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildPeriodChip('all', 'الكل'),
          _buildPeriodChip('today', 'اليوم'),
          _buildPeriodChip('week', 'الأسبوع'),
          _buildPeriodChip('month', 'الشهر'),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String value, String label) {
    final isSelected = _selectedTimePeriod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTimePeriod = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatusChip('all', 'الكل', Icons.list),
          const SizedBox(width: 8),
          Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return Row(
                children: [
                  _buildStatusChip(
                      'delivered', loc.deliveredStatus, Icons.check_circle),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                      'cancelled', loc.cancelledStatus, Icons.cancel),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                      'rejected', loc.rejectedStatus, Icons.block),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String value, String label, IconData icon) {
    final isSelected = _selectedStatus == value;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        setState(() => _selectedStatus = value);
      },
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildKeyMetricsSection(Map<String, dynamic> stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return MerchantModernStatCard(
                    title: loc.totalOrders,
                    value: stats['totalOrders'].toString(),
                    icon: Icons.shopping_bag_outlined,
                    color: AppColors.primary,
                    trend: null,
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MerchantModernStatCard(
                title: 'طلبات نشطة',
                value: stats['activeOrders'].toString(),
                icon: Icons.pending_actions,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return MerchantModernStatCard(
                    title: loc.deliveredLabel,
                    value: stats['deliveredOrders'].toString(),
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
                    subtitle:
                        '${stats['successRate'].toStringAsFixed(1)}% معدل النجاح',
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return MerchantModernStatCard(
                    title: loc.cancelledRejectedLabel,
                    value:
                        '${stats['cancelledOrders'] + stats['rejectedOrders']}',
                    icon: Icons.cancel_outlined,
                    color: AppColors.error,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAverageDeliveryTimeCard(Map<String, dynamic> stats) {
    final avgMinutes = stats['avgDeliveryMinutes'] as double;
    final hours = avgMinutes ~/ 60;
    final minutes = (avgMinutes % 60).round();

    String timeDisplay;
    String timeUnit;

    if (avgMinutes == 0) {
      timeDisplay = '--';
      timeUnit = '';
    } else if (hours > 0) {
      timeDisplay = '$hours:${minutes.toString().padLeft(2, '0')}';
      timeUnit = 'ساعة';
    } else {
      timeDisplay = minutes.toString();
      timeUnit = 'دقيقة';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'متوسط وقت التوصيل',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'من إنشاء الطلب حتى التسليم',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  timeDisplay,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (timeUnit.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    timeUnit,
                    style: AppTextStyles.heading3.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (stats['deliveredOrders'] > 0) ...[
            const SizedBox(height: 12),
            Text(
              'بناءً على ${stats['deliveredOrders']} طلب مكتمل',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBreakdown(Map<String, dynamic> stats) {
    return Builder(
      builder: (context) {
        final loc = AppLocalizations.of(context);
        return Column(
          children: [
            _buildStatusRow(
              loc.deliveredLabel,
              stats['deliveredOrders'],
              stats['totalOrders'],
              AppColors.success,
              Icons.check_circle,
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
              loc.cancelledStatus,
              stats['cancelledOrders'],
              stats['totalOrders'],
              AppColors.error,
              Icons.cancel,
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
              loc.rejectedStatus,
              stats['rejectedOrders'],
              stats['totalOrders'],
              AppColors.warning,
              Icons.block,
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
              'نشطة',
              stats['activeOrders'],
              stats['totalOrders'],
              AppColors.primary,
              Icons.pending_actions,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusRow(
      String label, int count, int total, Color color, IconData icon) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$count طلب',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.themeTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerRight,
                  widthFactor: percentage / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.success,
            AppColors.success.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'الملخص المالي',
                style: AppTextStyles.heading3.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildFinancialRow(
            'إجمالي الإيرادات',
            '${stats['totalRevenue'].toStringAsFixed(0)} د.ع',
          ),
          const SizedBox(height: 12),
          _buildFinancialRow(
            'إجمالي رسوم التوصيل',
            '${stats['totalDeliveryFees'].toStringAsFixed(0)} د.ع',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white24, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'صافي الإيرادات',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(stats['totalRevenue'] - stats['totalDeliveryFees']).toStringAsFixed(0)} د.ع',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentOrderItem(dynamic order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(order.status).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getStatusColor(order.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getStatusIcon(order.status),
              color: _getStatusColor(order.status),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customerName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.themeTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getStatusText(order.status),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: _getStatusColor(order.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${order.grandTotal.toStringAsFixed(0)} د.ع',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
              Text(
                'المجموع الكلي (الطلب + التوصيل)',
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.themeTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
      case 'assigned':
        return AppColors.warning;
      case 'accepted':
      case 'on_the_way':
        return AppColors.primary;
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
      case 'rejected':
        return AppColors.error;
      case 'scheduled':
        return Colors.purple.shade600;
      default:
        return AppColors.textTertiary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
      case 'assigned':
        return Icons.pending;
      case 'accepted':
        return Icons.check_circle;
      case 'on_the_way':
        return Icons.delivery_dining;
      case 'delivered':
        return Icons.done_all;
      case 'cancelled':
      case 'rejected':
        return Icons.cancel;
      case 'scheduled':
        return Icons.schedule;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String status) {
    final loc = AppLocalizations.of(context);
    switch (status) {
      case 'pending':
        return loc.pendingStatus;
      case 'assigned':
        return loc.assignedStatus;
      case 'accepted':
        return loc.acceptedStatus;
      case 'on_the_way':
        return loc.onTheWayStatus;
      case 'delivered':
        return loc.deliveredStatus;
      case 'cancelled':
        return loc.cancelledStatus;
      case 'rejected':
        return loc.rejectedStatus;
      case 'scheduled':
        return loc.scheduledStatus;
      default:
        return loc.unknownStatus;
    }
  }
}

class MerchantStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const MerchantStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
                const Spacer(),
                Text(
                  value,
                  style: AppTextStyles.heading3.copyWith(
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.themeTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MerchantModernStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final String? trend;

  const MerchantModernStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const Spacer(),
              if (trend != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    trend!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: context.themeTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.themeTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                subtitle!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
