import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/painting.dart';

import '../components/nucleus.dart';
import '../systems/bottled_star_world.dart';
import 'collapse_tuning.dart';
import 'eddington_field.dart';
import 'remnant_state.dart';

/// Static sensor at chamber centre. Consumes nuclei on contact; grows with mass.
class Remnant extends BodyComponent with ContactCallbacks {
  Remnant({required this.gameWorld})
      : super(renderBody: false, priority: 40);

  final BottledStarWorld gameWorld;
  final RemnantState state = RemnantState();

  bool _radiusDirty = false;
  bool _collapseBeatActive = false;
  double _collapseBeatAge = 0;
  double _pulse = 0;

  bool get exists => state.exists;
  bool get spawnLocked => _collapseBeatActive;

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      type: BodyType.static,
      position: BottledStarWorld.chamberCenter.clone(),
      userData: this,
    );
    // Fixture created when the remnant first appears.
    return world.createBody(bodyDef);
  }

  void reset() {
    state.reset();
    _radiusDirty = false;
    _collapseBeatActive = false;
    _collapseBeatAge = 0;
    _clearFixtures();
  }

  /// Called after a mid-run supernova shell finishes resolving.
  void onSupernova(Vector2 blastCenter) {
    state.supernovaCount++;
    state.mass += CollapseTuning.massPerSupernova;

    if (!state.exists) {
      state.kind = RemnantKind.neutronStar;
      body.setTransform(BottledStarWorld.chamberCenter.clone(), 0);
      _syncBodyRadiusImmediate();
    } else {
      _queueRadiusSync();
    }

    _checkTovCrossing();
  }

  void applyForces() {
    if (!exists) return;
    EddingtonField.applyPressure(
      state: state,
      origin: body.position,
      pieces: gameWorld.nuclei,
    );
  }

  void tick(double dt) {
    if (!exists) return;

    _pulse += dt;
    state.radiationPressure *=
        math.exp(-CollapseTuning.pressureDecay * dt);
    state.timeSinceLastMeal += dt;

    if (_collapseBeatActive) {
      _collapseBeatAge += dt;
      if (_collapseBeatAge >= CollapseTuning.blackHoleBeatSeconds) {
        _collapseBeatActive = false;
        gameWorld.endCollapseBeat();
      }
    }

    _updateStarvation();
  }

  void drainDeferred() {
    if (_radiusDirty) {
      _radiusDirty = false;
      _syncBodyRadiusImmediate();
      _consumeOverlapping();
    }
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (!exists) return;
    if (other is! Nucleus || other.pendingDestroy) return;
    _consume(other);
  }

  void _consume(Nucleus piece) {
    if (!exists || piece.pendingDestroy) return;

    final tierIndex = piece.tier.tier;
    final gained = math.max(
      CollapseTuning.massFloor,
      tierIndex * CollapseTuning.massPerTierUnit,
    );

    state.mass += gained;
    state.consumedCount++;
    state.timeSinceLastMeal = 0;
    state.radiationPressure += gained * CollapseTuning.pressurePerMass;

    final credit =
        (piece.tier.scoreOnCreate * CollapseTuning.consumptionCreditFraction)
            .round();
    if (credit > 0) {
      gameWorld.score += credit;
      gameWorld.onScore(credit, gameWorld.score);
    }

    // Claim immediately so merge/blast skip this body; destroy after step.
    piece.pendingDestroy = true;
    gameWorld.deferPostStep(() {
      if (piece.isMounted) piece.removeFromParent();
    });

    _checkTovCrossing();
    _queueRadiusSync();
  }

  void _updateStarvation() {
    if (state.timeSinceLastMeal < CollapseTuning.starvationInterval) return;

    final reach = state.radius * CollapseTuning.starvationReach;
    Nucleus? nearest;
    var best = double.infinity;
    for (final n in gameWorld.nuclei) {
      if (!n.isMounted || n.pendingDestroy) continue;
      final d = n.body.position.distanceTo(body.position);
      if (d <= reach && d < best) {
        best = d;
        nearest = n;
      }
    }
    if (nearest != null) {
      _consume(nearest);
    }
  }

  void _checkTovCrossing() {
    if (state.kind != RemnantKind.neutronStar) return;
    if (state.mass < CollapseTuning.tovMassThreshold) return;

    state.kind = RemnantKind.blackHole;
    _onCollapseToBlackHole();
  }

  void _onCollapseToBlackHole() {
    _collapseBeatActive = true;
    _collapseBeatAge = 0;
    gameWorld.beginCollapseBeat();
    gameWorld.onFlash(0.18);
    gameWorld.onShake(0.45, 7);
  }

  void _queueRadiusSync() {
    _radiusDirty = true;
  }

  void _syncBodyRadiusImmediate() {
    _clearFixtures();
    final shape = CircleShape()..radius = state.radius;
    final fixtureDef = FixtureDef(
      shape,
      isSensor: true,
      density: 0,
      filter: Filter()
        ..categoryBits = 0x0004
        ..maskBits = 0xFFFF,
    );
    body.createFixture(fixtureDef);
  }

  void _clearFixtures() {
    for (final f in List<Fixture>.from(body.fixtures)) {
      body.destroyFixture(f);
    }
  }

  void _consumeOverlapping() {
    final r = state.radius;
    for (final n in List<Nucleus>.from(gameWorld.nuclei)) {
      if (!n.isMounted || n.pendingDestroy) continue;
      final d = n.body.position.distanceTo(body.position);
      if (d <= r + n.tier.radius) {
        _consume(n);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (!exists) return;

    final r = state.radius;
    final pressure = state.radiationPressure.clamp(0.0, 2.5);
    final glowR = r * (1.2 + 0.55 * pressure);

    if (state.kind == RemnantKind.neutronStar) {
      final pulse = 0.85 + 0.15 * math.sin(_pulse * 5);
      final glow = Paint()
        ..color = const Color(0xFFB8E0FF).withValues(alpha: 0.22 * pulse + 0.12 * pressure)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + 6 * pressure);
      canvas.drawCircle(Offset.zero, glowR, glow);

      final core = Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          r,
          [
            const Color(0xFFF2FBFF),
            const Color(0xFF9ED0FF),
            const Color(0xFF3A6A9A),
          ],
          const [0.0, 0.45, 1.0],
        );
      canvas.drawCircle(Offset.zero, r, core);

      final rim = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, r * 0.05)
        ..color = const Color(0xFFE8F6FF).withValues(alpha: 0.85);
      canvas.drawCircle(Offset.zero, r - 1, rim);
    } else {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.5, r * 0.07)
        ..color = const Color(0xFFFFC978).withValues(alpha: 0.35 + 0.2 * pressure)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset.zero, r * 1.08, ring);

      final disc = Paint()..color = const Color(0xFF050308);
      canvas.drawCircle(Offset.zero, r, disc);

      final lens = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.6, r * 0.04)
        ..color = const Color(0xFFFFE0A8).withValues(alpha: 0.55 + 0.15 * pressure);
      canvas.drawCircle(Offset.zero, r * 1.02, lens);

      if (_collapseBeatActive) {
        final t = (_collapseBeatAge / CollapseTuning.blackHoleBeatSeconds)
            .clamp(0.0, 1.0);
        final veil = Paint()
          ..color = Color.fromRGBO(0, 0, 0, 0.35 * (1 - t));
        canvas.drawCircle(Offset.zero, r * (1.4 - 0.3 * t), veil);
      }
    }
  }
}
