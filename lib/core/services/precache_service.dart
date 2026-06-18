import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../icons/hur_icons.dart';

class PrecacheService {
  static Future<void> preloadCoreAssets(BuildContext context) async {
    final rasterAssets = <ImageProvider>[
      const AssetImage('assets/icons/googlemaps.png'),
      const AssetImage('assets/icons/waze.png'),
    ];

    for (final provider in rasterAssets) {
      try {
        await precacheImage(provider, context);
      } catch (_) {}
    }

    await preloadHurIcons();
  }

  /// Warms the SVG cache so drawer/nav icons render instantly.
  static Future<void> preloadHurIcons() async {
    for (final path in HurIcons.all) {
      try {
        final loader = SvgAssetLoader(path);
        await svg.cache.putIfAbsent(
          loader.cacheKey(null),
          () => loader.loadBytes(null),
        );
      } catch (_) {}
    }
  }
}
