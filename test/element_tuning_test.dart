import 'package:bottled_star/game/element_tier.dart';
import 'package:bottled_star/game/element_tuning.dart';
import 'package:bottled_star/game/modes/game_mode.dart';
import 'package:bottled_star/game/modes/mode_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ElementTuning', () {
    test('Classic and Collapse share scale; Challenge stays 1.0', () {
      expect(
        ElementTuning.elementScaleFor(GameMode.classic),
        ElementTuning.kElementScaleClassicCollapse,
      );
      expect(
        ElementTuning.elementScaleFor(GameMode.collapse),
        ElementTuning.kElementScaleClassicCollapse,
      );
      expect(ElementTuning.elementScaleFor(GameMode.challenge), 1.0);
    });

    test('radiusFor applies mode scale at read time', () {
      final scaled = ElementTier.hydrogen.radiusFor(GameMode.classic);
      expect(scaled, closeTo(14 * 1.15, 0.001));
      expect(
        ElementTier.hydrogen.radiusFor(GameMode.challenge),
        ElementTier.hydrogen.baseRadius,
      );
    });

    test('impulse scale is scale squared', () {
      final s = ElementTuning.elementScaleFor(GameMode.classic);
      expect(ElementTuning.impulseScaleFor(GameMode.classic), s * s);
    });

    test('table radii match enum when derived mode is off', () {
      expect(ElementTuning.kUseDerivedTierRadii, isFalse);
      for (final tier in ElementTier.values) {
        expect(
          ElementTuning.tableRadiusForTier(tier.tier),
          tier.baseRadius,
        );
      }
    });
  });

  group('ModeRules', () {
    test('ironCollapses true for Collapse and Challenge', () {
      expect(ModeRules.forMode(GameMode.collapse).ironCollapses, isTrue);
      expect(ModeRules.forMode(GameMode.challenge).ironCollapses, isTrue);
    });

    test('Classic ironCollapses follows master flag (off by default)', () {
      expect(ElementTuning.kIronInertClassicEnabled, isFalse);
      expect(ModeRules.forMode(GameMode.classic).ironCollapses, isTrue);
    });
  });
}
