import 'package:bottled_star/game/modes/game_mode.dart';
import 'package:bottled_star/game/systems/achievement_defs.dart';
import 'package:bottled_star/game/systems/achievement_hooks.dart';
import 'package:bottled_star/game/systems/achievement_store.dart';
import 'package:bottled_star/game/systems/leaderboard_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LeaderboardService helpers', () {
    test('utcDayKey formats UTC calendar day', () {
      expect(
        LeaderboardService.utcDayKey(DateTime.utc(2026, 8, 6, 23, 59)),
        '2026-08-06',
      );
      expect(
        LeaderboardService.utcDayKey(DateTime.utc(2026, 1, 2, 0, 0)),
        '2026-01-02',
      );
    });

    test('sanitizeDisplayName trims and rejects empties', () {
      expect(LeaderboardService.sanitizeDisplayName('  Saki  '), 'Saki');
      expect(LeaderboardService.sanitizeDisplayName(''), null);
      expect(LeaderboardService.sanitizeDisplayName('   '), null);
      expect(
        LeaderboardService.sanitizeDisplayName('a' * 17),
        null,
      );
      expect(
        LeaderboardService.sanitizeDisplayName("Ada-1's Star"),
        "Ada-1's Star",
      );
    });

    test('collapseRankScore prefers more kilonovas then fewer shots', () {
      final a = LeaderboardService.collapseRankScore(kilonovas: 2, shots: 40);
      final b = LeaderboardService.collapseRankScore(kilonovas: 1, shots: 5);
      final c = LeaderboardService.collapseRankScore(kilonovas: 2, shots: 10);
      expect(a > b, isTrue);
      expect(c > a, isTrue);
    });

    test('mode collections are split', () {
      expect(
        LeaderboardService.allTimeCollection(GameMode.classic),
        'classic_all_time',
      );
      expect(
        LeaderboardService.allTimeCollection(GameMode.collapse),
        'collapse_all_time',
      );
      expect(
        LeaderboardService.dailyCollection(GameMode.classic),
        'classic_daily',
      );
      expect(
        LeaderboardService.dailyCollection(GameMode.collapse),
        'collapse_daily',
      );
    });

    test('LeaderboardEntry collapse label', () {
      const entry = LeaderboardEntry(
        rank: 1,
        displayName: 'Nova',
        uid: 'u1',
        mode: GameMode.collapse,
        kilonovas: 3,
        shots: 22,
      );
      expect(entry.valueLabel, 'K3 · 22 shots');
    });
  });

  group('AchievementStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('unlock is idempotent and persists', () async {
      final store = AchievementStore.instance;
      await store.load();
      expect(store.isUnlocked(AchievementId.firstFusion), isFalse);

      expect(await store.unlock(AchievementId.firstFusion), isTrue);
      expect(store.isUnlocked(AchievementId.firstFusion), isTrue);
      expect(await store.unlock(AchievementId.firstFusion), isFalse);

      final again = AchievementStore.instance;
      await again.load();
      expect(again.isUnlocked(AchievementId.firstFusion), isTrue);
    });

    test('hooks unlock fusion and iron', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AchievementStore.instance;
      await store.load();

      await AchievementHooks.onFusion(resultTier: 2);
      expect(store.isUnlocked(AchievementId.firstFusion), isTrue);
      expect(store.isUnlocked(AchievementId.reachIron), isFalse);

      await AchievementHooks.onFusion(resultTier: 10);
      expect(store.isUnlocked(AchievementId.reachIron), isTrue);
    });

    test('hooks unlock five kilonovas', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AchievementStore.instance;
      await store.load();

      await AchievementHooks.onKilonova(countThisRun: 1);
      expect(store.isUnlocked(AchievementId.firstKilonova), isTrue);
      expect(store.isUnlocked(AchievementId.fiveKilonovas), isFalse);

      await AchievementHooks.onKilonova(countThisRun: 5);
      expect(store.isUnlocked(AchievementId.fiveKilonovas), isTrue);
    });
  });
}
