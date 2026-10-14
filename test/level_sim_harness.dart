import 'dart:math' as math;

import 'package:bottled_star/game/challenge/challenge_run.dart';
import 'package:bottled_star/game/challenge/level_spec.dart';
import 'package:bottled_star/game/element_tier.dart';
import 'package:bottled_star/game/modes/game_mode.dart';
import 'package:bottled_star/game/systems/bottled_star_world.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mounts a real Challenge world and drives it frame by frame.
class LevelSim {
  LevelSim._(this.tester, this.world);

  final WidgetTester tester;
  final BottledStarWorld world;

  static Future<LevelSim> boot(WidgetTester tester, LevelSpec level) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final world = BottledStarWorld(
      mode: GameMode.challenge,
      challengeLevel: level,
    );
    final game = Forge2DGame(world: world, zoom: 1);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 800,
          child: GameWidget(game: game),
        ),
      ),
    );
    for (var i = 0; i < 60 && !world.isLoaded; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    return LevelSim._(tester, world);
  }

  Future<void> run(double seconds) async {
    final frames = (seconds * 60).round();
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// [angleDeg] is the injector position; the shot travels toward the origin.
  bool fire(double angleDeg, double power) {
    final inj = world.injector;
    inj.cooldown = 0;
    inj.orbitAngle = angleDeg * math.pi / 180;
    inj.charging = true;
    inj.charge = power;
    return world.fireInjector();
  }

  ChallengeRunStatus get status =>
      world.challengeTracker?.status ?? ChallengeRunStatus.playing;

  Map<String, int> get counts {
    final out = <String, int>{};
    for (final n in world.nuclei) {
      if (!n.isMounted || n.pendingDestroy) continue;
      out[n.tier.symbol] = (out[n.tier.symbol] ?? 0) + 1;
    }
    return out;
  }

  int count(ElementTier tier) => world.countForTier(tier);

  String describe() {
    final parts = <String>[];
    for (final n in world.nuclei) {
      if (!n.isMounted || n.pendingDestroy) continue;
      final p = n.body.position;
      final a = math.atan2(p.y, p.x) * 180 / math.pi;
      parts.add(
        '${n.tier.symbol}@${a.toStringAsFixed(0)}°/${p.length.toStringAsFixed(0)}',
      );
    }
    return '$status ${parts.join(' ')}';
  }
}

/// Fires [shots] (angleDeg, power, waitSeconds after) and returns the sim.
Future<LevelSim> playLine(
  WidgetTester tester,
  LevelSpec level,
  List<(double, double, double)> shots, {
  double settleFirst = 2,
  bool log = false,
}) async {
  final sim = await LevelSim.boot(tester, level);
  await sim.run(settleFirst);
  if (log) debugPrint('load: ${sim.describe()}');
  for (final (angle, power, wait) in shots) {
    if (sim.status != ChallengeRunStatus.playing) break;
    sim.fire(angle, power);
    await sim.run(wait);
    if (log) debugPrint('after $angle/$power: ${sim.describe()}');
  }
  return sim;
}

Vector2 unit(double deg) =>
    Vector2(math.cos(deg * math.pi / 180), math.sin(deg * math.pi / 180));
