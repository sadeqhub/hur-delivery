import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/driver_location_service.dart';
import '../data/driver_repository.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/logger.dart';

class SimpleLocationUpdateWidget extends StatefulWidget {
  final String driverId;
  final Function(String orderId, double lat, double lng) onLocationUpdate;
  final VoidCallback? onRouteRebuildNeeded;

  const SimpleLocationUpdateWidget({
    super.key,
    required this.driverId,
    required this.onLocationUpdate,
    this.onRouteRebuildNeeded,
  });

  @override
  State<SimpleLocationUpdateWidget> createState() => _SimpleLocationUpdateWidgetState();
}

class _SimpleLocationUpdateWidgetState extends State<SimpleLocationUpdateWidget> {
  RealtimeChannel? _locationUpdateChannel;
  final Set<String> _notifiedOrders = {};

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  Future<void> _acknowledgeUpdates(List<CustomerLocationUpdate> updates) async {
    for (final update in updates) {
      try {
        await DriverLocationService.markDriverNotified(update.orderId);
        
        Logger.d('📍 Location update acknowledged for order ${update.orderId}');
        Logger.d('   New coordinates: (${update.deliveryLatitude}, ${update.deliveryLongitude})');
        
        // Notify parent widget - this will trigger map recalculation
        widget.onLocationUpdate(update.orderId, update.deliveryLatitude, update.deliveryLongitude);
        
        // Trigger route rebuild to ensure map updates immediately
        if (widget.onRouteRebuildNeeded != null) {
          Logger.d('🔄 Triggering route rebuild from popup acknowledgment');
          widget.onRouteRebuildNeeded!();
        }
      } catch (e) {
        Logger.d('❌ Error acknowledging location update: $e');
      }
    }
  }

  Widget _buildUpdateCard(CustomerLocationUpdate update) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: context.themeSurface,
      elevation: isDark ? 4 : 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer name removed per request
            if (update.merchantName.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.store, size: 16, color: context.themeTextSecondary),
                  const SizedBox(width: 4),
                  Text(
                    update.merchantName,
                    style: TextStyle(color: context.themeTextPrimary),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.success.withOpacity(isDark ? 0.4 : 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.celebration,
                    size: 16,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).locationReadyNoCallNeeded,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.success.withOpacity(0.9) : AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  @override
  void dispose() {
    _locationUpdateChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This widget is invisible - it only handles background polling
    return const SizedBox.shrink();
  }

  void _startPolling() {
    Logger.d('🔄 Starting realtime customer location update listener...');

    // Initial check catches updates that arrived before the subscription opened.
    _checkForLocationUpdates();

    _locationUpdateChannel = Supabase.instance.client
        .channel('driver_${widget.driverId}_order_location_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: widget.driverId,
          ),
          callback: (payload) {
            if (!mounted) return;
            final record = payload.newRecord;

            final locationProvided =
                record['customer_location_provided'] as bool? ?? false;
            final alreadyNotified =
                record['driver_notified_location'] as bool? ?? true;
            if (!locationProvided || alreadyNotified) return;

            final orderId = record['id'] as String?;
            final lat = (record['delivery_latitude'] as num?)?.toDouble();
            final lng = (record['delivery_longitude'] as num?)?.toDouble();
            final customerName = record['customer_name'] as String?;
            final address = record['delivery_address'] as String?;

            if (orderId != null &&
                lat != null &&
                lng != null &&
                !_notifiedOrders.contains(orderId)) {
              Logger.d(
                  '📍 Realtime: location update for order $orderId: $lat, $lng');
              _notifiedOrders.add(orderId);
              _showLocationUpdatePopup(orderId, lat, lng, customerName, address);
              widget.onLocationUpdate(orderId, lat, lng);
            }
          },
        )
        .subscribe();
  }

  Future<void> _checkForLocationUpdates() async {
    try {
      Logger.d('🔍 Checking for customer location updates...');
      
      // Query orders table directly for this driver's active orders
      // Only check orders where customer actually provided location (not auto-updated)
      // AND driver hasn't been notified yet
      final response = await DriverRepository.instance.getActiveOrdersWithPendingLocation(widget.driverId);

      if (response.isNotEmpty) {
        Logger.d('📍 Found ${response.length} orders with customer location updates');
        
        for (final order in response) {
          final orderId = order['id'] as String;
          final lat = order['delivery_latitude'] as double?;
          final lng = order['delivery_longitude'] as double?;
          final customerName = order['customer_name'] as String?;
          final address = order['delivery_address'] as String?;
          
          // Only notify if we haven't already notified for this order
          if (!_notifiedOrders.contains(orderId) && lat != null && lng != null) {
            Logger.d('📍 New location update for order $orderId: $lat, $lng');
            _notifiedOrders.add(orderId);
            
            // Show popup immediately
            _showLocationUpdatePopup(orderId, lat, lng, customerName, address);
            
            // Notify parent widget
            widget.onLocationUpdate(orderId, lat, lng);
          }
        }
      } else {
        Logger.d('📍 No location updates found');
      }
    } catch (e) {
      Logger.d('❌ Error checking for location updates: $e');
    }
  }

  void _showLocationUpdatePopup(String orderId, double lat, double lng, String? customerName, String? address) {
    if (!mounted) return;
    
    Logger.d('📍 Showing location update popup for order $orderId');
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 450,
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            decoration: BoxDecoration(
              color: context.themeSurface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Banner image - clean, no overlay text
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    child: Image.asset(
                      'assets/images/banner3.png',
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          height: 180,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withOpacity(0.7),
                              ],
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.location_on,
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // Content section
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Title with icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: AppColors.success,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'موقع العميل جاهز! 🎉',
                                style: TextStyle(
                                  color: context.themeTextPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Customer info card removed per request
                        
                        // Success message
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(isDark ? 0.15 : 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.success.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: AppColors.success,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'يمكنك التوجه مباشرة للعنوان المحدث',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark 
                                        ? AppColors.success.withOpacity(0.95)
                                        : AppColors.success.withOpacity(0.9),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Action button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // Close dialog first
                          Navigator.of(dialogContext).pop();
                          
                          // Acknowledge the update and trigger route rebuild
                          await _acknowledgeUpdates([
                            CustomerLocationUpdate(
                              orderId: orderId,
                              customerName: customerName ?? 'العميل',
                              customerPhone: '',
                              deliveryAddress: address ?? 'العنوان محدث',
                              deliveryLatitude: lat,
                              deliveryLongitude: lng,
                              merchantName: '',
                              status: '',
                              createdAt: '',
                              updatedAt: '',
                            )
                          ]);
                          
                          // Show confirmation that map is updating
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.route, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'جاري تحديث المسار للموقع الجديد...',
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: AppColors.success,
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle, size: 22),
                        label: const Text(
                          'تم الاطلاع',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
