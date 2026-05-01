import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/models/order_model.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';

class DriverOrdersScreen extends StatefulWidget {
  const DriverOrdersScreen({super.key});

  @override
  State<DriverOrdersScreen> createState() => _DriverOrdersScreenState();
}

class _DriverOrdersScreenState extends State<DriverOrdersScreen> {
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    // Don't call initialize() here - it causes instability
    // OrderProvider is already initialized and listening to real-time updates
    // Just use the existing data from the provider
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).myOrders),
        centerTitle: true,
        backgroundColor: context.themePrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<OrderProvider>().refreshOrders();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Builder(
                    builder: (context) {
                      final loc = AppLocalizations.of(context);
                      return Row(
                        children: [
                          _buildFilterChip('all', loc.all, Icons.list),
                          const SizedBox(width: 8),
                          _buildFilterChip('pending', loc.pending, Icons.pending),
                          const SizedBox(width: 8),
                          _buildFilterChip('accepted', loc.accepted, Icons.check_circle),
                          const SizedBox(width: 8),
                          _buildFilterChip('delivered', loc.completed, Icons.done_all),
                          const SizedBox(width: 8),
                          _buildFilterChip('cancelled', loc.cancelled, Icons.cancel),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Orders List
          Expanded(
            child: Consumer2<OrderProvider, AuthProvider>(
              builder: (context, orderProvider, authProvider, _) {
                if (orderProvider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (orderProvider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          orderProvider.error!,
                          style: AppTextStyles.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => orderProvider.refreshOrders(),
                          child: Text(AppLocalizations.of(context).retry),
                        ),
                      ],
                    ),
                  );
                }

                final driverId = authProvider.user?.id;
                if (driverId == null) {
                  return Center(
                    child: Text(
                      AppLocalizations.of(context).driverIdNotFound,
                      style: AppTextStyles.bodyLarge,
                    ),
                  );
                }

                final orders = _filterOrders(orderProvider.orders, _selectedFilter);

                if (orders.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: _getEmptyMessage(_selectedFilter),
                    subtitle: AppLocalizations.of(context).noOrdersYet,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _buildOrderCard(order, driverId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _selectedFilter == value;
    return Builder(
      builder: (context) {
        return FilterChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : context.themePrimary),
              const SizedBox(width: 4),
              Text(label),
            ],
          ),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _selectedFilter = value;
            });
          },
          backgroundColor: context.themeSurfaceVariant,
          selectedColor: context.themePrimary,
          labelStyle: AppTextStyles.bodySmall.copyWith(
            color: isSelected ? Colors.white : context.themePrimary,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(OrderModel order, String? driverId) {
    // Only show orders assigned to this driver
    if (driverId != null && order.driverId != driverId) {
      return const SizedBox.shrink();
    }
    
    final isAssignedToMe = order.driverId == driverId;
    final canAccept = order.status == 'pending' && !isAssignedToMe;
    final canComplete = order.status == 'accepted' && isAssignedToMe;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.themeColor(
              light: Colors.black.withOpacity(0.05),
              dark: Colors.black.withOpacity(0.3),
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(order.status).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getStatusIcon(order.status),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (context) {
                          final loc = AppLocalizations.of(context);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${loc.orderNumber}${order.userFriendlyCode ?? order.id.substring(0, 8)}',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: context.themeTextPrimary,
                                ),
                              ),
                              Text(
                                _getStatusText(order.status),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: _getStatusColor(order.status),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          loc.orderPrice,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: context.themeTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${order.totalAmount.toStringAsFixed(0)} ${loc.currencySymbol}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Order Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer Info
                    _buildInfoRow(
                      icon: Icons.person,
                      iconColor: AppColors.primary,
                      label: loc.customerLabelColon,
                      value: order.customerName.isNotEmpty 
                          ? order.customerName 
                          : loc.unknown,
                        ),
                    const SizedBox(height: 12),
                    // Pickup Location (Store Name)
                    _buildInfoRow(
                      icon: Icons.store,
                      iconColor: AppColors.success,
                      label: loc.pickupLocation,
                      value: (order.merchantName != null && order.merchantName!.isNotEmpty)
                          ? order.merchantName!
                          : (order.pickupAddress.isNotEmpty 
                              ? order.pickupAddress 
                              : loc.notAvailable),
                            ),
                    const SizedBox(height: 12),
                            // Delivery Location
                    _buildInfoRow(
                      icon: Icons.location_on,
                      iconColor: AppColors.error,
                      label: loc.deliveryLocation,
                      value: order.deliveryAddress.isNotEmpty 
                          ? order.deliveryAddress 
                          : loc.notAvailable,
                            ),
                    const SizedBox(height: 12),
                            // Order Time
                    _buildInfoRow(
                      icon: Icons.access_time,
                      iconColor: context.themeTextSecondary,
                      label: loc.orderTimeLabel('').split(':').first.trim(),
                      value: _formatDateTime(order.createdAt),
                            ),
                            if (order.notes != null && order.notes!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      loc.notesLabel,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: context.themeTextPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      order.notes!,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: context.themeTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                ),
              ),

          // Action Buttons
          if (canAccept || canComplete)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  if (canAccept) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _acceptOrder(order.id),
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(AppLocalizations.of(context).acceptOrder),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _rejectOrder(order.id),
                        icon: const Icon(Icons.close, size: 18),
                        label: Text(AppLocalizations.of(context).reject),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ] else if (canComplete) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _completeOrder(order.id),
                        icon: const Icon(Icons.done_all, size: 18),
                        label: Text(AppLocalizations.of(context).completeOrder),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.themeTextSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.themeTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<OrderModel> _filterOrders(List<OrderModel> orders, String filter) {
    final driverId = context.read<AuthProvider>().user?.id;
    if (driverId == null) return [];
    
    // Filter by driver first
    final driverOrders = orders.where((order) => order.driverId == driverId).toList();
    
    // Then filter by status
    switch (filter) {
      case 'pending':
        return driverOrders.where((order) => order.status == 'pending').toList();
      case 'accepted':
        return driverOrders.where((order) => order.status == 'accepted' || order.status == 'on_the_way').toList();
      case 'delivered':
        return driverOrders.where((order) => order.status == 'delivered').toList();
      case 'cancelled':
        return driverOrders.where((order) => order.status == 'cancelled').toList();
      default:
        return driverOrders;
    }
  }

  String _getEmptyMessage(String filter) {
    final loc = AppLocalizations.of(context);
    switch (filter) {
      case 'pending':
        return loc.noPendingOrders;
      case 'accepted':
        return loc.noAcceptedOrders;
      case 'delivered':
        return loc.noCompletedOrders;
      case 'cancelled':
        return loc.noCancelledOrders;
      default:
        return loc.noOrders;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'accepted':
      case 'on_the_way':
        return AppColors.primary;
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'accepted':
        return Icons.check_circle;
      case 'on_the_way':
        return Icons.directions_car;
      case 'delivered':
        return Icons.done_all;
      case 'cancelled':
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String status) {
    final loc = AppLocalizations.of(context);
    switch (status) {
      case 'pending':
        return loc.pending;
      case 'accepted':
        return loc.accepted;
      case 'on_the_way':
        return loc.inTransit;
      case 'delivered':
        return loc.delivered;
      case 'cancelled':
        return loc.cancelled;
      case 'rejected':
        return loc.rejected;
      default:
        return loc.unknown;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    // Convert from UTC to Baghdad time (GMT+3)
    final baghdadTime = dateTime.toUtc().add(const Duration(hours: 3));
    
    // Format date
    final dateFormatter = DateFormat('yyyy/MM/dd');
    final dateStr = dateFormatter.format(baghdadTime);
    
    // Format time in 12-hour format
    int hour = baghdadTime.hour;
    final minute = baghdadTime.minute.toString().padLeft(2, '0');
    final loc = AppLocalizations.of(context);
    String period = loc.amShort;
    
    if (hour >= 12) {
      period = loc.pmShort;
      if (hour > 12) {
        hour = hour - 12;
      }
    } else if (hour == 0) {
      hour = 12;
    }
    
    return '$dateStr $hour:$minute $period';
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      await context.read<OrderProvider>().updateOrderStatus(orderId, 'accepted');
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.orderAcceptedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.errorOccurred(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectOrder(String orderId) async {
    try {
      await context.read<OrderProvider>().updateOrderStatus(orderId, 'cancelled');
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.orderRejectedSuccess),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.errorOccurred(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _completeOrder(String orderId) async {
    try {
      await context.read<OrderProvider>().updateOrderStatus(orderId, 'completed');
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.orderCompletedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.errorOccurred(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
