import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/painting.dart';

import '../constants.dart';
import '../systems/bottled_star_world.dart';
import 'collapse_tuning.dart';

/// Dense, inert neutron-star leftover. Cannot fuse; sinks under radial gravity.
class Remnant extends BodyComponent with ContactCallbacks {
  Remnant({
    required this.gameWorld,
    required Vector2 spawnPosition,
  })  : _spawnPosition = spawnPosition.clone(),
        // Above heavy nuclei, below light ones — wedged C/H stay readable.
        super(renderBody: false, priority: 95);

  final BottledStarWorld gameWorld;
  final Vector2 _spawnPosition;

  bool pendingDestroy = false;

  @override
  Body createBody() {
    final shape = CircleShape()..radius = CollapseTuning.remnantRadius;
    final bodyDef = BodyDef(
      type: BodyType.dynamic,
      position: _spawnPosition,
      userData: this,
      bullet: true,
      linearDamping: 0.55,
      angularDamping: 0.8,
    );
    final fixtureDef = FixtureDef(
      shape,
      density: CollapseTuning.remnantDensity,
      friction: CollapseTuning.remnantFriction,
      restitution: CollapseTuning.remnantRestitution,
      filter: Filter()
        ..categoryBits = CollapseTuning.categoryRemnant
        ..maskBits = 0xFFFF,
    );
    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  void applyRadialGravity() {
    if (pendingDestroy) return;
    final toCenter = -body.position;
    final dist = toCenter.length;
    if (dist < 0.001) return;
    final dir = toCenter / dist;
    final accel =
        GameConstants.gravityStrength * CollapseTuning.remnantRelativeDensity;
    body.applyForce(dir * (body.mass * accel));
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (pendingDestroy) return;
    if (other is! Remnant || other.pendingDestroy) return;
    // Sample closing speed here — before the solver kills it (§9.5).
    gameWorld.remnantSystem?.onRemnantContact(this, other);
  }

  @override
  void onRemove() {
    gameWorld.remnantSystem?.remnants.remove(this);
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    if (pendingDestroy) return;
    final r = CollapseTuning.remnantRadius;

    final glow = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        r * 1.35,
        [
          const Color(0xE6F4FBFF),
          const Color(0x66A8D4FF),
          const Color(0x00A8D4FF),
        ],
        const [0.0, 0.35, 1.0],
      );
    canvas.drawCircle(Offset.zero, r * 1.35, glow);

    final core = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        r,
        [
          const Color(0xFFF8FCFF),
          const Color(0xFFB8DFFF),
          const Color(0xFF4A6A88),
        ],
        const [0.0, 0.4, 1.0],
      );
    canvas.drawCircle(Offset.zero, r, core);

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, r * 0.06)
      ..color = const Color(0xFFF0F8FF);
    canvas.drawCircle(Offset.zero, r - 0.8, rim);
  }
}
