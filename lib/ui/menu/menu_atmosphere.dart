import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../theme/game_colors.dart';

/// Which nuclei may drift across the menu atmosphere.
enum MenuDriftCast {
  /// Normal ladder colors (main menu, options, etc.).
  gameElements,

  /// Credits only — Panda / Yeti stand-ins for the family.
  creditsFamily,
}

/// Full-bleed menu backdrop: deep space, warm bottled-star core, faint rim,
/// sparse drifting points, and a rare soft nucleus crossing the frame.
class MenuAtmosphere extends StatefulWidget {
  const MenuAtmosphere({
    super.key,
    this.driftCast = MenuDriftCast.gameElements,
  });

  final MenuDriftCast driftCast;

  @override
  State<MenuAtmosphere> createState() => _MenuAtmosphereState();
}

class _MenuAtmosphereState extends State<MenuAtmosphere>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _elapsed = 0;
  final Map<String, ui.Image> _creditArt = {};

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() => _elapsed = elapsed.inMilliseconds / 1000.0);
    })..start();
    _loadCreditArt();
  }

  @override
  void didUpdateWidget(covariant MenuAtmosphere oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.driftCast != widget.driftCast) {
      _loadCreditArt();
    }
  }

  Future<void> _loadCreditArt() async {
    if (widget.driftCast != MenuDriftCast.creditsFamily) return;
    for (final kind in _CreditDriftKind.roster) {
      final path = kind.assetPath;
      if (path == null || _creditArt.containsKey(path)) continue;
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _creditArt[path] = frame.image);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    for (final image in _creditArt.values) {
      image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MenuAtmospherePainter(
        elapsedSeconds: _elapsed,
        driftCast: widget.driftCast,
        creditArt: _creditArt,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _CreditDriftKind {
  const _CreditDriftKind({required this.fill, this.emoji, this.assetPath});

  final Color fill;
  final String? emoji;
  final String? assetPath;

  static const panda = _CreditDriftKind(fill: Color(0xFFF0F0F2), emoji: '🐼');

  static const yeti = _CreditDriftKind(
    fill: Color(0xFFD8E8F5),
    assetPath: 'assets/images/elements/yeti.png',
  );

  static const roster = [panda, yeti];
}

class _MenuAtmospherePainter extends CustomPainter {
  _MenuAtmospherePainter({
    required this.elapsedSeconds,
    required this.driftCast,
    required this.creditArt,
  });

  final double elapsedSeconds;
  final MenuDriftCast driftCast;
  final Map<String, ui.Image> creditArt;

  /// Seconds between drift starts (crossing itself is shorter).
  static const _driftPeriod = 7.0;
  static const _driftDuration = 4.5;
  static const _loopSeconds = 18.0;

  static final _stars = _buildStars();

  static List<_Star> _buildStars() {
    final rng = math.Random(42);
    return [
      for (var i = 0; i < 36; i++)
        _Star(
          x: rng.nextDouble(),
          y: rng.nextDouble(),
          r: 0.6 + rng.nextDouble() * 1.4,
          depth: 0.35 + rng.nextDouble() * 0.65,
          phase: rng.nextDouble() * math.pi * 2,
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = (elapsedSeconds % _loopSeconds) / _loopSeconds;
    final center = Offset(size.width * 0.5, size.height * 0.42);
    final minSide = math.min(size.width, size.height);

    final bg = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.15),
        radius: 1.15,
        colors: [Color(0xFF1A0C14), GameColors.spaceDeep, GameColors.space],
        stops: [0.0, 0.45, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final driftX = math.sin(t * math.pi * 2) * 10;
    final driftY = math.cos(t * math.pi * 2 * 0.7) * 7;
    for (final star in _stars) {
      final dx = (star.x - 0.5) * size.width;
      final dy = (star.y - 0.42) * size.height;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist < minSide * 0.22) continue;

      final twinkle =
          0.35 +
          0.65 * (0.5 + 0.5 * math.sin(t * math.pi * 2 * 1.4 + star.phase));
      final paint = Paint()
        ..color = Color.fromRGBO(
          255,
          232,
          192,
          (0.18 + 0.35 * twinkle * star.depth).clamp(0.0, 0.55),
        );
      canvas.drawCircle(
        Offset(
          star.x * size.width + driftX * star.depth,
          star.y * size.height + driftY * star.depth,
        ),
        star.r * star.depth,
        paint,
      );
    }

    final pulse = 0.92 + 0.08 * math.sin(t * math.pi * 2);
    final coreR = minSide * 0.38 * pulse;
    final core = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0x55FFB84A),
          const Color(0x28FF8A3C),
          const Color(0x10FF6B3D),
          const Color(0x00000000),
        ],
        stops: const [0.0, 0.35, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: coreR));
    canvas.drawCircle(center, coreR, core);

    final rimPulse = 0.55 + 0.2 * math.sin(t * math.pi * 2 + 0.8);
    final rimR = minSide * 0.28;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = GameColors.chamberGlow.withValues(alpha: 0.12 * rimPulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, rimR, glow);

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = GameColors.rimMetal.withValues(alpha: 0.35 + 0.2 * rimPulse);
    canvas.drawCircle(center, rimR, rim);

    _paintDriftingNucleus(canvas, size, center, rimR);
  }

  void _paintDriftingNucleus(
    Canvas canvas,
    Size size,
    Offset coreCenter,
    double rimR,
  ) {
    // Brand lands first; first crossing starts after a short hold.
    final time = elapsedSeconds - 2.5;
    if (time < 0) return;

    final cycleIndex = time ~/ _driftPeriod;
    final local = time - cycleIndex * _driftPeriod;
    if (local > _driftDuration) return;

    final u = (local / _driftDuration).clamp(0.0, 1.0);
    final travel = Curves.easeInOut.transform(u);
    final fade = u < 0.18
        ? Curves.easeOut.transform(u / 0.18)
        : u > 0.82
        ? Curves.easeIn.transform((1 - u) / 0.18)
        : 1.0;
    final alpha = 0.32 * fade;
    if (alpha < 0.02) return;

    // Stable per-crossing RNG so the path doesn't jitter frame to frame.
    final rng = math.Random(cycleIndex * 9973 + 42);

    final Offset pos;
    if (driftCast == MenuDriftCast.creditsFamily) {
      final points = _cometPath(rng, size, coreCenter, rimR);
      if (points == null) return;
      pos = _samplePolyline(points, travel);
    } else {
      final path = _driftPath(rng, size, coreCenter, rimR * 1.25);
      if (path == null) return;
      pos = Offset.lerp(path.$1, path.$2, travel)!;
      // Keep ladder nuclei clear of the bottled-star core on other menus.
      if ((pos - coreCenter).distance < rimR * 1.1) return;
    }

    final r = driftCast == MenuDriftCast.creditsFamily
        ? math.min(size.width, size.height) * 0.044
        : math.min(size.width, size.height) * (0.034 + rng.nextDouble() * 0.02);

    final Color fill;
    final String? emoji;
    final ui.Image? art;
    if (driftCast == MenuDriftCast.creditsFamily) {
      final kind =
          _CreditDriftKind.roster[cycleIndex % _CreditDriftKind.roster.length];
      fill = kind.fill;
      emoji = kind.emoji;
      final path = kind.assetPath;
      art = path == null ? null : creditArt[path];
    } else {
      fill = TierPalette.fills[rng.nextInt(TierPalette.fills.length)];
      emoji = null;
      art = null;
    }

    final glowPaint = Paint()
      ..color = fill.withValues(alpha: alpha * 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(pos, r * 1.55, glowPaint);

    final sphere = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 1.0,
        colors: [
          Color.lerp(
            fill,
            const Color(0xFFFFFFFF),
            0.5,
          )!.withValues(alpha: (alpha * 1.1).clamp(0.0, 1.0)),
          fill.withValues(alpha: alpha),
          Color.lerp(
            fill,
            const Color(0xFF1A0508),
            0.35,
          )!.withValues(alpha: alpha * 0.9),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: pos, radius: r));
    canvas.drawCircle(pos, r, sphere);

    if (art != null) {
      // Inset face so the soft sphere rim matches the panda emoji read.
      final faceR = r * 0.88;
      final src = Rect.fromLTWH(
        0,
        0,
        art.width.toDouble(),
        art.height.toDouble(),
      );
      final dst = Rect.fromCircle(center: pos, radius: faceR);
      canvas.save();
      canvas.clipPath(Path()..addOval(dst));
      canvas.drawImageRect(
        art,
        src,
        dst,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..colorFilter = ColorFilter.mode(
            Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0)),
            BlendMode.modulate,
          ),
      );
      canvas.restore();
    } else if (emoji != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: emoji,
          style: TextStyle(
            fontSize: r * 1.15,
            height: 1,
            color: Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0)),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  /// Credits-only: edge → skim the core with soft gravity → exit another edge.
  List<Offset>? _cometPath(
    math.Random rng,
    Size size,
    Offset core,
    double rimR,
  ) {
    for (var attempt = 0; attempt < 16; attempt++) {
      final startEdge = rng.nextInt(4);
      final start = _pointOnEdge(rng, size, startEdge);

      // Aim for a flyby just outside the rim glow.
      final periapsis = rimR * (0.55 + rng.nextDouble() * 0.5);
      final aimAngle = rng.nextDouble() * math.pi * 2;
      final aim =
          core + Offset(math.cos(aimAngle), math.sin(aimAngle)) * periapsis;

      final toAim = aim - start;
      final aimLen = toAim.distance;
      if (aimLen < 8) continue;

      final baseSpeed = math.min(size.width, size.height) * 0.62;
      var vel = Offset(toAim.dx / aimLen, toAim.dy / aimLen) * baseSpeed;
      var pos = start;

      final gravity = math.pow(math.min(size.width, size.height), 2) * 0.14;
      final soft = rimR * 0.4;
      final floor = rimR * 0.48;
      const dt = 1 / 60.0;
      final margin = math.min(size.width, size.height) * 0.25;
      final bounds = Rect.fromLTRB(
        -margin,
        -margin,
        size.width + margin,
        size.height + margin,
      );

      final points = <Offset>[start];
      var skimmed = false;

      for (var step = 0; step < 480; step++) {
        final toCore = core - pos;
        final d = toCore.distance;
        if (d > 1) {
          var pull = gravity / (d * d + soft * soft);
          if (d < floor) {
            // Bounce soft off the core so it curves instead of plunging in.
            final out = Offset(-toCore.dx / d, -toCore.dy / d);
            vel += out * ((floor - d) / floor) * baseSpeed * 0.35;
            pull *= 0.25;
            skimmed = true;
          } else if (d < rimR * 1.35) {
            skimmed = true;
          }
          vel += Offset(toCore.dx / d, toCore.dy / d) * pull * dt;
        }

        final spd = vel.distance;
        final maxSpd = baseSpeed * 1.85;
        if (spd > maxSpd) {
          vel = Offset(vel.dx / spd, vel.dy / spd) * maxSpd;
        }

        pos += vel * dt;
        points.add(pos);

        if (step > 40 && !bounds.contains(pos)) {
          if (skimmed && points.length > 24) return points;
          break;
        }
      }
    }
    return null;
  }

  Offset _samplePolyline(List<Offset> points, double t) {
    if (points.length == 1) return points.first;
    final f = (t.clamp(0.0, 1.0)) * (points.length - 1);
    final i = f.floor().clamp(0, points.length - 2);
    return Offset.lerp(points[i], points[i + 1], f - i)!;
  }

  /// Edge-to-edge chord that stays clear of the bottled-star core.
  (Offset, Offset)? _driftPath(
    math.Random rng,
    Size size,
    Offset core,
    double clearRadius,
  ) {
    for (var attempt = 0; attempt < 24; attempt++) {
      final startEdge = rng.nextInt(4);
      var endEdge = rng.nextInt(4);
      if (endEdge == startEdge) {
        endEdge = (endEdge + 1 + rng.nextInt(3)) % 4;
      }
      final a = _pointOnEdge(rng, size, startEdge);
      final b = _pointOnEdge(rng, size, endEdge);
      if (_segmentClearance(a, b, core) >= clearRadius) {
        return (a, b);
      }
    }
    return null;
  }

  Offset _pointOnEdge(math.Random rng, Size size, int edge) {
    const m = 0.08;
    final along = -m + rng.nextDouble() * (1 + 2 * m);
    switch (edge) {
      case 0: // left → any vertical, including slight overshoot
        return Offset(-size.width * m, size.height * along);
      case 1: // right
        return Offset(size.width * (1 + m), size.height * along);
      case 2: // top
        return Offset(size.width * along, -size.height * m);
      default: // bottom
        return Offset(size.width * along, size.height * (1 + m));
    }
  }

  double _segmentClearance(Offset a, Offset b, Offset p) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 < 1) return (p - a).distance;
    var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    final closest = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - closest).distance;
  }

  @override
  bool hitTest(Offset position) => false;

  @override
  bool shouldRepaint(covariant _MenuAtmospherePainter oldDelegate) =>
      oldDelegate.elapsedSeconds != elapsedSeconds ||
      oldDelegate.driftCast != driftCast ||
      oldDelegate.creditArt.length != creditArt.length;
}

class _Star {
  const _Star({
    required this.x,
    required this.y,
    required this.r,
    required this.depth,
    required this.phase,
  });

  final double x;
  final double y;
  final double r;
  final double depth;
  final double phase;
}
