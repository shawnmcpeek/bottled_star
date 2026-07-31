import 'package:bottled_star/game/element_tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ElementTier merge rules', () {
    test('hydrogen self-pairs to helium', () {
      expect(
        ElementTier.mergeResult(
          ElementTier.hydrogen,
          ElementTier.hydrogen,
        ),
        ElementTier.helium,
      );
    });

    test('helium self-pairs to carbon', () {
      expect(
        ElementTier.mergeResult(
          ElementTier.helium,
          ElementTier.helium,
        ),
        ElementTier.carbon,
      );
    });

    test('helium levels carbon to oxygen', () {
      expect(
        ElementTier.mergeResult(
          ElementTier.helium,
          ElementTier.carbon,
        ),
        ElementTier.oxygen,
      );
    });

    test('same-tier fusion skips two rungs', () {
      expect(
        ElementTier.mergeResult(ElementTier.carbon, ElementTier.carbon),
        ElementTier.magnesium,
      );
      expect(
        ElementTier.mergeResult(ElementTier.oxygen, ElementTier.oxygen),
        ElementTier.sulfur,
      );
      expect(
        ElementTier.mergeResult(ElementTier.neon, ElementTier.neon),
        ElementTier.calcium,
      );
      expect(
        ElementTier.mergeResult(ElementTier.silicon, ElementTier.silicon),
        ElementTier.iron,
      );
    });

    test('Mg S Ar Ca same-tier stay inert', () {
      expect(
        ElementTier.mergeResult(ElementTier.magnesium, ElementTier.magnesium),
        isNull,
      );
      expect(
        ElementTier.mergeResult(ElementTier.sulfur, ElementTier.sulfur),
        isNull,
      );
      expect(
        ElementTier.mergeResult(ElementTier.argon, ElementTier.argon),
        isNull,
      );
      expect(
        ElementTier.mergeResult(ElementTier.calcium, ElementTier.calcium),
        isNull,
      );
    });

    test('helium capture still works at every heavy tier below iron', () {
      expect(
        ElementTier.mergeResult(ElementTier.helium, ElementTier.neon),
        ElementTier.magnesium,
      );
      expect(
        ElementTier.mergeResult(ElementTier.helium, ElementTier.calcium),
        ElementTier.iron,
      );
    });

    test('iron never merges with helium', () {
      expect(
        ElementTier.mergeResult(
          ElementTier.helium,
          ElementTier.iron,
        ),
        isNull,
      );
    });

    test('isSameTierMerge flags fusion pairs', () {
      expect(
        ElementTier.isSameTierMerge(ElementTier.silicon, ElementTier.silicon),
        isTrue,
      );
      expect(
        ElementTier.isSameTierMerge(ElementTier.helium, ElementTier.carbon),
        isFalse,
      );
    });
  });
}
