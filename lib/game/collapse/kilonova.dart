import 'package:flutter/foundation.dart';

import 'collapse_tuning.dart';
import 'remnant.dart';

/// Closing-speed check and startup safety for remnant–remnant merges.
abstract final class Kilonova {
  static bool _asserted = false;

  /// Call once when Collapse mode loads.
  static void assertThreshold() {
    if (_asserted) return;
    _asserted = true;
    assert(
      CollapseTuning.kilonovaClosingSpeed >
          CollapseTuning.gravityCeilingSpeed * 2.5,
      'Kilonova threshold (${CollapseTuning.kilonovaClosingSpeed}) is within '
      'reach of gravity alone (${CollapseTuning.gravityCeilingSpeed}). '
      'Remnants will merge while settling and the positioning game is dead. '
      'Raise blastRetentionFraction or lower remnantDensity.',
    );
    if (kDebugMode) {
      debugPrint(
        'Kilonova threshold=${CollapseTuning.kilonovaClosingSpeed.toStringAsFixed(1)} '
        'gravityCeiling=${CollapseTuning.gravityCeilingSpeed.toStringAsFixed(1)} '
        'blastDelivered=${CollapseTuning.blastDeliveredSpeed.toStringAsFixed(1)}',
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
      final pass = closingSpeed >= CollapseTuning.kilonovaClosingSpeed;
      debugPrint(
        'Remnant contact closing=${closingSpeed.toStringAsFixed(1)} '
        'threshold=${CollapseTuning.kilonovaClosingSpeed.toStringAsFixed(1)} '
        '${pass ? "PASS" : "fail"}',
      );
    }

    return closingSpeed >= CollapseTuning.kilonovaClosingSpeed;
  }
}
