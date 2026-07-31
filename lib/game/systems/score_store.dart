import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

class ScoreStore {
  int highScore = 0;
  int highestTier = 0;
  int totalRuns = 0;
  RunEnding? lastEnding;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    highScore = prefs.getInt(GameConstants.prefsHighScore) ?? 0;
    highestTier = prefs.getInt(GameConstants.prefsHighestTier) ?? 0;
    totalRuns = prefs.getInt(GameConstants.prefsTotalRuns) ?? 0;
    lastEnding =
        RunEnding.fromPrefs(prefs.getString(GameConstants.prefsLastEnding));
  }

  Future<void> recordRun({
    required int score,
    required int highestTierReached,
    required RunEnding ending,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    totalRuns += 1;
    lastEnding = ending;

    if (score > highScore) {
      highScore = score;
    }
    if (highestTierReached > highestTier) {
      highestTier = highestTierReached;
    }

    await prefs.setInt(GameConstants.prefsTotalRuns, totalRuns);
    await prefs.setInt(GameConstants.prefsHighScore, highScore);
    await prefs.setInt(GameConstants.prefsHighestTier, highestTier);
    await prefs.setString(GameConstants.prefsLastEnding, ending.prefsValue);
  }
}
