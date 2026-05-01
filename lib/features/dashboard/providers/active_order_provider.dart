import 'package:flutter/foundation.dart';

import '../../../core/providers/order_provider.dart';
import '../../../shared/models/order_model.dart';

/// Owns the driver's active order list and the swipe-card index.
///
/// **Old architecture problems fixed here:**
///   - The order list was re-filtered by 6 independent Consumer widgets,
///     each calling `getAllActiveOrdersForDriver()` redundantly.
///   - `_currentOrderIndex` and `_cachedActiveOrders` lived directly in the
///     8 000-line dashboard widget, mixing UI state with data concerns.
///   - Any OrderProvider change (even an unrelated order status update)
///     triggered every Consumer rebuild.  This provider absorbs OrderProvider
///     changes and only notifyListeners() when the _visible_ order list
///     actually differs — so downstream Selectors fire far less often.
class ActiveOrderProvider extends ChangeNotifier {
  final OrderProvider _orderProvider;
  final String _driverId;

  List<OrderModel> _orders = [];
  int _currentIndex = 0;

  ActiveOrderProvider({
    required OrderProvider orderProvider,
    required String driverId,
  })  : _orderProvider = orderProvider,
        _driverId = driverId {
    _orderProvider.addListener(_sync);
    _sync();
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  List<OrderModel> get orders => _orders;
  int get currentIndex => _currentIndex;
  bool get hasOrders => _orders.isNotEmpty;
  OrderModel? get current =>
      _orders.isNotEmpty ? _orders[_currentIndex] : null;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  void setCurrentIndex(int index) {
    if (index < 0 || index >= _orders.length || index == _currentIndex) return;
    _currentIndex = index;
    notifyListeners();
  }

  /// Force a refresh from OrderProvider (e.g. after accept/reject).
  void refresh() => _sync(force: true);

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _sync({bool force = false}) {
    final fresh = _orderProvider.getAllActiveOrdersForDriver(_driverId);

    // Only notify if the visible list actually changed — avoids cascading
    // rebuilds from unrelated OrderProvider changes.
    if (!force && _listEqual(fresh, _orders)) return;

    // Remember the previously focused order's ID so we can re-find it after
    // the list is refreshed.  When a new order arrives and is inserted at the
    // front, a naive clamp would silently switch the focused card to the new
    // pending order instead of keeping the driver on the order they were viewing.
    final previousFocusId =
        (_orders.isNotEmpty && _currentIndex < _orders.length)
            ? _orders[_currentIndex].id
            : null;

    _orders = List.unmodifiable(fresh);

    if (_orders.isEmpty) {
      _currentIndex = 0;
    } else if (previousFocusId != null) {
      // Try to keep the same order focused after the list refresh.
      final newIdx = _orders.indexWhere((o) => o.id == previousFocusId);
      if (newIdx != -1) {
        _currentIndex = newIdx;
      } else {
        // Previously focused order is gone (e.g. completed/rejected) — reset.
        _currentIndex = 0;
      }
    } else {
      _currentIndex = _currentIndex.clamp(0, _orders.length - 1);
    }

    notifyListeners();
  }

  bool _listEqual(List<OrderModel> a, List<OrderModel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].status != b[i].status ||
          // Timer fields: presence/absence of the delivery timer must also
          // trigger a rebuild so the countdown appears/disappears correctly
          // when the server sets or clears these fields between status updates.
          a[i].deliveryTimerExpiresAt != b[i].deliveryTimerExpiresAt ||
          a[i].deliveryTimerStoppedAt != b[i].deliveryTimerStoppedAt) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _orderProvider.removeListener(_sync);
    super.dispose();
  }
}
