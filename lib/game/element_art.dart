import 'dart:ui' as ui;

import 'package:flame/cache.dart';

import 'element_tier.dart';

/// Hand-painted element discs. Missing tiers fall back to procedural render.
///
/// Flame's [Images] prefixes loads with `assets/images/`, so Flame paths are
/// relative to that. Flutter [Image.asset] needs the full pubspec path.
abstract final class ElementArt {
  static const flameDirectory = 'elements';
  static const flutterDirectory = 'assets/images/elements';

  /// Filename stem per tier — add entries as new art lands.
  static const Map<ElementTier, String> fileNames = {
    ElementTier.hydrogen: 'Hydrogen.png',
    ElementTier.helium: 'Helium.png',
    ElementTier.carbon: 'carbon.png',
    ElementTier.oxygen: 'Oxygen.png',
    ElementTier.neon: 'Neon.png',
    ElementTier.magnesium: 'Magnisium.png',
    ElementTier.silicon: 'silicon.png',
    ElementTier.sulfur: 'sulfur.png',
    ElementTier.argon: 'argon.png',
    ElementTier.calcium: 'calcium.png',
    ElementTier.iron: 'iron.png',
  };

  /// Full Flutter asset path for widgets ([Image.asset]).
  static String? assetPath(ElementTier tier) {
    final name = fileNames[tier];
    if (name == null) return null;
    return '$flutterDirectory/$name';
  }

  /// Path relative to Flame's `assets/images/` prefix.
  static String? flamePath(ElementTier tier) {
    final name = fileNames[tier];
    if (name == null) return null;
    return '$flameDirectory/$name';
  }

  static bool hasArt(ElementTier tier) => fileNames.containsKey(tier);

  static List<String> get allFlamePaths => [
        for (final name in fileNames.values) '$flameDirectory/$name',
      ];

  /// Loads every known element PNG into Flame's image cache.
  static Future<void> preload(Images images) async {
    await images.loadAll(allFlamePaths);
  }

  static ui.Image? image(Images images, ElementTier tier) {
    final path = flamePath(tier);
    if (path == null || !images.containsKey(path)) return null;
    return images.fromCache(path);
  }
}
