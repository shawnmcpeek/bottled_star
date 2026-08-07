import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';

import '../components/nucleus.dart';
import '../systems/radial_gravity.dart';
import 'collapse_tuning.dart';
import 'remnant_state.dart';

/// Outward radiation pressure opposing radial gravity near the remnant.
abstract final class EddingtonField {
  static bool _asserted = false;

  static void assertFalloff() {
    if (_asserted) return;
    assert(
      CollapseTuning.pressureFalloffExponent >
          RadialGravity.falloffExponent + 0.5,
      'Eddington pressure must fall off faster than radial gravity, '
      'or the moat radius will not resolve.',
    );
    _asserted = true;
  }

  static void applyPressure({
    required RemnantState state,
    required Vector2 origin,
    required Iterable<Nucleus> pieces,
  }) {
    assertFalloff();
    if (!state.exists || state.radiationPressure <= 0.001) return;

    final cutoff = state.radius * CollapseTuning.pressureCutoffRadii;
    final cutoffSq = cutoff * cutoff;

    var p = state.radiationPressure;
    if (state.kind == RemnantKind.blackHole) {
      p *= CollapseTuning.blackHolePressureMultiplier;
    }

    for (final piece in pieces) {
      if (!piece.isMounted || piece.pendingDestroy) continue;
      final delta = piece.body.position - origin;
      final distSq = delta.length2;
      if (distSq > cutoffSq || distSq < 0.0001) continue;

      final dist = math.sqrt(distSq);
      final dir = delta / dist;

      final falloff = math
          .pow(
            state.radius / dist,
            CollapseTuning.pressureFalloffExponent,
          )
          .toDouble();

      final magnitude = p *
          CollapseTuning.pressureForceScale *
          falloff *
          piece.body.mass;

      piece.body.applyForce(dir * magnitude);
    }
  }
}
