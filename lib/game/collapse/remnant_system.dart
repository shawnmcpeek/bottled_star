import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../components/effects.dart';
import '../components/nucleus.dart';
import '../systems/bottled_star_world.dart';
import '../systems/haptics_controller.dart';
import '../systems/sfx_controller.dart';
import '../systems/achievement_hooks.dart';
import 'collapse_tuning.dart';
import 'kilonova.dart';
import 'remnant.dart';

/// Owns Collapse remnants: spawn after Fe+Fe blasts, resolve kilonovas.
class RemnantSystem {
  RemnantSystem(this.gameWorld);

  final BottledStarWorld gameWorld;
  final List<Remnant> remnants = [];

  int kilonovaCount = 0;
  int supernovaCount = 0;

  void reset() {
    for (final r in List<Remnant>.from(remnants)) {
      if (r.isMounted) r.removeFromParent();
    }
    remnants.clear();
    kilonovaCount = 0;
    supernovaCount = 0;
  }

  /// Called after a mid-run supernova shell finishes — spawn at fusion point.
  void spawnAt(Vector2 fusionPoint) {
    Kilonova.assertThreshold(gameWorld.mode);
    supernovaCount++;
    _addRemnant(fusionPoint);
  }

  /// Replay a remnant from a saved run without bumping counts.
  void restoreBody({
    required Vector2 position,
    Vector2? velocity,
    double angle = 0,
    double angularVelocity = 0,
  }) {
    _addRemnant(
      position,
      velocity: velocity,
      angle: angle,
      angularVelocity: angularVelocity,
    );
  }

  void _addRemnant(
    Vector2 position, {
    Vector2? velocity,
    double angle = 0,
    double angularVelocity = 0,
  }) {
    final remnant = Remnant(
      gameWorld: gameWorld,
      spawnPosition: position,
      initialVelocity: velocity,
      initialAngle: angle,
      initialAngularVelocity: angularVelocity,
    );
    remnants.add(remnant);
    gameWorld.add(remnant);
  }

  void applyGravity() {
    for (final r in remnants) {
      if (r.isMounted) r.applyRadialGravity();
    }
  }

  void onRemnantContact(Remnant a, Remnant b) {
    if (a.pendingDestroy || b.pendingDestroy) return;
    if (!Kilonova.shouldMerge(a, b)) return;
    triggerKilonova(a, b);
  }

  void triggerKilonova(Remnant a, Remnant b) {
    if (a.pendingDestroy || b.pendingDestroy) return;

    final midpoint = (a.body.position + b.body.position) * 0.5;

    a.pendingDestroy = true;
    b.pendingDestroy = true;
    kilonovaCount++;

    gameWorld.deferPostStep(() {
      if (a.isMounted) a.removeFromParent();
      if (b.isMounted) b.removeFromParent();
    });

    _emitHeavyElementBurst(midpoint);
    _clearNearbyPieces(midpoint);

    SfxController.instance.playSpringHit();
    HapticsController.instance.playBlast();
    // ignore: unawaited_futures
    AchievementHooks.onKilonova(countThisRun: kilonovaCount);
    gameWorld.score += CollapseTuning.kilonovaScore;
    gameWorld.onScore(CollapseTuning.kilonovaScore, gameWorld.score);
    gameWorld.onFlash(0.16);
    gameWorld.onShake(0.4, 9);
    gameWorld.add(
      ScreenFlash(
        life: 0.14,
        color: const Color(0xFFFFE8A0),
      ),
    );
  }

  void _emitHeavyElementBurst(Vector2 midpoint) {
    gameWorld.add(
      MergeFlash(
        at: midpoint,
        radius: CollapseTuning.remnantRadiusFor(gameWorld.mode) * 2.2,
      ),
    );
    gameWorld.add(KilonovaBurst(origin: midpoint));
  }

  void _clearNearbyPieces(Vector2 midpoint) {
    final reach = CollapseTuning.kilonovaClearRadius;
    for (final n in List<Nucleus>.from(gameWorld.nuclei)) {
      if (!n.isMounted || n.pendingDestroy) continue;
      final delta = n.body.position - midpoint;
      final dist = delta.length;
      if (dist < 0.01 || dist > reach) continue;
      final falloff =
          math.pow(1.0 - (dist / reach).clamp(0.0, 1.0), 2).toDouble();
      n.body.applyLinearImpulse(
        delta.normalized() * CollapseTuning.kilonovaClearImpulse * falloff,
      );
    }
  }
}

/// Gold-white particle burst — visual/scoring event only, no new ladder tiers.
class KilonovaBurst extends PositionComponent {
  KilonovaBurst({required Vector2 origin})
      : origin = origin.clone(),
        super(
          position: origin.clone(),
          anchor: Anchor.center,
          priority: 60,
        );

  final Vector2 origin;
  double _age = 0;
  static const _life = 0.55;
  final _rng = math.Random();
  late final List<_Speck> _specks = List.generate(28, (_) {
    final a = _rng.nextDouble() * math.pi * 2;
    final speed = 90 + _rng.nextDouble() * 160;
    return _Speck(
      dir: Vector2(math.cos(a), math.sin(a)),
      speed: speed,
      size: 2.0 + _rng.nextDouble() * 3.5,
      symbol: const ['Au', 'Pt', 'U', 'Ag'][_rng.nextInt(4)],
    );
  });

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / _life).clamp(0.0, 1.0);
    final alpha = (1 - t) * (1 - t);
    for (final s in _specks) {
      final d = s.speed * _age * (0.55 + 0.45 * (1 - t));
      final p = Offset(s.dir.x * d, s.dir.y * d);
      final paint = Paint()
        ..color = const Color(0xFFFFE0A0).withValues(alpha: 0.85 * alpha);
      canvas.drawCircle(p, s.size * (1 - t * 0.4), paint);
    }

    final core = Paint()
      ..color = const Color(0xFFFFF6D0).withValues(alpha: 0.7 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset.zero, 18 + 40 * t, core);
  }
}

class _Speck {
  _Speck({
    required this.dir,
    required this.speed,
    required this.size,
    required this.symbol,
  });

  final Vector2 dir;
  final double speed;
  final double size;
  final String symbol;
}
