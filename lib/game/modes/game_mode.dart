import '../systems/purchases_controller.dart';

enum GameMode { classic, collapse, challenge }

extension GameModeInfo on GameMode {
  String get label => switch (this) {
        GameMode.classic => 'Classic',
        GameMode.collapse => 'Collapse',
        GameMode.challenge => 'Challenge',
      };

  String get blurb => switch (this) {
        GameMode.classic =>
          'Fuse to iron. Let the star go quietly, or let it go loud.',
        GameMode.collapse => 'Every supernova leaves something behind.',
        GameMode.challenge => 'Preset starts. Limited shots.',
      };

  /// Separate high-score keys. Never merge these boards.
  String get scoreKey => 'highscore_$name';

  String get highestTierKey => 'highest_tier_$name';

  /// Challenge requires the RevenueCat `challenge` entitlement (or the
  /// debug unlock override in PurchasesController). Locked players still see
  /// level-select — they buy what they can see.
  bool get isPlayable => switch (this) {
        GameMode.classic || GameMode.collapse => true,
        GameMode.challenge => PurchasesController.instance.hasChallenge,
      };
}
