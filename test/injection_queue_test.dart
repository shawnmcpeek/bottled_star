import 'dart:math';

import 'package:bottled_star/game/constants.dart';
import 'package:bottled_star/game/element_tier.dart';
import 'package:bottled_star/game/systems/injection_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InjectionQueue', () {
    test('starts hydrogen-only', () {
      final queue = InjectionQueue(random: Random(1));
      expect(queue.pool, [ElementTier.hydrogen]);
      expect(queue.current, ElementTier.hydrogen);
    });

    test('unlocks helium after creating helium', () {
      final queue = InjectionQueue(random: Random(1));
      queue.onHighestTier(ElementTier.helium.tier);
      expect(
        queue.pool,
        [ElementTier.hydrogen, ElementTier.helium],
      );
    });

    test('caps unlock at neon', () {
      final queue = InjectionQueue(random: Random(1));
      queue.onHighestTier(ElementTier.iron.tier);
      expect(queue.unlockedThrough, GameConstants.maxInjectTier);
      expect(queue.pool.last, ElementTier.neon);
      expect(queue.pool.contains(ElementTier.iron), isFalse);
    });

    test('consume advances current to next', () {
      final queue = InjectionQueue(random: Random(42));
      queue.onHighestTier(ElementTier.carbon.tier);
      final first = queue.current;
      final second = queue.next;
      final fired = queue.consume();
      expect(fired, first);
      expect(queue.current, second);
    });

    test('weighted rolls favor hydrogen and helium', () {
      final queue = InjectionQueue(random: Random(7));
      queue.onHighestTier(ElementTier.neon.tier);

      final counts = <ElementTier, int>{};
      for (var i = 0; i < 500; i++) {
        final rolled = queue.consume();
        counts[rolled] = (counts[rolled] ?? 0) + 1;
      }

      expect(counts[ElementTier.hydrogen]! + counts[ElementTier.helium]!,
          greaterThan(counts[ElementTier.neon] ?? 0));
      expect(counts[ElementTier.hydrogen]!, greaterThan(counts[ElementTier.carbon]!));
    });
  });
}
