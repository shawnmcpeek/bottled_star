import 'package:flutter/foundation.dart';

import '../modes/game_mode.dart';
import 'collapse_tuning.dart';
import 'remnant.dart';

/// Closing-speed check and startup safety for remnant–remnant merges.
abstract final class Kilonova {
  static bool _asserted = false;

  /// Call once when Collapse mode loads.
  static void assertThreshold(GameMode mode) {
    if (_asserted) return;
    _asserted = true;
    final closing = CollapseTuning.kilonovaClosingSpeedFor(mode);
    final gravityCeiling = CollapseTuning.gravityCeilingSpeed;
    assert(
      closing > gravityCeiling * 2.5,
      'Kilonova threshold ($closing) is within '
      'reach of gravity alone ($gravityCeiling). '
      'Remnants will merge while settling and the positioning game is dead. '
      'Raise blastRetentionFraction or lower remnantDensity.',
    );
    if (kDebugMode) {
      debugPrint(
        'Kilonova threshold=${closing.toStringAsFixed(1)} '
        'gravityCeiling=${gravityCeiling.toStringAsFixed(1)} '
        'blastDelivered=${CollapseTuning.blastDeliveredSpeedFor(mode).toStringAsFixed(1)}',
      );
    }
  }

  /// Sample velocities inside beginContact — before the solver resolves them.
  static bool shouldMerge(Remnant a, Remnant b) {
    final delta = b.body.position - a.body.position;
    final dist = delta.length;
    if (dist < 0.0001) return true;

    final normal = delta / dist;
    final relVel = b.body.linearVelocity - a.body.linearVelocity;
    final closingSpeed = -relVel.dot(normal);

    if (kDebugMode) {
      final threshold =
          CollapseTuning.kilonovaClosingSpeedFor(a.gameWorld.mode);
      final pass = closingSpeed >= threshold;
      debugPrint(
        'Remnant contact closing=${closingSpeed.toStringAsFixed(1)} '
        'threshold=${threshold.toStringAsFixed(1)} '
        '${pass ? "PASS" : "fail"}',
      );
    }

    return closingSpeed >=
        CollapseTuning.kilonovaClosingSpeedFor(a.gameWorld.mode);
  }
}
