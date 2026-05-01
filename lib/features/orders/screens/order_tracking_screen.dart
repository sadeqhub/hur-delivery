import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../shared/widgets/navigation_overlay_system.dart';
import '../../dashboard/widgets/state_of_the_art_map_widget.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with WidgetsBindingObserver {
  Timer? _driverLocationTimer;
  Map<String, dynamic>? _driverLocation;
  String? _locationError;

  // Adaptive interval: 3s normally, backs off to 10s after consecutive errors
  static const _normalInterval = Duration(seconds: 3);
  static const _backoffInterval = Duration(seconds: 10);
  int _consecutiveErrors = 0;
  static const _backoffThreshold = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().initialize();
      _startDriverLocationTracking();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _driverLocationTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _driverLocationTimer?.cancel();
      _driverLocationTimer = null;
    } else if (state == AppLifecycleState.resumed &&
        _driverLocationTimer == null) {
      _consecutiveErrors = 0;
      _startDriverLocationTracking();
    }
  }

  void _startDriverLocationTracking() {
    _driverLocationTimer?.cancel();
    final interval = _consecutiveErrors >= _backoffThreshold
        ? _backoffInterval
        : _normalInterval;
    _driverLocationTimer = Timer.periodic(interval, (_) {
      _fetchDriverLocation();
    });
    _fetchDriverLocation();
  }

  Future<void> _fetchDriverLocation() async {
    final order = context.read<OrderProvider>().getOrderById(widget.orderId);
    if (order == null || order.driverId == null) return;

    try {
      // PERFORMANCE: Use materialized view (215ms → <10ms, 95% faster)
      final response = await Supabase.instance.client
          .from('recent_driver_locations')
          .select()
          .eq('driver_id', order.driverId!)
          .maybeSingle();

      if (mounted) {
        final wasBackingOff = _consecutiveErrors >= _backoffThreshold;
        _consecutiveErrors = 0;
        setState(() {
          _driverLocation = response;
          _locationError = null;
        });
        // Restore normal polling interval after recovering from backoff
        if (wasBackingOff) _startDriverLocationTracking();
      }
    } catch (e) {
      if (mounted) {
        _consecutiveErrors++;
        setState(() => _locationError = e.toString());
        // Switch to backoff interval when threshold is reached
        if (_consecutiveErrors == _backoffThreshold) {
          _startDriverLocationTracking();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            loc.trackDriver,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, _) {
          final order = orderProvider.getOrderById(widget.orderId);

          if (order == null) {
            // Order not found — show actionable error rather than infinite spin
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off_rounded,
                        size: 64, color: AppColors.textTertiary),
                    const SizedBox(height: 16),
                    Text(
                      loc.orderNotFound,
                      style: AppTextStyles.heading3.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.read<OrderProvider>().initialize();
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text(loc.retryAction),
                    ),
                  ],
                ),
              ),
            );
          }

          // Wrap all states in AnimatedSwitcher so switching from "searching"
          // to the live map fades in smoothly instead of snapping.
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: order.driverId == null
                ? Center(
                    key: const ValueKey('searching'),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.hourglass_empty,
                              size: 64, color: AppColors.textTertiary),
                          const SizedBox(height: 16),
                          Text(
                            loc.searchingDriver,
                            style: AppTextStyles.heading3.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildMapView(order, loc),
          );
        },
      ),
    );
  }

  Widget _buildMapView(dynamic order, dynamic loc) {
          final centerLat = (order.pickupLatitude + order.deliveryLatitude) / 2;
          final centerLng = (order.pickupLongitude + order.deliveryLongitude) / 2;

          return Stack(
            key: const ValueKey('map'),
            children: [
              // Full-screen map: exact same state-of-the-art route/pins/navigation as driver dashboard
              NavigationOverlayScope(
                child: StateOfTheArtMapWidget(
                  activeOrder: order,
                  driverLocation: _driverLocation,
                  centerLat: centerLat,
                  centerLng: centerLng,
                  isOrderCardExpanded: false,
                ),
              ),

              // Location error banner — non-blocking, shown above status card
              if (_locationError != null)
                Positioned(
                  bottom: 180,
                  left: 16,
                  right: 16,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_off,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              loc.locationUnavailable,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(40, 28)),
                            onPressed: _fetchDriverLocation,
                            child: Text(loc.retryAction,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Status overlay at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _getStatusColor(order.status),
                          _getStatusColor(order.status).withOpacity(0.9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getStatusIcon(order.status),
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.statusDisplay,
                                    style: AppTextStyles.heading3.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (order.driverName != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'السائق: ${order.driverName}',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (order.driverPhone != null &&
                            order.driverPhone!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _showCallDriverOptions(context, order.driverPhone!, order.driverName ?? loc.driver),
                              icon:
                                  const Icon(Icons.phone, color: Colors.white),
                              label: Text(
                                '${loc.callTitle} السائق',
                                style: const TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.2),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending_actions;
      case 'assigned':
      case 'accepted':
        return Icons.check_circle;
      case 'on_the_way':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      case 'rejected':
        return Icons.block;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'assigned':
      case 'accepted':
        return AppColors.statusAccepted;
      case 'on_the_way':
        return AppColors.statusInProgress;
      case 'delivered':
        return AppColors.statusCompleted;
      case 'cancelled':
      case 'rejected':
        return AppColors.statusCancelled;
      default:
        return AppColors.textTertiary;
    }
  }

  void _showCallDriverOptions(BuildContext context, String phoneNumber, String driverName) {
    final loc = AppLocalizations.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.themeSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: context.themeTextTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              '${loc.callTitle} $driverName',
              style: AppTextStyles.heading3.copyWith(
                color: context.themeTextPrimary,
              ),
            ),
            const SizedBox(height: 24),
            // Cellular Call
            _CallOptionButton(
              icon: Icons.phone,
              label: loc.callViaPhone,
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                _makePhoneCall(phoneNumber);
              },
            ),
            const SizedBox(height: 12),
            // WhatsApp Call
            _CallOptionButton(
              icon: Icons.video_call,
              label: loc.callViaWhatsapp,
              color: const Color(0xFF25D366),
              onTap: () {
                Navigator.pop(context);
                _callOnWhatsApp(phoneNumber);
              },
            ),
            const SizedBox(height: 12),
            // WhatsApp Message
            _CallOptionButton(
              icon: Icons.message,
              label: loc.whatsappMessage,
              color: const Color(0xFF25D366),
              onTap: () {
                Navigator.pop(context);
                _messageOnWhatsApp(phoneNumber, driverName);
              },
            ),
            const SizedBox(height: 12),
            // Cancel button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                loc.cancel,
                style: TextStyle(
                  color: context.themeTextSecondary,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _normalizeIraqPhoneToE164(String raw) {
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'[^0-9+]'), '');
    if (s.startsWith('00')) s = s.substring(2);
    if (s.startsWith('+')) s = s.substring(1);
    s = s.replaceAll(RegExp(r'[^0-9]'), '');

    if (s.startsWith('964')) return '+$s';
    if (s.startsWith('0')) return '+964${s.substring(1)}';
    if (s.length <= 11) return '+964$s';
    return '+$s';
  }

  String _normalizePhoneForWhatsApp(String raw) {
    // wa.me expects digits only, typically including country code (no +)
    return _normalizeIraqPhoneToE164(raw).replaceAll('+', '');
  }

  Future<void> _makePhoneCall(String phone) async {
    final tel = _normalizeIraqPhoneToE164(phone);
    final uri = Uri.parse('tel:$tel');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.cannotMakeCall),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _callOnWhatsApp(String phone) async {
    final loc = AppLocalizations.of(context);
    final waDigits = _normalizePhoneForWhatsApp(phone);

    // Best-effort: WhatsApp call deep link (may not work on every device)
    final callUri = Uri.parse('whatsapp://call?phone=$waDigits');
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri, mode: LaunchMode.externalApplication);
      return;
    }

    // Fallback: open WhatsApp chat
    final chatUri = Uri.parse('https://wa.me/$waDigits');
    if (await canLaunchUrl(chatUri)) {
      await launchUrl(chatUri, mode: LaunchMode.externalApplication);
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.cannotOpenWhatsapp),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _messageOnWhatsApp(String phone, String name) async {
    final loc = AppLocalizations.of(context);
    final waDigits = _normalizePhoneForWhatsApp(phone);
    final message = loc.driverWhatsappMessage(name);
    final uri = Uri.parse(
        'https://wa.me/$waDigits?text=${Uri.encodeComponent(message)}');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.cannotOpenWhatsapp),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _CallOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallOptionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: context.themeTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: context.themeTextSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}


