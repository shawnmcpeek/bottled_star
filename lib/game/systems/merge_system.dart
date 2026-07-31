import 'package:flame_forge2d/flame_forge2d.dart';

import '../components/effects.dart';
import '../components/nucleus.dart';
import '../constants.dart';
import '../element_tier.dart';
import 'bottled_star_world.dart';

class PendingMerge {
  PendingMerge(this.a, this.b);

  final Nucleus a;
  final Nucleus b;

  bool get isSameTier => ElementTier.isSameTierMerge(a.tier, b.tier);
}

class MergeSystem {
  MergeSystem(this.world);

  final BottledStarWorld world;

  final List<PendingMerge> _queue = [];

  int scoreGainedThisStep = 0;
  int chainDepth = 0;
  ElementTier? highestCreated;

  /// Queue a candidate. Claiming happens in [resolve] after precedence sort.
  void request(Nucleus a, Nucleus b) {
    if (a.pendingDestroy || b.pendingDestroy) return;
    if (identical(a, b)) return;
    if (ElementTier.mergeResult(a.tier, b.tier) == null) return;
    if (_containsPair(a, b)) return;
    _queue.add(PendingMerge(a, b));
  }

  bool _containsPair(Nucleus a, Nucleus b) {
    for (final p in _queue) {
      if ((identical(p.a, a) && identical(p.b, b)) ||
          (identical(p.a, b) && identical(p.b, a))) {
        return true;
      }
    }
    return false;
  }

  /// Geometric scan for resting / already-touching mergeable pairs.
  /// Needed after hot reload and for pairs that never re-fire beginContact.
  void scanTouchingPairs() {
    final list = world.nuclei
        .where((n) => n.isMounted && !n.pendingDestroy)
        .toList();
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        final a = list[i];
        final b = list[j];
        if (ElementTier.mergeResult(a.tier, b.tier) == null) continue;
        final gap = a.body.position.distanceTo(b.body.position) -
            a.tier.radius -
            b.tier.radius;
        if (gap <= GameConstants.mergeContactEpsilon) {
          request(a, b);
        }
      }
    }
  }

  void resolve() {
    scoreGainedThisStep = 0;
    if (_queue.isEmpty) {
      chainDepth = 0;
      return;
    }

    // Same-tier before helium capture — larger gain, expected by the player.
    final batch = List<PendingMerge>.from(_queue)
      ..sort((x, y) {
        if (x.isSameTier == y.isSameTier) return 0;
        return x.isSameTier ? -1 : 1;
      });
    _queue.clear();

    final consumed = <Nucleus>{};

    for (final pending in batch) {
      final a = pending.a;
      final b = pending.b;
      if (consumed.contains(a) || consumed.contains(b)) continue;
      if (!a.isMounted || !b.isMounted) continue;
      if (a.pendingDestroy || b.pendingDestroy) continue;

      final result = ElementTier.mergeResult(a.tier, b.tier);
      if (result == null) continue;

      consumed
        ..add(a)
        ..add(b);
      a.pendingDestroy = true;
      b.pendingDestroy = true;

      final posA = a.body.position.clone();
      final posB = b.body.position.clone();
      final mid = (posA + posB) * 0.5;

      final massA = a.body.mass;
      final massB = b.body.mass;
      final massSum = massA + massB;
      final velocity = massSum > 0
          ? (a.body.linearVelocity * massA + b.body.linearVelocity * massB) /
              massSum
          : Vector2.zero();

      final cascaded = a.freshFromMerge || b.freshFromMerge;
      if (cascaded) {
        chainDepth += 1;
      } else {
        chainDepth = 0;
      }

      final base = result.scoreOnCreate;
      final multiplier = 1 + (0.5 * chainDepth);
      scoreGainedThisStep += (base * multiplier).round();

      highestCreated = result;
      world.onElementCreated(result);

      a.removeFromParent();
      b.removeFromParent();

      world.spawnNucleus(
        tier: result,
        position: mid,
        freshFromMerge: true,
        velocity: velocity,
      );

      world.add(
        MergeFlash(at: mid, radius: result.radius),
      );
    }
  }
}
