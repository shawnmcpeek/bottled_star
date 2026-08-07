import 'dart:math';

import '../../game/systems/message_bag.dart';

/// Milestone lines fire exactly once, ever, and take priority over the pool.
abstract final class BlackHoleMessages {
  static const milestoneOrder = [
    'first_black_hole',
    'survived_ten',
    'no_consumption',
  ];

  static const milestones = <String, String>{
    'first_black_hole':
        'The core stopped pushing back. Everything you built went in after it.',
    'survived_ten':
        'Ten stars died to make this. It was never going to be satisfied.',
    'no_consumption':
        'It never ate a single nucleus. It simply grew until there was no room left for you.',
  };

  static const messages = <int, List<String>>{
    1: [
      'One collapse was enough. The iron came, the light left, and the dark stayed.',
      'You reached the end of the ladder and found there was another rung below it.',
      'It formed in a second and took everything at its leisure.',
      'The star had one death in it. What it left had more patience than you did.',
      'Nothing you added after the iron was ever really yours.',
    ],
    2: [
      'Twice the core gave out. The second time it did not stop falling.',
      'You fed it a star, then fed it another, and it learned the shape of your hand.',
      'Two collapses. The remnant kept the difference.',
      'The second blast bought you room. The dark took the room back.',
      'It was heavier than the sum of what you gave it. That is how these things work.',
    ],
    3: [
      'Three stars, and the pressure that kept you alive finally guttered out.',
      'You held the line at the rim while the centre quietly stopped radiating.',
      'The moat closed. Everything that drifted inward arrived.',
      'Each collapse was a reprieve you paid for twice over.',
      'You knew what you were building. You built it anyway, and well.',
      'By the third, the glow was gone and the falling was silent.',
    ],
    5: [
      'Five deaths deep, and the thing at the centre had stopped being a star at all.',
      'You outlasted the light by a considerable margin.',
      'The chamber belonged to it long before the last piece fell.',
      'Every supernova you triggered was a debt. This is the ledger closing.',
      'It ate the bottle from the inside and you kept the rim clean to the end.',
      'A long run, measured in collapses. Very few get to see the horizon this wide.',
    ],
    8: [
      'Eight collapses. At some point you were no longer keeping a star alive — you were feeding something else.',
      'The bottle is full of nothing now, and the nothing is very heavy.',
      'You pushed it past every limit that had a name. It found one that did not.',
      'There is no element after this. There is only the mass and what it wants.',
      'A star that dies once is unlucky. A star that dies eight times was being farmed.',
      'You did not lose the chamber. You were simply outlived by what was in it.',
    ],
  };

  /// Bucket resolution — floor to the nearest defined key.
  static List<String> poolFor(int supernovaCount) {
    final keys = messages.keys.toList()..sort();
    final bucket =
        keys.lastWhere((k) => k <= supernovaCount, orElse: () => keys.first);
    return messages[bucket]!;
  }

  static String poolKey(int supernovaCount) {
    final keys = messages.keys.toList()..sort();
    final bucket =
        keys.lastWhere((k) => k <= supernovaCount, orElse: () => keys.first);
    return 'ending_black_hole_$bucket';
  }

  static String? milestoneFor({
    required int supernovaCount,
    required int consumedCount,
    required Set<String> fired,
  }) {
    for (final id in milestoneOrder) {
      if (fired.contains(id)) continue;
      final met = switch (id) {
        'first_black_hole' => true,
        'survived_ten' => supernovaCount >= 10,
        'no_consumption' => consumedCount == 0,
        _ => false,
      };
      if (met) return id;
    }
    return null;
  }

  static ({String id, String text}) drawPool({
    required int supernovaCount,
    required Map<String, Set<int>> bagSeen,
    required Random rng,
    String? lastMessageId,
  }) {
    final lines = poolFor(supernovaCount);
    final key = poolKey(supernovaCount);
    final bag = MessageBag(lines, bagSeen[key]);
    var pick = bag.drawIndexed(rng);
    var id = '$key:${pick.index}';

    if (lastMessageId != null && id == lastMessageId && lines.length > 1) {
      pick = bag.drawIndexed(rng);
      id = '$key:${pick.index}';
    }

    bagSeen[key] = {...bag.seen};
    return (id: id, text: pick.text);
  }
}
