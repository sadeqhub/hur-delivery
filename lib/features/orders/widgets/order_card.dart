import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../shared/models/order_model.dart';
import '../../../core/localization/app_localizations.dart';

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onTap;

  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final responsivePadding = ResponsiveHelper.getResponsiveCardPadding(context);
    final responsiveMargin = ResponsiveHelper.getResponsiveSpacing(context, 12);
    final loc = AppLocalizations.of(context);

    return Container(
      margin: EdgeInsets.only(bottom: responsiveMargin),
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.themeColor(
              light: Colors.black.withOpacity(0.04),
              dark: Colors.black.withOpacity(0.3),
            ),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap == null ? null : () {
            HapticFeedback.lightImpact();
            onTap!();
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: responsivePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Order ID & Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.themeColor(
                              light: AppColors.surfaceVariant,
                              dark: Colors.white.withOpacity(0.05),
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.local_mall_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '#${order.userFriendlyCode ?? order.id.substring(0, 6)}',
                          style: AppTextStyles.responsiveBodyMedium(context).copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: context.themeTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    _StatusBadge(status: order.status),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Addresses Timeline
                _buildTimeline(context, loc),
                
                const SizedBox(height: 20),
                
                // Customer Info Block
                _buildInfoTile(
                  context: context,
                  icon: Icons.person_outline_rounded,
                  title: order.customerName,
                  subtitle: order.customerPhone,
                  iconColor: AppColors.primary,
                ),
                
                // Driver Info Block
                if (order.driverId != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    context: context,
                    icon: Icons.two_wheeler_rounded,
                    title: order.driverName ?? loc.assignedStatus,
                    subtitle: order.driverPhone ?? '${loc.merchantLabel} ID: ${order.driverId!.substring(0, 8)}...',
                    iconColor: AppColors.success,
                  ),
                ],
                
                const SizedBox(height: 20),
                Divider(color: Theme.of(context).dividerColor.withOpacity(0.05), height: 1),
                const SizedBox(height: 16),
                
                // Footer
                Row(
                  children: [
                    // Items count pill
                    if (order.items.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.themeColor(
                            light: AppColors.surfaceVariant,
                            dark: Colors.white.withOpacity(0.05),
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shopping_bag_outlined,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${order.items.length}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    
                    // Time
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(order.createdAt, context),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    
                    const Spacer(),
                    
                    // Total amount
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primary, Color(0xFF2B5B84)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        '${order.grandTotal.toStringAsFixed(0)} ${loc.currencySymbol}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, AppLocalizations loc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline Graphics
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Container(
              width: 2,
              height: 32,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.location_on_rounded,
                  size: 14,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        // Timeline Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.from,
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.themeTextSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                order.pickupAddress,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.themeTextPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 18), // Spacing to match timeline line
              Text(
                loc.to,
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.themeTextSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                order.deliveryAddress,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.themeTextPrimary,
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

  Widget _buildInfoTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.themeColor(
          light: AppColors.surfaceVariant.withOpacity(0.4),
          dark: Colors.white.withOpacity(0.02),
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.04),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.themeTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.themeTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime, BuildContext context) {
    final loc = AppLocalizations.of(context);
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return loc.nowText;
    } else if (difference.inMinutes < 60) {
      final minChar = loc.isArabic ? 'د' : 'm';
      return '${difference.inMinutes}$minChar';
    } else if (difference.inHours < 24) {
      final hrChar = loc.isArabic ? 'س' : 'h';
      return '${difference.inHours}$hrChar';
    } else {
      final dayChar = loc.isArabic ? 'ي' : 'd';
      return '${difference.inDays}$dayChar';
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    Color backgroundColor;
    Color textColor;
    String text;

    switch (status) {
      case 'pending':
        backgroundColor = AppColors.statusPending.withOpacity(0.12);
        textColor = AppColors.statusPending;
        text = loc.statusPending;
        break;
      case 'assigned':
        backgroundColor = AppColors.statusAccepted.withOpacity(0.12);
        textColor = AppColors.statusAccepted;
        text = loc.statusAssigned;
        break;
      case 'accepted':
        backgroundColor = AppColors.statusAccepted.withOpacity(0.12);
        textColor = AppColors.statusAccepted;
        text = loc.statusAccepted;
        break;
      case 'on_the_way':
        backgroundColor = AppColors.statusInProgress.withOpacity(0.12);
        textColor = AppColors.statusInProgress;
        text = loc.statusOnTheWay;
        break;
      case 'delivered':
        backgroundColor = AppColors.statusCompleted.withOpacity(0.12);
        textColor = AppColors.statusCompleted;
        text = loc.statusDelivered;
        break;
      case 'cancelled':
        backgroundColor = AppColors.statusCancelled.withOpacity(0.12);
        textColor = AppColors.statusCancelled;
        text = loc.statusCancelled;
        break;
      case 'unassigned':
        backgroundColor = AppColors.warning.withOpacity(0.12);
        textColor = AppColors.warning;
        text = loc.statusUnassigned;
        break;
      case 'rejected':
        backgroundColor = AppColors.statusCancelled.withOpacity(0.12);
        textColor = AppColors.statusCancelled;
        text = loc.statusRejected;
        break;
      default:
        backgroundColor = AppColors.textTertiary.withOpacity(0.12);
        textColor = AppColors.textTertiary;
        text = loc.statusUnknown;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20), // Pill shape
      ),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
