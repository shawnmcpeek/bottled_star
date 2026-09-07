import 'package:bottled_star/game/element_tier.dart';
import 'package:bottled_star/game/modes/game_mode.dart';
import 'package:bottled_star/game/systems/sfx_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SfxController pluck assets', () {
    test('modes map to distinct baked scales', () {
      expect(SfxController.pluckFolderFor(GameMode.classic), 'harmonic_minor');
      expect(SfxController.pluckFolderFor(GameMode.collapse), 'diminished');
      expect(SfxController.pluckFolderFor(GameMode.challenge), 'augmented');
    });

    test('each rung is a zero-padded file in the mode folder', () {
      expect(
        SfxController.pluckAssetFor(
          mode: GameMode.classic,
          tier: ElementTier.hydrogen,
        ),
        'sfx/plucks/harmonic_minor/00.m4a',
      );
      expect(
        SfxController.pluckAssetFor(
          mode: GameMode.collapse,
          tier: ElementTier.iron,
        ),
        'sfx/plucks/diminished/10.m4a',
      );
      expect(
        SfxController.pluckAssetFor(
          mode: GameMode.challenge,
          tier: ElementTier.silicon,
        ),
        'sfx/plucks/augmented/06.m4a',
      );
    });

    test('every mode has one asset per element tier', () {
      for (final mode in GameMode.values) {
        final paths = [
          for (final tier in ElementTier.values)
            SfxController.pluckAssetFor(mode: mode, tier: tier),
        ];
        expect(paths.toSet(), hasLength(ElementTier.values.length));
      }
    });
  });
}
