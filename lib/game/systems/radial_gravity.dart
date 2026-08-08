import '../constants.dart';

/// Classic radial gravity: constant acceleration toward chamber centre.
///
/// Do not change [falloffExponent] or [GameConstants.gravityStrength] to tune
/// Collapse — Collapse derives its kilonova threshold from these read-only
/// values instead.
abstract final class RadialGravity {
  /// Classic applies no distance falloff (force magnitude independent of r).
  static const double falloffExponent = 0.0;

  static double get strength => GameConstants.gravityStrength;

  /// Acceleration magnitude for a body with the given relative density.
  static double accelerationForDensity(double relativeDensity) =>
      strength * relativeDensity;
}
