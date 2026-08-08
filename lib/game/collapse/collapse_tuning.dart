import 'dart:math' as math;

import '../constants.dart';
import '../element_tier.dart';
import '../systems/supernova_blast.dart';

/// All Collapse-mode magic numbers. Nothing here retunes Classic.
abstract final class CollapseTuning {
  // --- Remnant geometry / body ---
  /// Visibly smaller than iron — density reads as compactness.
  static const double remnantRadiusFactor = 0.8;

  /// Multiplier on Fe fixture density. Keep low — Box2D degrades past ~10:1
  /// mass ratios and light nuclei were wedging into remnant/Ca contacts.
  static const double remnantDensityFactor = 3.5;

  static const double remnantFriction = 0.4;
  static const double remnantRestitution = 0.05;

  static double get remnantRadius =>
      remnantRadiusFactor * ElementTier.iron.radius;

  static double get remnantDensity =>
      remnantDensityFactor * ElementTier.iron.fixtureDensity;

  /// Analytic Box2D mass (density × area) for threshold derivation.
  static double get remnantMass {
    final r = remnantRadius;
    return remnantDensity * math.pi * r * r;
  }

  /// Relative density used for radial gravity force (matches Nucleus formula).
  static double get remnantRelativeDensity =>
      remnantDensityFactor * ElementTier.iron.relativeDensity;

  // --- Kilonova threshold derivation ---
  /// Typical distance from a blast origin to a remnant being shoved.
  static double get typicalRemnantSeparation =>
      GameConstants.kVaporizeRadius * 0.65;

  /// Fraction of blast-delivered speed a remnant must still carry on impact.
  static const double blastRetentionFraction = 0.4;

  /// Collapse-only multiplier when a supernova shell hits a remnant.
  ///
  /// Classic [GameConstants.kBlastImpulse] is tuned for ladder nuclei. Remnant
  /// fixture masses are much higher, so without a mode-scoped gain the shell
  /// cannot produce a usable Δv and the kilonova threshold is unreachable.
  /// This does not change the shared blast constant.
  static const double remnantBlastImpulseGain = 8000.0;

  /// Empirical ceiling for gravity/settle closing speeds at remnant contact.
  /// Free-fall √(2ad) overshoots badly once linear damping is in play.
  static const double gravityContactClosingCeiling = 15.0;

  static double get blastDeliveredSpeed =>
      SupernovaBlast.impulseAtRadius(typicalRemnantSeparation) *
      remnantBlastImpulseGain /
      remnantMass;

  static double get gravityCeilingSpeed => gravityContactClosingCeiling;

  static double get kilonovaClosingSpeed =>
      blastDeliveredSpeed * blastRetentionFraction;

  // --- Kilonova payoff ---
  static const int kilonovaScore = 750;

  /// Outward impulse on nearby nuclei (supernova-style, lower magnitude).
  static const double kilonovaClearImpulse = 4200.0;
  static const double kilonovaClearRadius = 160.0;

  // --- Collision categories (raw bits; no shared CollisionCategory type) ---
  static const int categoryRemnant = 0x0004;
}

