import 'dart:math';

import '../../game/systems/message_bag.dart';

/// Milestone lines fire exactly once, ever, and take priority over the pool.
abstract final class KilonovaMessages {
  static const milestoneOrder = [
    'first_kilonova',
    'five_kilonovas',
    'quiet_ending_first',
  ];

  static const milestones = <String, String>{
    'first_kilonova':
        'Two dead stars found each other. What came out was gold — the first gold, '
            'made the only way gold is ever made.',
    'five_kilonovas':
        'Five times you drove the dark together and made something that outlasts stars.',
    'quiet_ending_first':
        'You stopped while the chamber still held. Not every star has to die badly.',
  };

  static const messages = <int, List<String>>{
    1: [
      'Three irons for one collision. The universe pays the same price.',
      'Everything heavier than iron was made like this. Now some of it is yours.',
      'The blast did what gravity never could — it introduced them.',
      'One kilonova. Platinum, gold, and a chamber you can almost work in again.',
      'Two remnants, one impact, and the heaviest light you will ever see.',
    ],
    2: [
      'Twice now. The core remembers both, and it is running out of room to forget.',
      'You are getting good at aiming an explosion at something that cannot be aimed at.',
      'Two kilonovas and the leftovers of four dead stars, still sitting there.',
      'The second is harder than the first. It will keep being true.',
      'Gold twice over, and a chamber that is mostly graveyard now.',
    ],
    3: [
      'Three. At this point the empty space is the achievement.',
      'Nine irons, six remnants, three collisions. The arithmetic of a very long run.',
      'You have been using supernovae as a tool for a while now.',
      'The core is crowded with things that will not move and cannot burn. You made room anyway.',
      'Three kilonovas deep, and every one of them was a decision rather than a gift.',
    ],
    5: [
      'Five. There is barely a chamber left, and you were still steering.',
      'The bottle is more remnant than star. It has been for some time.',
      'Most runs end with iron. Yours ended with a periodic table.',
      'You stopped treating the dead mass as a problem and started treating it as material.',
      'Five collisions, and the room to make them got smaller every time.',
    ],
    8: [
      'Eight kilonovas. Whatever this is, it stopped being a star a long time ago.',
      'You have manufactured more gold than most galaxies manage in a good century.',
      'The chamber is a wall of dead cores and you found gaps in it eight times.',
      'At some point skill stops being the word for it.',
      'Eight. The dark kept accumulating and you kept finding the angle.',
    ],
  };

  static List<String> poolFor(int kilonovaCount) {
    final keys = messages.keys.toList()..sort();
    final bucket =
        keys.lastWhere((k) => k <= kilonovaCount, orElse: () => keys.first);
    return messages[bucket]!;
  }

  static String poolKey(int kilonovaCount) {
    final keys = messages.keys.toList()..sort();
    final bucket =
        keys.lastWhere((k) => k <= kilonovaCount, orElse: () => keys.first);
    return 'ending_kilonova_$bucket';
  }

  static String? milestoneFor({
    required int kilonovaCount,
    required bool voluntaryEnd,
    required Set<String> fired,
  }) {
    for (final id in milestoneOrder) {
      if (fired.contains(id)) continue;
      final met = switch (id) {
        'first_kilonova' => kilonovaCount >= 1,
        'five_kilonovas' => kilonovaCount >= 5,
        'quiet_ending_first' => voluntaryEnd,
        _ => false,
      };
      if (met) return id;
    }
    return null;
  }

  static ({String id, String text}) drawPool({
    required int kilonovaCount,
    required Map<String, Set<int>> bagSeen,
    required Random rng,
    String? lastMessageId,
  }) {
    final lines = poolFor(kilonovaCount);
    final key = poolKey(kilonovaCount);
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
