import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

/// Helper class for managing map styles based on theme
class MapStyleHelper {
  /// Get the appropriate Mapbox style URI based on current theme
  static String getMapStyle(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return themeProvider.isDarkMode 
        ? MapboxStyles.DARK 
        : MapboxStyles.MAPBOX_STREETS;
  }

  /// Get the appropriate Mapbox style URI based on theme mode
  static String getMapStyleFromThemeMode(ThemeMode themeMode) {
    return themeMode == ThemeMode.dark 
        ? MapboxStyles.DARK 
        : MapboxStyles.MAPBOX_STREETS;
  }

  /// Check if dark mode is active
  static bool isDarkMode(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return themeProvider.isDarkMode;
  }
}

