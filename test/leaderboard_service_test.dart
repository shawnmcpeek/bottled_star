import 'package:bottled_star/game/systems/leaderboard_service.dart';
import 'package:flutter_test/flutter_test.dart';

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
  });
}
