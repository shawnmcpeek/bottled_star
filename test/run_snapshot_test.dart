import 'package:bottled_star/game/challenge/sweep_orbit.dart';
import 'package:bottled_star/game/element_tier.dart';
import 'package:bottled_star/game/modes/game_mode.dart';
import 'package:bottled_star/game/systems/injection_queue.dart';
import 'package:bottled_star/game/systems/run_snapshot.dart';
import 'package:bottled_star/game/systems/score_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RunSnapshot', () {
    test('round-trips weighted classic state', () {
      final snap = RunSnapshot(
        mode: GameMode.classic,
        score: 42,
        highestTier: 3,
        shotCount: 12,
        kilonovaCount: 0,
        supernovaCount: 0,
        injectorAngle: -1.2,
        tiersCreated: {0, 1, 3},
        queue: QueueSnapshot.weighted(
          current: ElementTier.hydrogen.tier,
          next: ElementTier.helium.tier,
          unlockedThrough: 3,
        ),
        nuclei: [
          NucleusSnapshot(
            tier: ElementTier.carbon.tier,
            rimPressure: 0.4,
            body: const BodySnapshot(
              x: 10,
              y: -4,
              vx: 1,
              vy: 2,
              angle: 0.3,
              angularVelocity: -0.1,
            ),
          ),
        ],
        remnants: const [],
      );

      final parsed = RunSnapshot.tryParse(snap.toJson());
      expect(parsed, isNotNull);
      expect(parsed!.mode, GameMode.classic);
      expect(parsed.score, 42);
      expect(parsed.highestTier, 3);
      expect(parsed.shotCount, 12);
      expect(parsed.injectorAngle, closeTo(-1.2, 0.0001));
      expect(parsed.tiersCreated, {0, 1, 3});
      expect(parsed.queue.kind, QueueKind.weighted);
      expect(parsed.queue.next, ElementTier.helium.tier);
      expect(parsed.queue.unlockedThrough, 3);
      expect(parsed.nuclei, hasLength(1));
      expect(parsed.nuclei.first.tier, ElementTier.carbon.tier);
      expect(parsed.nuclei.first.rimPressure, closeTo(0.4, 0.0001));
      expect(parsed.nuclei.first.body.x, 10);
      expect(parsed.isWorthSaving, isTrue);
    });

    test('empty classic board with no shots is not worth saving', () {
      const snap = RunSnapshot(
        mode: GameMode.classic,
        score: 0,
        highestTier: 0,
        shotCount: 0,
        kilonovaCount: 0,
        supernovaCount: 0,
        injectorAngle: 0,
        tiersCreated: {},
        queue: QueueSnapshot.weighted(
          current: 0,
          next: 0,
          unlockedThrough: 0,
        ),
        nuclei: [],
        remnants: [],
      );
      expect(snap.isWorthSaving, isFalse);
    });

    test('round-trips a sweeping nucleus', () {
      final snap = RunSnapshot(
        mode: GameMode.challenge,
        levelId: 'p2_11',
        score: 0,
        highestTier: 8,
        shotCount: 1,
        kilonovaCount: 0,
        supernovaCount: 0,
        injectorAngle: 0,
        tiersCreated: {8, 2},
        queue: const QueueSnapshot.fixed(
          current: 1,
          next: 1,
          index: 1,
        ),
        nuclei: [
          NucleusSnapshot(
            tier: ElementTier.carbon.tier,
            rimPressure: 0,
            orbit: SweepOrbit(
              radius: 140.8,
              centerRad: 0,
              halfSweepRad: 0.87,
              periodSeconds: 4,
              elapsed: 1.25,
            ),
            body: const BodySnapshot(
              x: 140.8,
              y: 0,
              vx: 0,
              vy: 40,
              angle: 0,
              angularVelocity: 0.3,
            ),
          ),
        ],
        remnants: const [],
      );

      final parsed = RunSnapshot.tryParse(snap.toJson());
      expect(parsed, isNotNull);
      expect(parsed!.nuclei.first.orbit, isNotNull);
      expect(parsed.nuclei.first.orbit!.elapsed, closeTo(1.25, 1e-9));
      expect(parsed.nuclei.first.orbit!.periodSeconds, 4);
    });

    test('rejects unknown schema versions', () {
      expect(RunSnapshot.tryParse({'v': 99, 'mode': 'classic'}), isNull);
    });
  });

  group('InjectionQueue.restore', () {
    test('restores current, next, and unlock', () {
      final queue = InjectionQueue();
      queue.restore(
        current: ElementTier.carbon,
        next: ElementTier.oxygen,
        unlockedThrough: 4,
      );
      expect(queue.current, ElementTier.carbon);
      expect(queue.next, ElementTier.oxygen);
      expect(queue.unlockedThrough, 4);
      expect(queue.pool.last, ElementTier.neon);
    });
  });

  group('ScoreStore.displayedHighScore', () {
    test('tracks the current score when there is no saved best', () {
      final store = ScoreStore(mode: GameMode.classic);
      expect(store.displayedHighScore(0), 0);
      expect(store.displayedHighScore(15), 15);
    });

    test('stays on the saved best until the current run passes it', () {
      final store = ScoreStore(mode: GameMode.classic)..highScore = 100;
      expect(store.displayedHighScore(40), 100);
      expect(store.displayedHighScore(100), 100);
      expect(store.displayedHighScore(101), 101);
    });
  });
}
