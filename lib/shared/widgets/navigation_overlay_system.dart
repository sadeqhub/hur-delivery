import 'package:flutter/material.dart';

/// Controller that manages the height of navigation overlays (footers)
/// and notifies listeners when the safe bottom inset changes.
class NavigationOverlayController extends ChangeNotifier {
  final Map<String, double> _overlayHeights = {};
  double _maxOverlayHeight = 0;

  double get bottomInset => _maxOverlayHeight;

  /// Returns the last reported height for a specific overlay key.
  /// Returns 0 if the key is not registered (e.g. the footer is hidden).
  double getHeight(String key) => _overlayHeights[key] ?? 0;

  void updateHeight(String key, double height) {
    if (_overlayHeights[key] != height) {
      _overlayHeights[key] = height;
      _recalculateMaxHeight();
    }
  }

  void removeOverlay(String key) {
    if (_overlayHeights.containsKey(key)) {
      _overlayHeights.remove(key);
      _recalculateMaxHeight();
    }
  }

  void _recalculateMaxHeight() {
    double max = 0;
    for (final height in _overlayHeights.values) {
      if (height > max) max = height;
    }

    if ((max - _maxOverlayHeight).abs() > 0.5) {
      _maxOverlayHeight = max;
      notifyListeners();
    }
  }
}

/// A scope that provides a [NavigationOverlayController] to its descendants.
/// Wrap your Scaffold or Page body with this widget.
class NavigationOverlayScope extends StatefulWidget {
  final Widget child;

  const NavigationOverlayScope({super.key, required this.child});

  @override
  State<NavigationOverlayScope> createState() => _NavigationOverlayScopeState();

  static NavigationOverlayController? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_InheritedNavigationOverlayScope>()?.controller;
  }
}

class _NavigationOverlayScopeState extends State<NavigationOverlayScope> {
  final NavigationOverlayController _controller = NavigationOverlayController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedNavigationOverlayScope(
      controller: _controller,
      child: widget.child,
    );
  }
}

class _InheritedNavigationOverlayScope extends InheritedNotifier<NavigationOverlayController> {
  final NavigationOverlayController controller;

  const _InheritedNavigationOverlayScope({
    required this.controller,
    required super.child,
  }) : super(notifier: controller);
}

/// A widget that positions its child relative to the safe bottom inset
/// reported by the [NavigationOverlayScope].
/// Use this for floating action buttons or other elements that should
/// float above the footer/navigation bar.
class AdaptivePositioned extends StatelessWidget {
  final Widget child;
  final double bottomOffset;
  final double? left;
  final double? right;
  final double? top;
  final Duration animationDuration;
  final Curve animationCurve;

  const AdaptivePositioned({
    super.key,
    required this.child,
    this.bottomOffset = 16.0,
    this.left,
    this.right,
    this.top,
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeInOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    final controller = NavigationOverlayScope.of(context);
    
    // If no controller found, fallback to standard Positioned with safe area
    final bottomInset = controller?.bottomInset ?? MediaQuery.of(context).viewPadding.bottom;
    
    return AnimatedPositioned(
      duration: animationDuration,
      curve: animationCurve,
      bottom: bottomInset + bottomOffset,
      left: left,
      right: right,
      top: top,
      child: child,
    );
  }
}
