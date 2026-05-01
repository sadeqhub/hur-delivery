import 'package:flutter/material.dart';
import 'navigation_overlay_system.dart';
import 'size_reporting_widget.dart';

/// A wrapper widget that ensures its child (footer) is positioned correctly
/// respecting the Android system navigation bar (gesture pill or 3-button nav)
/// and the keyboard.
/// 
/// Automatically reports its height to [NavigationOverlaySystem] if [id] is provided.
class NavigationBarAwareFooterWrapper extends StatefulWidget {
  final Widget child;
  
  /// Unique ID for the Navigation Overlay System.
  /// If provided, this footer's height will be tracked globally.
  final String? id;
  
  /// Whether to hide the footer when the keyboard is open.
  /// Useful for floating action buttons or non-essential status bars.
  /// Default is false (footer moves up with keyboard).
  final bool hideOnKeyboardOpen;
  
  /// Optional background color for the content area of the footer.
  /// If null, it will be transparent.
  final Color? backgroundColor;

  /// Optional background color specifically for the system navigation bar zone
  /// (the area below the content, covering the device's gesture/button bar).
  /// Falls back to [backgroundColor] if not set.
  final Color? navBarZoneColor;

  /// Padding to apply inside the safe area logic.
  /// This adds to the safe area padding.
  final EdgeInsets padding;

  /// Duration for the layout animation (keyboard/nav bar changes)
  final Duration animationDuration;

  /// Curve for the layout animation
  final Curve animationCurve;

  const NavigationBarAwareFooterWrapper({
    super.key,
    required this.child,
    this.id,
    this.hideOnKeyboardOpen = false,
    this.backgroundColor,
    this.navBarZoneColor,
    this.padding = EdgeInsets.zero,
    this.animationDuration = const Duration(milliseconds: 200),
    this.animationCurve = Curves.easeOutQuad,
  });

  @override
  State<NavigationBarAwareFooterWrapper> createState() => _NavigationBarAwareFooterWrapperState();
}

class _NavigationBarAwareFooterWrapperState extends State<NavigationBarAwareFooterWrapper> {
  NavigationOverlayController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.id != null) {
      _controller = NavigationOverlayScope.of(context);
    }
  }

  @override
  void dispose() {
    if (widget.id != null && _controller != null) {
      // We can't easily remove on dispose because controller might be disposed too
      // But usually it's fine as the map key will just be overwritten next time
      // Ideally we would call removeOverlay but we need to be careful about lifecycle
      // _controller!.removeOverlay(widget.id!); 
      // Actually, standard practice is to let it be or remove. 
      // Safe to remove if controller is still alive.
      try {
        _controller?.removeOverlay(widget.id!);
      } catch (_) {}
    }
    super.dispose();
  }

  void _updateHeight(Size size, double effectiveBottomPadding) {
    if (widget.id != null && _controller != null) {
      // The total visual height blocking the bottom of the screen is:
      // content height + internal padding + safe area inset
      final totalHeight = size.height + widget.padding.bottom + effectiveBottomPadding;
      _controller!.updateHeight(widget.id!, totalHeight);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get media query data
    final mediaQuery = MediaQuery.of(context);
    
    // Bottom padding from system navigation bar
    // viewPadding is better than padding for persistent UI elements as it stays
    // valid even when keyboard opens (where padding.bottom reduces to 0)
    final double systemNavBarHeight = mediaQuery.viewPadding.bottom;
    
    // Bottom inset from keyboard
    final double keyboardHeight = mediaQuery.viewInsets.bottom;
    
    // Max of either, to ensure we clear both (though typically they add up in different ways)
    // Actually, when keyboard is open, we usually want to be above it.
    // When keyboard is closed, we want to be above the nav bar.
    
    // Logic:
    // If keyboard is open (keyboardHeight > 0):
    //   totalBottom = keyboardHeight (keyboard usually covers nav bar in coordinate space)
    // If keyboard is closed:
    //   totalBottom = systemNavBarHeight
    
    // Note: On some Android versions/modes, viewInsets includes nav bar height, on others not.
    // Using max is a safe bet for "above everything".
    final double effectiveBottomPadding = keyboardHeight > 0 
        ? keyboardHeight 
        : systemNavBarHeight;

    final bool isKeyboardOpen = keyboardHeight > 0;

    if (widget.hideOnKeyboardOpen && isKeyboardOpen) {
      // If hiding, report 0 height
      if (widget.id != null && _controller != null) {
         _controller!.updateHeight(widget.id!, 0);
      }
      return const SizedBox.shrink();
    }

    // Split into content area + system nav bar zone.
    // The nav bar zone is wrapped in IgnorePointer so no Flutter widget can
    // absorb gestures there — critical for edge-back and home-swipe on devices
    // that use gesture navigation (Android 10+ / iOS).
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: widget.animationDuration,
          curve: widget.animationCurve,
          padding: widget.padding,
          color: widget.backgroundColor,
          child: SizeReportingWidget(
            onSizeChange: (size) => _updateHeight(size, effectiveBottomPadding),
            child: widget.child,
          ),
        ),
        // System nav bar zone: visually fills the area to avoid bleed-through,
        // but IgnorePointer ensures this zone is completely transparent to touches.
        IgnorePointer(
          child: AnimatedContainer(
            duration: widget.animationDuration,
            curve: widget.animationCurve,
            height: effectiveBottomPadding,
            color: widget.navBarZoneColor ?? widget.backgroundColor,
          ),
        ),
      ],
    );
  }
}
