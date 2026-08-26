import 'package:flutter/foundation.dart';

import '../challenge/level_spec.dart';
import 'game_mode.dart';

/// Arguments for the `/play` route. Classic / Collapse still push a bare
/// [GameMode]; Challenge pushes this to carry the chosen [LevelSpec] too.
@immutable
class PlayArgs {
  const PlayArgs({required this.mode, this.challengeLevel});

  final GameMode mode;
  final LevelSpec? challengeLevel;
}
