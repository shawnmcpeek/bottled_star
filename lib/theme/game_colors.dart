import 'dart:ui';

/// Visual language for Bottled Star — warm contained star, not sterile lab.
abstract final class GameColors {
  static const space = Color(0xFF050308);
  static const spaceDeep = Color(0xFF0A0612);
  static const chamberVoid = Color(0xFF120810);
  static const chamberGlow = Color(0xFFFFB84A);
  static const chamberGlowSoft = Color(0x66FF9A3C);
  static const rimMetal = Color(0xFFE8C078);
  static const rimWarning = Color(0xFFFF5A3C);
  static const rimCritical = Color(0xFFFF2A2A);
  static const scoreText = Color(0xFFFFF0D4);
  static const mutedText = Color(0xB3E8C9A0);
  static const heliumAura = Color(0xFFFFE08A);
  static const mergeFlash = Color(0xFFFFF6D8);
  static const injectorBody = Color(0xFFFFD27A);
  static const injectorCharge = Color(0xFFFFF1B8);
  static const hudPanel = Color(0x990A0612);
}

abstract final class TierPalette {
  static const List<Color> fills = [
    Color(0xFFFFF4D2), // H
    Color(0xFFFFE066), // He — energetic fuel
    Color(0xFFFFB347), // C
    Color(0xFFFF8F3C), // O
    Color(0xFFFF6B3D), // Ne
    Color(0xFFF24E3D), // Mg
    Color(0xFFE03A48), // Si
    Color(0xFFC92E5A), // S
    Color(0xFFA8286E), // Ar
    Color(0xFF8B2478), // Ca
    Color(0xFF6B1F6E), // Fe
  ];

  static const List<Color> glows = [
    Color(0x66FFF8E0),
    Color(0xAAFFE066),
    Color(0x88FFB347),
    Color(0x77FF8F3C),
    Color(0x66FF6B3D),
    Color(0x55F24E3D),
    Color(0x55E03A48),
    Color(0x44C92E5A),
    Color(0x44A8286E),
    Color(0x338B2478),
    Color(0x336B1F6E),
  ];

  static Color fillFor(int tier) => fills[tier.clamp(0, fills.length - 1)];
  static Color glowFor(int tier) => glows[tier.clamp(0, glows.length - 1)];
}
