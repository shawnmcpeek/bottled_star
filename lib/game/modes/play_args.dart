import 'package:flutter/foundation.dart';

import '../challenge/level_spec.dart';
import 'game_mode.dart';

/// Arguments for the `/play` route. Classic / Collapse still push a bare
/// [GameMode]; Challenge pushes this to carry the chosen [LevelSpec] too.
@immutable
class PlayArgs {
  const PlayArgs({
    required this.mode,
    this.challengeLevel,
    this.resumeSavedRun = false,
  });

  final GameMode mode;
  final LevelSpec? challengeLevel;

  /// Load the locally saved in-progress run for this mode / level.
  final bool resumeSavedRun;
}
