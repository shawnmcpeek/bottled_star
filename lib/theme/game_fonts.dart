import 'package:flutter/painting.dart';

import 'game_colors.dart';

/// Bundled type: Space Grotesk (functional) + Fraunces (endings / codex).
/// No runtime network fetch — faces live in `assets/fonts/`.
abstract final class GameFonts {
  static const spaceGrotesk = 'Space Grotesk';
  static const fraunces = 'Fraunces';

  static const _tabular = [FontFeature.tabularFigures()];

  /// Soft up, wonk low — for ending/codex prose.
  static const _frauncesProse = [
    FontVariation('SOFT', 80),
    FontVariation('WONK', 0.25),
    FontVariation('opsz', 18),
    FontVariation('wght', 400),
  ];

  static const _frauncesDisplay = [
    FontVariation('SOFT', 70),
    FontVariation('WONK', 0.2),
    FontVariation('opsz', 36),
    FontVariation('wght', 600),
  ];

  /// Element symbols on nuclei / injector chips.
  static TextStyle symbol({
    required double fontSize,
    Color color = const Color(0xD11A0808),
    bool multiLetter = false,
  }) {
    return TextStyle(
      fontFamily: spaceGrotesk,
      fontWeight: FontWeight.w700,
      fontSize: fontSize,
      color: color,
      letterSpacing: multiLetter ? -0.6 : 0,
      height: 1,
    );
  }

  /// Score and other counting numerals — tabular so digits don't jitter.
  static TextStyle score({
    double fontSize = 36,
    FontWeight weight = FontWeight.w500,
    Color color = GameColors.scoreText,
    double height = 1.05,
  }) {
    return TextStyle(
      fontFamily: spaceGrotesk,
      fontWeight: weight,
      fontSize: fontSize,
      color: color,
      height: height,
      fontFeatures: _tabular,
    );
  }

  /// Uppercase HUD labels (SCORE, PEAK, NOW) — ~0.15em tracking.
  static TextStyle label({
    double fontSize = 11,
    Color color = GameColors.mutedText,
    FontWeight weight = FontWeight.w500,
  }) {
    return TextStyle(
      fontFamily: spaceGrotesk,
      fontWeight: weight,
      fontSize: fontSize,
      color: color,
      letterSpacing: fontSize * 0.15,
      height: 1.1,
    );
  }

  static TextStyle ui({
    double fontSize = 14,
    FontWeight weight = FontWeight.w500,
    Color color = GameColors.scoreText,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: spaceGrotesk,
      fontWeight: weight,
      fontSize: fontSize,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Ending / future codex body copy.
  static TextStyle prose({
    double fontSize = 14,
    Color color = GameColors.mutedText,
    double height = 1.45,
  }) {
    return TextStyle(
      fontFamily: fraunces,
      fontSize: fontSize,
      color: color,
      height: height,
      fontVariations: _frauncesProse,
    );
  }

  /// Ending card titles (WHITE DWARF, SUPERNOVA).
  static TextStyle endingTitle({
    double fontSize = 28,
    Color color = GameColors.scoreText,
  }) {
    return TextStyle(
      fontFamily: fraunces,
      fontSize: fontSize,
      color: color,
      letterSpacing: 2,
      height: 1.1,
      fontVariations: _frauncesDisplay,
    );
  }

  /// Small ending eyebrows (CONTAINMENT LOST, CORE COLLAPSE).
  static TextStyle endingEyebrow({
    double fontSize = 12,
    Color color = GameColors.mutedText,
  }) {
    return TextStyle(
      fontFamily: spaceGrotesk,
      fontWeight: FontWeight.w600,
      fontSize: fontSize,
      color: color,
      letterSpacing: fontSize * 0.2,
    );
  }
}
