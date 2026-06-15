import 'dart:async';
import 'package:flutter/foundation.dart';

/// Controller holding the driver dashboard UI state that was previously
/// scattered across 47 setState calls in _DriverDashboardState.
class DriverDashboardController extends ChangeNotifier {
  bool _isOnline = false;
  bool _showSidebar = false;
  bool _isOrderCardExpanded = true;
  int _currentOrderIndex = 0;
  String? _expandedAddressCardId;
  bool _showNavigationButtons = false;
  double? _targetLatitude;
  double? _targetLongitude;
  bool _hasLocationAlwaysPermission = false;

  bool get isOnline => _isOnline;
  bool get showSidebar => _showSidebar;
  bool get isOrderCardExpanded => _isOrderCardExpanded;
  int get currentOrderIndex => _currentOrderIndex;
  String? get expandedAddressCardId => _expandedAddressCardId;
  bool get showNavigationButtons => _showNavigationButtons;
  double? get targetLatitude => _targetLatitude;
  double? get targetLongitude => _targetLongitude;
  bool get hasLocationAlwaysPermission => _hasLocationAlwaysPermission;

  void setOnline(bool value) {
    if (_isOnline == value) return;
    _isOnline = value;
    notifyListeners();
  }

  void toggleSidebar() {
    _showSidebar = !_showSidebar;
    notifyListeners();
  }

  void setSidebarVisible(bool visible) {
    if (_showSidebar == visible) return;
    _showSidebar = visible;
    notifyListeners();
  }

  void setOrderCardExpanded(bool expanded) {
    if (_isOrderCardExpanded == expanded) return;
    _isOrderCardExpanded = expanded;
    notifyListeners();
  }

  void setCurrentOrderIndex(int index) {
    if (_currentOrderIndex == index) return;
    _currentOrderIndex = index;
    notifyListeners();
  }

  void toggleAddressCard(String cardId, {double? lat, double? lng}) {
    if (_expandedAddressCardId == cardId) {
      _expandedAddressCardId = null;
      _showNavigationButtons = false;
      _targetLatitude = null;
      _targetLongitude = null;
    } else {
      _expandedAddressCardId = cardId;
      _showNavigationButtons = lat != null && lng != null;
      _targetLatitude = lat;
      _targetLongitude = lng;
    }
    notifyListeners();
  }

  void closeAddressCard() {
    _expandedAddressCardId = null;
    _showNavigationButtons = false;
    _targetLatitude = null;
    _targetLongitude = null;
    notifyListeners();
  }

  void setNavigationTarget(double lat, double lng) {
    _targetLatitude = lat;
    _targetLongitude = lng;
    _showNavigationButtons = true;
    notifyListeners();
  }

  void setLocationPermission(bool hasPermission) {
    if (_hasLocationAlwaysPermission == hasPermission) return;
    _hasLocationAlwaysPermission = hasPermission;
    notifyListeners();
  }
}
