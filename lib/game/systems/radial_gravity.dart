import '../constants.dart';

/// Classic radial gravity: constant acceleration toward chamber centre.
///
/// Falloff is exposed so Collapse Eddington pressure can assert a steeper
/// curve. Do not change [falloffExponent] or [GameConstants.gravityStrength]
/// to tune Collapse — use mode-scoped overrides instead.
abstract final class RadialGravity {
  /// Classic applies no distance falloff (force magnitude independent of r).
  static const double falloffExponent = 0.0;

  static double get strength => GameConstants.gravityStrength;
}
