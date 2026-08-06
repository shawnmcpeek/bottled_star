import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../theme/game_colors.dart';
import '../../theme/game_fonts.dart';
import '../constants.dart';

class MergeFlash extends PositionComponent {
  MergeFlash({required Vector2 at, required this.radius})
      : super(
          position: at.clone(),
          anchor: Anchor.center,
          priority: 30,
        );

  final double radius;
  double _age = 0;
  static const _life = 0.35;

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= _life) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / _life).clamp(0.0, 1.0);
    final burst = radius * (0.6 + t * 1.8);
    final alpha = (1 - t) * (1 - t);

    final glow = Paint()
      ..color = GameColors.mergeFlash.withValues(alpha: 0.55 * alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + 20 * t);
    canvas.drawCircle(Offset.zero, burst, glow);

    final core = Paint()
      ..color = const Color(0xFFFFF8E0).withValues(alpha: 0.9 * alpha);
    canvas.drawCircle(Offset.zero, burst * 0.25, core);

    // Starburst spikes
    final spike = Paint()
      ..color = GameColors.mergeFlash.withValues(alpha: 0.75 * alpha)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + t * 0.4;
      final inner = burst * 0.2;
      final outer = burst * (0.85 + (i.isEven ? 0.25 : 0));
      canvas.drawLine(
        Offset(math.cos(a) * inner, math.sin(a) * inner),
        Offset(math.cos(a) * outer, math.sin(a) * outer),
        spike,
      );
    }
  }
}

class ScreenFlash extends PositionComponent {
  ScreenFlash({
    this.life = 0.12,
    this.color = const Color(0xFFFFFFFF),
    Vector2? size,
  }) : super(priority: 100, anchor: Anchor.center) {
    this.size = size ?? Vector2.all(2000);
  }

  final double life;
  final Color color;
  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / life).clamp(0.0, 1.0);
    final alpha = (1 - t) * (1 - t);
    final paint = Paint()..color = color.withValues(alpha: alpha * 0.92);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
      paint,
    );
  }
}

class RemnantStar extends PositionComponent {
  RemnantStar() : super(priority: 40, anchor: Anchor.center);

  double age = 0;
  double opacity = 0;

  @override
  void update(double dt) {
    age += dt;
  }

  @override
  void render(Canvas canvas) {
    if (opacity <= 0) return;
    final scale = (1.0 - (age / GameConstants.whiteDwarfRemnant).clamp(0.0, 1.0) * 0.67)
        .clamp(0.33, 1.0);
    final r = 10.0 * scale;
    final glow = Paint()
      ..color = const Color(0xFFFFE8C0).withValues(alpha: 0.35 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset.zero, r * 2.2, glow);
    final core = Paint()
      ..color = const Color(0xFFFFF6E0).withValues(alpha: opacity);
    canvas.drawCircle(Offset.zero, r, core);
  }
}

class SeedParticle extends PositionComponent {
  SeedParticle({
    required this.symbol,
    required this.color,
    required Vector2 velocity,
    required this.appearDelay,
  })  : _velocity = velocity.clone(),
        super(priority: 35, anchor: Anchor.center);

  final String symbol;
  final Color color;
  final Vector2 _velocity;
  final double appearDelay;
  double _age = 0;
  double opacity = 0;

  @override
  void update(double dt) {
    _age += dt;
    if (_age < appearDelay) {
      opacity = 0;
      return;
    }
    final live = _age - appearDelay;
    opacity = (live / 0.35).clamp(0.0, 1.0) * (1.0 - (live / 4.5).clamp(0.0, 1.0) * 0.4);
    position += _velocity * dt;
    _velocity.scale(0.992);
  }

  @override
  void render(Canvas canvas) {
    if (opacity <= 0.02) return;
    const r = 11.0;
    final fill = Paint()
      ..color = color.withValues(alpha: opacity * 0.95);
    final glow = Paint()
      ..color = color.withValues(alpha: opacity * 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset.zero, r * 1.6, glow);
    canvas.drawCircle(Offset.zero, r, fill);

    final tp = TextPainter(
      text: TextSpan(
        text: symbol,
        style: GameFonts.symbol(
          fontSize: symbol.length > 1 ? 9 : 11,
          color: const Color(0xE0101828),
          multiLetter: symbol.length > 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }
}

/// Brief outward streak when a nucleus is vaporized by the supernova shell.
class EjectStreak extends PositionComponent {
  EjectStreak({
    required Vector2 at,
    required Vector2 direction,
    required this.color,
    required this.radius,
  })  : _dir = direction.length2 < 0.01
            ? Vector2(1, 0)
            : direction.normalized(),
        super(position: at.clone(), anchor: Anchor.center, priority: 45);

  final Color color;
  final double radius;
  final Vector2 _dir;
  double _age = 0;
  static const _life = 0.3;

  @override
  void update(double dt) {
    _age += dt;
    position += _dir * (220 * dt * (1 - _age / _life).clamp(0.0, 1.0));
    if (_age >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / _life).clamp(0.0, 1.0);
    final alpha = (1 - t) * (1 - t);
    final len = radius * (1.2 + t * 2.4);

    final glow = Paint()
      ..color = color.withValues(alpha: 0.45 * alpha)
      ..strokeWidth = radius * 0.55 * (1 - t * 0.5)
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawLine(
      Offset.zero,
      Offset(_dir.x * len, _dir.y * len),
      glow,
    );

    final core = Paint()
      ..color = const Color(0xFFFFF4D0).withValues(alpha: 0.85 * alpha)
      ..strokeWidth = math.max(1.5, radius * 0.22)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset.zero,
      Offset(_dir.x * len * 0.85, _dir.y * len * 0.85),
      core,
    );
  }
}

