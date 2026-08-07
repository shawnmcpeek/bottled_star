import '../element_tier.dart';
import '../systems/radial_gravity.dart';

/// All Collapse-mode magic numbers. Nothing here retunes Classic.
abstract final class CollapseTuning {
  // --- Geometry (factors × Fe radius so the remnant reads as a distinct body) ---
  static const double baseRemnantRadiusFactor = 1.15;
  static const double radiusPerMassFactor = 0.22;

  static double get baseRemnantRadius =>
      baseRemnantRadiusFactor * ElementTier.iron.radius;

  static double get radiusPerMass =>
      radiusPerMassFactor * ElementTier.iron.radius;

  // --- Accretion ---
  static const double massPerTierUnit = 0.08;
  static const double massFloor = 0.05;
  static const double massPerSupernova = 1.0;

  // --- TOV limit: neutron star → black hole ---
  static const double tovMassThreshold = 3.0;

  // --- Eddington radiation pressure ---
  static const double pressurePerMass = 1.4;
  static const double pressureDecay = 1.8;
  static const double pressureForceScale = 2.6;

  /// Must exceed [RadialGravity.falloffExponent] — see EddingtonField assert.
  static const double pressureFalloffExponent = 3.0;
  static const double pressureCutoffRadii = 4.5;
  static const double blackHolePressureMultiplier = 0.25;

  // --- Starvation floor ---
  static const double starvationInterval = 15.0;
  static const double starvationReach = 2.0;

  // --- Scoring ---
  static const double consumptionCreditFraction = 0.35;

  // --- Fail state ---
  static const double chamberConsumedFraction = 0.55;

  // --- TOV presentation ---
  static const double blackHoleBeatSeconds = 1.2;
}
