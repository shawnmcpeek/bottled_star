import 'package:flutter/material.dart';

import 'game_colors.dart';
import 'game_fonts.dart';

abstract final class AppTheme {
  static ThemeData build() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: GameColors.space,
      fontFamily: GameFonts.spaceGrotesk,
      colorScheme: const ColorScheme.dark(
        primary: GameColors.chamberGlow,
        secondary: GameColors.rimMetal,
        surface: GameColors.spaceDeep,
        onPrimary: GameColors.space,
        onSurface: GameColors.scoreText,
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: GameFonts.ui(
          fontSize: 40,
          weight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        displayMedium: GameFonts.ui(
          fontSize: 32,
          weight: FontWeight.w600,
        ),
        headlineMedium: GameFonts.ui(
          fontSize: 24,
          weight: FontWeight.w600,
        ),
        titleLarge: GameFonts.ui(
          fontSize: 20,
          weight: FontWeight.w600,
        ),
        bodyLarge: GameFonts.prose(fontSize: 16),
        bodyMedium: GameFonts.prose(fontSize: 14),
        labelLarge: GameFonts.ui(
          fontSize: 16,
          weight: FontWeight.w700,
          letterSpacing: 0.4,
          color: GameColors.space,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GameColors.chamberGlow,
          foregroundColor: GameColors.space,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GameFonts.ui(
            fontSize: 16,
            weight: FontWeight.w700,
            color: GameColors.space,
          ),
        ),
      ),
    );
  }
}
