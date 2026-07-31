import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/painting.dart';

import '../../theme/game_colors.dart';
import '../constants.dart';

class ChamberWall extends BodyComponent {
  ChamberWall() : super(renderBody: false);

  /// Smoothed 0..1 rim pressure for rendering.
  double displayedPressure = 0;

  /// One-frame flare override (supernova), then falls back to accumulator.
  double flare = 0;

  /// Supernova ending: rim is destroyed rather than faded.
  bool broken = false;
  double breakProgress = 0;
  double _elapsed = 0;

  @override
  Body createBody() {
    final vertices = <Vector2>[
      for (var i = 0; i < GameConstants.chamberSegments; i++)
        Vector2(
          GameConstants.chamberRadius *
              math.cos(i * 2 * math.pi / GameConstants.chamberSegments),
          GameConstants.chamberRadius *
              math.sin(i * 2 * math.pi / GameConstants.chamberSegments),
        ),
    ];

    final shape = ChainShape()..createLoop(vertices);
    final bodyDef = BodyDef(
      type: BodyType.static,
      userData: this,
    );
    final fixtureDef = FixtureDef(
      shape,
      friction: GameConstants.friction,
      restitution: GameConstants.restitution,
    );

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void update(double dt) {
    _elapsed += dt;
    if (flare > 0) {
      flare = math.max(0, flare - dt * 2.5);
    }
  }

  double get _pressure {
    final p = math.max(displayedPressure, flare).clamp(0.0, 1.0);
    return p;
  }

  @override
  void render(Canvas canvas) {
    final r = GameConstants.chamberRadius;
    final p = _pressure;

    if (!broken) {
      final interior = Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(
              const Color(0x33FFB84A),
              const Color(0x55FF5A2B),
              p,
            )!,
            const Color(0x18FF8A3C),
            const Color(0x00000000),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
      canvas.drawCircle(Offset.zero, r, interior);
    }

    if (broken) {
      _renderBrokenRim(canvas, r);
      return;
    }

    // Low pressures are the ones the player needs to notice, so brightness
    // rises faster than pressure does.
    final g = math.pow(p, 0.55).toDouble();

    const calm = Color(0xFFD8A44A);
    const critical = Color(0xFFFF5A2B);
    final color = Color.lerp(calm, critical, g)!;

    var halo = uiLerp(16.0, 46.0, g);
    var blur = uiLerp(9.0, 32.0, g);
    if (p > 0.75) {
      // ~2 Hz vessel strain pulse
      final strain = (p - 0.75) / 0.25;
      final beat = math.sin(_elapsed * math.pi * 4) * strain;
      blur += 6 * beat;
      halo += 10 * beat;
    }
    final stroke = uiLerp(2.5, 6.0, g);

    final ambient = Paint()
      ..style = PaintingStyle.stroke
      ..color = color.withValues(alpha: 0.22 + g * 0.3)
      ..strokeWidth = stroke + 14
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, halo);
    canvas.drawCircle(Offset.zero, r, ambient);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..color = color.withValues(alpha: 0.55 + g * 0.35)
      ..strokeWidth = stroke + 4
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    canvas.drawCircle(Offset.zero, r, glow);

    final crisp = Paint()
      ..style = PaintingStyle.stroke
      ..color = color.withValues(alpha: 0.95)
      ..strokeWidth = stroke;
    canvas.drawCircle(Offset.zero, r, crisp);
  }

  void _renderBrokenRim(Canvas canvas, double r) {
    final rng = math.Random(99);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFF5A2B).withValues(
        alpha: (1.0 - breakProgress * 0.85).clamp(0.0, 1.0),
      );

    final segments = 28;
    for (var i = 0; i < segments; i++) {
      final a0 = i * 2 * math.pi / segments;
      final a1 = (i + 0.55) * 2 * math.pi / segments;
      final outward = 1 + breakProgress * (0.15 + rng.nextDouble() * 0.55);
      final jitter = breakProgress * (rng.nextDouble() - 0.5) * 40;
      canvas.drawLine(
        Offset(
          math.cos(a0) * r * outward + jitter,
          math.sin(a0) * r * outward,
        ),
        Offset(
          math.cos(a1) * r * outward - jitter,
          math.sin(a1) * r * outward,
        ),
        paint,
      );
    }
  }
}

double uiLerp(double a, double b, double t) => a + (b - a) * t;

class ChamberBackdrop extends Component {
  double pulse = 0;

  @override
  void update(double dt) {
    pulse += dt;
  }

  @override
  void render(Canvas canvas) {
    const size = 900.0;
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size,
      height: size,
    );

    final bg = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFF1A0C14),
          GameColors.spaceDeep,
          GameColors.space,
        ],
        stops: [0.0, 0.45, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    final starPaint = Paint()..color = const Color(0x66FFE8C0);
    final rng = math.Random(42);
    for (var i = 0; i < 48; i++) {
      final x = (rng.nextDouble() - 0.5) * size;
      final y = (rng.nextDouble() - 0.5) * size;
      final dist = math.sqrt(x * x + y * y);
      if (dist < GameConstants.chamberRadius + 40) continue;
      final twinkle = 0.45 + 0.55 * math.sin(pulse * 1.7 + i);
      starPaint.color = Color.fromRGBO(
        255,
        232,
        192,
        (0.25 + 0.35 * twinkle).clamp(0.0, 1.0),
      );
      canvas.drawCircle(Offset(x, y), 1.1 + (i % 3) * 0.4, starPaint);
    }
  }
}
