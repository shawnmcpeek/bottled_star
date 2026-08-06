import 'dart:math';

import 'package:bottled_star/game/constants.dart';
import 'package:bottled_star/game/element_tier.dart';
import 'package:bottled_star/game/systems/ending_messages.dart';
import 'package:bottled_star/game/systems/message_bag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessageBag', () {
    test('draws unseen first then reshuffles', () {
      final bag = MessageBag(['a', 'b', 'c']);
      final rng = Random(1);
      final firstPass = {bag.draw(rng), bag.draw(rng), bag.draw(rng)};
      expect(firstPass, {'a', 'b', 'c'});
      // Exhausted — next draw reshuffles rather than throwing.
      expect(['a', 'b', 'c'], contains(bag.draw(rng)));
    });

    test('persisted seen state continues the bag', () {
      final bag = MessageBag(['a', 'b', 'c'], {0, 1});
      expect(bag.draw(Random(0)), 'c');
    });
  });

  group('EndingMessages', () {
    EndingMessageContext ctx({
      RunEnding ending = RunEnding.whiteDwarf,
      int peak = 2,
      int score = 10,
      int previousBest = 100,
      Set<int>? tiers,
    }) {
      return EndingMessageContext(
        ending: ending,
        peakTier: peak,
        score: score,
        previousHighScore: previousBest,
        tiersCreatedThisRun: tiers ?? {0, 1, peak},
      );
    }

    test('first iron milestone fires once', () {
      final fired = <String>{'first_carbon', 'first_silicon'};
      final bags = <String, Set<int>>{};
      final first = EndingMessages.select(
        ctx: ctx(peak: ElementTier.iron.tier, ending: RunEnding.supernova),
        firedMilestones: fired,
        bagSeen: bags,
        random: Random(2),
      );
      expect(first.id, 'milestone:first_iron');
      expect(fired, contains('first_iron'));

      final second = EndingMessages.select(
        ctx: ctx(peak: ElementTier.iron.tier, ending: RunEnding.supernova),
        firedMilestones: fired,
        bagSeen: bags,
        lastMessageId: first.id,
        random: Random(2),
      );
      expect(second.id, isNot(startsWith('milestone:first_iron')));
    });

    test('milestone priority prefers carbon before white dwarf', () {
      final fired = <String>{};
      final pick = EndingMessages.select(
        ctx: ctx(peak: ElementTier.carbon.tier),
        firedMilestones: fired,
        bagSeen: {},
        random: Random(0),
      );
      expect(pick.id, 'milestone:first_carbon');
    });

    test('new_best fires when score beats previous high', () {
      final fired = {
        'first_carbon',
        'first_silicon',
        'first_iron',
        'first_supernova',
        'first_white_dwarf',
      };
      final pick = EndingMessages.select(
        ctx: ctx(score: 200, previousBest: 50, peak: ElementTier.oxygen.tier),
        firedMilestones: fired,
        bagSeen: {},
        random: Random(0),
      );
      expect(pick.id, 'milestone:new_best');
      expect(pick.text, 'Best run yet.');
    });

    test('full_ladder requires every tier this run', () {
      final fired = {
        for (final id in EndingMessages.milestoneOrder) id,
      }..remove('full_ladder');
      // Force element path by burning ending chance with fixed RNG after milestones.
      final allTiers = {for (final t in ElementTier.values) t.tier};
      final pick = EndingMessages.select(
        ctx: ctx(
          peak: ElementTier.iron.tier,
          ending: RunEnding.supernova,
          score: 1,
          previousBest: 999,
          tiers: allTiers,
        ),
        firedMilestones: fired,
        bagSeen: {},
        random: Random(0),
      );
      expect(pick.id, 'milestone:full_ladder');
    });

    test('same peak produces no immediate repeats across ten draws', () {
      final fired = {...EndingMessages.milestoneOrder};
      final bags = <String, Set<int>>{};
      String? lastId;
      final ids = <String>[];
      // Force element pool: RNG always >= 0.4
      for (var i = 0; i < 10; i++) {
        final pick = EndingMessages.select(
          ctx: ctx(peak: ElementTier.carbon.tier, previousBest: 999),
          firedMilestones: fired,
          bagSeen: bags,
          lastMessageId: lastId,
          random: _AlwaysElementRandom(),
        );
        ids.add(pick.id);
        if (lastId != null) {
          expect(pick.id, isNot(lastId));
        }
        lastId = pick.id;
      }
      expect(ids.toSet().length, greaterThan(1));
    });

    test('catalog lines stay under 140 characters', () {
      for (final line in EndingMessages.milestones.values) {
        expect(line.length, lessThanOrEqualTo(140), reason: line);
      }
      for (final line in EndingMessages.supernovaPool) {
        expect(line.length, lessThanOrEqualTo(140), reason: line);
      }
      for (final line in EndingMessages.whiteDwarfPool) {
        expect(line.length, lessThanOrEqualTo(140), reason: line);
      }
      for (final lines in EndingMessages.elementPools.values) {
        for (final line in lines) {
          expect(line.length, lessThanOrEqualTo(140), reason: line);
        }
      }
    });
  });
}

/// nextDouble always 0.5 → skip ending pool (needs < 0.4), use element pool.
class _AlwaysElementRandom implements Random {
  @override
  double nextDouble() => 0.5;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}
