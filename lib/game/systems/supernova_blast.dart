import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../components/nucleus.dart';
import '../constants.dart';
import 'bottled_star_world.dart';

/// Expanding, lobed supernova shell. Affects each body exactly once as the
/// front reaches it — core eject, outer push, beyond untouched.
class SupernovaBlast extends PositionComponent {
  factory SupernovaBlast({
    required Vector2 origin,
    required BottledStarWorld gameWorld,
    math.Random? random,
    double? blastAxis,
  }) {
    final rng = random ?? math.Random();
    return SupernovaBlast._(
      origin: origin,
      gameWorld: gameWorld,
      random: rng,
      blastAxis: blastAxis ?? rng.nextDouble() * 2 * math.pi,
    );
  }

  SupernovaBlast._({
    required Vector2 origin,
    required this.gameWorld,
    required this.random,
    required this.blastAxis,
  })  : origin = origin.clone(),
        super(
          position: origin.clone(),
          anchor: Anchor.center,
          priority: 55,
        );

  final Vector2 origin;
  final BottledStarWorld gameWorld;
  final math.Random random;
  final double blastAxis;

  double _shellT = 0;
  final Set<Nucleus> _processed = {};
  bool _remnantHooked = false;

  double get _progress =>
      (_shellT / GameConstants.kShellDuration).clamp(0.0, 1.0);

  static double lobe(Vector2 pos, Vector2 origin, double axis) {
    final d = pos - origin;
    if (d.length2 < 0.01) {
      return 1.0 + GameConstants.kAsymmetry;
    }
    final alpha = math.atan2(d.y, d.x);
    return 1.0 + GameConstants.kAsymmetry * math.cos(alpha - axis);
  }

  /// Pure classifier for tests: `eject`, `push`, or `none`.
  static String classify({
    required double dist,
    required double lobeFactor,
    required double softRoll,
  }) {
    final vaporizeAt = GameConstants.kVaporizeRadius * lobeFactor;
    final soft = GameConstants.kSoftEdge;
    if (dist < vaporizeAt * (1 - soft)) return 'eject';
    if (dist < vaporizeAt * (1 + soft)) {
      final band = (dist - vaporizeAt * (1 - soft)) /
          (2 * soft * vaporizeAt);
      return softRoll > band ? 'eject' : 'push';
    }
    if (dist < GameConstants.kBlastRadius * lobeFactor) return 'push';
    return 'none';
  }

  @override
  void update(double dt) {
    _shellT += dt;
    final shellBase = _progress * GameConstants.kBlastRadius;

    final pendingEject = <Nucleus>[];

    for (final n in List<Nucleus>.from(gameWorld.nuclei)) {
      if (_processed.contains(n) || !n.isMounted || n.pendingDestroy) {
        continue;
      }

      final pos = n.body.position;
      final delta = pos - origin;
      final dist = delta.length;
      final lobeFactor = lobe(pos, origin, blastAxis);

      // Shell front is itself lobed — strong side reaches farther first.
      if (dist > shellBase * lobeFactor) continue;

      _processed.add(n);

      final action = classify(
        dist: dist,
        lobeFactor: lobeFactor,
        softRoll: random.nextDouble(),
      );

      if (action == 'eject') {
        pendingEject.add(n);
      } else if (action == 'push') {
        _push(n, delta, dist, lobeFactor);
      }
    }

    // Removals after the physics step (this component updates after stepDt).
    for (final n in pendingEject) {
      _eject(n);
    }

    // Linger briefly so the fully expanded lobe can be read, then go.
    if (_shellT >= GameConstants.kShellDuration + 0.2) {
      if (!_remnantHooked) {
        _remnantHooked = true;
        gameWorld.onSupernovaBlastResolved(origin);
      }
      removeFromParent();
    }
  }

  void _push(Nucleus n, Vector2 delta, double dist, double lobeFactor) {
    if (dist < 0.01) return;
    final reach = GameConstants.kBlastRadius * lobeFactor;
    final falloff =
        math.pow(1.0 - (dist / reach).clamp(0.0, 1.0), 2).toDouble();
    n.body.applyLinearImpulse(
      delta.normalized() * GameConstants.kBlastImpulse * falloff,
    );
  }

  void _eject(Nucleus n) {
    if (!n.isMounted || n.pendingDestroy) return;
    final credit =
        (n.tier.scoreOnCreate * GameConstants.kEjectCredit).round();
    if (credit > 0) {
      gameWorld.score += credit;
      gameWorld.onScore(credit, gameWorld.score);
    }
    n.spawnEjectEffect(origin: origin);
    n.pendingDestroy = true;
    n.removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final progress = _progress;
    if (progress <= 0.001) return;

    final fade = _shellT <= GameConstants.kShellDuration
        ? 1.0
        : (1.0 -
                (_shellT - GameConstants.kShellDuration) / 0.2)
            .clamp(0.0, 1.0);
    if (fade <= 0.01) return;

    final base = progress * GameConstants.kBlastRadius;
    const segments = 72;
    final path = Path();

    for (var i = 0; i <= segments; i++) {
      final angle = i * 2 * math.pi / segments;
      final lobeFactor =
          1.0 + GameConstants.kAsymmetry * math.cos(angle - blastAxis);
      final r = base * lobeFactor;
      final x = math.cos(angle) * r;
      final y = math.sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final trail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = const Color(0xFFFFE8A0).withValues(alpha: 0.18 * fade)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, trail);

    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = const Color(0xFFFFF6D0).withValues(alpha: 0.9 * fade);
    canvas.drawPath(path, edge);
  }
}
