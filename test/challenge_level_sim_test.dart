import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:bottled_star/game/challenge/challenge_run.dart';
import 'package:bottled_star/game/challenge/level_spec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'level_sim_harness.dart';

LevelSpec packLevel(int pack, String id) {
  final raw =
      jsonDecode(File('assets/levels/pack$pack.json').readAsStringSync())
          as Map<String, dynamic>;
  final levels = (raw['levels'] as List).cast<Map<String, dynamic>>();
  return LevelSpec.fromJson(
    levels.firstWhere((l) => l['id'] == id),
    pack: pack,
  );
}

double? angleOf(LevelSim sim, String symbol) {
  for (final n in sim.world.nuclei) {
    if (!n.isMounted || n.pendingDestroy || n.tier.symbol != symbol) continue;
    final p = n.body.position;
    return math.atan2(p.y, p.x) * 180 / math.pi;
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Housekeeping (p3_02)', () {
    testWidgets('the pin holds while you wait', (tester) async {
      final sim = await playLine(
        tester,
        packLevel(3, 'p3_02'),
        [],
        settleFirst: 30,
      );
      expect(sim.counts['C'], 2);
      expect(sim.status, ChallengeRunStatus.playing);
    });

    testWidgets('oxygen between patrol passes knocks the pin out', (
      tester,
    ) async {
      final sim = await LevelSim.boot(tester, packLevel(3, 'p3_02'));
      await sim.run(1.75);
      sim.fire(90, 0.6);
      await sim.run(20);
      expect(sim.status, ChallengeRunStatus.won);
    });

    testWidgets('oxygen into the patrol is neon', (tester) async {
      final sim = await LevelSim.boot(tester, packLevel(3, 'p3_02'));
      await sim.run(1.25);
      sim.fire(90, 0.6);
      await sim.run(10);
      expect(sim.status, ChallengeRunStatus.lost);
    });
  });

  group("Don't Look Away (p3_03)", () {
    final level = packLevel(3, 'p3_03');

    testWidgets('helium the decoys, wait for the real pair', (tester) async {
      final sim = await playLine(tester, level, [(150, 0.5, 15), (210, 0.5, 8)]);
      expect(sim.status, ChallengeRunStatus.won);
    });

    testWidgets('the decoy pair never merges on its own', (tester) async {
      final sim = await playLine(tester, level, [], settleFirst: 90);
      expect(sim.counts['Mg'], 1);
      expect(sim.counts['C'], 2);
    });

    testWidgets('helium on the real pair loses', (tester) async {
      final sim = await playLine(tester, level, [(0, 0.5, 15), (30, 0.5, 8)]);
      expect(sim.status, ChallengeRunStatus.lost);
    });

    testWidgets('rushing the second helium loses', (tester) async {
      final sim = await playLine(tester, level, [(150, 0.5, 3), (210, 0.5, 8)]);
      expect(sim.status, ChallengeRunStatus.lost);
    });
  });

  group('The Last One (p3_04)', () {
    final level = packLevel(3, 'p3_04');

    testWidgets('blast the calcium, then clean up', (tester) async {
      for (var i = 0; i < 5; i++) {
        final sim = await playLine(tester, level, [(180, 0.5, 6)]);
        if (sim.status == ChallengeRunStatus.playing) {
          sim.fire(angleOf(sim, 'C') ?? 90, 0.5);
          await sim.run(8);
        }
        expect(sim.status, ChallengeRunStatus.won, reason: 'run $i');
      }
    });

    testWidgets('helium on two carbons leaves the third', (tester) async {
      final sim = await playLine(tester, level, [(0, 0.5, 8), (70, 0.5, 20)]);
      expect(sim.status, ChallengeRunStatus.lost);
    });
  });

  group('Two Bites (p3_12)', () {
    final level = packLevel(3, 'p3_12');

    testWidgets('a led carbon catches the swinger', (tester) async {
      final sim = await LevelSim.boot(tester, level);
      await sim.run(1.5);
      sim.fire(-30, 0.5);
      await sim.run(5);
      sim.fire(180, 0.5);
      await sim.run(8);
      expect(sim.status, ChallengeRunStatus.won);
    });

    testWidgets('a carbon that lands behind it is stranded', (tester) async {
      final sim = await LevelSim.boot(tester, level);
      await sim.run(2);
      sim.fire(0, 0.5);
      await sim.run(5);
      sim.fire(180, 0.5);
      await sim.run(8);
      expect(sim.status, ChallengeRunStatus.lost);
    });
  });

  group('supernova family (p3_06–p3_10)', () {
    int supernovas(LevelSim sim) =>
        sim.world.challengeTracker?.supernovaCount ?? 0;

    testWidgets('none of them detonate while you wait', (tester) async {
      for (final id in ['p3_06', 'p3_07', 'p3_08', 'p3_09', 'p3_10']) {
        final sim = await playLine(
          tester,
          packLevel(3, id),
          [],
          settleFirst: 20,
        );
        expect(supernovas(sim), 0, reason: id);
      }
    });

    testWidgets('First Light: pair on the calcium between passes', (
      tester,
    ) async {
      final sim = await LevelSim.boot(tester, packLevel(3, 'p3_06'));
      await sim.run(1.5);
      sim.fire(0, 0.8);
      await sim.run(0.5);
      sim.fire(0, 0.8);
      await sim.run(6);
      expect(sim.status, ChallengeRunStatus.won);
    });

    testWidgets('Chain Reaction: a square hit chains, a glance does not', (
      tester,
    ) async {
      final level = packLevel(3, 'p3_07');
      final square = await playLine(tester, level, [(88, 0.5, 8)]);
      expect(square.status, ChallengeRunStatus.won);
      final glance = await playLine(tester, level, [(60, 0.5, 8)]);
      expect(supernovas(glance), 1);
      expect(glance.status, ChallengeRunStatus.lost);
    });

    testWidgets('Rim Runner: two hydrogens through the rim gap', (
      tester,
    ) async {
      var wins = 0;
      for (var t = 0.0; t < 2.5; t += 0.5) {
        final sim = await LevelSim.boot(tester, packLevel(3, 'p3_08'));
        await sim.run(0.5 + t);
        sim.fire(88, 0.8);
        await sim.run(1);
        sim.fire(88, 0.8);
        await sim.run(6);
        if (sim.status == ChallengeRunStatus.won) wins++;
      }
      expect(wins, inInclusiveRange(1, 4));
    });

    testWidgets('Two Points of Light: gated blast, then the last calcium', (
      tester,
    ) async {
      final sim = await LevelSim.boot(tester, packLevel(3, 'p3_09'));
      await sim.run(0.5);
      sim.fire(88, 0.8);
      await sim.run(4);
      expect(supernovas(sim), 1);
      sim.fire(angleOf(sim, 'Ca')!, 0.8);
      await sim.run(8);
      expect(sim.status, ChallengeRunStatus.won);
    });

    testWidgets('Two Is Enough: direct hits join only past the guard', (
      tester,
    ) async {
      final level = packLevel(3, 'p3_10');
      var wins = 0;
      for (final t in [0.0, 1.0, 2.0]) {
        for (final t2 in [0.0, 1.0, 2.0]) {
          final sim = await LevelSim.boot(tester, level);
          await sim.run(1 + t);
          sim.fire(72, 0.8);
          await sim.run(3 + t2);
          sim.fire(108, 0.8);
          await sim.run(10);
          if (sim.status == ChallengeRunStatus.won) wins++;
        }
      }
      expect(wins, inInclusiveRange(1, 8));
    });
  });

  group('fire-all-shots arcs', () {
    testWidgets('Ration: dump at the arc edge', (tester) async {
      final level = packLevel(1, 'p1_10');
      final good = await playLine(tester, level, [(0, 0.5, 4), (49, 0.5, 6)]);
      expect(good.status, ChallengeRunStatus.won);
      final bad = await playLine(tester, level, [(0, 0.5, 4), (30, 0.5, 6)]);
      expect(bad.status, ChallengeRunStatus.lost);
    });

    testWidgets('Hold the Line: dumps apart on the lead', (tester) async {
      final sim = await playLine(tester, packLevel(1, 'p1_13'), [
        (0, 0.5, 3),
        (0, 0.5, 4),
        (49, 0.5, 4),
        (-49, 0.5, 20),
      ]);
      expect(sim.status, ChallengeRunStatus.won);
    });

    testWidgets('Strict Diet: pair beside the carbon, dumps apart', (
      tester,
    ) async {
      final level = packLevel(3, 'p3_11');
      final good = await playLine(tester, level, [
        (66, 0.5, 2),
        (66, 0.5, 5),
        (66, 0.5, 3),
        (114, 0.5, 8),
      ]);
      expect(good.status, ChallengeRunStatus.won);
      final bad = await playLine(tester, level, [
        (90, 0.5, 2),
        (90, 0.5, 5),
        (66, 0.5, 3),
        (114, 0.5, 20),
      ]);
      expect(bad.status, ChallengeRunStatus.lost);
    });

    testWidgets('Overdraft completes on the static lead', (tester) async {
      final sim = await playLine(tester, packLevel(3, 'p3_13'), [
        (90, 0.5, 3),
        (90, 0.5, 4),
        (61, 0.5, 4),
        (119, 0.5, 6),
      ]);
      expect(sim.status, ChallengeRunStatus.won);
    });
  });

  group('Rationed, Compounded (p3_14)', () {
    testWidgets('carbon and oxygen hold still on the lead', (tester) async {
      final sim = await playLine(
        tester,
        packLevel(3, 'p3_14'),
        [],
        settleFirst: 15,
      );
      expect(sim.counts['C'], 1);
      expect(sim.counts['O'], 1);
    });

    testWidgets('the twin oxygens stay apart until knocked', (tester) async {
      final sim = await playLine(tester, packLevel(3, 'p3_14'), [
        (0, 0.5, 2),
        (0, 0.5, 15),
      ]);
      expect(sim.counts['O'], 2);
      expect(sim.status, ChallengeRunStatus.playing);
    });

    testWidgets('knock from behind an oxygen wins, between them loses', (
      tester,
    ) async {
      final level = packLevel(3, 'p3_14');
      for (final a in <double>[345, 85]) {
        final sim = await playLine(tester, level, [
          (0, 0.5, 2),
          (0, 0.5, 5),
          (a, 0.5, 8),
        ]);
        expect(sim.status, ChallengeRunStatus.won, reason: '$a');
      }
      for (final a in <double>[0, 35, 70]) {
        final sim = await playLine(tester, level, [
          (0, 0.5, 2),
          (0, 0.5, 5),
          (a, 0.5, 8),
        ]);
        expect(sim.status, ChallengeRunStatus.lost, reason: '$a');
      }
    });
  });

  group('Vanishing Act (p3_16)', () {
    testWidgets('helium in the path of each swinging carbon', (tester) async {
      final sim = await LevelSim.boot(tester, packLevel(3, 'p3_16'));
      await sim.run(2);
      sim.fire(90, 0.8);
      await sim.run(0.6);
      sim.fire(90, 0.8);
      await sim.run(4);
      sim.fire(270, 0.8);
      await sim.run(0.6);
      sim.fire(270, 0.8);
      await sim.run(8);
      expect(sim.status, ChallengeRunStatus.won);
    });

    testWidgets('the carbons never come down on their own', (tester) async {
      final sim = await playLine(
        tester,
        packLevel(3, 'p3_16'),
        [],
        settleFirst: 20,
      );
      expect(sim.counts['C'], 2);
    });
  });

  group('Rationed Cage (p3_18)', () {
    testWidgets('the lead cage never detonates', (tester) async {
      final sim = await playLine(
        tester,
        packLevel(3, 'p3_18'),
        [],
        settleFirst: 20,
      );
      expect(sim.counts['Ar'], 1);
      expect(sim.counts['Pb'], 4);
    });

    testWidgets('pair at the far edge of the gap', (tester) async {
      final level = packLevel(3, 'p3_18');
      final good = await playLine(tester, level, [(68, 0.5, 4), (68, 0.5, 8)]);
      expect(good.status, ChallengeRunStatus.won);
      final bad = await playLine(tester, level, [(90, 0.5, 4), (90, 0.5, 8)]);
      expect(bad.status, ChallengeRunStatus.lost);
    });
  });

  group('Let It Ride (p3_15)', () {
    final level = packLevel(3, 'p3_15');

    testWidgets('waiting lets the helium reach the carbons', (tester) async {
      final sim = await playLine(tester, level, [], settleFirst: 10);
      expect(sim.status, ChallengeRunStatus.lost);
    });

    testWidgets('both magnesiums in time, the heliums finish it', (
      tester,
    ) async {
      for (final (o1, o2) in [(0.0, 0.0), (-3.0, 3.0), (0.0, 6.0)]) {
        final sim = await LevelSim.boot(tester, level);
        await sim.run(1);
        sim.fire(71 + o1, 0.8);
        await sim.run(1);
        sim.fire(109 + o2, 0.8);
        await sim.run(14);
        expect(sim.status, ChallengeRunStatus.won, reason: '$o1/$o2');
      }
    });

    testWidgets('too slow, or aimed inward, loses', (tester) async {
      final late = await LevelSim.boot(tester, level);
      await late.run(4.5);
      late.fire(71, 0.8);
      await late.run(1.5);
      late.fire(109, 0.8);
      await late.run(14);
      expect(late.status, ChallengeRunStatus.lost);

      final inward = await LevelSim.boot(tester, level);
      await inward.run(1);
      inward.fire(77, 0.8);
      await inward.run(1);
      inward.fire(103, 0.8);
      await inward.run(14);
      expect(inward.status, ChallengeRunStatus.lost);
    });
  });

  group('Everything (p3_20)', () {
    final level = packLevel(3, 'p3_20');

    testWidgets('carbon and oxygen hold still, no free merge', (tester) async {
      final sim = await playLine(tester, level, [], settleFirst: 15);
      expect(sim.counts['C'], 2);
      expect(sim.counts['O'], 1);
    });

    Future<LevelSim> climb(WidgetTester tester, double wait) async {
      final sim = await playLine(tester, level, [(0, 0.5, 2), (0, 0.5, 6)]);
      await sim.run(wait);
      sim.fire(180, 0.8);
      await sim.run(0.3);
      sim.fire(180, 0.8);
      await sim.run(4.5);
      sim.fire(180, 0.8);
      await sim.run(0.3);
      sim.fire(180, 0.8);
      await sim.run(12);
      return sim;
    }

    testWidgets('helium on the carbon from any side is sulfur', (
      tester,
    ) async {
      for (final a in <double>[-20, -7.5, -5, -2.5, 0, 2.5, 5, 12.5, 15]) {
        for (final p in [0.2, 0.8]) {
          final sim = await playLine(tester, level, [
            ((a + 360) % 360, p, 2),
            ((a + 360) % 360, p, 10),
          ]);
          expect(sim.counts['S'], 1, reason: '$a/$p');
        }
      }
    });

    testWidgets('climbs timed past the guard detonate', (tester) async {
      final sim = await climb(tester, 0.75);
      expect(sim.status, ChallengeRunStatus.won);
    });

    testWidgets('climbs into the guard fail', (tester) async {
      final sim = await climb(tester, 0);
      expect(sim.status, ChallengeRunStatus.lost);
    });

    testWidgets('helium on the oxygen is neon', (tester) async {
      final sim = await playLine(tester, level, [(20, 0.5, 2), (20, 0.5, 6)]);
      expect(sim.status, ChallengeRunStatus.lost);
    });
  });
}
