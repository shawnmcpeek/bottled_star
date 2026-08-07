enum GameMode { classic, collapse }

extension GameModeInfo on GameMode {
  String get label => switch (this) {
        GameMode.classic => 'Classic',
        GameMode.collapse => 'Collapse',
      };

  String get blurb => switch (this) {
        GameMode.classic =>
          'Fuse to iron. Let the star go quietly, or let it go loud.',
        GameMode.collapse => 'Every supernova leaves something behind.',
      };

  /// Separate high-score keys. Never merge these boards.
  String get scoreKey => 'highscore_$name';

  String get highestTierKey => 'highest_tier_$name';
}
