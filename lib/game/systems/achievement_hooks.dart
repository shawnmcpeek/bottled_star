import '../element_tier.dart';
import 'achievement_defs.dart';
import 'achievement_store.dart';

/// Fire-and-forget unlock helpers used from gameplay systems.
abstract final class AchievementHooks {
  static Future<void> onFusion({required int resultTier}) async {
    await AchievementStore.instance.unlock(AchievementId.firstFusion);
    if (resultTier >= ElementTier.iron.tier) {
      await AchievementStore.instance.unlock(AchievementId.reachIron);
    }
  }

  static Future<void> onSupernovaBlast() async {
    await AchievementStore.instance.unlock(AchievementId.firstSupernova);
  }

  static Future<void> onKilonova({required int countThisRun}) async {
    await AchievementStore.instance.unlock(AchievementId.firstKilonova);
    if (countThisRun >= 5) {
      await AchievementStore.instance.unlock(AchievementId.fiveKilonovas);
    }
  }

  static Future<void> onQuietEnd() async {
    await AchievementStore.instance.unlock(AchievementId.quietEnd);
  }

  static Future<void> onSupernovaEnding() async {
    await AchievementStore.instance.unlock(AchievementId.firstSupernova);
  }

  static Future<void> onPeakTier(int peakTier) async {
    if (peakTier >= ElementTier.iron.tier) {
      await AchievementStore.instance.unlock(AchievementId.reachIron);
    }
  }

  static Future<void> onBoardPosted() async {
    await AchievementStore.instance.unlock(AchievementId.postAScore);
  }
}
