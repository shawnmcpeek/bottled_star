import 'dart:math' as math;

import 'modes/game_mode.dart';
import 'element_tier.dart';

/// Tunable element sizes and fail-state knobs. Edit constants here for playtests.
abstract final class ElementTuning {
  /// Uniform nucleus scale for Classic + Collapse (Challenge stays at 1.0).
  /// Playtest: 1.0, 1.15, 1.20, 1.25.
  static const double kElementScaleClassicCollapse = 1.15;

  static const double kElementScaleChallenge = 1.0;

  /// Phase 2 — tier-to-tier radius ratio when [kUseDerivedTierRadii] is true.
  /// Inert: table radii in [ElementTier.baseRadius] are used instead.
  /// Playtest when enabled: 1.28, 1.32, 1.36 (stay below ~1.38).
  static const double kTierRadiusGrowthFactor = 1.22;

  static const bool kUseDerivedTierRadii = false;

  static const double kHydrogenBaseRadius = 14.0;

  /// Phase 3 — when true, Classic Fe+Fe does not supernova (inert ballast).
  /// Deliverable ships false so Classic behavior is unchanged until playtest.
  static const bool kIronInertClassicEnabled = false;

  /// Debug physics overlay (Classic/Collapse/Challenges). Off in release.
  static bool showPhysicsDebug = false;

  static double elementScaleFor(GameMode mode) => switch (mode) {
        GameMode.challenge => kElementScaleChallenge,
        GameMode.classic || GameMode.collapse => kElementScaleClassicCollapse,
      };

  /// Table or derived base radius before mode scale (never scaled for Challenge
  /// layout math — use [ElementTier.radiusFor] in gameplay).
  static double tableRadiusForTier(int tier) {
    if (!kUseDerivedTierRadii) {
      return ElementTier.fromTier(tier).baseRadius;
    }
    return kHydrogenBaseRadius *
        math.pow(kTierRadiusGrowthFactor, tier).toDouble();
  }

  /// Scale injection impulse so launch speed stays similar when mass ∝ r².
  static double impulseScaleFor(GameMode mode) {
    final s = elementScaleFor(mode);
    return s * s;
  }
}
