import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Utility class to manage System UI modes (Status bar, Navigation bar)
class SystemUiUtils {
  
  /// Enables Edge-to-Edge mode where content draws behind system bars.
  /// This is the modern Android standard.
  /// 
  /// [statusBarColor] - Color of the status bar (top). Default transparent.
  /// [navBarColor] - Color of the navigation bar (bottom). Default transparent.
  /// [systemUiOverlayStyle] - Light or Dark icons.
  static void enableEdgeToEdge({
    Color statusBarColor = Colors.transparent,
    Color navBarColor = Colors.transparent, // Transparent to let content show through
    SystemUiOverlayStyle? systemUiOverlayStyle,
  }) {
    SystemChrome.setSystemUIOverlayStyle(
      systemUiOverlayStyle ?? SystemUiOverlayStyle(
        statusBarColor: statusBarColor,
        systemNavigationBarColor: navBarColor,
        // Enforce transparent divider on Android Q+
        systemNavigationBarDividerColor: Colors.transparent,
        // Ensure icons are visible based on theme usually, but can be forced here
        // If not provided, it inherits from Theme.
      ),
    );
    
    // This tells Flutter to let the app draw behind the system bars
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// Enter immersive sticky mode (hides bars, swipe to show)
  /// Use with caution as it hides navigation.
  static void enterImmersiveSticky() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Exit immersive mode and return to edge-to-edge (or normal)
  static void showSystemBars() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}
