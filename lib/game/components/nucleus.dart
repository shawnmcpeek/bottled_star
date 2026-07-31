import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/painting.dart';

import '../../theme/game_colors.dart';
import '../../theme/game_fonts.dart';
import '../constants.dart';
import '../element_tier.dart';
import '../systems/bottled_star_world.dart';
import 'chamber.dart';
import 'effects.dart';

typedef MergeRequest = void Function(Nucleus a, Nucleus b);

class Nucleus extends BodyComponent with ContactCallbacks {
  Nucleus({
    required this.tier,
    required Vector2 spawnPosition,
    required this.onMergeRequest,
    this.freshFromMerge = false,
    this.asProjectile = false,
    Vector2? initialVelocity,
  })  : _spawnPosition = spawnPosition.clone(),
        _initialVelocity = initialVelocity?.clone(),
        super(renderBody: false);

  ElementTier tier;
  final Vector2 _spawnPosition;
  final Vector2? _initialVelocity;
  final MergeRequest onMergeRequest;
  final bool freshFromMerge;
  final bool asProjectile;

  bool pendingDestroy = false;
  double rimPressure = 0;
  double renderOpacity = 1;
  double _pulse = 0;
  double _inertCooldown = 0;

  static final Map<int, TextPainter> _symbolPainters = {};

  bool touchingRim(Vector2 chamberCenter, double chamberRadius) {
    if (!isMounted || pendingDestroy) return false;
    final d = body.position.distanceTo(chamberCenter);
    return d + tier.radius >=
        chamberRadius - GameConstants.rimContactEpsilon;
  }

  @override
  Body createBody() {
    final shape = CircleShape()..radius = tier.radius;
    final bodyDef = BodyDef(
      type: BodyType.dynamic,
      position: _spawnPosition,
      userData: this,
      linearDamping: GameConstants.linearDamping,
      angularDamping: GameConstants.angularDamping,
      bullet: asProjectile,
      linearVelocity: _initialVelocity ?? Vector2.zero(),
    );
    final fixtureDef = FixtureDef(
      shape,
      density: tier.fixtureDensity,
      friction: GameConstants.friction,
      restitution: GameConstants.restitution,
    );
    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void update(double dt) {
    _pulse += dt;
    if (_inertCooldown > 0) {
      _inertCooldown = math.max(0, _inertCooldown - dt);
    }
  }

  void applyRadialGravity() {
    if (pendingDestroy) return;
    final toCenter = -body.position;
    final dist = toCenter.length;
    if (dist < 0.001) return;
    final dir = toCenter / dist;
    final accel = GameConstants.gravityStrength * tier.relativeDensity;
    body.applyForce(dir * (body.mass * accel));
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (pendingDestroy) return;

    if (other is ChamberWall) return;

    if (other is! Nucleus || other.pendingDestroy) return;

    final result = ElementTier.mergeResult(tier, other.tier);
    if (result != null) {
      onMergeRequest(this, other);
      return;
    }

    if (_inertCooldown > 0 || other._inertCooldown > 0) return;
    _inertCooldown = 0.15;
    other._inertCooldown = 0.15;

    final delta = body.position - other.body.position;
    final sep = delta.length;
    if (sep < 0.001) return;
    final dir = delta / sep;
    body.applyLinearImpulse(dir * GameConstants.inertBumpImpulse);
    other.body.applyLinearImpulse(-dir * GameConstants.inertBumpImpulse);

    final mid = (body.position + other.body.position) * 0.5;
    final gameWorld = world;
    if (gameWorld is BottledStarWorld) {
      gameWorld.add(InertBumpRipple(at: mid));
    }
  }

  @override
  void onRemove() {
    final gameWorld = world;
    if (gameWorld is BottledStarWorld) {
      gameWorld.nuclei.remove(this);
    }
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    if (renderOpacity <= 0.01) return;
    canvas.saveLayer(
      null,
      Paint()..color = Color.fromRGBO(255, 255, 255, renderOpacity),
    );

    final r = tier.radius;
    final fillColor = TierPalette.fillFor(tier.tier);
    final glowColor = TierPalette.glowFor(tier.tier);
    final energetic = tier.isHelium;

    final glowRadius = r * (energetic ? 1.85 : 1.45);
    final glowPaint = Paint()
      ..color = glowColor
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        energetic ? 10 + 3 * math.sin(_pulse * 6) : 7,
      );
    canvas.drawCircle(Offset.zero, glowRadius, glowPaint);

    if (energetic) {
      final aura = Paint()
        ..color = GameColors.heliumAura.withValues(
          alpha: 0.25 + 0.12 * math.sin(_pulse * 8),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(Offset.zero, r * 2.1, aura);
    }

    final sphere = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 1.0,
        colors: [
          Color.lerp(fillColor, const Color(0xFFFFFFFF), 0.55)!,
          fillColor,
          Color.lerp(fillColor, const Color(0xFF1A0508), 0.35)!,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
    canvas.drawCircle(Offset.zero, r, sphere);

    final rim = Paint()
      ..color = fillColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, r * 0.06);
    canvas.drawCircle(Offset.zero, r - rim.strokeWidth * 0.5, rim);

    final highlight = Paint()..color = const Color(0x66FFFFFF);
    canvas.drawCircle(
      Offset(-r * 0.28, -r * 0.32),
      r * 0.18,
      highlight,
    );

    final painter = _symbolPainterFor(tier, r);
    painter.paint(
      canvas,
      Offset(-painter.width / 2, -painter.height / 2),
    );

    canvas.restore();
  }

  static TextPainter _symbolPainterFor(ElementTier tier, double radius) {
    final key = tier.tier * 1000 + radius.round();
    final existing = _symbolPainters[key];
    if (existing != null) return existing;

    final fontSize =
        (radius * (tier.symbol.length > 1 ? 0.7 : 0.85)).clamp(8.0, 36.0);
    final painter = TextPainter(
      text: TextSpan(
        text: tier.symbol,
        style: GameFonts.symbol(
          fontSize: fontSize,
          multiLetter: tier.symbol.length > 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _symbolPainters[key] = painter;
    return painter;
  }
}
