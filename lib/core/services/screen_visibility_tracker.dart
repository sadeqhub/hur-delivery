import 'package:flutter/material.dart';

/// Tracks which screen is currently visible to prioritize requests
class ScreenVisibilityTracker {
  static final ScreenVisibilityTracker _instance = ScreenVisibilityTracker._internal();
  factory ScreenVisibilityTracker() => _instance;
  ScreenVisibilityTracker._internal();

  String? _currentScreen;
  final Map<String, DateTime> _screenHistory = {};

  /// Register that a screen is now visible
  void setVisibleScreen(String screenName) {
    if (_currentScreen != screenName) {
      final previousScreen = _currentScreen;
      _currentScreen = screenName;
      _screenHistory[screenName] = DateTime.now();
      
      if (previousScreen != null) {
        print('📱 Screen changed: $previousScreen → $screenName');
      } else {
        print('📱 Screen visible: $screenName');
      }
    }
  }

  /// Register that a screen is no longer visible
  void setScreenHidden(String screenName) {
    if (_currentScreen == screenName) {
      _currentScreen = null;
      print('📱 Screen hidden: $screenName');
    }
  }

  /// Get the currently visible screen
  String? get currentScreen => _currentScreen;

  /// Check if a specific screen is currently visible
  bool isScreenVisible(String screenName) {
    return _currentScreen == screenName;
  }

  /// Get screen visibility duration
  Duration? getScreenVisibilityDuration(String screenName) {
    final visibleAt = _screenHistory[screenName];
    if (visibleAt == null) return null;
    return DateTime.now().difference(visibleAt);
  }

  /// Check if screen has been visible for a minimum duration
  bool hasScreenBeenVisibleFor(String screenName, Duration minimumDuration) {
    final duration = getScreenVisibilityDuration(screenName);
    if (duration == null) return false;
    return duration >= minimumDuration;
  }
}

/// Mixin for screens to automatically track visibility
mixin ScreenVisibilityMixin<T extends StatefulWidget> on State<T> {
  String get screenName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScreenVisibilityTracker().setVisibleScreen(screenName);
    });
  }

  @override
  void dispose() {
    ScreenVisibilityTracker().setScreenHidden(screenName);
    super.dispose();
  }
}

