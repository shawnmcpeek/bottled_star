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
        GameMode.challenge =>
          'Preset starts. Limited shots. Coming soon.',
      };

  /// Separate high-score keys. Never merge these boards.
  String get scoreKey => 'highscore_$name';

  String get highestTierKey => 'highest_tier_$name';

  bool get isPlayable => this != GameMode.challenge;
}
