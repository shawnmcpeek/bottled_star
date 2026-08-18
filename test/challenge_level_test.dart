import 'dart:convert';

import 'package:bottled_star/game/challenge/challenge_progress.dart';
import 'package:bottled_star/game/challenge/challenge_run.dart';
import 'package:bottled_star/game/challenge/fixed_queue.dart';
import 'package:bottled_star/game/challenge/level_library.dart';
import 'package:bottled_star/game/challenge/level_spec.dart';
import 'package:bottled_star/game/constants.dart';
import 'package:bottled_star/game/element_tier.dart';
import 'package:bottled_star/game/modes/game_mode.dart';
import 'package:bottled_star/game/systems/leaderboard_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _exampleLevelJson = '''
{
  "id": "p1_09",
  "name": "Starved",
  "blurb": "One calcium. No helium given.",
  "seed": {
    "bodies": [
      { "element": "Ca", "count": 1, "placement": "point",
        "angleDeg": 270, "radiusFrac": 0.72 },
      { "element": "C", "count": 4, "placement": "ring",
        "radiusFrac": 0.55, "phaseDeg": 45 }
    ],
    "baked": null
  },
  "injectionArc": { "centerDeg": 90, "widthDeg": 120 },
  "queue": {
    "mode": "fixed",
    "sequence": ["H","H","H","H","H","H","H","H","H","H","H","H"],
    "visibleCount": 3
  },
  "budget": { "shots": 12 },
  "goals": [
    { "type": "produce", "element": "Fe", "count": 1 }
  ],
  "constraints": [
    { "type": "maxBodies", "value": 22 }
  ],
  "rules": { "remnants": false },
  "par": { "shots": 9 }
}
''';

Map<String, dynamic> _exampleLevelMap() =>
    Map<String, dynamic>.from(jsonDecode(_exampleLevelJson) as Map);

Map<String, dynamic> _packWith(List<Map<String, dynamic>> levels) => {
  'schemaVersion': 1,
  'pack': 1,
  'levels': levels,
};

LevelSpec _parseExample() => LevelSpec.fromJson(_exampleLevelMap(), pack: 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ElementTier.fromSymbol', () {
    test('resolves periodic symbols', () {
      expect(ElementTier.fromSymbol('Si'), ElementTier.silicon);
      expect(ElementTier.fromSymbol('Fe'), ElementTier.iron);
      expect(ElementTier.fromSymbol('H'), ElementTier.hydrogen);
      expect(ElementTier.fromSymbol('silicon'), isNull);
      expect(ElementTier.fromSymbol('Xx'), isNull);
    });
  });

  group('LevelSpec parse — success', () {
    test('parses the hand-written example level', () {
      final level = _parseExample();
      expect(level.id, 'p1_09');
      expect(level.name, 'Starved');
      expect(level.blurb, 'One calcium. No helium given.');
      expect(level.budgetShots, 12);
      expect(level.parShots, 9);
      expect(level.queue.sequence.length, 12);
      expect(level.queue.visibleCount, 3);
      expect(level.goals, hasLength(1));
      expect(level.constraints, hasLength(1));
      expect(level.rules.remnants, isFalse);
      expect(level.seed.baked, isNull);
      expect(level.seed.bodies, hasLength(2));
    });

    test('baked null instantiates from composition', () {
      final level = _parseExample();
      final bodies = level.resolveSeed(chamberRadius: 100);
      expect(bodies, hasLength(5)); // 1 Ca + 4 C
      expect(
        bodies.where((b) => b.element == ElementTier.calcium),
        hasLength(1),
      );
      expect(
        bodies.where((b) => b.element == ElementTier.carbon),
        hasLength(4),
      );

      final ca = bodies.firstWhere((b) => b.element == ElementTier.calcium);
      // angleDeg 270 = down (−Y), radiusFrac 0.72 * 100
      expect(ca.x, closeTo(0, 1e-9));
      expect(ca.y, closeTo(-72, 1e-9));
    });

    test('non-null baked overrides composition', () {
      final map = _exampleLevelMap();
      (map['seed'] as Map)['baked'] = [
        {'element': 'Fe', 'x': 12.4, 'y': -88.1, 'angle': 0.31},
        {'element': 'He', 'x': 0.0, 'y': 10.0, 'angle': 1.0},
      ];
      final level = LevelSpec.fromJson(map, pack: 1);
      final bodies = level.resolveSeed();
      expect(bodies, hasLength(2));
      expect(bodies[0].element, ElementTier.iron);
      expect(bodies[0].x, 12.4);
      expect(bodies[0].y, -88.1);
      expect(bodies[0].angle, 0.31);
      expect(bodies[1].element, ElementTier.helium);
    });

    test('seed may contain elements above maxInjectTier', () {
      final map = _exampleLevelMap();
      expect(() => LevelSpec.fromJson(map, pack: 1), returnsNormally);
      final level = LevelSpec.fromJson(map, pack: 1);
      expect(
        level.seed.bodies.any(
          (b) => b.element.tier > GameConstants.maxInjectTier,
        ),
        isTrue,
      );
    });
  });

  group('LevelSpec parse — fatal validation', () {
    test('unknown schemaVersion', () {
      expect(
        () => LevelPack.fromJson({
          'schemaVersion': 99,
          'pack': 1,
          'levels': [_exampleLevelMap()],
        }),
        throwsA(
          isA<LevelParseException>().having(
            (e) => e.message,
            'message',
            contains('schemaVersion'),
          ),
        ),
      );
    });

    test('unknown element symbol', () {
      final map = _exampleLevelMap();
      ((map['goals'] as List).first as Map)['element'] = 'Xx';
      expect(
        () => LevelSpec.fromJson(map, pack: 1),
        throwsA(
          isA<LevelParseException>()
              .having((e) => e.levelId, 'levelId', 'p1_09')
              .having((e) => e.message, 'message', contains('Xx')),
        ),
      );
    });

    test('queue element above maxInjectTier', () {
      final map = _exampleLevelMap();
      (map['queue'] as Map)['sequence'] = [
        'H',
        'Si',
        'H',
        'H',
        'H',
        'H',
        'H',
        'H',
        'H',
        'H',
        'H',
        'H',
      ];
      expect(
        () => LevelSpec.fromJson(map, pack: 1),
        throwsA(
          isA<LevelParseException>().having(
            (e) => e.message,
            'message',
            contains('maxInjectTier'),
          ),
        ),
      );
    });

    test('queue.mode not fixed', () {
      final map = _exampleLevelMap();
      (map['queue'] as Map)['mode'] = 'weighted';
      expect(
        () => LevelSpec.fromJson(map, pack: 1),
        throwsA(
          isA<LevelParseException>().having(
            (e) => e.message,
            'message',
            contains('fixed'),
          ),
        ),
      );
    });

    test('sequence shorter than budget', () {
      final map = _exampleLevelMap();
      (map['queue'] as Map)['sequence'] = ['H', 'H', 'H'];
      expect(
        () => LevelSpec.fromJson(map, pack: 1),
        throwsA(
          isA<LevelParseException>().having(
            (e) => e.message,
            'message',
            contains('sequence.length'),
          ),
        ),
      );
    });

    test('empty goals array', () {
      final map = _exampleLevelMap();
      map['goals'] = [];
      expect(
        () => LevelSpec.fromJson(map, pack: 1),
        throwsA(
          isA<LevelParseException>().having(
            (e) => e.message,
            'message',
            contains('goals'),
          ),
        ),
      );
    });

    test('unknown goal type', () {
      final map = _exampleLevelMap();
      map['goals'] = [
        {'type': 'collectStars', 'count': 3},
      ];
      expect(
        () => LevelSpec.fromJson(map, pack: 1),
        throwsA(
          isA<LevelParseException>().having(
            (e) => e.message,
            'message',
            contains('unknown goal'),
          ),
        ),
      );
    });

    test('unknown constraint type', () {
      final map = _exampleLevelMap();
      map['constraints'] = [
        {'type': 'noFun'},
      ];
      expect(
        () => LevelSpec.fromJson(map, pack: 1),
        throwsA(
          isA<LevelParseException>().having(
            (e) => e.message,
            'message',
            contains('unknown constraint'),
          ),
        ),
      );
    });

    test('duplicate id within pack', () {
      final a = _exampleLevelMap();
      final b = _exampleLevelMap();
      b['id'] = 'p1_09';
      expect(
        () => LevelPack.fromJson(_packWith([a, b])),
        throwsA(
          isA<LevelParseException>().having(
            (e) => e.message,
            'message',
            contains('duplicate'),
          ),
        ),
      );
    });

    test('duplicate id across packs', () {
      final lib = LevelLibrary();
      lib.loadPackJson(jsonEncode(_packWith([_exampleLevelMap()])));
      expect(
        () => lib.loadPackJson(
          jsonEncode({
            'schemaVersion': 1,
            'pack': 2,
            'levels': [_exampleLevelMap()],
          }),
        ),
        throwsA(
          isA<LevelParseException>().having(
            (e) => e.message,
            'message',
            contains('across packs'),
          ),
        ),
      );
    });

    test('radiusFrac out of range', () {
      final map = _exampleLevelMap();
      (((map['seed'] as Map)['bodies'] as List).first as Map)['radiusFrac'] =
          1.5;
      expect(
        () => LevelSpec.fromJson(map, pack: 1),
        throwsA(
          isA<LevelParseException>().having(
            (e) => e.message,
            'message',
            contains('radiusFrac'),
          ),
        ),
      );
    });

    test('angleDeg out of range', () {
      final map = _exampleLevelMap();
      (((map['seed'] as Map)['bodies'] as List).first as Map)['angleDeg'] = 400;
      expect(
        () => LevelSpec.fromJson(map, pack: 1),
        throwsA(
          isA<LevelParseException>().having(
            (e) => e.message,
            'message',
            contains('angleDeg'),
          ),
        ),
      );
    });

    test('point placement with count != 1', () {
      final map = _exampleLevelMap();
      (((map['seed'] as Map)['bodies'] as List).first as Map)['count'] = 2;
      expect(
        () => LevelSpec.fromJson(map, pack: 1),
        throwsA(
          isA<LevelParseException>().having(
            (e) => e.message,
            'message',
            contains('point'),
          ),
        ),
      );
    });

    test('par.shots > budget.shots', () {
      final map = _exampleLevelMap();
      (map['par'] as Map)['shots'] = 20;
      expect(
        () => LevelSpec.fromJson(map, pack: 1),
        throwsA(
          isA<LevelParseException>().having(
            (e) => e.message,
            'message',
            contains('par.shots'),
          ),
        ),
      );
    });
  });

  group('LevelLibrary asset load', () {
    test('loads pack1.json from assets', () async {
      final lib = LevelLibrary();
      await lib.loadAll();
      final level = lib.require('p1_09');
      expect(level.name, 'Starved');
      expect(lib.allLevels, hasLength(1));
      expect(lib.pack(1)!.levels.first.id, 'p1_09');
    });
  });

  group('FixedInjectionQueue', () {
    test('walks sequence in order and exhausts', () {
      final q = FixedInjectionQueue(
        sequence: [
          ElementTier.hydrogen,
          ElementTier.helium,
          ElementTier.carbon,
        ],
        visibleCount: 2,
      );
      expect(q.current, ElementTier.hydrogen);
      expect(q.next, ElementTier.helium);
      expect(q.isExhausted, isFalse);
      expect(q.visible, [ElementTier.hydrogen, ElementTier.helium]);

      expect(q.consume(), ElementTier.hydrogen);
      expect(q.current, ElementTier.helium);
      expect(q.consume(), ElementTier.helium);
      expect(q.consume(), ElementTier.carbon);
      expect(q.isExhausted, isTrue);
    });

    test('onHighestTier is a no-op', () {
      final q = FixedInjectionQueue(
        sequence: [ElementTier.hydrogen, ElementTier.hydrogen],
      );
      q.onHighestTier(ElementTier.iron.tier);
      expect(q.consume(), ElementTier.hydrogen);
      expect(q.consume(), ElementTier.hydrogen);
      expect(q.isExhausted, isTrue);
    });

    test('reset restarts the sequence', () {
      final q = FixedInjectionQueue(
        sequence: [ElementTier.helium, ElementTier.carbon],
      );
      q.consume();
      q.reset();
      expect(q.current, ElementTier.helium);
      expect(q.isExhausted, isFalse);
    });
  });

  group('ChallengeRunTracker goals and constraints', () {
    LevelSpec levelWith({
      List<Map<String, dynamic>>? goals,
      List<Map<String, dynamic>>? constraints,
      bool remnants = false,
    }) {
      final map = _exampleLevelMap();
      if (goals != null) map['goals'] = goals;
      if (constraints != null) map['constraints'] = constraints;
      map['rules'] = {'remnants': remnants};
      return LevelSpec.fromJson(map, pack: 1);
    }

    test('produce is cumulative; evaluated at settle', () {
      final tracker = ChallengeRunTracker(
        levelWith(
          goals: [
            {'type': 'produce', 'element': 'Mg', 'count': 1},
          ],
          constraints: [],
        ),
      );

      tracker.onElementCreated(ElementTier.magnesium);
      // Created then "consumed" — produce still counts.
      expect(tracker.produced[ElementTier.magnesium], 1);
      expect(tracker.status, ChallengeRunStatus.playing);

      tracker.onShotFired();
      final won = tracker.evaluateAtSettle(boardBodies: 0);
      expect(won, isTrue);
      expect(tracker.status, ChallengeRunStatus.won);
    });

    test('neverProduce fails even when element is immediately consumed', () {
      final tracker = ChallengeRunTracker(
        levelWith(
          goals: [
            {'type': 'produce', 'element': 'Fe', 'count': 1},
          ],
          constraints: [
            {'type': 'neverProduce', 'element': 'Mg'},
          ],
        ),
      );

      // Chain: Mg created then fused away before settle.
      tracker.onElementCreated(ElementTier.magnesium);
      expect(tracker.status, ChallengeRunStatus.lost);

      // Subsequent settle / produce Fe must not resurrect the run.
      tracker.onElementCreated(ElementTier.iron);
      tracker.onShotFired();
      tracker.evaluateAtSettle(boardBodies: 1);
      expect(tracker.status, ChallengeRunStatus.lost);
    });

    test('boardUnder only wins at settle occupancy', () {
      final tracker = ChallengeRunTracker(
        levelWith(
          goals: [
            {'type': 'boardUnder', 'value': 3},
          ],
          constraints: [],
        ),
      );
      tracker.onShotFired();
      expect(tracker.evaluateAtSettle(boardBodies: 5), isFalse);
      expect(tracker.status, ChallengeRunStatus.playing);
      expect(tracker.evaluateAtSettle(boardBodies: 2), isTrue);
      expect(tracker.status, ChallengeRunStatus.won);
    });

    test('maxBodies constraint is immediate', () {
      final tracker = ChallengeRunTracker(
        levelWith(
          goals: [
            {'type': 'produce', 'element': 'Fe', 'count': 1},
          ],
          constraints: [
            {'type': 'maxBodies', 'value': 2},
          ],
        ),
      );
      tracker.onBoardChanged(totalBodies: 3, countsByElement: const {});
      expect(tracker.status, ChallengeRunStatus.lost);
    });
  });

  group('noSameTier merge flag', () {
    test('disables same-tier merges without mutating static tables', () {
      final map = _exampleLevelMap();
      map['constraints'] = [
        {'type': 'noSameTier'},
      ];
      final level = LevelSpec.fromJson(map, pack: 1);
      final tracker = ChallengeRunTracker(level);
      expect(tracker.allowSameTierMerges, isFalse);

      expect(
        tracker.mergeResult(ElementTier.carbon, ElementTier.carbon),
        isNull,
      );
      expect(
        tracker.mergeResult(ElementTier.helium, ElementTier.carbon),
        ElementTier.oxygen,
      );

      // Classic path (default) still merges same-tier — no leakage.
      expect(
        ElementTier.mergeResult(ElementTier.carbon, ElementTier.carbon),
        ElementTier.magnesium,
      );
      expect(
        ElementTier.mergeResult(
          ElementTier.carbon,
          ElementTier.carbon,
          allowSameTier: true,
        ),
        ElementTier.magnesium,
      );
    });
  });

  group('rules.remnants attach helper', () {
    test('true attaches; false does not; Collapse always does', () {
      final withRemnants = LevelSpec.fromJson({
        ..._exampleLevelMap(),
        'rules': {'remnants': true},
      }, pack: 1);
      final without = _parseExample();

      expect(
        shouldAttachRemnants(isCollapse: false, challengeLevel: withRemnants),
        isTrue,
      );
      expect(
        shouldAttachRemnants(isCollapse: false, challengeLevel: without),
        isFalse,
      );
      expect(
        shouldAttachRemnants(isCollapse: true, challengeLevel: null),
        isTrue,
      );
      expect(
        shouldAttachRemnants(isCollapse: false, challengeLevel: null),
        isFalse,
      );

      expect(withRemnants.remnantsEnabled, isTrue);
      expect(without.remnantsEnabled, isFalse);
    });
  });

  group('ChallengeProgress', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ChallengeProgress.instance.resetForTest();
    });

    test('records clear and best shots; ignores failures', () async {
      final progress = ChallengeProgress.instance;
      await progress.load();
      expect(progress.isCompleted('p1_09'), isFalse);

      await progress.recordClear(levelId: 'p1_09', shots: 11);
      expect(progress.isCompleted('p1_09'), isTrue);
      expect(progress.bestShots('p1_09'), 11);

      await progress.recordClear(levelId: 'p1_09', shots: 9);
      expect(progress.bestShots('p1_09'), 9);

      await progress.recordClear(levelId: 'p1_09', shots: 12);
      expect(progress.bestShots('p1_09'), 9);
    });

    test('unlocks next level after prior clear', () async {
      final progress = ChallengeProgress.instance;
      await progress.load();
      const order = ['a', 'b', 'c'];
      expect(progress.isUnlocked('a', order), isTrue);
      expect(progress.isUnlocked('b', order), isFalse);
      await progress.recordClear(levelId: 'a', shots: 5);
      expect(progress.isUnlocked('b', order), isTrue);
      expect(progress.isUnlocked('c', order), isFalse);
    });
  });

  group('LeaderboardService Challenge exclusion', () {
    test('submitBest rejects Challenge', () async {
      final boards = LeaderboardService();
      final result = await boards.submitBest(
        mode: GameMode.challenge,
        displayName: 'Tester',
        peakTier: 10,
        ending: 'whiteDwarf',
        shots: 9,
      );
      expect(result, LeaderboardSubmitResult.rejected);
    });

    test('collection helpers throw for Challenge', () {
      expect(
        () => LeaderboardService.allTimeCollection(GameMode.challenge),
        throwsUnsupportedError,
      );
      expect(
        () => LeaderboardService.dailyCollection(GameMode.challenge),
        throwsUnsupportedError,
      );
    });
  });
}
