import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ChangeNotifierProvider, Provider;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/foundation.dart'
    show unawaited, kReleaseMode, debugPrint;
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/utils/map_style_helper.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../widgets/state_of_the_art_map_widget.dart';
import '../../../core/providers/location_provider.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/models/order_status.dart';
import '../../../core/widgets/header_notification.dart';
import '../../../core/services/order_redirect_service.dart';
import '../../../core/riverpod/app_providers.dart';
import '../../../shared/widgets/maintenance_mode_dialog.dart';
import '../widgets/state_of_the_art_navigation.dart';
// Removed legacy map/annotation systems
import '../../driver/widgets/simple_location_update_widget.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/services/audio_notification_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/navigation_overlay_system.dart';
import '../../../shared/widgets/navigation_bar_aware_footer_wrapper.dart';
import '../../../shared/widgets/delivery_timer_widget.dart';
import '../../../core/services/screen_visibility_tracker.dart';
import '../providers/driver_status_provider.dart';
import '../providers/active_order_provider.dart';
import '../providers/driver_dashboard_controller.dart';
import '../services/driver_location_manager.dart';
import '../widgets/driver_map_section.dart';
import '../widgets/driver_bottom_nav.dart';
import '../widgets/driver_header_buttons.dart';
import '../widgets/driver_sidebar.dart';
import '../widgets/driver_timer_banner.dart';
import '../widgets/driver_order_swipe_cards.dart';
import '../widgets/order_proof_uploader.dart';

// ---------------------------------------------------------------------------
// Public entry point — provides dashboard-scoped providers then renders the
// implementation widget.  Keeping providers here (not main.dart) means they
// are created and disposed with the dashboard route, not the whole app.
// ---------------------------------------------------------------------------

/// Thin entry point.  Provides all dashboard-scoped providers and delegates to
/// [_DriverDashboardCore] which contains the full implementation.
class DriverDashboard extends StatelessWidget {
  const DriverDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.read<OrderProvider>();
    final driverId = context.read<AuthProvider>().user?.id ?? '';

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DriverStatusProvider()),
        ChangeNotifierProvider(
          create: (_) => ActiveOrderProvider(
            orderProvider: orderProvider,
            driverId: driverId,
          ),
        ),
        Provider(create: (_) => DriverLocationManager()),
        ChangeNotifierProvider(create: (_) => DriverDashboardController()),
      ],
      child: const _DriverDashboardCore(),
    );
  }
}

// Wrapper classes to handle both regular orders and bulk orders
abstract class _OrderItem {
  String get id;
  String get status;
  bool get isPending => OrderStatus.fromDb(status) == OrderStatus.pending;
}

class _RegularOrderItem extends _OrderItem {
  final OrderModel order;
  _RegularOrderItem(this.order);

  @override
  String get id => order.id;

  @override
  String get status => order.status;
}

class _DriverDashboardCore extends ConsumerStatefulWidget {
  const _DriverDashboardCore();

  @override
  ConsumerState<_DriverDashboardCore> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends ConsumerState<_DriverDashboardCore>
    with WidgetsBindingObserver, ScreenVisibilityMixin {
  @override
  String get screenName => 'driver_dashboard';

  // _isOnline is now derived from DriverStatusProvider (single source of truth).
  // It is kept as a cached local copy so that existing methods/animation code
  // can read it synchronously without going through BuildContext.
  bool _isOnline = false;

  bool _showSidebar = false;
  Timer? _mapGestureDebounce; // Debounces post-pan gesture-state reset
  bool _hasLocationAlwaysPermission = false;

  // Order cards swipe functionality
  PageController? _orderCardsPageController;
  int _currentOrderIndex = 0;
  String? _lastOrderListHash; // To detect order list changes

  // Enhanced route management (removed legacy managers)
  List<OrderModel>? _cachedActiveOrders; // Cache orders to prevent flickering
  bool _isOrderCardExpanded = true; // Track if order card is expanded
  ActiveOrderProvider? _activeOrderProviderRef; // For listener disposal
  VoidCallback? _activeOrderListener;

  // Navigation buttons state
  bool _showNavigationButtons = false;
  double? _targetLatitude;
  double? _targetLongitude;
  GlobalKey<StateOfTheArtMapWidgetState>? _mapWidgetKey;

  final double _bottomOverlayInset = 0;
  String? _expandedAddressCardId;

  // Geocoding cache to prevent excessive API calls
  final Map<String, String?> _geocodedAddresses = {};

  // ── Provider accessors ────────────────────────────────────────────────────
  DriverStatusProvider get _statusProvider =>
      context.read<DriverStatusProvider>();
  DriverLocationManager get _locationManager =>
      context.read<DriverLocationManager>();

  // NOTE: Footer height tracking is now handled by NavigationOverlaySystem
  // _bottomOverlayInset is updated via Consumer/Listener in the MapWidget or here if needed.

  void _refreshMapRoute([OrderModel? order]) {
    final mapState = _mapWidgetKey?.currentState;
    if (mapState != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mapState.forceRefreshActiveOrder(order);
      });
    }
  }

  /// Reacts to ActiveOrderProvider changes outside of build:
  ///   • plays the new-order chime when an unseen order id appears,
  ///   • keeps [_currentOrderIndex] aligned with the provider's currentIndex,
  ///   • refreshes [_cachedActiveOrders] for the next diff.
  ///
  /// Must run as a listener (not inside a Selector builder) to avoid the
  /// rebuild storm caused by scheduling setState from build.
  void _attachActiveOrderListener() {
    final ap = context.read<ActiveOrderProvider>();
    _activeOrderProviderRef = ap;
    _cachedActiveOrders = ap.orders;
    if (ap.currentIndex != _currentOrderIndex) {
      _currentOrderIndex = ap.currentIndex;
    }

    _activeOrderListener = () {
      if (!mounted) return;
      final orders = ap.orders;

      if (_cachedActiveOrders != null && orders.isNotEmpty) {
        final prevIds = _cachedActiveOrders!.map((o) => o.id).toSet();
        final hasNew = orders.any((o) => !prevIds.contains(o.id));
        if (hasNew) {
          AudioNotificationService.playNewOrderNotification();
        }
      }
      _cachedActiveOrders = orders;

      if (ap.currentIndex != _currentOrderIndex) {
        setState(() => _currentOrderIndex = ap.currentIndex);
      }
    };
    ap.addListener(_activeOrderListener!);
  }

  /// Rebuild annotations for a specific order after swipe
  void _rebuildAnnotationsForOrder(OrderModel order) {
    // Force refresh map route which will rebuild all annotations without destroying the geocoding cache
    _refreshMapRoute(order);

    print('🔄 Rebuilding annotations for order ${order.id} after swipe');
  }

  // Bulk order methods removed - bulk orders are no longer supported

  /// Get geocoded address with caching to prevent excessive API calls
  /// This solves the issue of making thousands of geocoding requests per hour
  Future<String?> _getGeocodedAddress(
    String orderId,
    double latitude,
    double longitude,
    bool isPickup,
  ) async {
    final key = '${orderId}_${isPickup ? 'pickup' : 'delivery'}';

    // Return cached address if available
    if (_geocodedAddresses.containsKey(key)) {
      return _geocodedAddresses[key];
    }

    // Fetch and cache the address
    final address = await GeocodingService.reverseGeocode(latitude, longitude);
    if (mounted) {
      _geocodedAddresses[key] = address;
    }
    return address;
  }

  Future<void> _openSupportChat() async {
    if (!mounted) return;

    // Get active order ID if available
    final orderProvider = context.read<OrderProvider>();
    final authProvider = context.read<AuthProvider>();
    final activeOrderId = _getFocusedOrderId(orderProvider, authProvider);

    // Navigate to support chat with order ID if available
    if (activeOrderId != null) {
      context.push('/driver/messages?orderId=$activeOrderId');
    } else {
      context.push('/driver/messages');
    }
  }

  String? _getFocusedOrderId(
      OrderProvider orderProvider, AuthProvider authProvider) {
    final driverId = authProvider.user?.id;
    if (driverId == null) return null;
    final activeOrders = orderProvider.getAllActiveOrdersForDriver(driverId);
    if (activeOrders.isEmpty) {
      return null;
    }
    var index = _currentOrderIndex;
    if (index < 0) index = 0;
    if (index >= activeOrders.length) {
      index = activeOrders.length - 1;
    }
    final order = activeOrders[index];
    return order.id;
  }

  Widget _buildOnlineToggleButton() {
    const toggleWidth = 100.0; // Increased for better text visibility
    const toggleHeight = 42.0; // Taller for better aesthetics

    const horizontalPadding = 4.0;
    const verticalPadding = 4.0;
    const innerWidth = toggleWidth - (horizontalPadding * 2);
    const innerHeight = toggleHeight - (verticalPadding * 2);
    const knobSize = innerHeight;
    const highlightWidth = innerWidth / 2;

    final loc = AppLocalizations.of(context);

    return Container(
      constraints: const BoxConstraints(
        minWidth: toggleWidth,
        maxWidth: toggleWidth,
        minHeight: toggleHeight,
        maxHeight: toggleHeight,
      ),
      width: toggleWidth,
      height: toggleHeight,
      child: GestureDetector(
        onTap: () async {
          final systemStatus = ref.read(systemStatusProvider);
          final authProvider = context.read<AuthProvider>();

          // Restrict going online in demo mode
          if (authProvider.isDemoMode) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('لا يمكن تفعيل وضع الاتصال في وضع التجربة'),
                backgroundColor: AppColors.error,
              ),
            );
            return;
          }

          // Delegate to DriverStatusProvider — it handles the DB write,
          // location manager start/stop, and notification setup.
          final newStatus = !_statusProvider.isOnline;

          if (newStatus && !systemStatus.isSystemEnabled) {
            MaintenanceModeDialog.show(context, 'driver');
            return;
          }

          if (!newStatus) {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) {
                return AlertDialog(
                  title: Text(loc.confirmGoOfflineTitle),
                  content: Text(loc.confirmGoOfflineMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(loc.cancel),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(loc.confirm),
                    ),
                  ],
                );
              },
            );

            if (confirm != true) {
              return;
            }
          }

          if (newStatus) {
            final ok = await _showBackgroundLocationDisclosureAndRequest();
            if (!ok) return;
          }

          try {
            await _statusProvider.setOnline(
              newStatus,
              authProvider: authProvider,
              notificationProvider: ref.read(notificationProvider.notifier),
            );
            // _isOnline is synced by onWentOnline/onWentOffline callbacks.
          } catch (e) {
            final message = e.toString();
            final loc = AppLocalizations.of(context);
            if (message.contains('DRIVER_WALLET_NEGATIVE')) {
              if (mounted) {
                showHeaderNotification(
                  context,
                  title: loc.error,
                  message:
                      'رصيد محفظتك بالسالب. يرجى شحن المحفظة أولاً لتسديد العمولة.',
                  type: NotificationType.error,
                );
                context.push('/driver/wallet');
              }
              return;
            }
            if (message.contains('SYSTEM_DISABLED') ||
                message.contains(loc.maintenanceMode)) {
              if (mounted) MaintenanceModeDialog.show(context, 'driver');
            } else {
              print('❌ Error toggling online status: $e');
              // Show a generic error so the driver knows it failed.
              if (mounted) {
                showHeaderNotification(
                  context,
                  title: loc.error,
                  message:
                      message.contains('permission') || message.contains('RLS')
                          ? 'لا يمكن تغيير الحالة. تحقق من الاتصال بالإنترنت.'
                          : 'فشل تحديث الحالة. حاول مجدداً.',
                  type: NotificationType.error,
                );
              }
            }
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(toggleHeight / 2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubicEmphasized,
            width: toggleWidth,
            height: toggleHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isOnline
                    ? [const Color(0xFF4CAF50), const Color(0xFF388E3C)]
                    : [const Color(0xFF78909C), const Color(0xFF546E7A)],
              ),
              borderRadius: BorderRadius.circular(toggleHeight / 2),
              boxShadow: [
                BoxShadow(
                  color: (_isOnline
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF78909C))
                      .withValues(alpha: 0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: SizedBox.expand(
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      left: _isOnline ? innerWidth - highlightWidth : 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: highlightWidth,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(toggleHeight / 2),
                        ),
                      ),
                    ),
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      alignment: _isOnline
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Builder(
                          builder: (context) {
                            final loc = AppLocalizations.of(context);
                            return Text(
                              _isOnline ? loc.connected : loc.notAvailable,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black38,
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      left: _isOnline ? innerWidth - knobSize : 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: knobSize,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.power_settings_new_rounded,
                            color: _isOnline
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFEF5350),
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        OrderRedirectService.stopMonitoring();

        _attachActiveOrderListener();

        // Wire DriverStatusProvider → DriverLocationManager so going
        // online/offline automatically starts/stops the location timer.
        _statusProvider.onWentOnline = () {
          if (!mounted) return;
          _locationManager.start(
            authProvider: context.read<AuthProvider>(),
            locationProvider: context.read<LocationProvider>(),
            orderProvider: context.read<OrderProvider>(),
          );
          if (mounted) setState(() => _isOnline = true);
        };
        _statusProvider.onWentOffline = () {
          _locationManager.stop();
          if (mounted) setState(() => _isOnline = false);
        };

        await _checkLocationAlwaysPermission();

        if (!_hasLocationAlwaysPermission) {
          _showLocationPermissionDialog();
          return;
        }

        await _initializeDashboardWithPermission();
      } catch (e) {
        if (!kReleaseMode) debugPrint('❌ Dashboard init error: $e');
      }
    });
  }

  Future<void> _initializeDashboardWithPermission() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isDemoMode) return;

    try {
      await context.read<OrderProvider>().initialize();

      final locationProvider = context.read<LocationProvider>();
      await locationProvider.initialize();

      // Foreground GPS stream always runs for map display.
      locationProvider.startLocationTracking();

      // Wait up to 5 s for first GPS fix so the map marker appears on open.
      int attempts = 0;
      while (locationProvider.currentPosition == null && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }

      // Initialize DriverStatusProvider — subscribes to realtime + starts
      // 15 s poll.  Also syncs local _isOnline from the DB value.
      await _statusProvider.initialize(authProvider);
      setState(() => _isOnline = _statusProvider.isOnline);

      // If already online, start location push timer immediately.
      if (_isOnline) {
        _locationManager.start(
          authProvider: authProvider,
          locationProvider: locationProvider,
          orderProvider: context.read<OrderProvider>(),
        );
      }

      if (mounted) {
        setState(() {});
        await ref.read(systemStatusProvider.notifier).initialize();

        if (authProvider.user != null) {
          await ref.read(announcementProvider.notifier).initialize(
                userRole: 'driver',
                userId: authProvider.user!.id,
                context: context,
              );

          final systemStatus = ref.read(systemStatusProvider);
          if (!systemStatus.isSystemEnabled) {
            if (_isOnline) {
              await _statusProvider.setOnline(false,
                  authProvider: authProvider);
            }
            MaintenanceModeDialog.show(context, 'driver');
          }
        }
      }
    } catch (e) {
      if (!kReleaseMode) debugPrint('❌ Dashboard init error: $e');
    }
  }

  // _initializeOnlineStatus, _subscribeToOnlineStatus, _startStatusCheckTimer
  // are removed — all three concerns now live in DriverStatusProvider.

  Future<void> _acceptOrder(String orderId) async {
    HapticFeedback.heavyImpact();
    try {
      final orderProvider = context.read<OrderProvider>();
      final authProvider = context.read<AuthProvider>();

      final loc = AppLocalizations.of(context);
      if (authProvider.user == null) {
        showHeaderNotification(
          context,
          title: loc.notLoggedIn,
          message: loc.mustLoginFirst,
          type: NotificationType.error,
        );
        return;
      }

      final success = await orderProvider.acceptOrder(orderId);

      // Clear cached orders to force immediate refresh and update route
      if (mounted) {
        setState(() {
          _cachedActiveOrders = null;
        });

        // Trigger rebuild to ensure map updates route
        // Map will update automatically through coordinate change detection
      }

      if (success && mounted) {
        showHeaderNotification(
          context,
          title: loc.accepted,
          message: loc.orderAcceptedSuccessMessage,
          type: NotificationType.success,
        );
      } else if (mounted) {
        final err = orderProvider.error;
        if (err != null && err.contains('رصيد محفظتك')) {
          showHeaderNotification(
            context,
            title: loc.error,
            message: err,
            type: NotificationType.error,
          );
          context.push('/driver/wallet');
          return;
        }
        showHeaderNotification(
          context,
          title: loc.error,
          message: orderProvider.error ?? loc.errorAcceptingOrder,
          type: NotificationType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        showHeaderNotification(
          context,
          title: loc.error,
          message: loc.errorInOperation,
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _rejectOrder(String orderId) async {
    HapticFeedback.mediumImpact();
    try {
      final orderProvider = context.read<OrderProvider>();
      final authProvider = context.read<AuthProvider>();

      final loc = AppLocalizations.of(context);
      if (authProvider.user == null) {
        showHeaderNotification(
          context,
          title: loc.notLoggedIn,
          message: loc.mustLoginFirst,
          type: NotificationType.error,
        );
        return;
      }

      print('🚫 Rejecting order $orderId');

      // STEP 1: Clear map annotations BEFORE rejecting
      print('🧹 STEP 1: Clearing routes and markers for rejected order');
      try {
        await StateOfTheArtNavigation().clearAll();
      } catch (_) {}

      // STEP 2: Reject the order
      final success = await orderProvider.rejectOrder(orderId);

      if (!success) {
        if (mounted) {
          showHeaderNotification(
            context,
            title: loc.error,
            message: orderProvider.error ?? loc.errorRejectingOrder,
            type: NotificationType.error,
          );
        }
        return;
      }

      // STEP 3: Clear annotations again after rejection
      print('🧹 STEP 3: Post-rejection clearing');
      try {
        await StateOfTheArtNavigation().clearAll();
      } catch (_) {}

      // STEP 4: Force immediate removal from local state
      print('🧹 STEP 4: Removing order from local state');
      if (mounted) {
        orderProvider.removeOrderFromLocalState(orderId);
      }

      // STEP 5: Clear cached orders to force refresh
      if (mounted) {
        setState(() {
          _cachedActiveOrders = null;
        });
      }

      // STEP 6: Show success message
      if (mounted) {
        showHeaderNotification(
          context,
          title: loc.rejected,
          message: loc.orderRejectedSuccessMessage,
          type: NotificationType.warning,
        );
      }

      print('✅ Order $orderId rejected successfully and annotations cleared');
    } catch (e) {
      print('❌ Error rejecting order: $e');
      if (mounted) {
        final loc = AppLocalizations.of(context);
        showHeaderNotification(
          context,
          title: loc.error,
          message: loc.errorInOperation,
          type: NotificationType.error,
        );
      }
    }
  }

  Widget _buildSwipeableOrderCards(List<_OrderItem> allItemsToShow) {
    // Generate hash including item IDs and statuses to detect changes
    final currentHash =
        allItemsToShow.map((item) => '${item.id}_${item.status}').join(',');

    // Initialize or reinitialize PageController when orders change
    if (_lastOrderListHash != currentHash ||
        _orderCardsPageController == null) {
      print('🔄 Order list changed - reinitializing PageController');
      print('   Old hash: $_lastOrderListHash');
      print('   New hash: $currentHash');

      _lastOrderListHash = currentHash;

      // Clear geocoding cache when orders change to avoid stale addresses
      _geocodedAddresses.clear();
      print(
          '🗺️ Cleared geocoding cache (${_geocodedAddresses.length} entries)');

      // Find index of first pending order (if only one exists)
      // Find pending items (both regular orders and bulk orders)
      final pendingItems =
          allItemsToShow.where((item) => item.isPending).toList();
      int initialPage = 0;

      if (pendingItems.length == 1) {
        // Auto-scroll to the single pending item
        initialPage = allItemsToShow.indexOf(pendingItems.first);
        print('🎯 Auto-scrolling to pending item at index $initialPage');
      }

      // Ensure index is within bounds
      if (initialPage >= allItemsToShow.length) {
        initialPage = 0;
      }

      _currentOrderIndex = initialPage;
      // Keep ActiveOrderProvider in sync when PageController resets.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ActiveOrderProvider>().setCurrentIndex(initialPage);
        }
      });
      _orderCardsPageController?.dispose();
      _orderCardsPageController = PageController(
        initialPage: initialPage,
        viewportFraction:
            allItemsToShow.length > 1 ? 0.88 : 1.0, // Show more of edges (12%)
        keepPage: true, // Keep the page between rebuilds
      );

      if (allItemsToShow.isNotEmpty) {
        final item = allItemsToShow[_currentOrderIndex];
        if (item is _RegularOrderItem) {
          // Schedule annotation rebuild AFTER the current frame completes so we
          // don't kick off async Mapbox operations (deleteAll / HTTP route /
          // polylineManager.create) during Flutter's build phase.  Doing so
          // blocked the first animation frame and caused the visible jank.
          final orderToAnnotate = item.order;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _rebuildAnnotationsForOrder(orderToAnnotate);
          });
        }
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Compact sizing - only enough for content
        final screenHeight = MediaQuery.sizeOf(context).height;
        const collapsedHeight = 60.0; // Fixed height for collapsed card

        // Check if current item is pending
        final currentItem = _currentOrderIndex < allItemsToShow.length
            ? allItemsToShow[_currentOrderIndex]
            : null;
        final isPendingOrder = currentItem?.isPending ?? false;
        final baseExpandedHeight =
            screenHeight * 0.54; // Base height for order cards
        // Reduced pending order card height by 5% (removed the extra 5% that was added)
        final maxExpandedHeight =
            baseExpandedHeight; // Use same height for all orders

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Enhanced page indicator with better visibility - BEFORE the card
            if (allItemsToShow.length > 1)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chevron_left,
                      size: 16,
                      color: _currentOrderIndex > 0
                          ? AppColors.primary
                          : AppColors.textTertiary.withValues(alpha: 0.3),
                    ),
                    SizedBox(width: context.rs(8)),
                    ...List.generate(
                      allItemsToShow.length,
                      (index) => Container(
                        margin: EdgeInsets.symmetric(horizontal: context.rs(3)),
                        width: _currentOrderIndex == index
                            ? context.rs(24)
                            : context.rs(8),
                        height: context.rs(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: _currentOrderIndex == index
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.25),
                          boxShadow: _currentOrderIndex == index
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                    SizedBox(width: context.rs(8)),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: _currentOrderIndex < allItemsToShow.length - 1
                          ? AppColors.primary
                          : AppColors.textTertiary.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),

            Align(
              alignment: Alignment.bottomCenter,
              child: Builder(
                builder: (context) {
                  final pageView = PageView.builder(
                    key: ValueKey('order_cards_pageview_$currentHash'),
                    controller: _orderCardsPageController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: allItemsToShow.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentOrderIndex = index;
                      });
                      // Sync to ActiveOrderProvider — this notifies the Selector in
                      // DriverMapSection, which rebuilds StateOfTheArtMapWidget with
                      // the new activeOrder, triggering didUpdateWidget →
                      // _setActiveOrder → navigationSystem.setActiveOrder.
                      // That single path hides the old order and shows the new one.
                      // A second explicit call (_rebuildAnnotationsForOrder) is NOT
                      // needed and was causing a racing concurrent setActiveOrder.
                      context
                          .read<ActiveOrderProvider>()
                          .setCurrentIndex(index);

                      final item = allItemsToShow[index];
                      print('📄 Switched to card $index: ${item.id}');
                    },
                    itemBuilder: (context, index) {
                      final item = allItemsToShow[index];
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: allItemsToShow.length > 1 ? 8.0 : 0.0,
                        ),
                        child: RepaintBoundary(
                          key: ValueKey('order_card_${item.id}_${item.status}'),
                          child: _buildOrderCard(
                              (item as _RegularOrderItem).order),
                        ),
                      );
                    },
                  );

                  return _isOrderCardExpanded
                      ? SizedBox(
                          height: maxExpandedHeight,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 400),
                            opacity: 1.0,
                            child: pageView,
                          ),
                        )
                      : SizedBox(
                          height: collapsedHeight,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 400),
                            opacity: 1.0,
                            child: pageView,
                          ),
                        );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrderCard(dynamic order) {
    final isPending = order.isPending;
    final isAssigned = order.isAssigned;
    final isAccepted = order.isAccepted;
    final isOnTheWay = order.isOnTheWay;

    // Get vehicle type icon
    final loc = AppLocalizations.of(context);
    IconData vehicleIcon = Icons.two_wheeler;
    String vehicleText = loc.motorbikeLabel;
    if (order.vehicleType == 'car') {
      vehicleIcon = Icons.directions_car;
      vehicleText = loc.car;
    } else if (order.vehicleType == 'truck') {
      vehicleIcon = Icons.local_shipping;
      vehicleText = loc.truck;
    }

    // Listener claims the pointer event at the lowest Flutter level.  On iOS,
    // after a Mapbox pan/zoom, the platform view's UIGestureRecognizer can
    // linger in an active state and absorb taps that land on Flutter overlay
    // widgets.  Having an opaque Listener here ensures this touch reaches
    // Flutter's pointer routing before the gesture arena runs, which prevents
    // the platform view's recognizer from silently consuming it.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {}, // intentionally empty — just claims the event
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Allow tapping collapsed card to expand
          if (!_isOrderCardExpanded) {
            setState(() {
              _isOrderCardExpanded = true;
            });
            // Ensure route and pins are created when card expands
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  // Force Consumer rebuild to update map widget
                });
              }
            });
          }
        },
        child: AnimatedSize(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          child: _isOrderCardExpanded
              ? _buildExpandedCard(order, vehicleIcon, vehicleText)
              : _buildCollapsedCard(order),
        ),
      ),
    );
  }

  // Collapsed card - Teal blue floating card
  Widget _buildCollapsedCard(dynamic order) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.keyboard_arrow_up,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  // Expanded card - Modern design inspired by provided template (Compact version)
  Widget _buildExpandedCard(
      dynamic order, IconData vehicleIcon, String vehicleText) {
    final isPending = order.isPending;
    final isAssigned = order.isAssigned;
    final isAccepted = order.isAccepted;
    final isOnTheWay = order.isOnTheWay;
    final double routeDistanceMeters = LocationService.calculateDistance(
      order.pickupLatitude,
      order.pickupLongitude,
      order.deliveryLatitude,
      order.deliveryLongitude,
    );
    final String formattedRouteDistance =
        LocationService.getFormattedDistance(routeDistanceMeters);

    final card = GestureDetector(
      onTap: () {
        // Close expanded address card if any when clicking on the card
        if (_expandedAddressCardId != null) {
          setState(() {
            _expandedAddressCardId = null;
            _showNavigationButtons = false;
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary, // Teal blue background
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(40),
          ), // Curved top edge
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, -4),
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(40),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar - Enhanced for easier collapse
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isOrderCardExpanded = false;
                  });
                },
                onVerticalDragEnd: (details) {
                  // Collapse when dragged down (reduced threshold for easier use)
                  if (details.primaryVelocity != null &&
                      details.primaryVelocity! > 150) {
                    setState(() {
                      _isOrderCardExpanded = false;
                    });
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  width: double.infinity,
                  child: Column(
                    children: [
                      Container(
                        width: 50,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),

              // Ready countdown banner (if set by merchant)
              _buildReadyCountdownBanner(order),

              // Content area - all content visible, no scrolling
              _buildPaymentSummarySection(order),
              SizedBox(height: context.rs(4)),
              _buildAddressSection(order),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              SizedBox(height: context.rs(4)),
              _buildResponsiveActionButtons(order),

              // Action buttons at the bottom (always visible)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 10,
                    bottom:
                        0, // No bottom padding - NavigationBarAwareFooterWrapper handles all safe area spacing
                  ),
                  child: (order.isPending ||
                              order.isAssigned) &&
                          !isAccepted
                      ? _buildPendingOrderButtons(order)
                      : _buildMainActionButton(order),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return card;
  }

  Widget _buildProminentAddressCard({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String label,
    required String address,
    dynamic order,
    double? targetLatitude,
    double? targetLongitude,
    required bool isPickup,
  }) {
    // Generate card ID from order
    final cardId = order != null
        ? '${order.id}_${isPickup ? 'pickup' : 'dropoff'}'
        : '${address.hashCode}_${isPickup ? 'pickup' : 'dropoff'}';
    final isExpanded = _expandedAddressCardId == cardId;
    final double contentHeight = context.rs(80);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (order != null) {
              _openInMaps(order, isPickup: isPickup);
            } else if (targetLatitude != null && targetLongitude != null) {
              // Open maps for specific coordinates
              _openInMapsForCoordinates(
                  targetLatitude, targetLongitude, address);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            padding: context.rp(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(context.rs(12)),
              border: Border.all(
                color: isExpanded
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.2),
                width: isExpanded ? 1.5 : 1,
              ),
            ),
            child: SizedBox(
              height: contentHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedOpacity(
                    key: ValueKey('${cardId}_address'),
                    duration: const Duration(milliseconds: 200),
                    opacity: isExpanded ? 0.0 : 1.0,
                    child: _buildAddressInfo(
                      icon: icon,
                      iconColor: iconColor,
                      label: label,
                      address: address,
                      height: contentHeight,
                    ),
                  ),
                  IgnorePointer(
                    ignoring: !isExpanded,
                    child: AnimatedOpacity(
                      key: ValueKey('${cardId}_nav'),
                      duration: const Duration(milliseconds: 200),
                      opacity: isExpanded ? 1.0 : 0.0,
                      child: _buildNavigationButtonsInCard(contentHeight),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressInfo({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
    required double height,
  }) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: context.rp(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(context.rs(10)),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: context.ri(28),
            ),
          ),
          SizedBox(width: context.rs(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ResponsiveText(
                  label,
                  style: TextStyle(
                    fontSize: context.rf(12),
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: context.rs(4)),
                ResponsiveText(
                  address,
                  style: TextStyle(
                    fontSize: context.rf(15),
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white.withValues(alpha: 0.6),
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtonsInCard(double height) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildNavigationButton(
            assetPath: 'assets/icons/googlemaps.png',
            fallbackColor: const Color(0xFF4285F4),
            icon: Icons.map,
            onTap: () {
              if (_targetLatitude != null && _targetLongitude != null) {
                _openGoogleMaps(_targetLatitude!, _targetLongitude!);
              }
            },
          ),
          SizedBox(width: context.rs(16)),
          _buildNavigationButton(
            assetPath: 'assets/icons/waze.png',
            fallbackColor: const Color(0xFF33CCFF),
            icon: Icons.navigation,
            onTap: () {
              if (_targetLatitude != null && _targetLongitude != null) {
                _openWaze(_targetLatitude!, _targetLongitude!);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButton({
    required String assetPath,
    required Color fallbackColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: context.rs(56),
        height: context.rs(56),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(context.rs(14)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.28),
            width: 1,
          ),
        ),
        child: Center(
          child: Container(
            width: context.rs(36),
            height: context.rs(36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(context.rs(10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(context.rs(10)),
              child: Image.asset(
                assetPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: fallbackColor,
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: context.ri(18),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSummarySection(dynamic order) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: context.isTablet ? 20.0 : 14.0,
        vertical: context.rs(6),
      ),
      padding: EdgeInsets.all(context.rs(12)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(context.rs(16)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
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
              Icon(
                Icons.receipt_long_rounded,
                color: Colors.white.withValues(alpha: 0.9),
                size: context.ri(18),
              ),
              SizedBox(width: context.rs(8)),
              ResponsiveText(
                'رقم الطلب: #${order.userFriendlyCode ?? order.id.substring(0, 8)}',
                style: TextStyle(
                  fontSize: context.rf(14),
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          SizedBox(height: context.rs(14)),
          Row(
            children: [
              Expanded(
                child: _buildFeeSummaryTile(
                  context: context,
                  icon: Icons.local_shipping_rounded,
                  accentColor: Colors.orangeAccent,
                  label: 'رسوم التوصيل',
                  amount: '${order.deliveryFee.toStringAsFixed(0)} د.ع',
                ),
              ),
              SizedBox(width: context.rs(12)),
              Expanded(
                child: _buildFeeSummaryTile(
                  context: context,
                  icon: Icons.storefront_rounded,
                  accentColor: Colors.greenAccent,
                  label: 'قيمة الطلب',
                  amount: '${order.totalAmount.toStringAsFixed(0)} د.ع',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeeSummaryTile({
    required BuildContext context,
    required IconData icon,
    required Color accentColor,
    required String label,
    required String amount,
  }) {
    return Container(
      padding: context.rp(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.9),
            accentColor.withValues(alpha: 0.65),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(context.rs(16)),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.95),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: context.rs(44),
            height: context.rs(44),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(context.rs(12)),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: context.ri(22),
            ),
          ),
          SizedBox(width: context.rs(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ResponsiveText(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: context.rf(12),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: context.rs(4)),
                ResponsiveText(
                  amount,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: context.rf(18),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Format ready countdown in Arabic format (س for hours, د for minutes, ث for seconds)
  // Format examples: "2س 15د" (2h 15m), "45د 30ث" (45m 30s), "30ث" (30s)
  String _formatReadyCountdownArabic(int seconds) {
    if (seconds <= 0) return 'الآن';

    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    final List<String> parts = [];

    if (hours > 0) {
      parts.add('$hoursس');
      if (minutes > 0) {
        parts.add('$minutesد');
      }
      // Don't show seconds when hours are present
    } else if (minutes > 0) {
      parts.add('$minutesد');
      if (secs > 0) {
        parts.add('$secsث');
      }
    } else if (secs > 0) {
      // Only seconds
      parts.add('$secsث');
    }

    return parts.isEmpty ? 'الآن' : parts.join(' ');
  }

  // Build ready countdown banner widget
  Widget _buildReadyCountdownBanner(dynamic order) {
    // Only show if order has ready_at time
    if (order.readyAt == null) {
      return const SizedBox.shrink();
    }

    // Get initial seconds until ready
    final initialSeconds = order.secondsUntilReady;

    return StreamBuilder<int>(
      stream: Stream<int>.periodic(
        const Duration(seconds: 1),
        (i) {
          final readyAt = order.readyAt;
          if (readyAt == null) return 0;
          final now = DateTime.now();
          final difference = readyAt.difference(now);
          final seconds = difference.inSeconds;
          return seconds > 0 ? seconds : 0;
        },
      ).takeWhile((seconds) => seconds >= 0),
      initialData: initialSeconds,
      builder: (context, snapshot) {
        final seconds = snapshot.data ?? initialSeconds;
        final isReady = seconds <= 0;

        // Ready banner (green)
        if (isReady) {
          return Container(
            margin: EdgeInsets.symmetric(
              horizontal: context.isTablet ? 20.0 : 14.0,
              vertical: context.rs(8),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: context.rs(16),
              vertical: context.rs(12),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.shade600,
                  Colors.green.shade500,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(context.rs(12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: context.ri(20),
                ),
                SizedBox(width: context.rs(8)),
                Text(
                  '✅ الطلب جاهز الآن',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: context.rf(15),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          );
        }

        // Countdown banner (orange)
        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: context.isTablet ? 20.0 : 14.0,
            vertical: context.rs(8),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: context.rs(16),
            vertical: context.rs(12),
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade600,
                Colors.orange.shade500,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(context.rs(12)),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer,
                color: Colors.white,
                size: context.ri(20),
              ),
              SizedBox(width: context.rs(8)),
              Text(
                '⏰ جاهز بعد ${_formatReadyCountdownArabic(seconds)}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: context.rf(15),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddressSection(dynamic order) {
    return GestureDetector(
      onTap: () {
        if (_expandedAddressCardId != null) {
          setState(() {
            _expandedAddressCardId = null;
            _showNavigationButtons = false;
          });
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.isTablet ? 22.0 : 14.0,
          vertical: context.rs(4),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalGap = context.rs(12);

            Widget buildPickupCard() {
              return GestureDetector(
                onTap: () {},
                child: FutureBuilder<String?>(
                  future: _getGeocodedAddress(
                    order.id,
                    order.pickupLatitude,
                    order.pickupLongitude,
                    true,
                  ),
                  builder: (context, snapshot) {
                    final pickupAddress =
                        (snapshot.hasData && snapshot.data != null)
                            ? snapshot.data!
                            : order.pickupAddress;
                    return _buildProminentAddressCard(
                      icon: Icons.store_mall_directory_rounded,
                      iconColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      label: 'التاجر',
                      address: pickupAddress,
                      order: order,
                      isPickup: true,
                    );
                  },
                ),
              );
            }

            Widget buildDropoffCard() {
              return GestureDetector(
                onTap: () {},
                child: FutureBuilder<String?>(
                  future: _getGeocodedAddress(
                    order.id,
                    order.deliveryLatitude,
                    order.deliveryLongitude,
                    false,
                  ),
                  builder: (context, snapshot) {
                    final dropoffAddress =
                        (snapshot.hasData && snapshot.data != null)
                            ? snapshot.data!
                            : order.deliveryAddress;
                    return _buildProminentAddressCard(
                      icon: Icons.location_on_rounded,
                      iconColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      label: 'العميل',
                      address: dropoffAddress,
                      order: order,
                      isPickup: false,
                    );
                  },
                ),
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: buildPickupCard()),
                SizedBox(width: horizontalGap),
                Expanded(child: buildDropoffCard()),
              ],
            );
          },
        ),
      ),
    );
  }


  Widget _buildModernActionButton(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: color, // Solid color for contrast
            radius: context.rs(26),
            child: Icon(icon, color: Colors.white, size: context.ri(28)),
          ),
          SizedBox(height: context.rs(6)),
          ResponsiveText(
            label,
            style: TextStyle(
              fontSize: context.rf(13),
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Responsive layout for action buttons: wraps to next line on small widths
  Widget _buildResponsiveActionButtons(dynamic order) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        spacing: context.rs(10),
        runSpacing: context.rs(8),
        children: [
          _buildModernActionButton(
            icon: Icons.business,
            label: 'التاجر',
            color: Colors.orangeAccent,
            onTap: () => _callMerchant(order.merchantId),
          ),
          _buildModernActionButton(
            icon: Icons.person,
            label: 'العميل',
            color: Colors.teal,
            onTap: () => _callCustomer(order.customerPhone, order.customerName),
          ),
          _buildModernActionButton(
            icon: Icons.navigation_rounded,
            label: 'الموقع',
            color: Colors.blueAccent,
            onTap: () => _openInMaps(order),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingOrderButtons(dynamic order) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: _buildRejectButton(order),
        ),
        SizedBox(width: context.rs(8)),
        Expanded(
          flex: 4,
          child: _buildAcceptButtonWithLongPress(order),
        ),
      ],
    );
  }

  Widget _buildAcceptButtonWithLongPress(dynamic order) {
    return _AcceptButtonWithLongPress(
      orderId: order.id,
      onAccept: () => _acceptOrder(order.id),
    );
  }

  Widget _buildRejectButton(dynamic order) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.red.shade600, // Solid red background
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextButton(
        onPressed: () => _rejectOrder(order.id),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        child: const Text(
          'رفض',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildMainActionButton(dynamic order) {
    final isAccepted = order.isAccepted;
    final isOnTheWay = order.isOnTheWay;

    String buttonText;
    VoidCallback? onPressed;
    Color buttonColor;
    Color shadowColor;

    if (isAccepted) {
      buttonText = 'تم استلام الطلب';
      onPressed = () => _markOrderOnTheWay(order.id);
      buttonColor = Colors.orangeAccent;
      shadowColor = Colors.orangeAccent;
    } else if (isOnTheWay) {
      buttonText = 'تم التوصيل';
      onPressed = () => _ensureOrderProofThenDeliver(order);
      buttonColor = Colors.green;
      shadowColor = Colors.green;
    } else {
      buttonText = 'اكتمل الطلب';
      onPressed = null;
      buttonColor = Colors.grey;
      shadowColor = Colors.grey;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: buttonColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          buttonText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _ensureOrderProofThenDeliver(dynamic order) async {
    final orderProvider = context.read<OrderProvider>();

    print('🔍 Checking if order ${order.id} has proof...');
    final hasProof = await orderProvider.hasOrderProof(order.id);
    print('📸 Order ${order.id} proof status: $hasProof');

    if (hasProof) {
      print('✅ Proof exists, proceeding to mark as delivered...');
      // INSTANT CLEAR: Clear annotations immediately before marking as delivered
      print(
          '🧹 INSTANT CLEAR: Clearing annotations before delivery (proof exists)');
      StateOfTheArtNavigation().clearAll().catchError((e) {
        print('⚠️ Error in instant clear: $e');
      });
      StateOfTheArtNavigation().clearOrder(order.id).catchError((e) {
        print('⚠️ Error clearing specific order: $e');
      });

      // Proof exists, proceed with delivery confirmation
      await _markOrderDelivered(order.id);
      return;
    }

    print('⚠️ No proof found, showing upload dialog...');
    if (!mounted) return;

    // No proof exists, show upload dialog
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.themeSurface,
      isDismissible: false, // Prevent dismissal without completing action
      enableDrag: false, // Prevent accidental dismissal
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return PopScope(
          canPop: false, // Prevent back button dismissal
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: OrderProofUploader(
              orderId: order.id,
              onUploaded: () async {
                print('📸 ========================================');
                print('📸 ORDER PROOF UPLOADED CALLBACK TRIGGERED');
                print('📸 Order ID: ${order.id}');
                print('📸 Time: ${DateTime.now()}');
                print('📸 ========================================');

                try {
                  // INSTANT CLEAR: Clear annotations immediately when proof is uploaded
                  print(
                      '🧹 INSTANT CLEAR: Clearing annotations (proof uploaded)');
                  StateOfTheArtNavigation().clearAll().catchError((e) {
                    print('⚠️ Error in instant clear: $e');
                  });
                  StateOfTheArtNavigation()
                      .clearOrder(order.id)
                      .catchError((e) {
                    print('⚠️ Error clearing specific order: $e');
                  });

                  // CRITICAL: Mark as delivered FIRST, then close the bottom sheet
                  // Skip confirmation dialog since uploading proof is the confirmation
                  print(
                      '🚚 Marking order as delivered with skip confirmation...');
                  await _markOrderDelivered(order.id, skipConfirmation: true);
                  print('✅ Order marked as delivered successfully');

                  // Close the bottom sheet
                  print('🚪 Closing bottom sheet...');
                  if (Navigator.canPop(ctx)) {
                    Navigator.pop(ctx);
                  }
                  print('✅ Bottom sheet closed');
                } catch (e) {
                  print('❌ Error in onUploaded callback: $e');
                  // Still close the bottom sheet even if there's an error
                  if (Navigator.canPop(ctx)) {
                    Navigator.pop(ctx);
                  }
                  // Show error notification
                  if (mounted) {
                    showHeaderNotification(
                      context,
                      title: 'خطأ',
                      message:
                          'تم رفع الصورة لكن فشل تحديث حالة الطلب. حاول الضغط على زر التسليم مرة أخرى.',
                      type: NotificationType.error,
                      duration: const Duration(seconds: 5),
                    );
                  }
                }
              },
              onCancel: () {
                // Allow cancellation - close the bottom sheet
                if (Navigator.canPop(ctx)) {
                  Navigator.pop(ctx);
                }
              },
            ),
          ),
        );
      },
    );
  }






  IconData _getOrderStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'assigned':
        return Icons.assignment;
      case 'accepted':
        return Icons.check_circle;
      case 'on_the_way':
        return Icons.directions_car;
      case 'delivered':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      case 'unassigned':
        return Icons.assignment_late;
      case 'rejected':
        return Icons.block;
      default:
        return Icons.help;
    }
  }

  Future<void> _markOrderOnTheWay(String orderId) async {
    final loc = AppLocalizations.of(context);
    final orderProvider = context.read<OrderProvider>();
    final order = orderProvider.getOrderById(orderId);

    // Check if customer phone is missing
    if (order?.customerPhone == null || order!.customerPhone!.isEmpty) {
      // Show dialog to enter customer phone
      final phoneController = TextEditingController();
      final phoneFocusNode = FocusNode();

      // Auto-remove leading zeros
      phoneController.addListener(() {
        final text = phoneController.text;
        if (text.startsWith('0')) {
          final newText = text.replaceFirst(RegExp('^0+'), '');
          if (newText != text) {
            phoneController.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: newText.length),
            );
          }
        }
      });

      final formKey = GlobalKey<FormState>();

      final shouldContinue = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => Theme(
          data: Theme.of(context),
          child: AlertDialog(
            backgroundColor: context.themeSurface,
            title: Text(
              loc.customerPhoneRequired,
              style: TextStyle(color: context.themeTextPrimary),
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    loc.customerPhoneRequiredForPickup,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: context.themeTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    focusNode: phoneFocusNode,
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: context.themeTextPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: loc.phoneLabel ?? 'رقم الهاتف',
                      hintText: '7XX XXX XXXX',
                      hintStyle: TextStyle(
                        color: context.themeTextTertiary,
                      ),
                      prefixIcon:
                          Icon(Icons.phone, color: context.themeTextSecondary),
                      filled: true,
                      fillColor: context.themeSurfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.themeBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.themeBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.primary, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.error),
                      ),
                      labelStyle: TextStyle(color: context.themeTextSecondary),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return loc.phoneRequired;
                      }
                      final digits = value.replaceAll(RegExp(r'\D'), '');
                      if (!(digits.length == 10 && digits.startsWith('7'))) {
                        return loc.phoneInvalidFormat;
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  loc.cancel,
                  style: TextStyle(color: context.themeTextSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.of(context).pop(true);
                  }
                },
                child: Text(loc.continueAction),
              ),
            ],
          ),
        ),
      );

      if (shouldContinue == true && mounted) {
        // Update customer phone
        final phoneUpdated = await orderProvider.updateCustomerPhone(
          orderId,
          phoneController.text,
        );

        if (!phoneUpdated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(orderProvider.error ?? loc.error),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      } else {
        return; // User cancelled
      }
    }

    // Now proceed with marking as picked up
    final success =
        await orderProvider.markOrderOnTheWay(orderId, context: context);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.pickupConfirmed),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(orderProvider.error ?? loc.error),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }


  Future<void> _markOrderDelivered(String orderId,
      {bool skipConfirmation = false}) async {
    // Show confirmation dialog (unless skipped - e.g., when proof was already uploaded)
    bool confirmed = skipConfirmation;

    if (!skipConfirmation) {
      confirmed = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.success,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(AppLocalizations.of(context).confirmDelivery),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'هل قمت بتسليم الطلب للعميل؟',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.amber.shade700,
                            size: 20,
                          ),
                          SizedBox(width: context.rs(8)),
                          Expanded(
                            child: Text(
                              'تأكد من استلام العميل للطلب قبل التأكيد',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  Builder(
                    builder: (context) {
                      final loc = AppLocalizations.of(context);
                      return TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          loc.cancel,
                          style: const TextStyle(fontSize: 16),
                        ),
                      );
                    },
                  ),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text(
                      'تم التسليم',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              );
            },
          ) ??
          false;
    }

    // Only proceed if confirmed
    if (!confirmed) {
      print('❌ Delivery not confirmed by user');
      return;
    }

    print('✅ Delivery confirmed (skipConfirmation: $skipConfirmation)');

    // INSTANT CLEAR: Clear annotations IMMEDIATELY when user confirms
    // Fire-and-forget async clear - don't wait for it
    print(
        '🧹 INSTANT CLEAR: Clearing annotations immediately (fire-and-forget)');
    StateOfTheArtNavigation().clearAll().catchError((e) {
      print('⚠️ Error in instant clear: $e');
    });
    _mapWidgetKey?.currentState?.forceClearAnnotations();

    // Also clear specific order annotations immediately
    try {
      final nav = StateOfTheArtNavigation();
      // Clear this specific order's markers and route
      nav.clearOrder(orderId).catchError((e) {
        print('⚠️ Error clearing specific order: $e');
      });
    } catch (e) {
      print('⚠️ Error in order-specific clear: $e');
    }

    try {
      print('🚚 ===========================================');
      print('🚚 MARKING ORDER AS DELIVERED');
      print('🚚 Order ID: $orderId');
      print('🚚 Time: ${DateTime.now()}');
      print('🚚 ===========================================');

      // STEP 1: Clear ONLY this specific order's annotations (not all orders)
      print('🧹 STEP 1: CLEARING ROUTES AND MARKERS FOR ORDER $orderId ONLY');
      try {
        // Only clear the delivered order, keep other orders' cached annotations
        await StateOfTheArtNavigation().clearOrder(orderId);
        print('✅ Cleared annotations for delivered order $orderId only');
      } catch (e) {
        print('⚠️ Error clearing order-specific annotations: $e');
      }

      // STEP 2: Mark order as delivered
      final success =
          await context.read<OrderProvider>().markOrderDelivered(orderId);

      if (!success) {
        // If delivery marking failed, show error and don't continue cleanup
        print('❌ Failed to mark order as delivered');

        // Get the specific error message from OrderProvider
        final errorMessage = context.read<OrderProvider>().error;
        print('🔍 Specific error from provider: $errorMessage');

        if (mounted) {
          // Show detailed error dialog for debugging
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context).deliveryError),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'فشل تحديث حالة الطلب:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: SelectableText(
                      errorMessage ?? 'خطأ غير معروف',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'يرجى أخذ لقطة شاشة وإرسالها للدعم الفني',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocalizations.of(context).ok),
                ),
              ],
            ),
          );
        }
        return;
      }

      // STEP 3: Clear annotations again immediately after to catch any stragglers
      print('🧹 STEP 3: POST-DELIVERY CLEARING');
      try {
        // Clear all annotations
        await StateOfTheArtNavigation().clearAll();
        // Also clear this specific order
        await StateOfTheArtNavigation().clearOrder(orderId);
      } catch (e) {
        print('⚠️ Error in post-delivery clear: $e');
      }

      // STEP 4: Force immediate removal from local state
      print('🧹 STEP 4: REMOVING ORDER FROM LOCAL STATE');
      if (mounted) {
        final orderProvider = context.read<OrderProvider>();
        // The subscription will handle the removal, but we force a manual removal for immediate effect
        // This prevents any visual lag while waiting for the subscription to update
        orderProvider.removeOrderFromLocalState(orderId);
      }

      // STEP 5: Clear cached orders and force map refresh
      print('🧹 STEP 5: CLEARING CACHED ORDERS AND REFRESHING MAP');
      if (mounted) {
        setState(() {
          _cachedActiveOrders = null;
          // Force map to rebuild and clear all annotations
        });

        // Force map widget refresh immediately
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              StateOfTheArtNavigation().clearAll();
              // Note: StateOfTheArtNavigation().clearAll() already handles all route/marker clearing
            } catch (e) {
              print('⚠️ Error in post-frame clear: $e');
            }
          }
        });
      }

      showHeaderNotification(
        context,
        title: 'تم التسليم',
        message: 'تم تسليم الطلب بنجاح',
        type: NotificationType.success,
      );

      print('✅ Order delivery process complete - route cleared');
    } catch (e) {
      print('❌ Error marking order as delivered: $e');
      if (mounted) {
        showHeaderNotification(
          context,
          title: 'خطأ',
          message: 'حدث خطأ في العملية',
          type: NotificationType.error,
        );
      }
    }
  }

  void _callMerchant(String merchantId) async {
    // Fetch merchant details from users table
    try {
      print('📞 Fetching merchant details for: $merchantId');

      final merchantResponse = await Supabase.instance.client
          .from('users')
          .select('id, phone, name, store_name')
          .eq('id', merchantId)
          .maybeSingle();

      if (merchantResponse == null) {
        print(
            '⚠️ Merchant not found in database (merchant may have been deleted)');
        if (mounted) {
          showHeaderNotification(
            context,
            title: 'تنبيه',
            message: 'معلومات التاجر غير متوفرة',
            type: NotificationType.warning,
          );
        }
        return;
      }

      final merchantName = merchantResponse['store_name'] ??
          merchantResponse['name'] ??
          'التاجر';
      final merchantPhone = merchantResponse['phone'] as String;

      print('✅ Merchant found: $merchantName - $merchantPhone');

      if (mounted) {
        _showContactDialog(
          context: context,
          name: merchantName,
          phone: merchantPhone,
          title: 'الاتصال بالتاجر',
          icon: Icons.store,
          color: AppColors.primary,
        );
      }
    } catch (e) {
      print('❌ Error fetching merchant: $e');
      if (mounted) {
        showHeaderNotification(
          context,
          title: 'خطأ',
          message: 'فشل جلب بيانات التاجر',
          type: NotificationType.error,
        );
      }
    }
  }

  void _callCustomer(String? customerPhone, String customerName) {
    _showContactDialog(
      context: context,
      name: customerName,
      phone: customerPhone ?? '',
      title: 'الاتصال بالعميل',
      icon: Icons.person,
      color: AppColors.success,
    );
  }

  void _showContactDialog({
    required BuildContext context,
    required String name,
    required String phone,
    required String title,
    required IconData icon,
    required Color color,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isDark
                  ? Theme.of(context).dialogBackgroundColor
                  : Colors.white,
              gradient: isDark
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        color.withValues(alpha: 0.05),
                      ],
                    ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 40,
                    color: color,
                  ),
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  title,
                  style: AppTextStyles.heading3.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Name
                Text(
                  name,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white
                        : Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),

                // Phone number
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.phone,
                        size: 18,
                        color: color,
                      ),
                      SizedBox(width: context.rs(8)),
                      Text(
                        phone,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Column(
                  children: [
                    // Call on Cellular
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: phone !=
                                AppLocalizations.of(context).notAvailableShort
                            ? () {
                                Navigator.of(dialogContext).pop();
                                _makePhoneCall(phone);
                              }
                            : null,
                        icon: const Icon(Icons.phone, size: 20),
                        label: Text(AppLocalizations.of(context).callViaPhone),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          disabledBackgroundColor: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Call on WhatsApp
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: phone !=
                                AppLocalizations.of(context).notAvailableShort
                            ? () {
                                Navigator.of(dialogContext).pop();
                                _callOnWhatsApp(phone);
                              }
                            : null,
                        icon: const Icon(Icons.call, size: 20),
                        label:
                            Text(AppLocalizations.of(context).callViaWhatsapp),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF25D366), // WhatsApp green
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          disabledBackgroundColor: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Message on WhatsApp
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: phone !=
                                AppLocalizations.of(context).notAvailableShort
                            ? () {
                                Navigator.of(dialogContext).pop();
                                _messageOnWhatsApp(phone, name);
                              }
                            : null,
                        icon: const Icon(Icons.chat, size: 20),
                        label:
                            Text(AppLocalizations.of(context).whatsappMessage),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF25D366),
                          side: const BorderSide(
                              color: Color(0xFF25D366), width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledForegroundColor: Colors.grey,
                        ),
                      ),
                    ),

                    // Show helpful message if phone not available
                    if (phone ==
                        AppLocalizations.of(context).notAvailableShort) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppColors.warning, size: 20),
                            SizedBox(width: context.rs(8)),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)
                                    .merchantInfoUnavailable,
                                style: const TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Cancel button
                Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        loc.cancel,
                        style: TextStyle(
                          color: context.themeTextSecondary,
                          fontSize: 16,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        showHeaderNotification(
          context,
          title: AppLocalizations.of(context).error,
          message: AppLocalizations.of(context).cannotMakeCall,
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _callOnWhatsApp(String phone) async {
    // Remove any non-digit characters and ensure it starts with country code
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleanPhone.startsWith('+')) {
      cleanPhone = '+964$cleanPhone'; // Add Iraq country code if missing
    }

    final uri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        showHeaderNotification(
          context,
          title: AppLocalizations.of(context).error,
          message: AppLocalizations.of(context).cannotOpenWhatsapp,
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _messageOnWhatsApp(String phone, String name) async {
    // Remove any non-digit characters and ensure it starts with country code
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleanPhone.startsWith('+')) {
      cleanPhone = '+964$cleanPhone'; // Add Iraq country code if missing
    }

    final loc = AppLocalizations.of(context);
    final message = loc.driverWhatsappMessage(name);
    final uri = Uri.parse(
        'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        showHeaderNotification(
          context,
          title: AppLocalizations.of(context).error,
          message: AppLocalizations.of(context).cannotOpenWhatsapp,
          type: NotificationType.error,
        );
      }
    }
  }

  void _openInMaps(dynamic order, {bool? isPickup}) async {
    // Determine location based on isPickup parameter or order status
    double latitude;
    double longitude;
    String cardId;

    if (isPickup != null) {
      // Explicitly specified
      if (isPickup) {
        latitude = order.pickupLatitude;
        longitude = order.pickupLongitude;
        cardId = '${order.id}_pickup';
      } else {
        latitude = order.deliveryLatitude;
        longitude = order.deliveryLongitude;
        cardId = '${order.id}_dropoff';
      }
    } else if (order.isPending ||
        order.isAssigned ||
        order.isAccepted) {
      // Go to pickup location (store)
      latitude = order.pickupLatitude;
      longitude = order.pickupLongitude;
      cardId = '${order.id}_pickup';
    } else {
      // Go to delivery location (customer)
      latitude = order.deliveryLatitude;
      longitude = order.deliveryLongitude;
      cardId = '${order.id}_dropoff';
    }

    _targetLatitude = latitude;
    _targetLongitude = longitude;

    // Refocus map on the location
    if (_mapWidgetKey?.currentState != null) {
      _mapWidgetKey!.currentState!.refocusCamera(latitude, longitude);
    }

    setState(() {
      if (_expandedAddressCardId == cardId) {
        // Close if already expanded
        _expandedAddressCardId = null;
        _showNavigationButtons = false;
      } else {
        // Expand the clicked card
        _expandedAddressCardId = cardId;
        _showNavigationButtons = true;
      }
    });
  }

  // Bulk order method removed - _openInMapsForBulkOrder

  void _openInMapsForCoordinates(
      double latitude, double longitude, String address) async {
    _targetLatitude = latitude;
    _targetLongitude = longitude;

    final cardId = '${address.hashCode}_${latitude}_$longitude';

    // Refocus map on the location
    if (_mapWidgetKey?.currentState != null) {
      _mapWidgetKey!.currentState!.refocusCamera(latitude, longitude);
    }

    setState(() {
      if (_expandedAddressCardId == cardId) {
        // Close if already expanded
        _expandedAddressCardId = null;
        _showNavigationButtons = false;
      } else {
        // Expand the clicked card
        _expandedAddressCardId = cardId;
        _showNavigationButtons = true;
      }
    });

    // Refocus map on the location
    if (_mapWidgetKey?.currentState != null) {
      _mapWidgetKey!.currentState!.refocusCamera(latitude, longitude);
    }

    // Toggle navigation buttons inside the address card
    setState(() {
      if (_expandedAddressCardId == cardId) {
        // Close if already expanded
        _expandedAddressCardId = null;
        _showNavigationButtons = false;
      } else {
        // Expand the clicked card
        _expandedAddressCardId = cardId;
        _showNavigationButtons = true;
        _targetLatitude = latitude;
        _targetLongitude = longitude;
      }
    });
  }

  void _openGoogleMaps(double latitude, double longitude) async {
    try {
      // Validate coordinates
      if (latitude.isNaN ||
          longitude.isNaN ||
          latitude.abs() > 90 ||
          longitude.abs() > 180) {
        throw Exception(AppLocalizations.of(context).invalidCoordinates);
      }

      print('📍 Opening Google Maps with: $latitude, $longitude');

      // Try multiple Google Maps URLs in order of preference
      final urls = [
        // Native Android Google Maps app with navigation
        'google.navigation:q=$latitude,$longitude&mode=d',
        // Alternative native app URL
        'comgooglemaps://?daddr=$latitude,$longitude&directionsmode=driving',
        // Universal URL that opens in app if installed, otherwise browser
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving',
      ];

      bool opened = false;
      for (final url in urls) {
        try {
          final uri = Uri.parse(url);
          print('   Trying: $url');

          // For custom schemes (google.navigation, comgooglemaps), try to launch directly
          if (url.startsWith('google.navigation:') ||
              url.startsWith('comgooglemaps://')) {
            try {
              final launched =
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (launched) {
                print('   ✅ Opened successfully with: $url');
                opened = true;
                break;
              }
            } catch (e) {
              print('   ❌ Failed: $e');
              continue; // Try next URL
            }
          } else {
            // For https URLs, check first then launch
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              print('   ✅ Opened successfully with: $url');
              opened = true;
              break;
            }
          }
        } catch (e) {
          print('   ❌ Failed: $e');
          continue; // Try next URL
        }
      }

      if (!opened && mounted) {
        showHeaderNotification(
          context,
          title: AppLocalizations.of(context).error,
          message: AppLocalizations.of(context).cannotOpenGoogleMaps,
          type: NotificationType.error,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      print('❌ Google Maps error: $e');
      if (mounted) {
        showHeaderNotification(
          context,
          title: AppLocalizations.of(context).error,
          message: AppLocalizations.of(context).failedOpenGoogleMaps,
          type: NotificationType.error,
        );
      }
    }
  }

  void _openWaze(double latitude, double longitude) async {
    try {
      // Validate coordinates
      if (latitude.isNaN ||
          longitude.isNaN ||
          latitude.abs() > 90 ||
          longitude.abs() > 180) {
        throw Exception(AppLocalizations.of(context).invalidCoordinates);
      }

      print('🗺️ Opening Waze with: $latitude, $longitude');

      // Try multiple Waze URLs in order of preference
      final urls = [
        // Waze app URL with navigation
        'waze://?ll=$latitude,$longitude&navigate=yes',
        // Alternative Waze format
        'https://waze.com/ul?ll=$latitude,$longitude&navigate=yes',
        // Web fallback with direct coordinates
        'https://www.waze.com/ul?ll=$latitude,$longitude&navigate=yes&zoom=17',
      ];

      bool opened = false;
      for (final url in urls) {
        try {
          final uri = Uri.parse(url);
          print('   Trying: $url');

          // For waze:// scheme, try to launch directly
          if (url.startsWith('waze://')) {
            try {
              final launched =
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (launched) {
                print('   ✅ Opened successfully with: $url');
                opened = true;
                break;
              }
            } catch (e) {
              print('   ❌ Failed: $e');
              continue; // Try next URL
            }
          } else {
            // For https URLs, check first then launch
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              print('   ✅ Opened successfully with: $url');
              opened = true;
              break;
            }
          }
        } catch (e) {
          print('   ❌ Failed: $e');
          continue; // Try next URL
        }
      }

      if (!opened && mounted) {
        showHeaderNotification(
          context,
          title: AppLocalizations.of(context).error,
          message: AppLocalizations.of(context).cannotOpenWaze,
          type: NotificationType.error,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      print('❌ Waze error: $e');
      if (mounted) {
        showHeaderNotification(
          context,
          title: AppLocalizations.of(context).error,
          message: AppLocalizations.of(context).failedOpenWaze,
          type: NotificationType.error,
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapGestureDebounce?.cancel();
    if (_activeOrderListener != null) {
      _activeOrderProviderRef?.removeListener(_activeOrderListener!);
      _activeOrderListener = null;
      _activeOrderProviderRef = null;
    }
    // DriverStatusProvider and DriverLocationManager dispose via their
    // ChangeNotifierProvider / Provider — no manual cleanup needed here.
    ref.read(announcementProvider.notifier).stopChecking();
    _locationManager.dispose();
    _orderCardsPageController?.dispose();
    context.read<LocationProvider>().stopLocationTracking();
    _geocodedAddresses.clear();

    // Cleanup enhanced route manager
    // legacy route manager removed

    // Cleanup order card manager
    // legacy order card manager removed

    // Note: Don't stop persistent service on dispose - it should keep running in background
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    print('🔄 App lifecycle changed to $state');

    // When app is detached (swiped away from recent apps), set driver offline
    // Note: We don't trigger on 'paused' as that happens when switching apps temporarily
    if (state == AppLifecycleState.detached) {
      print('   Setting driver offline');
      _setDriverOfflineOnAppClose();
    }
    // When app is resumed, ensure UI is stable - don't clear cache
    else if (state == AppLifecycleState.resumed) {
      print('   App resumed - maintaining cached orders for stability');
      // Don't clear _cachedActiveOrders - this prevents flickering
      // The Consumer will update with fresh data naturally
    }
  }

  Future<void> _setDriverOfflineOnAppClose() async {
    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user != null && _isOnline) {
        await authProvider.setOnlineStatus(false);
        print('✅ Driver set to offline due to app close');
      }
    } catch (e) {
      print('❌ Error setting driver offline: $e');
    }
  }

  Future<void> _checkLocationAlwaysPermission() async {
    // Use Geolocator (CLLocationManager) for the authoritative iOS status check.
    // permission_handler's Permission.locationAlways.status is unreliable on iOS 13+
    // — it can return denied even when the user has granted "Always" in Settings.
    final geoPermission = await geo.Geolocator.checkPermission();
    final isAlways = geoPermission == geo.LocationPermission.always;
    setState(() {
      _hasLocationAlwaysPermission = isAlways;
    });
    print(
        '📍 Location Always Permission (Geolocator): ${isAlways ? "✅ Always" : "❌ $geoPermission"}');
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent dismissing with back button
        child: AlertDialog(
          title: const Text(
            'إذن الموقع مطلوب',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Text(
                    loc.locationPermissionDriverLong,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  );
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'هذا يسمح لك بـ:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Text(
                    loc.locationPermissionExplanation,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 14),
                  );
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return Text(
                      loc.pleaseAllowAlways,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);

                // Request permission (permission_handler handles the iOS two-step
                // whileInUse → always upgrade flow).
                await Permission.locationAlways.request();

                // Re-check with Geolocator — authoritative on iOS.
                await Future.delayed(const Duration(seconds: 1));
                await _checkLocationAlwaysPermission();

                // If still not always, open settings so the user can change it manually.
                if (!_hasLocationAlwaysPermission) {
                  await openAppSettings();
                  // Give the user time to return from Settings before re-checking.
                  await Future.delayed(const Duration(seconds: 2));
                  await _checkLocationAlwaysPermission();
                }

                // If still not granted, show dialog again
                if (!_hasLocationAlwaysPermission) {
                  _showLocationPermissionDialog();
                } else {
                  // Permission granted, initialize dashboard using shared method
                  print(
                      '✅ Permission granted! Starting full initialization...');
                  await _initializeDashboardWithPermission();

                  // Map will update automatically through coordinate change detection
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const ui.Size(double.infinity, 48),
              ),
              child: Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Text(
                    loc.openSettings,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showBackgroundLocationDisclosureAndRequest() async {
    // If "Always" is already granted, skip the disclosure dialog and permission
    // request entirely — calling requestAlwaysAuthorization() again when already
    // granted can confuse iOS's permission state machine.
    final existingPermission = await geo.Geolocator.checkPermission();
    if (existingPermission == geo.LocationPermission.always) {
      // Silently request notifications (non-blocking — driver can work without them).
      await Permission.notification.request();
      return true;
    }

    // Permission is not yet "Always" — show disclosure then request.
    bool accepted = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context).backgroundLocationPermissionTitle,
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.location_on, size: 48, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).backgroundLocationExplanation,
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
        actions: [
          Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(loc.cancel),
              );
            },
          ),
          Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return ElevatedButton(
                onPressed: () {
                  accepted = true;
                  Navigator.pop(context);
                },
                child: Text(loc.agree),
              );
            },
          ),
        ],
      ),
    );
    if (!accepted) return false;

    // Request background location — permission_handler handles the iOS two-step
    // whileInUse → always upgrade flow.
    await Permission.locationAlways.request();

    // Use Geolocator for the authoritative status check.
    final geoPermission = await geo.Geolocator.checkPermission();
    if (geoPermission != geo.LocationPermission.always) {
      _showLocationPermissionDialog();
      return false;
    }

    // Silently request notifications — driver can work without them.
    await Permission.notification.request();
    return true;
  }

  // Countdown is now handled by order_timeout_state table
  // No local timer needed - just display the value from database

  // Location tracking is now fully managed by DriverLocationManager.
  // These thin wrappers preserve call-site compatibility across the file.




  Future<void> _updateDriverLocation() async {
    // Only update if driver is online
    if (!_isOnline) {
      print('ℹ️ Skipping location update - driver is offline');
      return;
    }

    try {
      print('🔄 _updateDriverLocation called...');
      final locationProvider = context.read<LocationProvider>();
      final authProvider = context.read<AuthProvider>();

      // ANR FIX: Add timeout to prevent blocking main thread
      // Get current location with timeout
      print('   📍 Getting current location from GPS...');
      final position = await locationProvider
          .getCurrentLocation()
          .timeout(const Duration(seconds: 5), onTimeout: () {
        print('   ⚠️ Location fetch timed out');
        return null;
      });

      if (position != null && authProvider.user != null && _isOnline) {
        print(
            '   ✅ GPS position obtained: ${position.latitude}, ${position.longitude}');

        // ANR FIX: Add timeout to database update
        // Update location in database (with full GPS data)
        print('   💾 Saving to database...');
        final updateResult = await authProvider
            .updateUserLocation(
          position.latitude,
          position.longitude,
          accuracy: position.accuracy,
          heading: position.heading,
          speed: position.speed,
        )
            .timeout(const Duration(seconds: 5), onTimeout: () {
          print('   ⚠️ Database update timed out');
          return false;
        });

        if (updateResult) {
          print(
              '   ✅ Driver location updated in DB: ${position.latitude}, ${position.longitude}');
        } else {
          print('   ❌ Failed to update driver location in DB');
          print('   ❌ AuthProvider error: ${authProvider.error}');
        }
        print(
            '   📡 LocationProvider currentPosition: ${locationProvider.currentPosition}');

        // Check dropoff proximity for active orders (non-blocking)
        unawaited(_checkDropoffProximity(position));
      } else {
        print(
            '   ❌ Cannot update: position=$position, user=${authProvider.user != null}');
      }
    } catch (e) {
      print('❌ Error updating driver location: $e');
      print('   Stack: ${StackTrace.current}');
    }
  }

  /// Check if driver is within 200m of dropoff location and stop timer
  Future<void> _checkDropoffProximity(geo.Position driverPosition) async {
    try {
      final orderProvider = context.read<OrderProvider>();
      final authProvider = context.read<AuthProvider>();

      if (authProvider.user == null) return;

      // Get active orders that are on_the_way
      final activeOrders = orderProvider.orders
          .where((order) =>
              order.isOnTheWay &&
              order.driverId == authProvider.user!.id &&
              order.deliveryTimerStartedAt != null &&
              order.deliveryTimerStoppedAt == null)
          .toList();

      if (activeOrders.isEmpty) return;

      // Check each order
      for (final order in activeOrders) {
        try {
          final result = await Supabase.instance.client.rpc(
            'check_dropoff_proximity',
            params: {
              'p_order_id': order.id,
              'p_driver_id': authProvider.user!.id,
              'p_driver_latitude': driverPosition.latitude,
              'p_driver_longitude': driverPosition.longitude,
            },
          );

          if (result is Map && result['timer_stopped'] == true) {
            print(
                '✅ Timer stopped for order ${order.id} - driver reached dropoff');
            // Reload orders to get updated timer status
            await orderProvider.initialize();
          }
        } catch (e) {
          print(
              '⚠️ Error checking dropoff proximity for order ${order.id}: $e');
        }
      }
    } catch (e) {
      print('❌ Error in _checkDropoffProximity: $e');
    }
  }

  Future<void> _updateDriverLocationFromDatabase() async {
    try {
      print('🔄 _updateDriverLocationFromDatabase called...');
      final authProvider = context.read<AuthProvider>();
      final locationProvider = context.read<LocationProvider>();

      if (authProvider.user != null) {
        print('   📥 Fetching user data from database...');
        // ANR FIX: Add timeout to prevent blocking main thread
        // Fetch latest user data from database with timeout
        await authProvider.refreshUser().timeout(const Duration(seconds: 5),
            onTimeout: () {
          print('   ⚠️ User refresh timed out');
        });

        // Update location provider with database location
        if (authProvider.user?.latitude != null &&
            authProvider.user?.longitude != null) {
          print(
              '   ✅ Got DB location: ${authProvider.user!.latitude}, ${authProvider.user!.longitude}');

          // Create a mock Position object from database coordinates
          final dbPosition = _createMockPosition(
            authProvider.user!.latitude!,
            authProvider.user!.longitude!,
          );

          // Update location provider's current position
          locationProvider.updateCurrentPosition(dbPosition);

          print('   ✅ LocationProvider updated with DB location');
          print(
              '   📡 LocationProvider currentPosition: ${locationProvider.currentPosition}');
        } else {
          print(
              '   ⚠️ No location in database: lat=${authProvider.user?.latitude}, lng=${authProvider.user?.longitude}');
        }
      } else {
        print('   ❌ No user logged in');
      }
    } catch (e) {
      print('❌ Error updating driver location from database: $e');
      print('   Stack: ${StackTrace.current}');
    }
  }

  // Helper method to create mock Position from database coordinates
  dynamic _createMockPosition(double latitude, double longitude) {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now(),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Check auth state - redirect if not authenticated (allow demo mode)
    final authProvider = context.watch<AuthProvider>();
    if (!authProvider.isAuthenticated && !authProvider.isDemoMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/');
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        // If sidebar is open, close it instead of exiting
        if (_showSidebar) {
          setState(() {
            _showSidebar = false;
          });
          return false;
        }
        // Otherwise, allow normal back behavior
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.primary, // Hur teal background
        // extendBody: true lets the body fill the entire screen including the
        // system nav bar zone. NavigationBarAwareFooterWrapper uses
        // viewPadding.bottom to reserve the nav bar area, so nothing is obscured.
        // Without this, the Scaffold clips the body above the nav bar and the
        // wrapper's transparent nav-bar zone shows the map — making cards "float".
        extendBody: true,
        body: NavigationOverlayScope(
          child: Stack(
            children: [
              // HIGHEST Z-INDEX: Simple location update notification system
              if (authProvider.user?.id != null)
                SimpleLocationUpdateWidget(
                  driverId: authProvider.user!.id,
                  onLocationUpdate: (orderId, lat, lng) {
                    print(
                        '📍 Driver received location update for order $orderId: $lat, $lng');
                    _handleLocationUpdate();
                  },
                  onRouteRebuildNeeded: () {
                    print(
                        '🔄 Route rebuild requested from location update popup');
                    _forceMapRouteRebuild();
                  },
                ),

              // ── Map section ────────────────────────────────────────────────────
              // DriverMapSection replaces Consumer3<LocationProvider, AuthProvider,
              // OrderProvider>.  It uses two nested Selectors so the map only
              // rebuilds when the driver position OR the active order list changes.
              DriverMapSection(
                hasLocationPermission: _hasLocationAlwaysPermission,
                mapKey: _mapWidgetKey ??=
                    GlobalKey<StateOfTheArtMapWidgetState>(),
                isOrderCardExpanded: _isOrderCardExpanded,
                bottomOverlayInset: _bottomOverlayInset,
                // The dashboard does not depend on map camera position, so the
                // map gestures must NOT trigger a rebuild of this 7900-line
                // widget. Any subtree that needs the camera should subscribe
                // via its own ValueNotifier.
                onCameraMoved: null,
                // bottomOverlay built here so _buildSwipeableOrderCards stays in
                // the shell without needing to be extracted.
                bottomOverlay: Selector<ActiveOrderProvider, List<OrderModel>>(
                  selector: (_, ap) => ap.orders,
                  builder: (context, orders, _) {
                    if (orders.isEmpty) return const SizedBox.shrink();

                    final allItems =
                        orders.map((o) => _RegularOrderItem(o)).toList();

                    return Stack(
                      children: [
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: NavigationBarAwareFooterWrapper(
                            id: 'order_cards',
                            backgroundColor: Colors.transparent,
                            navBarZoneColor: AppColors.primary,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: _buildSwipeableOrderCards(allItems),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Status Bar Background - Provides contrast for system icons
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: MediaQuery.paddingOf(context).top,
                  color: AppColors.primary,
                ),
              ),

              // Rank Badge and Timer - Top center of map
              //
              // Uses ActiveOrderProvider so that:
              //   • The timer follows the currently swiped card (current focused order).
              //   • The rank badge is hidden whenever there are active orders.
              Consumer2<AuthProvider, ActiveOrderProvider>(
                builder: (context, authProvider, activeOrderProvider, _) {
                  final driver = authProvider.user;

                  // Hide rank badge when the driver has any active orders.
                  final hasOrders = activeOrderProvider.hasOrders;
                  final hasRank = !hasOrders &&
                      driver != null &&
                      driver.role == 'driver' &&
                      driver.rank != null;

                  // Show the timer for the currently focused card, but only if it
                  // is on_the_way and has an active (not yet stopped) delivery timer.
                  final focusedOrder = activeOrderProvider.current;
                  final OrderModel? timerOrder = (focusedOrder != null &&
                          focusedOrder.isOnTheWay &&
                          focusedOrder.deliveryTimerExpiresAt != null &&
                          focusedOrder.deliveryTimerStoppedAt == null)
                      ? focusedOrder
                      : null;
                  final hasActiveTimer = timerOrder != null;

                  if (!hasRank && !hasActiveTimer) {
                    return const SizedBox.shrink();
                  }

                  return Positioned(
                    top: MediaQuery.paddingOf(context).top + 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasRank)
                            GestureDetector(
                              onTap: () => context.push('/driver/rank'),
                              child: _buildRankBadge(driver.rank!),
                            ),
                          if (hasRank && hasActiveTimer)
                            const SizedBox(height: 8),
                          if (hasActiveTimer) DriverTimerBanner(order: timerOrder),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // ── Bottom navigation bar ───────────────────────────────────────────
              // Replaced Consumer2<OrderProvider,AuthProvider> with DriverBottomNav.
              // Uses Selector<ActiveOrderProvider,bool> + Selector<DriverStatusProvider,bool>
              // so it only rebuilds on hasOrders / isOnline changes.
              DriverBottomNav(
                showSidebar: _showSidebar,
                onOpenSupport: _openSupportChat,
                onToggleSidebar: () =>
                    setState(() => _showSidebar = !_showSidebar),
                toggleWidget: _buildOnlineToggleButton(),
              ),

              // ── Header buttons (support + sidebar toggle, shown over map) ───────
              // Replaced Consumer2<OrderProvider,AuthProvider> with DriverHeaderButtons.
              // Only rebuilds when ActiveOrderProvider.hasOrders changes.
              DriverHeaderButtons(
                showSidebar: _showSidebar,
                onOpenSupport: _openSupportChat,
                onToggleSidebar: () =>
                    setState(() => _showSidebar = !_showSidebar),
              ),

              // ── Sidebar ─────────────────────────────────────────────────────────
              // Replaced Consumer2<OrderProvider,AuthProvider> with DriverSidebar.
              // DriverSidebar uses context.read<AuthProvider>() (no subscription)
              // so it never rebuilds from provider changes mid-session.
              DriverSidebar(
                visible: _showSidebar,
                onClose: () => setState(() => _showSidebar = false),
                onOpenSupport: _openSupportChat,
              ),
            ],
          ),
        ),
      ),
    );
  }



  /// Handle location update - simplified
  Future<void> _handleLocationUpdate() async {
    print('🔄 Handling location update - refreshing order data...');

    try {
      // Refresh order provider to get updated coordinates
      final orderProvider = context.read<OrderProvider>();
      await orderProvider.initialize();

      // Force a rebuild to trigger map widget's didUpdateWidget
      // which will detect coordinate changes and recalculate routes
      if (mounted) {
        setState(() {
          // This triggers a rebuild which will cause the map widget
          // to detect coordinate changes in didUpdateWidget
        });

        print(
            '✅ Location update handled - map will detect coordinate changes and update');
        print(
            '   Map widget will clear old annotations and create new ones automatically');
      }
    } catch (e) {
      print('❌ Error handling location update: $e');
    }
  }

  /// Force map route rebuild - called from location update popup
  Future<void> _forceMapRouteRebuild() async {
    print(
        '🔄 Forcing map route rebuild after location update acknowledgment...');

    try {
      // Refresh order provider to ensure we have the latest coordinates
      final orderProvider = context.read<OrderProvider>();
      await orderProvider.initialize();

      // Get the active order with updated coordinates
      final authProvider = context.read<AuthProvider>();
      final driverId = authProvider.user?.id;

      if (driverId != null) {
        final activeOrders =
            orderProvider.getAllActiveOrdersForDriver(driverId);
        if (activeOrders.isNotEmpty) {
          final currentOrder = activeOrders.first;
          print('📍 Active order found: ${currentOrder.id}');
          print(
              '📍 Delivery coordinates: (${currentOrder.deliveryLatitude}, ${currentOrder.deliveryLongitude})');

          // CRITICAL: Clear the coordinate cache to force recalculation
          // Access the map widget state and clear its cache
          if (_mapWidgetKey?.currentState != null) {
            print('🧹 Clearing coordinate cache in map widget...');
            _mapWidgetKey!.currentState!.clearCoordinateCache();

            // Directly trigger route recalculation on the map widget
            print('🔄 Directly triggering route recalculation...');
            await _mapWidgetKey!.currentState!
                .forceRouteRecalculation(currentOrder);
          }

          // Force a complete rebuild to ensure UI updates
          if (mounted) {
            setState(() {
              // Force rebuild to ensure all UI elements reflect the changes
            });

            print('✅ Route recalculation completed and UI updated');
          }
        } else {
          print('⚠️  No active orders found for route rebuild');
        }
      } else {
        print('⚠️  No driver ID found for route rebuild');
      }
    } catch (e) {
      print('❌ Error forcing map route rebuild: $e');
    }
  }



  Widget _buildRankBadge(String rank) {
    final loc = AppLocalizations.of(context);
    String rankName;
    List<Color> gradientColors;
    List<Color> borderColors;
    IconData badgeIcon;
    Color iconColor;
    Color shadowColor;

    switch (rank.toLowerCase()) {
      case 'gold':
        rankName = loc.goldRank;
        gradientColors = [
          const Color(0xFFB8860B), // Dark Goldenrod
          const Color(0xFFDAA520), // Goldenrod
        ];
        borderColors = [
          const Color(0xFFFFD700).withValues(alpha: 0.8),
          const Color(0xFFB8860B).withValues(alpha: 0.3),
        ];
        badgeIcon = Icons.workspace_premium_rounded;
        iconColor = const Color(0xFFFFF8E1);
        shadowColor = const Color(0xFFDAA520).withValues(alpha: 0.4);
        break;
      case 'silver':
        rankName = loc.silverRank;
        gradientColors = [
          const Color(0xFF546E7A), // Blue Grey
          const Color(0xFF78909C), // Lighter Blue Grey
        ];
        borderColors = [
          const Color(0xFFCFD8DC).withValues(alpha: 0.8),
          const Color(0xFF455A64).withValues(alpha: 0.3),
        ];
        badgeIcon = Icons.military_tech_rounded;
        iconColor = const Color(0xFFECEFF1);
        shadowColor = const Color(0xFF78909C).withValues(alpha: 0.4);
        break;
      case 'bronze':
        rankName = loc.bronzeRank;
        gradientColors = [
          const Color(0xFF6D4C41), // Brown (Bronze base)
          const Color(0xFF8D6E63), // Lighter Brown
        ];
        borderColors = [
          const Color(0xFFD7CCC8).withValues(alpha: 0.8),
          const Color(0xFF5D4037).withValues(alpha: 0.3),
        ];
        badgeIcon = Icons.star_rounded;
        iconColor = const Color(0xFFEFEBE9);
        shadowColor = const Color(0xFF8D6E63).withValues(alpha: 0.4);
        break;
      case 'trial':
        rankName = loc.trialRank;
        gradientColors = [
          const Color(0xFF1565C0), // Blue 800
          const Color(0xFF1E88E5), // Blue 600
        ];
        borderColors = [
          const Color(0xFFBBDEFB).withValues(alpha: 0.8),
          const Color(0xFF0D47A1).withValues(alpha: 0.3),
        ];
        badgeIcon = Icons.verified_rounded;
        iconColor = const Color(0xFFE3F2FD);
        shadowColor = const Color(0xFF1E88E5).withValues(alpha: 0.4);
        break;
      default:
        rankName = loc.bronzeRank;
        gradientColors = [
          const Color(0xFF5D4037),
          const Color(0xFF8D6E63),
        ];
        borderColors = [
          const Color(0xFFD7CCC8),
          const Color(0xFF5D4037),
        ];
        badgeIcon = Icons.star_rounded;
        iconColor = Colors.white;
        shadowColor = Colors.black26;
        break;
    }

    return Container(
      height: 64, // Sleek height
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1.5,
          ),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.1),
              Colors.transparent,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon Circle
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.2),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Icon(
                badgeIcon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // Text
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rankName.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: 2,
                    width: 20,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

}

// Top-level bottom sheet widget for uploading order proof
class _AcceptButtonWithLongPress extends StatefulWidget {
  final String orderId;
  final VoidCallback onAccept;

  const _AcceptButtonWithLongPress({
    required this.orderId,
    required this.onAccept,
  });

  @override
  State<_AcceptButtonWithLongPress> createState() =>
      _AcceptButtonWithLongPressState();
}

class _AcceptButtonWithLongPressState extends State<_AcceptButtonWithLongPress>
    with SingleTickerProviderStateMixin {
  Timer? _pressTimer;
  Timer? _timeoutTimer;
  double _progress = 0.0;
  bool _isPressed = false;
  int _lastHapticStep = -1;
  int _remainingSeconds = 30; // Default until loaded
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Start timeout tracking
    _updateTimeout();
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateTimeout();
    });
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    _timeoutTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _updateTimeout() {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final newRemaining = orderProvider.getLiveAcceptCountdownSeconds(widget.orderId);

    if (newRemaining != _remainingSeconds) {
      if (mounted) {
        setState(() {
          _remainingSeconds = newRemaining;
        });
      }
    }
  }

  void _startPress() {
    if (_isPressed) return;

    setState(() {
      _isPressed = true;
      _progress = 0.0;
      _lastHapticStep = -1;
    });
    _animationController.forward();
    HapticFeedback.mediumImpact();

    const duration = Duration(seconds: 1);
    const interval = Duration(milliseconds: 50);
    final increment = 1.0 / (duration.inMilliseconds / interval.inMilliseconds);

    _pressTimer = Timer.periodic(interval, (timer) {
      if (mounted) {
        setState(() {
          _progress += increment;

          final currentStep =
              (timer.tick * interval.inMilliseconds / 500).floor();
          if (currentStep > _lastHapticStep && currentStep < 6) {
            _lastHapticStep = currentStep;
            HapticFeedback.selectionClick();
          }

          if (_progress >= 1.0) {
            _progress = 1.0;
            timer.cancel();
            _completePress();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _cancelPress() {
    _pressTimer?.cancel();
    _animationController.reverse();
    if (mounted) {
      setState(() {
        _isPressed = false;
        _progress = 0.0;
      });
    }
  }

  void _completePress() {
    _pressTimer?.cancel();
    HapticFeedback.heavyImpact();
    widget.onAccept();
    if (mounted) {
      setState(() {
        _isPressed = false;
        _progress = 0.0;
      });
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate drainout factor (0.0 to 1.0)
    // Assuming 30s is max. Clamp between 0 and 1.
    final double timeoutFactor = (_remainingSeconds / 30.0).clamp(0.0, 1.0);

    final buttonText = _isPressed
        ? '${(1 - (_progress * 1)).ceil()}...'
        : '${AppLocalizations.of(context).acceptOrderButton} (${_remainingSeconds}s)';

    return GestureDetector(
      onTapDown: (_) => _startPress(),
      onTapUp: (_) => _cancelPress(),
      onTapCancel: _cancelPress,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors
                    .grey.shade800, // Background when drained (Empty part)
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // 1. Drainout Bar (The colored part that shrinks)
                    Align(
                      alignment: Alignment
                          .centerLeft, // Or right for RTL? Let's assume Left->Right fill means Left alignment
                      child: FractionallySizedBox(
                        widthFactor: timeoutFactor,
                        heightFactor: 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade400,
                                Colors.green.shade600
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 2. Long Press Progress Overlay (White transparency)
                    if (_isPressed)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _progress,
                          heightFactor: 1.0,
                          child: Container(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ),

                    // 3. Text and Icon
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!_isPressed) ...[
                            const Icon(Icons.check_circle_outline,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            buttonText,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Timeout countdown pill widget that updates in real-time
class _TimeoutCountdownPill extends StatefulWidget {
  final dynamic order;

  const _TimeoutCountdownPill({
    required this.order,
  });

  @override
  State<_TimeoutCountdownPill> createState() => _TimeoutCountdownPillState();
}

class _TimeoutCountdownPillState extends State<_TimeoutCountdownPill> {
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _updateRemainingSeconds();
    // Update every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateRemainingSeconds();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _updateRemainingSeconds() {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final newRemaining = orderProvider.getLiveAcceptCountdownSeconds(widget.order.id);

    if (mounted && newRemaining != _remainingSeconds) {
      setState(() {
        _remainingSeconds = newRemaining;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingSeconds <= 0) return const SizedBox.shrink();

    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final timeString = minutes > 0
        ? '$minutes:${seconds.toString().padLeft(2, '0')}'
        : '$seconds';

    final Color pillColor = _remainingSeconds <= 10
        ? Colors.red.shade400
        : _remainingSeconds <= 20
            ? Colors.orange.shade400
            : Colors.white.withValues(alpha: 0.2);

    return Container(
      // Margin handled by parent
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: pillColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: pillColor.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timer_outlined,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            timeString,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
