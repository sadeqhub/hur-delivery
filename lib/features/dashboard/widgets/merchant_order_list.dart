import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/services/driver_availability_service.dart';
import '../../../core/widgets/header_notification.dart';
import '../../orders/widgets/merchant_order_card.dart';
import '../../../shared/widgets/skeletons.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/utils/logger.dart';
import '../data/dashboard_repository.dart';

Future<void> openSupportChat(BuildContext context) async {
  context.push('/merchant/support');
}

class MerchantOrdersTab extends StatefulWidget {
  const MerchantOrdersTab({super.key});

  @override
  State<MerchantOrdersTab> createState() => _MerchantOrdersTabState();
}

class _MerchantOrdersTabState extends State<MerchantOrdersTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: context.themeSurface,
            boxShadow: [
              BoxShadow(
                color: context.themeColor(
                  light: Colors.black.withOpacity(0.05),
                  dark: Colors.black.withOpacity(0.3),
                ),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: context.themePrimary,
            unselectedLabelColor: context.themeTextTertiary,
            indicatorColor: context.themePrimary,
            indicatorWeight: 3,
            labelStyle: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: AppTextStyles.bodyMedium,
            tabs: [
              Tab(text: AppLocalizations.of(context).activeOrders),
              Tab(text: AppLocalizations.of(context).completedOrders),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              MerchantActiveOrdersList(),
              MerchantCompletedOrdersList(),
            ],
          ),
        ),
      ],
    );
  }
}

class MerchantActiveOrdersList extends StatefulWidget {
  const MerchantActiveOrdersList({super.key});

  @override
  State<MerchantActiveOrdersList> createState() =>
      _MerchantActiveOrdersListState();
}

class _MerchantActiveOrdersListState extends State<MerchantActiveOrdersList> {
  Timer? _refreshTimer;
  OrderProvider? _orderProvider;

  @override
  void initState() {
    super.initState();

    // Refresh every 5 seconds to keep orders live and updated
    // Note: Real-time subscription handles instant updates, this is just a backup
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _orderProvider != null && !_orderProvider!.isLoading) {
        _orderProvider!.refreshOrders();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, _) {
        // Store reference to provider for timer callback
        _orderProvider = orderProvider;
        if (orderProvider.isLoading && orderProvider.orders.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OrderListSkeleton(count: 4),
          );
        }

        if (orderProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: context.ri(64), color: AppColors.error),
                SizedBox(height: context.rs(16)),
                ResponsiveText(
                  orderProvider.error!,
                  style: AppTextStyles.bodyLarge.responsive(context),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: context.rs(16)),
                ElevatedButton(
                  onPressed: () => orderProvider.refreshOrders(),
                  child: Text(AppLocalizations.of(context).retryAction),
                ),
              ],
            ),
          );
        }

        // Get all active orders (including rejected and those with ready countdown)
        final allActiveOrders = orderProvider.orders
            .where((order) =>
                order.status != 'delivered' && order.status != 'cancelled')
            .toList()
          ..sort((a, b) {
            if (a.readyAt != null && b.readyAt == null) return -1;
            if (a.readyAt == null && b.readyAt != null) return 1;
            if (a.readyAt != null && b.readyAt != null) {
              return a.readyAt!.compareTo(b.readyAt!);
            }
            return b.createdAt.compareTo(a.createdAt);
          });

        // Prevent duplication: Ensure each order appears only once
        final orderMap = <String, OrderModel>{};
        for (final order in allActiveOrders) {
          if (!orderMap.containsKey(order.id)) {
            orderMap[order.id] = order;
          } else {
            final existing = orderMap[order.id]!;
            final orderUpdatedAt = order.updatedAt;
            final existingUpdatedAt = existing.updatedAt;

            if (orderUpdatedAt != null && existingUpdatedAt != null) {
              if (orderUpdatedAt.isAfter(existingUpdatedAt)) {
                orderMap[order.id] = order;
              }
            } else if (orderUpdatedAt != null && existingUpdatedAt == null) {
              orderMap[order.id] = order;
            }
          }
        }

        // Convert back to list and sort
        final uniqueActiveOrders = orderMap.values.toList()
          ..sort((a, b) {
            if (a.readyAt != null && b.readyAt == null) return -1;
            if (a.readyAt == null && b.readyAt != null) return 1;
            if (a.readyAt != null && b.readyAt != null) {
              return a.readyAt!.compareTo(b.readyAt!);
            }
            return b.createdAt.compareTo(a.createdAt);
          });

        final activeOrders = uniqueActiveOrders;
        final totalItemsCount = activeOrders.length;

        if (totalItemsCount == 0) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: 0.15,
                    child: Container(
                      width: MediaQuery.sizeOf(context).width * 0.5,
                      height: MediaQuery.sizeOf(context).width * 0.5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/icons/icon.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withOpacity(0.1),
                            ),
                            child: Icon(
                              Icons.local_shipping_rounded,
                              size: MediaQuery.sizeOf(context).width * 0.3,
                              color: AppColors.primary.withOpacity(0.3),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Builder(
                    builder: (context) {
                      final loc = AppLocalizations.of(context);
                      return Text(
                        loc.noCurrentOrders,
                        style: AppTextStyles.heading3.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => orderProvider.refreshOrders(),
          child: ListView.builder(
            padding: ResponsiveHelper.getResponsivePadding(context,
                horizontal: 16, vertical: 16),
            itemCount: totalItemsCount,
            itemBuilder: (context, index) {
              final order = activeOrders[index];

              if (order.status == 'rejected') {
                return MerchantOrderCard(
                  key: ValueKey('${order.id}_${order.status}_rejected'),
                  order: order,
                  actionButtons: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _cancelOrder(order.id, orderProvider),
                            icon: const Icon(Icons.close, size: 18),
                            label: Text(AppLocalizations.of(context).cancel),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Consumer<WalletProvider>(
                            builder: (context, walletProvider, _) {
                              final canRepost = walletProvider.balance >
                                  walletProvider.creditLimit;
                              return ElevatedButton.icon(
                                onPressed: canRepost
                                    ? () => _repostOrder(
                                        order.id,
                                        order.deliveryFee,
                                        orderProvider)
                                    : null,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: Text(
                                    AppLocalizations.of(context).repostOrder),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canRepost
                                      ? Colors.orange.shade600
                                      : Colors.grey,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return MerchantOrderCard(
                key: ValueKey('${order.id}_${order.status}'),
                order: order,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _cancelOrder(
      String orderId, OrderProvider orderProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).cancelOrderTitle),
        content: Text(AppLocalizations.of(context).cancelOrderConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).goBack),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(AppLocalizations.of(context).cancelOrderAction),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success =
          await orderProvider.updateOrderStatus(orderId, 'cancelled');
      if (mounted) {
        showHeaderNotification(
          context,
          title: success ? 'تم الإلغاء' : 'خطأ',
          message: success ? 'تم إلغاء الطلب بنجاح' : 'فشل إلغاء الطلب',
          type: success ? NotificationType.success : NotificationType.error,
        );
      }
    }
  }

  // ignore: unused_element
  Future<int> _checkOnlineDrivers() async {
    try {
      final merchantId = Supabase.instance.client.auth.currentUser?.id;
      if (merchantId == null) return 0;

      final merchantCity =
          await DashboardRepository.instance.getMerchantCity(merchantId);
      if (merchantCity.isEmpty) return 0;

      final driverIds = await DashboardRepository.instance
          .getOnlineDriversInCity(merchantCity);

      if (driverIds.isEmpty) return 0;

      final busyDriverIds = (await DashboardRepository.instance
              .getActiveOrderDriverIds(driverIds))
          .toSet();

      final freeDriverCount =
          driverIds.where((id) => !busyDriverIds.contains(id)).length;

      return freeDriverCount;
    } catch (e) {
      Logger.d('Error checking online drivers: $e');
      return 0;
    }
  }

  Future<void> _repostOrder(
      String orderId, double currentFee, OrderProvider orderProvider) async {
    final loc = AppLocalizations.of(context);
    final walletProvider = context.read<WalletProvider>();
    if (walletProvider.balance <= walletProvider.creditLimit) {
      showHeaderNotification(
        context,
        title: 'رصيد غير كافٍ',
        message: 'يرجى شحن محفظتك أولاً لإعادة نشر الطلب',
        type: NotificationType.warning,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    final order = orderProvider.orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => throw Exception('Order not found'),
    );

    final merchantId = order.merchantId;

    final availabilityResult =
        await DriverAvailabilityService.checkFreeDriversOnly(
      merchantId: merchantId,
      vehicleType: order.vehicleType ?? 'motorbike',
    );

    if (!availabilityResult.available) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loc.noDriversAvailable,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            content: Text(
              availabilityResult.userMessage(context),
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(loc.ok),
              ),
            ],
          ),
        );
      }
      return;
    }

    final newFee = currentFee + 500;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.replay, color: AppColors.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loc.repostOrderTitle,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.repostOrderMessage,
              style: const TextStyle(fontSize: 15),
            ),
            SizedBox(height: context.rs(12)),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          loc.currentDeliveryFee,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${currentFee.toStringAsFixed(0)} ${loc.currencySymbol}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          loc.newDeliveryFee,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${newFee.toStringAsFixed(0)} ${loc.currencySymbol}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              loc.repostOrderHint,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: Text(loc.repostOrderTitle),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await orderProvider.repostOrder(orderId, newFee);
      if (mounted) {
        showHeaderNotification(
          context,
          title: success ? 'نجحت العملية' : 'خطأ',
          message: success
              ? 'تم إعادة نشر الطلب بنجاح'
              : 'فشل إعادة نشر الطلب',
          type: success ? NotificationType.success : NotificationType.error,
          duration: const Duration(seconds: 4),
        );
      }
    }
  }
}

class MerchantCompletedOrdersList extends StatefulWidget {
  const MerchantCompletedOrdersList({super.key});

  @override
  State<MerchantCompletedOrdersList> createState() =>
      _MerchantCompletedOrdersListState();
}

class _MerchantCompletedOrdersListState
    extends State<MerchantCompletedOrdersList> {
  Future<void> _cancelOrder(
      String orderId, OrderProvider orderProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).cancelOrderTitle),
        content: Text(AppLocalizations.of(context).cancelOrderConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).goBack),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(AppLocalizations.of(context).cancelOrderAction),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await orderProvider.cancelOrder(orderId);
    }
  }

  Future<void> _repostOrder(
      String orderId, double currentFee, OrderProvider orderProvider) async {
    final order = orderProvider.orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => throw Exception('Order not found'),
    );

    final merchantId = order.merchantId;

    final availabilityResult =
        await DriverAvailabilityService.checkFreeDriversOnly(
      merchantId: merchantId,
      vehicleType: order.vehicleType ?? 'motorbike',
    );

    if (!availabilityResult.available) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning, color: AppColors.warning),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context).noDriversAvailableTitle),
              ],
            ),
            content: Text(
              availabilityResult.userMessage(context),
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context).ok),
              ),
            ],
          ),
        );
      }
      return;
    }

    final newFee = currentFee + 500;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).repostOrderTitle),
        content: Text(AppLocalizations.of(context)
            .repostOrderNewFee(newFee.toStringAsFixed(0))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
            ),
            child: Text(AppLocalizations.of(context).repostButton),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await orderProvider.repostOrder(orderId, newFee);
      if (mounted) {
        showHeaderNotification(
          context,
          title: success ? 'نجحت العملية' : 'خطأ',
          message: success
              ? 'تم إعادة نشر الطلب بنجاح'
              : 'فشل إعادة نشر الطلب',
          type: success ? NotificationType.success : NotificationType.error,
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, _) {
        if (orderProvider.isLoading && orderProvider.orders.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OrderListSkeleton(count: 3),
          );
        }

        final completedOrders = orderProvider.orders
            .where((order) =>
                order.status == 'delivered' || order.status == 'cancelled')
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (completedOrders.isEmpty) {
          return EmptyState(
            icon: Icons.check_circle_outline,
            title: AppLocalizations.of(context).noPastOrders,
            subtitle: AppLocalizations.of(context).noOrdersInPeriod,
            accentColor: AppColors.statusCompleted,
          );
        }

        return RefreshIndicator(
          onRefresh: () => orderProvider.refreshOrders(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: completedOrders.length,
            itemBuilder: (context, index) {
              final order = completedOrders[index];

              if (order.status == 'rejected') {
                return MerchantOrderCard(
                  key: ValueKey(
                      '${order.id}_${order.status}_rejected_completed'),
                  order: order,
                  actionButtons: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _cancelOrder(order.id, orderProvider),
                            icon: const Icon(Icons.close, size: 18),
                            label: Text(AppLocalizations.of(context).cancel),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Consumer<WalletProvider>(
                            builder: (context, walletProvider, _) {
                              final canRepost = walletProvider.balance >
                                  walletProvider.creditLimit;
                              return ElevatedButton.icon(
                                onPressed: canRepost
                                    ? () => _repostOrder(
                                        order.id,
                                        order.deliveryFee,
                                        orderProvider)
                                    : null,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: Text(
                                    AppLocalizations.of(context).repostOrder),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canRepost
                                      ? Colors.orange.shade600
                                      : Colors.grey,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return MerchantOrderCard(
                key: ValueKey('${order.id}_${order.status}_completed'),
                order: order,
              );
            },
          ),
        );
      },
    );
  }
}
