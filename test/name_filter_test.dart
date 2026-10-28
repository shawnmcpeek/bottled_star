import 'package:bottled_star/game/systems/leaderboard_service.dart';
import 'package:bottled_star/game/systems/name_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NameFilter blocks', () {
    for (final name in [
      'fuck',
      'FuckFace',
      'f u c k',
      'fvck',
      'f.u.c.k',
      'fuuuuck',
      'sh1t',
      '5h!t',
      'xXbitchXx',
      'Big Ass',
      'asss',
      'a s s',
      'dick',
      'Hitler88',
      'n1gger',
      'kkk',
      'cvnt',
      'b00bs pussy',
    ]) {
      test(name, () => expect(NameFilter.isBlocked(name), isTrue));
    }
  });

  group('NameFilter allows', () {
    for (final name in [
      'Saki',
      'sakivoid',
      'Daddoo',
      'Classic Ace',
      'Bass Player',
      'As Above',
      'Dickens',
      'Peacock',
      'Grape Ape',
      'Therapist',
      'Spice',
      'Raccoon',
      'Torpedo',
      'Night Owl',
      'Basement',
      'Cockpit',
      'Kilonova',
      "Ada-1's Star",
      'K',
    ]) {
      test(name, () => expect(NameFilter.isAllowed(name), isTrue));
    }
  });

  test('displayNameError explains each refusal', () {
    expect(LeaderboardService.displayNameError('Saki'), isNull);
    expect(LeaderboardService.displayNameError(''), '1–16 characters');
    expect(
      LeaderboardService.displayNameError('a#b'),
      "Letters, numbers, spaces, . ' - _ only",
    );
    expect(
      LeaderboardService.displayNameError('sh1thead'),
      'Please choose a different name',
    );
    expect(LeaderboardService.sanitizeDisplayName('sh1thead'), isNull);
  });
}
