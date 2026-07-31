import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../theme/game_colors.dart';
import '../../theme/game_fonts.dart';
import '../constants.dart';
import '../element_tier.dart';

class Injector extends PositionComponent {
  Injector() : super(priority: 20);

  double orbitAngle = -math.pi / 2;
  double charge = 0;
  bool charging = false;
  double cooldown = 0;
  ElementTier loadedTier = ElementTier.hydrogen;

  double get orbitRadius =>
      GameConstants.chamberRadius + GameConstants.injectorOrbitGap;

  Vector2 get tipPosition {
    final dir = Vector2(math.cos(orbitAngle), math.sin(orbitAngle));
    return dir * (orbitRadius - 10);
  }

  Vector2 get fireDirection =>
      Vector2(-math.cos(orbitAngle), -math.sin(orbitAngle));

  bool get canFire => cooldown <= 0 && !charging;

  void aimToward(Vector2 worldPoint) {
    if (worldPoint.length2 < 0.0001) return;
    orbitAngle = math.atan2(worldPoint.y, worldPoint.x);
  }

  void rotateBy(double delta) {
    orbitAngle += delta;
  }

  void startCharge() {
    if (cooldown > 0) return;
    charging = true;
    charge = 0;
  }

  /// Returns charged power in [0,1], or null if cancelled / on cooldown.
  double? releaseCharge() {
    if (!charging) return null;
    charging = false;
    final power = charge.clamp(0.15, 1.0);
    charge = 0;
    if (cooldown > 0) return null;
    cooldown = GameConstants.injectorCooldownSeconds;
    return power;
  }

  void cancelCharge() {
    charging = false;
    charge = 0;
  }

  double impulseForPower(double power01) {
    return GameConstants.injectionPowerMin +
        (GameConstants.injectionPowerMax - GameConstants.injectionPowerMin) *
            power01;
  }

  @override
  void update(double dt) {
    if (cooldown > 0) {
      cooldown = math.max(0, cooldown - dt);
    }
    if (charging) {
      charge = math.min(1.0, charge + dt / GameConstants.chargeSeconds);
    }
  }

  @override
  void render(Canvas canvas) {
    final dir = Vector2(math.cos(orbitAngle), math.sin(orbitAngle));
    final pos = dir * orbitRadius;
    final fill = TierPalette.fills[loadedTier.tier];

    canvas.save();
    canvas.translate(pos.x, pos.y);
    canvas.rotate(orbitAngle + math.pi / 2);

    final glow = Paint()
      ..color = fill.withValues(alpha: 0.35 + charge * 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset.zero, 22, glow);

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(fill, const Color(0xFFFFFFFF), 0.45)!,
          fill,
          Color.lerp(fill, const Color(0xFFC47A2E), 0.35)!,
        ],
      ).createShader(const Rect.fromLTWH(-14, -18, 28, 40));

    final path = Path()
      ..moveTo(0, -20)
      ..lineTo(12, 10)
      ..lineTo(5, 14)
      ..lineTo(-5, 14)
      ..lineTo(-12, 10)
      ..close();
    canvas.drawPath(path, bodyPaint);

    final outline = Paint()
      ..color = const Color(0xCCFFE6A8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(path, outline);

    const chipR = 7.0;
    final chip = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.35),
        colors: [
          Color.lerp(fill, const Color(0xFFFFFFFF), 0.5)!,
          fill,
        ],
      ).createShader(Rect.fromCircle(center: const Offset(0, 2), radius: chipR));
    canvas.drawCircle(const Offset(0, 2), chipR, chip);

    final label = TextPainter(
      text: TextSpan(
        text: loadedTier.symbol,
        style: GameFonts.symbol(
          fontSize: loadedTier.symbol.length > 1 ? 7.5 : 9,
          multiLetter: loadedTier.symbol.length > 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(-label.width / 2, 2 - label.height / 2));

    if (charge > 0) {
      final chargePaint = Paint()
        ..color = GameColors.injectorCharge.withValues(alpha: 0.55 + charge * 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(
        const Offset(0, 2),
        6 + charge * 8,
        chargePaint,
      );
    }

    final aim = Paint()
      ..color = fill.withValues(alpha: 0.45 + charge * 0.4)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, -22), Offset(0, -22 - 18 - charge * 24), aim);

    canvas.restore();
  }
}
