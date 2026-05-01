import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/foundation.dart'
    show unawaited, kIsWeb, kReleaseMode, debugPrint;
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart' as ip;
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
import '../../../core/widgets/header_notification.dart';
import '../../../core/services/order_redirect_service.dart';
import '../../../core/providers/announcement_provider.dart';
import '../../../core/providers/system_status_provider.dart';
import '../../../core/providers/notification_provider.dart';
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
import '../services/driver_location_manager.dart';
import '../widgets/driver_map_section.dart';
import '../widgets/driver_bottom_nav.dart';
import '../widgets/driver_header_buttons.dart';
import '../widgets/driver_sidebar.dart';

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
      ],
      child: const _DriverDashboardCore(),
    );
  }
}

// Wrapper classes to handle both regular orders and bulk orders
abstract class _OrderItem {
  String get id;
  String get status;
}

class _RegularOrderItem extends _OrderItem {
  final OrderModel order;
  _RegularOrderItem(this.order);

  @override
  String get id => order.id;

  @override
  String get status => order.status;
}

class _DriverDashboardCore extends StatefulWidget {
  const _DriverDashboardCore();

  @override
  State<_DriverDashboardCore> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<_DriverDashboardCore>
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

  Widget _buildSupportShortcut({bool onPrimaryBackground = false}) {
    final backgroundColor =
        onPrimaryBackground ? Colors.white.withValues(alpha: 0.15) : Colors.white;
    final iconColor = onPrimaryBackground ? Colors.white : AppColors.primary;
    final border = onPrimaryBackground
        ? Border.all(color: Colors.white.withValues(alpha: 0.5))
        : null;
    final boxShadow = onPrimaryBackground
        ? <BoxShadow>[]
        : <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: _openSupportChat,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: border,
            shape: BoxShape.circle,
            boxShadow: boxShadow,
          ),
          child: Icon(
            Icons.support_agent,
            color: iconColor,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarToggleButton() {
    return Container(
      decoration: BoxDecoration(
        color: context.themeSurface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          _showSidebar ? Icons.home_rounded : Icons.menu_rounded,
          color: context.themePrimary,
          size: 28,
        ),
        onPressed: () {
          setState(() {
            _showSidebar = !_showSidebar;
          });
        },
      ),
    );
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
          final systemStatus = context.read<SystemStatusProvider>();
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
              notificationProvider: context.read<NotificationProvider>(),
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
        await context.read<SystemStatusProvider>().initialize();

        if (authProvider.user != null) {
          await context.read<AnnouncementProvider>().initialize(
                userRole: 'driver',
                userId: authProvider.user!.id,
                context: context,
              );

          final systemStatus = context.read<SystemStatusProvider>();
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
          allItemsToShow.where((item) => item.status == 'pending').toList();
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
        final isPendingOrder = currentItem?.status == 'pending';
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
    final isPending = order.status == 'pending';
    final isAssigned = order.status == 'assigned';
    final isAccepted = order.status == 'accepted';
    final isOnTheWay = order.status == 'on_the_way';

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
    final isPending = order.status == 'pending';
    final isAssigned = order.status == 'assigned';
    final isAccepted = order.status == 'accepted';
    final isOnTheWay = order.status == 'on_the_way';
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
                  child: (order.status == 'pending' ||
                              order.status == 'assigned') &&
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

  // Bulk order methods removed - bulk orders are no longer supported

  Widget _buildCompactInfoRow(
      {required IconData icon, required String label, required String value}) {
    return Container(
      padding: context.rp(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(context.rs(8)),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: context.ri(16)),
          SizedBox(width: context.rs(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ResponsiveText(
                  label,
                  style: TextStyle(
                    color: context.themeTextSecondary,
                    fontSize: context.rf(11),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: context.rs(2)),
                ResponsiveText(
                  value,
                  style: TextStyle(
                    color: context.themeTextPrimary,
                    fontSize: context.rf(14),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernAddressRow(
      {required IconData icon,
      required Color iconColor,
      required String address,
      required dynamic order,
      required bool isPickup}) {
    return InkWell(
      onTap: () {
        // Navigate to pickup or dropoff when clicking on the address row
        _openInMaps(order, isPickup: isPickup);
      },
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              address,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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

  Widget _buildDistancePill(dynamic order) {
    if (order == null) return const SizedBox.shrink();

    final double routeDistanceMeters = LocationService.calculateDistance(
      order.pickupLatitude,
      order.pickupLongitude,
      order.deliveryLatitude,
      order.deliveryLongitude,
    );
    final String distanceText =
        LocationService.getFormattedDistance(routeDistanceMeters);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
            alpha: 0.2), // Glass effect for visibility on primary background
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
            Icons.route_outlined,
            color: Colors.white,
            size: 20,
          ),
          SizedBox(width: context.rs(8)),
          Text(
            distanceText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            textDirection: TextDirection.ltr,
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

  Widget _buildHeaderStatChip({
    required String label,
    required String value,
    Color? backgroundColor,
    Color? borderColor,
    Color? labelColor,
    Color? valueColor,
    IconData? icon,
    Color? iconColor,
  }) {
    final bg = backgroundColor ?? Colors.white.withValues(alpha: 0.18);
    final border = borderColor ?? Colors.white.withValues(alpha: 0.22);
    final labelTextColor = labelColor ?? Colors.white70;
    final valueTextColor = valueColor ?? Colors.white;

    return Container(
      padding: context.rp(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(context.rs(12)),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: context.ri(18),
              color: iconColor ?? valueTextColor,
            ),
            SizedBox(width: context.rs(8)),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              ResponsiveText(
                label,
                style: TextStyle(
                  color: labelTextColor,
                  fontSize: context.rf(11), // Increased from 10
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: context.rs(2)),
              ResponsiveText(
                value,
                style: TextStyle(
                  color: valueTextColor,
                  fontSize: context.rf(16), // Increased from 13
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
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
    final isAccepted = order.status == 'accepted';
    final isOnTheWay = order.status == 'on_the_way';

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
            child: _OrderProofUploader(
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

  Widget _buildAddressRow(
      {required IconData icon,
      required String label,
      required String address,
      bool isPickup = false,
      required dynamic order}) {
    // Match pin colors: Teal for pickup, Orange for dropoff
    final addressColor = isPickup ? AppColors.primary : AppColors.warning;

    return InkWell(
      onTap: () {
        // Navigate to pickup or dropoff when clicking anywhere on the address row
        _openInMaps(order, isPickup: isPickup);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: addressColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: addressColor.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: addressColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: addressColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Quick navigation button indicator
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: addressColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.navigation,
                          color: addressColor,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: TextStyle(
                      color: context.themeTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetailRow(
      IconData icon, String label, String value, Color iconColor) {
    return Row(
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 20,
        ),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: AppTextStyles.bodyMedium.copyWith(
            color: context.themeTextSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.themeTextPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactOrderDetailRow(
      IconData icon, String label, String value, Color iconColor) {
    return Row(
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 16,
        ),
        SizedBox(width: context.rs(8)),
        Text(
          '$label: ',
          style: AppTextStyles.bodySmall.copyWith(
            color: context.themeTextSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.themeTextPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeoutCountdownPill(dynamic order) {
    return _TimeoutCountdownPill(order: order);
  }

  Widget _buildCountdownTimer(String orderId) {
    // Get timeout from OrderProvider (from order_timeout_state table)
    final orderProvider = context.watch<OrderProvider>();
    final remainingSeconds = orderProvider.getTimeoutRemaining(orderId) ?? 0;

    final progress = remainingSeconds / 30.0;
    final Color timerColor = remainingSeconds <= 10
        ? Colors.red.shade300
        : remainingSeconds <= 20
            ? Colors.orange.shade300
            : Colors.white;

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular progress indicator
          SizedBox(
            width: 46,
            height: 46,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(timerColor),
            ),
          ),
          // Countdown text
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$remainingSeconds',
                style: TextStyle(
                  color: timerColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  height: 1.0,
                ),
              ),
              Text(
                'ثا',
                style: TextStyle(
                  color: timerColor.withValues(alpha: 0.8),
                  fontSize: 9,
                  height: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatReadyCountdown(int seconds) {
    if (seconds <= 0) return 'الآن';

    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '$hoursس $minutesد';
    } else if (minutes > 0) {
      return '$minutesد $secsث';
    } else {
      return '$secsث';
    }
  }

  String _formatReadyCountdownWestern(int seconds) {
    if (seconds <= 0) return '00:00';

    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildActionButtons(dynamic order) {
    final isPending = order.status == 'pending';
    final isAssigned = order.status == 'assigned';
    final isAccepted = order.status == 'accepted';
    final isOnTheWay = order.status == 'on_the_way';

    if (isPending || isAssigned) {
      // Show Accept/Reject buttons for pending/assigned orders
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _acceptOrder(order.id),
              icon: const Icon(Icons.check, size: 18),
              label: Text(AppLocalizations.of(context).acceptOrder),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _rejectOrder(order.id),
              icon: const Icon(Icons.close, size: 18),
              label: Text(AppLocalizations.of(context).rejectOrder),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // Show action buttons for other statuses
      return Column(
        children: [
          // Primary action button
          if (isAccepted) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _markOrderOnTheWay(order.id),
                icon: const Icon(Icons.directions_car, size: 18),
                label: Text(AppLocalizations.of(context).startDelivery),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ] else if (isOnTheWay) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _markOrderDelivered(order.id),
                icon: const Icon(Icons.done_all, size: 18),
                label: Text(AppLocalizations.of(context).markDelivered),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Secondary action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callMerchant(order.merchantId),
                  icon: const Icon(Icons.business, size: 16),
                  label: Text(AppLocalizations.of(context).merchantButton),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.rs(8)),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _callCustomer(order.customerPhone, order.customerName),
                  icon: const Icon(Icons.phone, size: 16),
                  label: Text(AppLocalizations.of(context).customerButton),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: const BorderSide(color: AppColors.success),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.rs(8)),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openInMaps(order),
                  icon: const Icon(Icons.map, size: 16),
                  label: Text(AppLocalizations.of(context).mapButton),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: const BorderSide(color: AppColors.warning),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildCompactActionButtons(dynamic order) {
    final isPending = order.status == 'pending';
    final isAssigned = order.status == 'assigned';
    final isAccepted = order.status == 'accepted';
    final isOnTheWay = order.status == 'on_the_way';

    if (isPending || isAssigned) {
      // Bigger Accept/Reject buttons
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              onPressed: () => _acceptOrder(order.id),
              icon: const Icon(Icons.check_circle, size: 22),
              label: const Text('قبول الطلب',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 2,
                shadowColor: AppColors.success.withValues(alpha: 0.3),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: OutlinedButton.icon(
              onPressed: () => _rejectOrder(order.id),
              icon: const Icon(Icons.close, size: 20),
              label: const Text('رفض',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                backgroundColor: AppColors.error.withValues(alpha: 0.05),
              ),
            ),
          ),
        ],
      );
    } else {
      // Compact action buttons for accepted/on_the_way orders
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick Action Buttons
          Row(
            children: [
              // Call Merchant
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callMerchant(order.merchantId),
                  icon: const Icon(Icons.business, size: 18),
                  label: const Text('التاجر',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.05),
                  ),
                ),
              ),
              SizedBox(width: context.rs(8)),
              // Call Customer
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _callCustomer(order.customerPhone, order.customerName),
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('العميل',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: const BorderSide(color: AppColors.success, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                    backgroundColor: AppColors.success.withValues(alpha: 0.05),
                  ),
                ),
              ),
              SizedBox(width: context.rs(8)),
              // Open in Maps
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openInMaps(order),
                  icon: const Icon(Icons.map, size: 18),
                  label: Text(AppLocalizations.of(context).mapButton,
                      style:
                          const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: const BorderSide(color: AppColors.warning, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                    backgroundColor: AppColors.warning.withValues(alpha: 0.05),
                  ),
                ),
              ),
            ],
          ),
          // Primary Action Button
          if (isAccepted) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _markOrderOnTheWay(order.id),
                icon: const Icon(Icons.local_shipping, size: 20),
                label: Text(AppLocalizations.of(context).pickedUpStartDelivery,
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                  shadowColor: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
            ),
          ] else if (isOnTheWay) ...[
            // Show timer widget if timer is active
            if (order.deliveryTimerExpiresAt != null) ...[
              const SizedBox(height: 10),
              DeliveryTimerWidget(order: order),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _markOrderDelivered(order.id),
                icon: const Icon(Icons.check_circle, size: 20),
                label: const Text('تم التسليم',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                  shadowColor: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
            ),
          ],
        ],
      );
    }
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

  String _getOrderStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'في الانتظار';
      case 'assigned':
        return 'تم التخصيص';
      case 'accepted':
        return 'تم القبول';
      case 'on_the_way':
        return 'في الطريق';
      case 'delivered':
        return 'تم التسليم';
      case 'cancelled':
        return 'ملغي';
      case 'unassigned':
        return 'غير مخصص';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'غير معروف';
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

  Future<void> _markOrderOnTheWayOld(String orderId) async {
    final loc = AppLocalizations.of(context);
    final orderProvider = context.read<OrderProvider>();

    try {
      final success =
          await orderProvider.markOrderOnTheWay(orderId, context: context);

      // Clear cached orders to force immediate refresh
      if (mounted) {
        setState(() {
          _cachedActiveOrders = null;
        });

        if (success) {
          showHeaderNotification(
            context,
            title: 'في الطريق',
            message: 'تم بدء التوصيل للعميل',
            type: NotificationType.success,
          );
        } else {
          showHeaderNotification(
            context,
            title: 'خطأ',
            message: orderProvider.error ?? loc.error,
            type: NotificationType.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showHeaderNotification(
          context,
          title: 'خطأ',
          message: orderProvider.error ?? 'حدث خطأ في العملية',
          type: NotificationType.error,
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

  void _callPhone(String phone, String name) {
    _showContactDialog(
      context: context,
      name: name,
      phone: phone,
      title: 'الاتصال',
      icon: Icons.phone,
      color: AppColors.primary,
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

  String _getDateDifferenceText(DateTime orderDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final orderDay = DateTime(orderDate.year, orderDate.month, orderDate.day);
    final difference = orderDay.difference(today).inDays;

    final loc = AppLocalizations.of(context);

    if (difference == 0) {
      return loc.today;
    } else if (difference == 1) {
      return 'غداً'; // Tomorrow (Arabic) / Tomorrow (English)
    } else if (difference == 2) {
      return 'بعد غد'; // Day after tomorrow
    } else {
      return 'خلال $difference ${loc.daysShort}'; // In X days
    }
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
    } else if (order.status == 'pending' ||
        order.status == 'assigned' ||
        order.status == 'accepted') {
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
    context.read<AnnouncementProvider>().stopChecking();
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

  void _startLocationTracking() {
    _locationManager.start(
      authProvider: context.read<AuthProvider>(),
      locationProvider: context.read<LocationProvider>(),
      orderProvider: context.read<OrderProvider>(),
    );
  }

  void _startDriverLocationTracking() {
    // The redundant 10-second DB readback timer has been removed.
    // DriverLocationManager.start() handles everything in one 5-second push timer.
  }

  void _stopLocationTracking() {
    _locationManager.stop();
    // Foreground LocationProvider tracking is intentionally kept running for
    // map display while offline — DriverLocationManager.stop() does not
    // stop it.
  }

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
                          if (hasActiveTimer) _buildProminentTimer(timerOrder),
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
              if (false) // DEAD CODE — kept to preserve old sidebar reference for grep
                Positioned.fill(
                  child: Consumer2<OrderProvider, AuthProvider>(
                    builder: (context, orderProvider, authProvider, _) {
                      final user = authProvider.user;
                      final currentOrderId =
                          _getFocusedOrderId(orderProvider, authProvider);

                      return Material(
                        type: MaterialType.transparency,
                        child: GestureDetector(
                          onTap: () => setState(() => _showSidebar = false),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.4),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap:
                                    () {}, // Prevent closing when tapping sidebar
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  width:
                                      MediaQuery.sizeOf(context).width * 0.75,
                                  transform: Matrix4.translationValues(
                                    _showSidebar
                                        ? 0
                                        : MediaQuery.sizeOf(context).width *
                                            0.75,
                                    0,
                                    0,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: context.themeSurface,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          blurRadius: 20,
                                          offset: const Offset(-4, 0),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        // Profile Header (matching merchant design)
                                        Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.fromLTRB(
                                            20,
                                            MediaQuery.paddingOf(context).top +
                                                20,
                                            20,
                                            20,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                AppColors.primary,
                                                AppColors.primary
                                                    .withValues(alpha: 0.7)
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Support button removed - already available in menu items below
                                              CircleAvatar(
                                                radius: 35,
                                                backgroundColor:
                                                    context.themeOnPrimary,
                                                child: Icon(
                                                  Icons.delivery_dining,
                                                  size: 35,
                                                  color: context.themePrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Builder(
                                                builder: (context) {
                                                  final loc =
                                                      AppLocalizations.of(
                                                          context);
                                                  return Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        user?.name ??
                                                            loc.notSpecified,
                                                        style: AppTextStyles
                                                            .heading3
                                                            .copyWith(
                                                          color: context
                                                              .themeOnPrimary,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        user?.phone ??
                                                            loc.notSpecified,
                                                        style: AppTextStyles
                                                            .bodyMedium
                                                            .copyWith(
                                                          color: context
                                                              .themeOnPrimary
                                                              .withValues(alpha: 0.9),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 12,
                                                                vertical: 4),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: context
                                                              .themeOnPrimary
                                                              .withValues(alpha: 0.2),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        child: Text(
                                                          loc.driver,
                                                          style: AppTextStyles
                                                              .bodySmall
                                                              .copyWith(
                                                            color: context
                                                                .themeOnPrimary,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Menu Items
                                        Expanded(
                                          child: ListView(
                                            padding: EdgeInsets.zero,
                                            children: [
                                              Builder(
                                                builder: (context) {
                                                  final loc =
                                                      AppLocalizations.of(
                                                          context);
                                                  return Column(
                                                    children: [
                                                      _SidebarItem(
                                                        icon:
                                                            Icons.edit_outlined,
                                                        title: loc.editProfile,
                                                        onTap: () {
                                                          setState(() =>
                                                              _showSidebar =
                                                                  false);
                                                          context.push(
                                                              '/driver/profile');
                                                        },
                                                      ),
                                                      _SidebarItem(
                                                        icon: Icons.list_alt,
                                                        title: loc.driverOrders,
                                                        onTap: () {
                                                          setState(() =>
                                                              _showSidebar =
                                                                  false);
                                                          context.push(
                                                              '/driver/orders');
                                                        },
                                                      ),
                                                      _SidebarItem(
                                                        icon: Icons
                                                            .analytics_outlined,
                                                        title:
                                                            loc.driverEarnings,
                                                        onTap: () {
                                                          setState(() =>
                                                              _showSidebar =
                                                                  false);
                                                          context.push(
                                                              '/driver/earnings');
                                                        },
                                                      ),
                                                      _SidebarItem(
                                                        icon:
                                                            Icons.help_outline,
                                                        title: loc.helpSupport,
                                                        onTap: () {
                                                          setState(() =>
                                                              _showSidebar =
                                                                  false);
                                                          _openSupportChat();
                                                        },
                                                      ),
                                                      _SidebarItem(
                                                        icon: Icons
                                                            .settings_outlined,
                                                        title: loc.settings,
                                                        onTap: () {
                                                          setState(() =>
                                                              _showSidebar =
                                                                  false);
                                                          context.push(
                                                              '/driver/settings');
                                                        },
                                                      ),
                                                      _SidebarItem(
                                                        icon: Icons
                                                            .privacy_tip_outlined,
                                                        title:
                                                            loc.privacyPolicy,
                                                        onTap: () {
                                                          setState(() =>
                                                              _showSidebar =
                                                                  false);
                                                          context.push(
                                                              '/driver/privacy-policy');
                                                        },
                                                      ),
                                                      _SidebarItem(
                                                        icon: Icons
                                                            .description_outlined,
                                                        title: loc
                                                            .termsAndConditions,
                                                        onTap: () {
                                                          setState(() =>
                                                              _showSidebar =
                                                                  false);
                                                          context.push(
                                                              '/driver/terms-conditions');
                                                        },
                                                      ),
                                                      const Divider(),
                                                      _SidebarItem(
                                                        icon: Icons.logout,
                                                        title: loc.logout,
                                                        onTap: () {
                                                          setState(() =>
                                                              _showSidebar =
                                                                  false);
                                                          context
                                                              .read<
                                                                  AuthProvider>()
                                                              .logout();
                                                          context.go('/');
                                                        },
                                                        isDestructive: true,
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Aggressive route clearing for completed orders
  void _aggressiveRouteClear() {
    print('🚨 AGGRESSIVE ROUTE CLEAR - Multiple attempts');

    // Clear through route manager
    // legacy route manager removed

    // Single clear is sufficient - no need for multiple delayed clears
  }

  /// Show location update popup to driver when coordinates change
  void _showLocationUpdatePopupToDriver(dynamic order) {
    if (order == null) return;
    print('📍 Showing location update popup for order: ${order.id}');
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.blue, size: 28),
              const SizedBox(width: 12),
              Text(
                'العميل أرسل موقعه',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تم تحديث موقع العميل - لا حاجة للاتصال',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          '${AppLocalizations.of(context).customerLabelColon}${order.customerName}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                          '${AppLocalizations.of(context).merchantLabelColon}${order.merchantName ?? AppLocalizations.of(context).notSpecified}'),
                      Text(
                          '${AppLocalizations.of(context).addressLabel}${order.deliveryAddress}'),
                      const SizedBox(height: 8),
                      Text(
                        'الموقع الجديد: ${order.deliveryLatitude.toStringAsFixed(6)}, ${order.deliveryLongitude.toStringAsFixed(6)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppLocalizations.of(context).close),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context).mapUpdated),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(context).understood),
            ),
          ],
        );
      },
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

  /// Apply strict route clearing based on current order card coordinates
  Future<void> _applyStrictRouteClearing() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final orderProvider = context.read<OrderProvider>();
      final driverId = authProvider.user?.id;

      if (driverId == null) {
        print('🧹 No driver ID - clearing all routes');
        // legacy route manager removed
        return;
      }

      final activeOrders = orderProvider.getAllActiveOrdersForDriver(driverId);
      if (activeOrders.isEmpty) {
        print('🧹 No active orders - clearing all routes');
        // legacy route manager removed
        return;
      }

      final currentOrder = activeOrders.first;
      print(
          '🔍 Recalculating route after customer location update for order ${currentOrder.id}');

      // Trigger state-of-the-art navigation to rebuild route using updated delivery coords
      // The map widget listens to activeOrder changes; here we just ensure it's up-to-date
      setState(() {
        // noop: forces rebuild so StateOfTheArtMapWidget re-reads activeOrder from provider
      });
    } catch (e) {
      print('❌ Error applying strict route clearing: $e');
    }
  }

  /// Recreate pins and routes after location update (legacy method)
  Future<void> _recreatePinsAndRoutesAfterLocationUpdate() async {
    print('🔄 Recreating pins and routes after location update');

    try {
      // Force refresh of the order provider to get updated locations
      final orderProvider = context.read<OrderProvider>();
      await orderProvider.initialize();

      print('📍 Order provider refreshed after location update');

      // Get current active order with updated location
      final authProvider = context.read<AuthProvider>();
      final driverId = authProvider.user?.id;

      if (driverId != null) {
        final activeOrders =
            orderProvider.getAllActiveOrdersForDriver(driverId);
        if (activeOrders.isNotEmpty) {
          final currentOrder = activeOrders.first;
          print('📍 Found active order: ${currentOrder.id}');
          print(
              '📍 Updated delivery location: ${currentOrder.deliveryLatitude}, ${currentOrder.deliveryLongitude}');

          // Clear existing route and markers first
          print('🧹 Clearing existing route and markers...');
          // legacy route manager removed

          // Clearing is immediate - no delay needed

          // Map will update automatically through coordinate change detection
          print(
              '🔄 Map will update automatically through coordinate change detection');

          print('✅ Route recreation triggered for updated location');
        } else {
          print('📍 No active orders found after location update');
        }
      } else {
        print('📍 No driver ID found');
      }
    } catch (e) {
      print('❌ Error recreating pins and routes: $e');
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

  Widget _buildProminentTimer(OrderModel order) {
    return _ProminentTimerWidget(order: order);
  }
}

/// Prominent timer widget matching rank badge style
class _ProminentTimerWidget extends StatefulWidget {
  final OrderModel order;

  const _ProminentTimerWidget({required this.order});

  @override
  State<_ProminentTimerWidget> createState() => _ProminentTimerWidgetState();
}

class _ProminentTimerWidgetState extends State<_ProminentTimerWidget> {
  Timer? _timer;
  int? _remainingSeconds;
  bool _lateDialogShown = false;
  String? _lateDialogOrderId;

  @override
  void initState() {
    super.initState();
    _calculateRemainingTime();
    _startTimer();
  }

  @override
  void didUpdateWidget(_ProminentTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.deliveryTimerExpiresAt !=
            widget.order.deliveryTimerExpiresAt ||
        oldWidget.order.deliveryTimerStoppedAt !=
            widget.order.deliveryTimerStoppedAt) {
      _calculateRemainingTime();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateRemainingTime() {
    final order = widget.order;

    // Timer is stopped if driver reached dropoff
    if (order.deliveryTimerStoppedAt != null) {
      _remainingSeconds = 0;
      return;
    }

    // Timer hasn't started yet
    if (order.deliveryTimerExpiresAt == null) {
      _remainingSeconds = null;
      return;
    }

    // Calculate remaining / late time (allow negative to count how late)
    final now = DateTime.now();
    final expiresAt = order.deliveryTimerExpiresAt!;
    final difference = expiresAt.difference(now);

    _remainingSeconds = difference.inSeconds;

    // Fire late popup exactly once per order, when timer hits zero (and not stopped)
    final remaining = _remainingSeconds ?? 0;
    if (order.deliveryTimerStoppedAt == null &&
        remaining <= 0 &&
        (!_lateDialogShown || _lateDialogOrderId != order.id)) {
      _lateDialogShown = true;
      _lateDialogOrderId = order.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showLateOrderDialog();
      });
    }
  }

  Future<void> _showLateOrderDialog() async {
    // Avoid stacking dialogs
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loc.deliveryLateTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.deliveryLateMessage,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loc.deliveryTimerInfoMessage,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
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
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.deliveryLateAck),
            ),
          ],
        );
      },
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _calculateRemainingTime();
        });
      }
    });
  }

  String _formatTime(int seconds) {
    if (seconds < 0) return '00:00';

    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    // Timer stopped (driver reached dropoff)
    if (order.deliveryTimerStoppedAt != null) {
      return Container(
        height: 64, // Same height as rank badge
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            colors: [
              AppColors.success,
              AppColors.success.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withValues(alpha: 0.4),
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
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'وصلت إلى موقع التسليم',
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
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(1),
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

    // Calculate remaining / late time
    final diffSeconds = _remainingSeconds ?? 0;
    final isLate = diffSeconds <= 0;
    final lateSeconds = diffSeconds < 0 ? -diffSeconds : 0;
    final remainingSeconds = diffSeconds > 0 ? diffSeconds : 0;
    final isWarning = !isLate && remainingSeconds <= 300; // 5 minutes warning

    // Choose colors based on status
    List<Color> gradientColors;
    Color iconColor;
    Color shadowColor;
    IconData timerIcon;

    if (isLate && lateSeconds > 0) {
      gradientColors = [
        AppColors.error,
        AppColors.error.withValues(alpha: 0.8),
      ];
      iconColor = Colors.white;
      shadowColor = AppColors.error.withValues(alpha: 0.4);
      timerIcon = Icons.error_outline;
    } else if (isWarning) {
      gradientColors = [
        AppColors.warning,
        AppColors.warning.withValues(alpha: 0.8),
      ];
      iconColor = Colors.white;
      shadowColor = AppColors.warning.withValues(alpha: 0.4);
      timerIcon = Icons.timer_outlined;
    } else {
      gradientColors = [
        AppColors.primary,
        AppColors.primary.withValues(alpha: 0.8),
      ];
      iconColor = Colors.white;
      shadowColor = AppColors.primary.withValues(alpha: 0.4);
      timerIcon = Icons.timer_outlined;
    }

    return GestureDetector(
      onTap: _showTimerInfoDialog,
      child: Container(
        height: 64, // Same height as rank badge
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
                  timerIcon,
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
                      (isLate && lateSeconds > 0
                              ? _formatTime(lateSeconds)
                              : _formatTime(remainingSeconds))
                          .toUpperCase(),
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
      ),
    );
  }

  Future<void> _showTimerInfoDialog() async {
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                color: AppColors.primary,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loc.deliveryTimerInfoTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.deliveryTimerInfoMessage,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loc.deliveryTimerInfoMessage,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
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
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.ok),
            ),
          ],
        );
      },
    );
  }
}

// Top-level bottom sheet widget for uploading order proof
class _OrderProofUploader extends StatefulWidget {
  final String orderId;
  final Future<void> Function()
      onUploaded; // Changed from VoidCallback to support async
  final VoidCallback? onCancel; // Optional cancel callback
  const _OrderProofUploader({
    required this.orderId,
    required this.onUploaded,
    this.onCancel,
  });
  @override
  State<_OrderProofUploader> createState() => _OrderProofUploaderState();
}

class _OrderProofUploaderState extends State<_OrderProofUploader> {
  bool _uploading = false;
  ip.XFile? _picked;
  Uint8List? _previewBytes;

  Future<void> _pick(ip.ImageSource source) async {
    final picker = ip.ImagePicker();
    // OPTIMIZED: Reduced dimensions and quality for faster uploads
    // Proof photos don't need high resolution - 1200x1200 at 75% quality is sufficient
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1200, // Reduced from 1600 for faster upload
      maxHeight: 1200, // Reduced from 1600 for faster upload
      imageQuality: 75, // Reduced from 85 for smaller file size
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _picked = file;
        _previewBytes = bytes;
      });
    }
  }

  Future<void> _upload() async {
    if (_picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = _previewBytes ?? await _picked!.readAsBytes();
      final ok = await context.read<OrderProvider>().uploadOrderProof(
            orderId: widget.orderId,
            fileBytes: bytes,
            contentType: 'image/jpeg',
            fileName: _picked!.name,
          );
      if (!mounted) return;
      if (ok) {
        print(
            '✅ Order proof uploaded successfully, calling onUploaded callback...');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context).photoUploadedSuccess)),
        );
        // CRITICAL: Await the callback to ensure delivery is marked before continuing
        await widget.onUploaded();
        print('✅ onUploaded callback completed');
      } else {
        print('❌ Order proof upload failed');
        final err = context.read<OrderProvider>().error ?? 'فشل رفع الصورة';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
    } catch (e) {
      print('❌ Error during order proof upload: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${AppLocalizations.of(context).errorColon}$e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'صورة إثبات التسليم',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.themeTextPrimary,
          ),
        ),
        const SizedBox(height: 16),

        // Instructions container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.themeColor(
              light: Colors.blue.shade50,
              dark: context.themeSurfaceVariant,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.themeColor(
                light: Colors.blue.shade200,
                dark: context.themeBorder,
              ),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: context.themeColor(
                      light: Colors.blue.shade700,
                      dark: context.themeTextSecondary,
                    ),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تعليمات مهمة قبل التسليم:',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: context.themeTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInstructionStep(
                number: '1',
                text: 'اعرض حالة الطلب للعميل على التطبيق',
                icon: Icons.smartphone,
              ),
              const SizedBox(height: 8),
              _buildInstructionStep(
                number: '2',
                text: 'تأكد من استلام العميل للطلب كاملاً',
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(height: 8),
              _buildInstructionStep(
                number: '3',
                text: 'التقط صورة واضحة للطلب مع العميل',
                icon: Icons.photo_camera,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Camera button
        if (_previewBytes == null)
          ElevatedButton.icon(
            onPressed: _uploading ? null : () => _pick(ip.ImageSource.camera),
            icon: const Icon(Icons.photo_camera, size: 28),
            label: const Text(
              'التقط صورة الآن',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
            ),
          ),

        // Preview and upload
        if (_previewBytes != null)
          Column(
            children: [
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.themeBorder, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(_previewBytes!, fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _uploading
                          ? null
                          : () {
                              setState(() {
                                _picked = null;
                                _previewBytes = null;
                              });
                            },
                      icon: const Icon(Icons.refresh),
                      label: Text(AppLocalizations.of(context).retakePhoto),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _uploading || _picked == null ? null : _upload,
                      icon: _uploading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle),
                      label: Text(_uploading
                          ? AppLocalizations.of(context).uploadingProgress
                          : AppLocalizations.of(context).confirmAndFinish),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

        const SizedBox(height: 16),

        // Cancel button
        if (widget.onCancel != null)
          Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return TextButton.icon(
                onPressed: _uploading ? null : widget.onCancel,
                icon: const Icon(Icons.close),
                label: Text(loc.cancelAndClose),
                style: TextButton.styleFrom(
                  foregroundColor: context.themeTextSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildInstructionStep({
    required String number,
    required String text,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, size: 20, color: context.themeTextSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: context.themeTextPrimary,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? context.themeError : context.themeTextSecondary,
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          color: isDestructive ? context.themeError : context.themeTextPrimary,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: isDestructive ? context.themeError : context.themeTextTertiary,
      ),
      onTap: onTap,
    );
  }
}

class _InteractiveMapWidget extends StatefulWidget {
  final double centerLat;
  final double centerLng;
  final dynamic activeOrder;
  final dynamic driverLocation;
  final int currentOrderIndex;
  final List<dynamic> allActiveOrders;
  final bool isOrderCardExpanded;

  const _InteractiveMapWidget({
    super.key,
    required this.centerLat,
    required this.centerLng,
    this.activeOrder,
    this.driverLocation,
    required this.currentOrderIndex,
    required this.allActiveOrders,
    this.isOrderCardExpanded = false,
  });

  @override
  State<_InteractiveMapWidget> createState() => _InteractiveMapWidgetState();
}

class _InteractiveMapWidgetState extends State<_InteractiveMapWidget> {
  MapboxMap? _mapboxMap;
  String? _mapboxAccessToken;
  final StateOfTheArtNavigation _navigationSystem = StateOfTheArtNavigation();

  // Legacy bulletproof manager removed
  bool _isInitialized = false;
  PointAnnotationManager? _pointAnnotationManager;
  PointAnnotation? _driverMarker;
  bool _customIconsLoaded = false;
  bool _isUpdatingDriverMarker = false;
  String? _appliedStyleUri;

  // Public method to clear coordinate cache
  void clearCoordinateCache() {
    print('🧹 Clearing coordinate cache from external call...');
    _lastRecalculatedOrderCoords = null;
  }

  // Public method to force route recalculation
  Future<void> forceRouteRecalculation(OrderModel order) async {
    print('🔄 Force route recalculation called from external...');

    if (!_isInitialized) {
      print('⚠️  Map not initialized, cannot recalculate route');
      return;
    }

    try {
      // Clear the coordinate cache first
      _lastRecalculatedOrderCoords = null;

      // Clear any existing flags
      _isRecalculatingRoute = false;

      // Explicitly call _handleDeliveryLocationUpdate which will:
      // 1. Check initialization
      // 2. Clear old routes/annotations
      // 3. Calculate new route
      // 4. Add new annotations
      await _handleDeliveryLocationUpdate();

      print('✅ Force route recalculation completed');
    } catch (e) {
      print('❌ Error in force route recalculation: $e');
      // Reset flag on error
      _isRecalculatingRoute = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _mapboxAccessToken = const String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
    print('🗺️ Legacy bulletproof map widget removed');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to theme changes and imperatively switch the map style.
    // MapWidget ignores styleUri prop changes after creation, so we must
    // call loadStyleURI ourselves whenever the theme toggles.
    final newStyle = MapStyleHelper.getMapStyle(context);
    if (_appliedStyleUri != null &&
        _appliedStyleUri != newStyle &&
        _mapboxMap != null) {
      print('🎨 Theme changed — reloading map style: $newStyle');
      _appliedStyleUri = newStyle;
      _customIconsLoaded = false; // Icons must be re-added after style reload
      _mapboxMap!.loadStyleURI(newStyle).catchError((e) {
        print('❌ Error reloading map style: $e');
      });
    } else {
      _appliedStyleUri = newStyle;
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    setState(() {
      _mapboxMap = mapboxMap;
    });
    print('🗺️ Map created');

    // Create point annotation manager for driver marker
    try {
      _pointAnnotationManager =
          await mapboxMap.annotations.createPointAnnotationManager();
      print('✅ Point annotation manager created');
    } catch (e) {
      print('⚠️ Error creating point annotation manager: $e');
    }

    // Load custom icons (driver marker)
    await _loadCustomIcons();

    // Initialize navigation system (routes + annotations)
    try {
      final initialized = await _navigationSystem.initialize(mapboxMap);
      if (initialized) {
        print('✅ Navigation system ready inside map widget');
        if (widget.activeOrder != null) {
          await _navigationSystem
              .setActiveOrder(widget.activeOrder as OrderModel);
        } else {
          await _navigationSystem.clearAll();
        }
      } else {
        print('⚠️ Navigation system failed to initialize');
      }
    } catch (e) {
      print('❌ Error initializing navigation system: $e');
    }

    // Add neighborhood labels (use a separate manager or reuse the existing one)
    try {
      if (_pointAnnotationManager != null) {
        // Neighborhood labels removed
      }
    } catch (e) {
      print('⚠️ Error adding neighborhood labels to driver map: $e');
    }

    // Update driver marker if location is available
    if (widget.driverLocation != null) {
      await _updateDriverMarker();
    }

    _isInitialized = true;
  }

  @override
  void didUpdateWidget(_InteractiveMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle order changes (new order or different order)
    if (widget.activeOrder?.id != oldWidget.activeOrder?.id) {
      _handleOrderChange();
    }
    // Handle same order but with updated coordinates (customer location update)
    else if (widget.activeOrder != null &&
        oldWidget.activeOrder != null &&
        widget.activeOrder?.id == oldWidget.activeOrder?.id) {
      // Same order, check if delivery coordinates changed
      final oldLat = (oldWidget.activeOrder as OrderModel?)?.deliveryLatitude;
      final oldLng = (oldWidget.activeOrder as OrderModel?)?.deliveryLongitude;
      final newLat = (widget.activeOrder as OrderModel?)?.deliveryLatitude;
      final newLng = (widget.activeOrder as OrderModel?)?.deliveryLongitude;

      if (oldLat != null &&
          oldLng != null &&
          newLat != null &&
          newLng != null) {
        // Check if coordinates changed (with tolerance for floating point precision)
        if ((newLat - oldLat).abs() > 0.0001 ||
            (newLng - oldLng).abs() > 0.0001) {
          print('📍 DELIVERY COORDINATES CHANGED - Recalculating route');
          print('   Old: ($oldLat, $oldLng)');
          print('   New: ($newLat, $newLng)');
          // Recalculate route WITHOUT calling notifyListeners
          // (that would cause a loop since we're already in a rebuild)
          _handleDeliveryLocationUpdate();
        }
      }
    }

    // Handle driver location changes
    if (widget.driverLocation != oldWidget.driverLocation) {
      _updateDriverMarker();
    }
  }

  void _handleOrderChange() {
    // Clear coordinate cache when order changes
    _lastRecalculatedOrderCoords = null;

    if (widget.activeOrder != null && _isInitialized) {
      _setActiveOrder();
    } else if (widget.activeOrder == null && _isInitialized) {
      _clearAllAnnotations();
    }
  }

  Future<void> _setActiveOrder() async {
    if (widget.activeOrder == null || !_isInitialized) return;

    try {
      if (widget.activeOrder is OrderModel) {
        await _navigationSystem
            .setActiveOrder(widget.activeOrder as OrderModel);
      }
      print('✅ Active order set - ${widget.activeOrder!.id}');
    } catch (e) {
      print('❌ Bulletproof: Error setting active order: $e');
    }
  }

  bool _isRecalculatingRoute = false;
  String? _lastRecalculatedOrderCoords; // Track last recalculated coordinates

  /// Handle delivery location update (customer sent new coordinates via WhatsApp)
  Future<void> _handleDeliveryLocationUpdate() async {
    if (widget.activeOrder == null || !_isInitialized) return;

    // Prevent concurrent recalculations (avoid loop)
    if (_isRecalculatingRoute) {
      print('⚠️  Route recalculation already in progress, skipping...');
      return;
    }

    // Check if we already recalculated for these exact coordinates
    final order = widget.activeOrder as OrderModel;
    final coordsKey =
        '${order.id}_${order.deliveryLatitude}_${order.deliveryLongitude}';

    if (_lastRecalculatedOrderCoords == coordsKey) {
      print(
          '⚠️  Route already recalculated for these coordinates, skipping...');
      return;
    }

    try {
      _isRecalculatingRoute = true;
      print('📍 ===========================================');
      print('📍 RECALCULATING ROUTE FOR LOCATION UPDATE');
      print('📍 ===========================================');
      print('   Order: ${order.id}');
      print('   Old coords: $_lastRecalculatedOrderCoords');
      print(
          '   New coords: (${order.deliveryLatitude}, ${order.deliveryLongitude})');
      print('   Coords key: $coordsKey');

      // CRITICAL: Clear coordinate cache to force recalculation
      _lastRecalculatedOrderCoords = '';

      // Recalculate route with new coordinates
      // This will clear ALL old annotations and create new ones
      await _navigationSystem.recalculateRouteForOrder(order);

      // Remember these coordinates to prevent duplicate recalculations
      _lastRecalculatedOrderCoords = coordsKey;

      print('✅ Route recalculated with new customer location');
      print('   Old annotations cleared, new route created');
      print('📍 ===========================================');
    } catch (e) {
      print('❌ Error recalculating route: $e');
      print('   Stack trace: ${StackTrace.current}');
    } finally {
      _isRecalculatingRoute = false;
    }
  }

  Future<void> _clearAllAnnotations() async {
    if (!_isInitialized) return;

    try {
      await _navigationSystem.clearAll();
      // Remove driver marker
      if (_driverMarker != null && _pointAnnotationManager != null) {
        await _pointAnnotationManager!.delete(_driverMarker!);
        _driverMarker = null;
      }
      print('🧹 All annotations cleared');
    } catch (e) {
      print('❌ Bulletproof: Error clearing annotations: $e');
    }
  }

  Future<void> _loadCustomIcons() async {
    if (_mapboxMap == null || _customIconsLoaded) return;

    try {
      // Load driver location marker (blue circle with black arrowhead)
      final driverBikeBytes = await _createBikeIcon();
      await _mapboxMap!.style.addStyleImage(
        'driver-bike',
        1.0,
        MbxImage(width: 96, height: 96, data: driverBikeBytes),
        false,
        [],
        [],
        null,
      );

      _customIconsLoaded = true;
      print('✅ Custom icons loaded (driver bike marker)');
    } catch (e) {
      print('❌ Error loading custom icons: $e');
    }
  }

  Future<Uint8List> _createBikeIcon({double? heading}) async {
    // Create a blue circle with black arrowhead inside pointing in the direction of movement
    // HIGH RESOLUTION (3x scale)
    const double iconSize = 96.0; // 32 * 3
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    const center = Offset(iconSize / 2, iconSize / 2);
    const radius = iconSize / 2 - 6; // Smaller border

    // Draw blue circle background
    final blueCirclePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, blueCirclePaint);

    // Draw blue circle border (white outline for visibility)
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, radius, borderPaint);

    // Draw arrowhead inside the circle pointing in the direction of movement
    // Arrowhead is a triangle pointing upward (north) by default
    // We'll rotate it based on heading if available
    const arrowSize = radius * 0.6; // Arrow takes up 60% of circle radius
    final arrowPath = Path();

    // Arrowhead points upward (north) - triangle pointing up
    final arrowTop = Offset(center.dx, center.dy - arrowSize);
    final arrowBottomLeft =
        Offset(center.dx - arrowSize * 0.5, center.dy + arrowSize * 0.3);
    final arrowBottomRight =
        Offset(center.dx + arrowSize * 0.5, center.dy + arrowSize * 0.3);

    arrowPath.moveTo(arrowTop.dx, arrowTop.dy);
    arrowPath.lineTo(arrowBottomLeft.dx, arrowBottomLeft.dy);
    arrowPath.lineTo(arrowBottomRight.dx, arrowBottomRight.dy);
    arrowPath.close();

    // Rotate arrow if heading is available
    if (heading != null && !heading.isNaN && !heading.isInfinite) {
      // Heading is in degrees, where 0 = North, 90 = East, etc.
      // We need to convert to radians and adjust for canvas rotation (canvas uses clockwise, heading is typically clockwise from North)
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(
          (heading * 3.14159265359 / 180.0)); // Convert degrees to radians
      canvas.translate(-center.dx, -center.dy);
    }

    // Draw arrowhead in black for visibility on blue background
    final arrowPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawPath(arrowPath, arrowPaint);

    if (heading != null) {
      canvas.restore();
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(iconSize.toInt(), iconSize.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    print(
        '✅ Driver location marker created (blue circle with black arrowhead${heading != null ? ', heading: $heading°' : ''})');
    return byteData!.buffer.asUint8List();
  }

  Future<void> _updateDriverMarker() async {
    if (_pointAnnotationManager == null ||
        widget.driverLocation == null ||
        _mapboxMap == null ||
        !_customIconsLoaded) {
      return;
    }

    // Prevent concurrent calls from creating duplicate markers
    if (_isUpdatingDriverMarker) return;
    _isUpdatingDriverMarker = true;

    try {
      // Extract location coordinates
      double? lat;
      double? lng;
      double? heading;

      if (widget.driverLocation is Map) {
        lat = widget.driverLocation['latitude'] as double?;
        lng = widget.driverLocation['longitude'] as double?;
        heading = widget.driverLocation['heading'] as double?;
      } else {
        try {
          lat = widget.driverLocation.latitude;
          lng = widget.driverLocation.longitude;
          heading = widget.driverLocation.heading;
        } catch (e) {
          print('❌ Cannot access coordinates from driverLocation: $e');
          return;
        }
      }

      if (lat == null || lng == null) {
        print('⚠️ Invalid driver location coordinates');
        return;
      }

      // Remove old marker and immediately null it to prevent double-deletion
      if (_driverMarker != null) {
        final markerToDelete = _driverMarker!;
        _driverMarker = null;
        try {
          await _pointAnnotationManager!.delete(markerToDelete);
        } catch (e) {
          print('⚠️ Error deleting old driver marker: $e');
        }
      }

      // If heading is available, recreate the icon with new rotation
      if (heading != null && !heading.isNaN && !heading.isInfinite) {
        final driverIconBytes = await _createBikeIcon(heading: heading);
        await _mapboxMap!.style.addStyleImage(
          'driver-bike',
          1.0,
          MbxImage(width: 96, height: 96, data: driverIconBytes),
          false,
          [],
          [],
          null,
        );
      }

      // Add new marker
      _driverMarker = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(lng, lat),
          ),
          iconImage: 'driver-bike',
          iconSize: 0.2,
        ),
      );
      print(
          '✅ Driver location marker updated (blue circle with black arrowhead${heading != null ? ', heading: $heading°' : ''})');
    } catch (e) {
      print('❌ Error updating driver marker: $e');
    } finally {
      _isUpdatingDriverMarker = false;
    }
  }

  @override
  void dispose() {
    // Clean up marker (fire and forget - dispose shouldn't be async)
    if (_driverMarker != null && _pointAnnotationManager != null) {
      _pointAnnotationManager!.delete(_driverMarker!).catchError((_) {
        // Ignore errors during dispose
      });
    }
    try {
      _navigationSystem.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No NavigationOverlayScope here — the outer Scaffold body scope (line 4812)
    // is already accessible from this subtree. Nesting a second scope would
    // isolate the floating nav button from the footer height registry.
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: MapWidget(
            key: const ValueKey("driver_map_widget"),
            cameraOptions: CameraOptions(
              center: Point(
                  coordinates: Position(widget.centerLng, widget.centerLat)),
              zoom: 15.0,
            ),
            styleUri: MapStyleHelper.getMapStyle(context),
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: (_) async {
              if (_mapboxMap == null) return;
              print('🔄 Style loaded, restoring map state...');
              // Style reload wipes all custom images and annotations — restore them
              _customIconsLoaded = false;
              _driverMarker = null;
              await _loadCustomIcons();
              if (widget.driverLocation != null) {
                await _updateDriverMarker();
              }
            },
          ),
        ),
        // Floating Navigation Button — fixed distance above the bottom_nav footer
        // only. Uses a _NavAwareFloatingButton wrapper so it can read the
        // NavigationOverlayController and emit a properly positioned widget as a
        // direct child of the Stack.
        _NavAwareFloatingButton(
          mapboxMap: _mapboxMap,
          activeOrder: widget.activeOrder,
          driverLocation: widget.driverLocation,
        ),
      ],
    );
  }
}

/// Positions the floating nav button a fixed gap above the `bottom_nav` footer
/// only — it intentionally ignores the order card height so the button doesn't
/// climb when the card expands.  Uses [ListenableBuilder] so it re-animates
/// whenever the NavigationOverlayController reports a footer height change.
class _NavAwareFloatingButton extends StatelessWidget {
  final MapboxMap? mapboxMap;
  final dynamic activeOrder;
  final dynamic driverLocation;

  const _NavAwareFloatingButton({
    this.mapboxMap,
    this.activeOrder,
    this.driverLocation,
  });

  @override
  Widget build(BuildContext context) {
    final controller = NavigationOverlayScope.of(context);
    final systemNavBar = MediaQuery.of(context).viewPadding.bottom;
    final right = MediaQuery.sizeOf(context).width * 0.04;

    double computeBottom() {
      final navFooterHeight = controller?.getHeight('bottom_nav') ?? 0;
      return (navFooterHeight > 0 ? navFooterHeight : systemNavBar) + 16.0;
    }

    if (controller == null) {
      return AnimatedPositioned(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        bottom: systemNavBar + 16.0,
        right: right,
        child: _FloatingNavigationButton(
          mapboxMap: mapboxMap,
          activeOrder: activeOrder,
          driverLocation: driverLocation,
        ),
      );
    }

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          bottom: computeBottom(),
          right: right,
          child: _FloatingNavigationButton(
            mapboxMap: mapboxMap,
            activeOrder: activeOrder,
            driverLocation: driverLocation,
          ),
        );
      },
    );
  }
}

class _FloatingNavigationButton extends StatefulWidget {
  final MapboxMap? mapboxMap;
  final dynamic activeOrder;
  final dynamic driverLocation;

  const _FloatingNavigationButton({
    this.mapboxMap,
    this.activeOrder,
    this.driverLocation,
  });

  @override
  State<_FloatingNavigationButton> createState() =>
      _FloatingNavigationButtonState();
}

class _FloatingNavigationButtonState extends State<_FloatingNavigationButton>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    // If no active order, directly navigate to driver location
    if (widget.activeOrder == null && widget.driverLocation != null) {
      if (widget.mapboxMap != null) {
        _navigateToDriverLocation();
      } else {
        _retryNavigationToDriverLocation(attempt: 1);
      }
      return;
    }

    // If there IS an active order, toggle the navigation list
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _navigateToLocation(double lat, double lng, String locationName) {
    if (widget.mapboxMap == null) return;

    widget.mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: 16.0,
        bearing: 0.0, // Reset to north like a compass
      ),
      MapAnimationOptions(duration: 1000),
    );

    // Close the expanded menu (only if it's expanded)
    if (_isExpanded) {
      _toggleExpansion();
    }
  }

  void _retryNavigationToDriverLocation(
      {int attempt = 1, int maxAttempts = 5}) {
    if (!mounted) return;

    if (widget.mapboxMap != null && widget.driverLocation != null) {
      _navigateToDriverLocation();
      return;
    }

    if (attempt >= maxAttempts) return;

    final delay = Duration(milliseconds: 250 * (1 << (attempt - 1)));
    Future.delayed(delay, () {
      if (mounted) {
        _retryNavigationToDriverLocation(
            attempt: attempt + 1, maxAttempts: maxAttempts);
      }
    });
  }

  void _navigateToDriverLocation() {
    if (widget.driverLocation == null || widget.mapboxMap == null) return;

    try {
      double? lat;
      double? lng;

      if (widget.driverLocation is Map) {
        lat = (widget.driverLocation as Map)['latitude'] as double?;
        lng = (widget.driverLocation as Map)['longitude'] as double?;
      } else {
        try {
          final dynamic loc = widget.driverLocation;
          lat = loc.latitude as double?;
          lng = loc.longitude as double?;
        } catch (e) {
          return;
        }
      }

      if (lat != null && lng != null && lat.isFinite && lng.isFinite) {
        _navigateToLocation(lat, lng, 'موقعك الحالي');
      }
    } catch (e) {
      // Silently handle errors
    }
  }

  void _navigateToStoreLocation() {
    if (widget.activeOrder != null) {
      _navigateToLocation(
        widget.activeOrder.pickupLatitude,
        widget.activeOrder.pickupLongitude,
        'موقع المتجر',
      );
    }
  }

  void _navigateToDeliveryLocation() {
    if (widget.activeOrder != null) {
      _navigateToLocation(
        widget.activeOrder.deliveryLatitude,
        widget.activeOrder.deliveryLongitude,
        'موقع التوصيل',
      );
    }
  }

  /// Check if customer has provided GPS location
  bool _hasCustomerProvidedGps() {
    if (widget.activeOrder == null) return false;
    // Check if customer_location_provided is true
    return widget.activeOrder.customerLocationProvided == true;
  }

  /// Get delivery button label with GPS indication
  String _getDeliveryButtonLabel() {
    if (_hasCustomerProvidedGps()) {
      return 'التوصيل 📍';
    }
    return 'التوصيل';
  }

  void _showFullRoute() {
    if (widget.mapboxMap == null || widget.activeOrder == null) return;

    print('📹 Overview: Showing full route...');

    // Get coordinates
    final pickupLat = widget.activeOrder.pickupLatitude;
    final pickupLng = widget.activeOrder.pickupLongitude;
    final deliveryLat = widget.activeOrder.deliveryLatitude;
    final deliveryLng = widget.activeOrder.deliveryLongitude;

    // Calculate bounds
    final minLat = pickupLat < deliveryLat ? pickupLat : deliveryLat;
    final maxLat = pickupLat > deliveryLat ? pickupLat : deliveryLat;
    final minLng = pickupLng < deliveryLng ? pickupLng : deliveryLng;
    final maxLng = pickupLng > deliveryLng ? pickupLng : deliveryLng;

    // Add padding
    final latPadding = (maxLat - minLat) * 0.15;
    final lngPadding = (maxLng - minLng) * 0.15;

    // Calculate center between pickup and delivery
    final centerLat = (pickupLat + deliveryLat) / 2;
    final centerLng = (pickupLng + deliveryLng) / 2;

    // Calculate appropriate zoom level
    final latDiff = maxLat - minLat + latPadding;
    final lngDiff = maxLng - minLng + lngPadding;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    double zoom = 13.0;
    if (maxDiff > 0.1) {
      zoom = 11.0;
    } else if (maxDiff > 0.05) {
      zoom = 12.0;
    } else if (maxDiff > 0.02) {
      zoom = 13.0;
    } else {
      zoom = 14.0;
    }

    // Animate to show full route
    widget.mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(centerLng, centerLat)),
        zoom: zoom,
        bearing: 0.0, // Reset to north
      ),
      MapAnimationOptions(duration: 1500),
    );

    print('✅ Overview: Camera set to show full route at zoom $zoom');

    // Close the expanded menu
    _toggleExpansion();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Expanded menu items
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.scale(
              scale: _animation.value,
              child: Opacity(
                opacity: _animation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isExpanded) ...[
                      // Show full route - only if there's an active order
                      if (widget.activeOrder != null) ...[
                        _buildNavButton(
                          icon: Icons.route,
                          label: 'عرض المسار',
                          onTap: _showFullRoute,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 8),
                        // Navigate to store
                        _buildNavButton(
                          icon: Icons.store,
                          label: 'المتجر',
                          onTap: _navigateToStoreLocation,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 8),
                        // Navigate to delivery with GPS indication
                        _buildNavButton(
                          icon: Icons.flag,
                          label: _getDeliveryButtonLabel(),
                          onTap: _navigateToDeliveryLocation,
                          color: AppColors.success,
                          hasGpsIndicator: _hasCustomerProvidedGps(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Navigate to driver location - always available
                      if (widget.driverLocation != null)
                        _buildNavButton(
                          icon: Icons.my_location,
                          label:
                              AppLocalizations.of(context).yourLocationButton,
                          onTap: _navigateToDriverLocation,
                          color: AppColors.warning,
                        ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        // Main floating button - ALWAYS VISIBLE
        FloatingActionButton(
          onPressed: _toggleExpansion,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          child: AnimatedRotation(
            turns: _isExpanded ? 0.125 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Icon(_isExpanded ? Icons.close : Icons.navigation),
          ),
        ),
      ],
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    bool hasGpsIndicator = false,
  }) {
    return SizedBox(
      width: 120,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0, // Remove elevation completely to prevent gray overlay
          shadowColor:
              Colors.transparent, // Remove shadow to prevent gray overlay
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasGpsIndicator) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.gps_fixed,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WebMapWidget extends StatefulWidget {
  @override
  _WebMapWidgetState createState() => _WebMapWidgetState();
}

class _WebMapWidgetState extends State<_WebMapWidget> {
  final double _zoom = 15.0;
  double _centerLat = 33.3152; // Baghdad default
  double _centerLng = 44.3661;
  final bool _showControls = false;
  String _locationStatus = ''; // Initialized in build or initState
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const webMapboxAccessToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
    return Consumer2<LocationProvider, AuthProvider>(
      builder: (context, locationProvider, authProvider, child) {
        final currentPosition = locationProvider.currentPosition;
        final user = authProvider.user;

        // Update map center with driver's actual location
        if (currentPosition != null) {
          _centerLat = currentPosition.latitude;
          _centerLng = currentPosition.longitude;
          _locationStatus = AppLocalizations.of(context).currentLocationStatus;
        } else if (user?.latitude != null && user?.longitude != null) {
          _centerLat = user!.latitude!;
          _centerLng = user.longitude!;
          _locationStatus = AppLocalizations.of(context).lastKnownLocation;
        } else {
          _locationStatus = AppLocalizations.of(context).determiningLocation;
        }

        return Stack(
          children: [
            // Interactive Map with Real Mapbox Integration
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Stack(
                children: [
                  // Interactive Mapbox Map
                  SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: 0.5,
                      maxScale: 4.0,
                      onInteractionStart: (details) {
                        // Handle interaction start
                      },
                      onInteractionUpdate: (details) {
                        // Handle interaction update
                      },
                      onInteractionEnd: (details) {
                        // Handle interaction end
                      },
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          image: webMapboxAccessToken.isEmpty
                              ? null
                              : DecorationImage(
                                  image: NetworkImage(
                                    'https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/$_centerLng,$_centerLat,${_zoom.toInt()},0/800x600?access_token=$webMapboxAccessToken',
                                  ),
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                  ),

                  // Driver location marker - Always visible and responsive
                  if (currentPosition != null ||
                      (user?.latitude != null && user?.longitude != null))
                    Positioned(
                      left: MediaQuery.sizeOf(context).width / 2 -
                          (MediaQuery.sizeOf(context).width *
                              0.08), // Responsive center
                      top: MediaQuery.sizeOf(context).height / 2 -
                          (MediaQuery.sizeOf(context).width *
                              0.08), // Responsive center
                      child: Container(
                        width: MediaQuery.sizeOf(context).width *
                            0.16, // Responsive size
                        height: MediaQuery.sizeOf(context).width *
                            0.16, // Responsive size
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: MediaQuery.sizeOf(context).width *
                                0.008, // Responsive border
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.navigation,
                          color: Colors.white,
                          size: MediaQuery.sizeOf(context).width *
                              0.08, // Responsive icon
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Status overlay
            Positioned(
              bottom: 0,
              left: 20,
              right: 20,
              child: NavigationBarAwareFooterWrapper(
                id: 'status_overlay',
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                padding: const EdgeInsets.only(bottom: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      SizedBox(width: context.rs(8)),
                      Expanded(
                        child: Text(
                          _locationStatus,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // My Location Button
            Positioned(
              bottom: 0,
              right: 20,
              child: NavigationBarAwareFooterWrapper(
                id: 'my_location_button',
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  children: [
                    FloatingActionButton(
                      onPressed: () {
                        final locationProvider =
                            context.read<LocationProvider>();
                        if (locationProvider.currentPosition != null) {
                          setState(() {
                            _centerLat =
                                locationProvider.currentPosition!.latitude;
                            _centerLng =
                                locationProvider.currentPosition!.longitude;
                          });
                          _transformationController.value = Matrix4.identity();
                        }
                      },
                      backgroundColor: AppColors.success,
                      elevation: 12,
                      mini: false,
                      child: Icon(
                        Icons.my_location,
                        color: Colors.white,
                        size: MediaQuery.sizeOf(context).width * 0.06,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Accept button with 3-second long press and haptic feedback
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
    final newRemaining =
        orderProvider.getTimeoutRemaining(widget.orderId) ?? 30;

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
    final newRemaining = orderProvider.getTimeoutRemaining(widget.order.id) ??
        widget.order.timeoutRemainingSeconds ??
        0;

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
