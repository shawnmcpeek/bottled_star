import 'package:bottled_star/game/element_tier.dart';
import 'package:bottled_star/game/modes/game_mode.dart';
import 'package:bottled_star/game/systems/bottled_star_world.dart';
import 'package:bottled_star/game/systems/run_snapshot.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mergeSystem is usable before the world loads', () {
    final world = BottledStarWorld();
    expect(world.mergeSystem.chainDepth, 0);
    world.mergeSystem.scanTouchingPairs();
    world.mergeSystem.resolve();
  });

  testWidgets('pending snapshot restores after world onLoad, not during Game.onLoad', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final world = BottledStarWorld(mode: GameMode.classic);
    world.pendingSnapshot = RunSnapshot(
      mode: GameMode.classic,
      score: 7,
      highestTier: ElementTier.carbon.tier,
      shotCount: 3,
      kilonovaCount: 0,
      supernovaCount: 0,
      injectorAngle: -1.2,
      tiersCreated: {ElementTier.carbon.tier},
      queue: QueueSnapshot.weighted(
        current: ElementTier.hydrogen.tier,
        next: ElementTier.helium.tier,
        unlockedThrough: 2,
      ),
      nuclei: [
        NucleusSnapshot(
          tier: ElementTier.carbon.tier,
          rimPressure: 0,
          body: const BodySnapshot(
            x: 40,
            y: -20,
            vx: 0,
            vy: 0,
            angle: 0,
            angularVelocity: 0,
          ),
        ),
      ],
      remnants: const [],
    );

    final game = Forge2DGame(world: world, zoom: 1);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 800,
          child: GameWidget(game: game),
        ),
      ),
    );
    for (var i = 0; i < 30 && !world.isLoaded; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(world.isLoaded, isTrue);
    expect(world.score, 7);
    expect(world.shotCount, 3);
    expect(world.nuclei, hasLength(1));
    expect(world.nuclei.first.tier, ElementTier.carbon);

    for (var i = 0; i < 10 && !world.nuclei.first.isMounted; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(world.nuclei.first.isMounted, isTrue);
  });
}
