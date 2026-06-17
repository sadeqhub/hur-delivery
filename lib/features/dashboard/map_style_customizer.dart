import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
/// Mutes default Mapbox styles (Streets/Dark) for a calmer “silver” driver view.
/// Best-effort: missing layer ids are ignored.
abstract final class MapStyleCustomizer {
  static String? _lastStyleUri;

  static Future<void> applyIfNeeded(MapboxMap map) async {
    final uri = await map.style.getStyleURI();
    if (_lastStyleUri == uri) return;
    _lastStyleUri = uri;

    final isDark = uri.contains('dark');

    try {
      if (!isDark) {
        await map.style.setStyleLayerProperty(
            'background', 'background-color', '#F3F4F6');
      }
    } catch (_) {}

    const hideCandidates = [
      'poi-label',
      'poi',
      'transit-label',
      'airport-label',
      'road-label-navigation',
    ];

    for (final id in hideCandidates) {
      try {
        if (await map.style.styleLayerExists(id)) {
          await map.style.setStyleLayerProperty(
              id, 'visibility', 'none');
        }
      } catch (_) {}
    }

    if (!isDark) {
      const roadIds = [
        'road-primary',
        'road-secondary-tertiary',
        'road-street',
        'road-minor-low',
      ];
      for (final id in roadIds) {
        try {
          if (await map.style.styleLayerExists(id)) {
            await map.style.setStyleLayerProperty(
                id, 'line-color', '#E6E8EC');
          }
        } catch (_) {}
      }
    }
  }

  /// Clear when testing style switching from outside.
  static void reset() => _lastStyleUri = null;
}
