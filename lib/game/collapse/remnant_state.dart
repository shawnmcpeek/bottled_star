import 'dart:math' as math;

import '../constants.dart';
import 'collapse_tuning.dart';

enum RemnantKind { none, neutronStar, blackHole }

class RemnantState {
  RemnantKind kind = RemnantKind.none;

  /// Accumulated mass in arbitrary units. Drives radius and TOV crossing.
  double mass = 0.0;

  /// Number of supernovae survived this run. Drives ending message bucket.
  int supernovaCount = 0;

  /// Total pieces consumed. Stats / ending card.
  int consumedCount = 0;

  /// Eddington radiation pressure, 0..1+. Spikes on consumption, decays over time.
  double radiationPressure = 0.0;

  /// Seconds since last consumption. Drives the starvation floor.
  double timeSinceLastMeal = 0.0;

  bool get exists => kind != RemnantKind.none;

  /// Physical radius in world units, derived from mass.
  double get radius =>
      CollapseTuning.baseRemnantRadius +
      CollapseTuning.radiusPerMass * math.sqrt(mass);

  bool get chamberConsumed =>
      exists &&
      radius >=
          GameConstants.chamberRadius * CollapseTuning.chamberConsumedFraction;

  void reset() {
    kind = RemnantKind.none;
    mass = 0;
    supernovaCount = 0;
    consumedCount = 0;
    radiationPressure = 0;
    timeSinceLastMeal = 0;
  }
}
