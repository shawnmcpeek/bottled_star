import 'dart:math';

import '../constants.dart';
import '../element_tier.dart';
import 'message_bag.dart';

class EndingMessagePick {
  const EndingMessagePick({required this.id, required this.text});

  final String id;
  final String text;
}

class EndingMessageContext {
  const EndingMessageContext({
    required this.ending,
    required this.peakTier,
    required this.score,
    required this.previousHighScore,
    required this.tiersCreatedThisRun,
  });

  final RunEnding ending;
  final int peakTier;
  final int score;
  final int previousHighScore;
  final Set<int> tiersCreatedThisRun;
}

/// Catalog + selection for the single variable line on the ending card.
abstract final class EndingMessages {
  static const milestoneOrder = [
    'first_carbon',
    'first_silicon',
    'first_iron',
    'first_supernova',
    'first_white_dwarf',
    'new_best',
    'full_ladder',
  ];

  static const milestones = <String, String>{
    'first_carbon':
        'Carbon forms three heliums at a time, in a reaction so unlikely it was predicted only because we exist to ask about it.',
    'first_silicon':
        'Silicon and oxygen are most of the rock beneath you. Sand, glass, and the chip in your phone.',
    'first_iron':
        'Iron is where fusion stops paying. Everything past this point costs a star its life.',
    'first_supernova':
        'A supernova can briefly outshine every other star in its galaxy combined.',
    'first_white_dwarf':
        'No white dwarf has finished cooling. The universe has not been around long enough.',
    'new_best': 'Best run yet.',
    'full_ladder':
        'Every element on the ladder, in one star. Stars take about ten million years to do that.',
  };

  static const supernovaPool = [
    "Ninety-nine percent of a supernova's energy leaves as neutrinos. The light is the rounding error.",
    'The 1054 supernova was visible in daylight for 23 days. The Crab Nebula is what is left.',
    'The collapse takes less than a second. The core falls at roughly a quarter the speed of light.',
    'Gold cannot be made by fusion. It takes an event like this one, or two neutron stars colliding.',
    'The shockwave compresses nearby gas clouds and triggers new stars. The ending is also a beginning.',
    'A collapsing core briefly reaches temperatures where iron is torn back apart into helium.',
    'What remains is a neutron star. A teaspoon of it would weigh about as much as a mountain.',
  ];

  static const whiteDwarfPool = [
    'No white dwarf has finished cooling. The universe has not existed long enough for one to go dark.',
    'The sun will end this way, in about five billion years.',
    'A white dwarf is roughly the mass of a star packed into the volume of a planet.',
    'The shed envelope is called a planetary nebula, named by an astronomer who mistook one for a planet.',
    'Most stars end here. Only the massive ones reach iron.',
    'A white dwarf no longer fuses anything. It is a cooling ember with no fuel left.',
  ];

  static const elementPools = <int, List<String>>{
    // Helium
    1: [
      'Helium was found in the sun before it was found on Earth. It is named for Helios.',
      'Helium is the only element that will not freeze solid under its own pressure, no matter how cold it gets.',
    ],
    // Carbon
    2: [
      'Carbon forms three heliums at a time. The middle step falls apart in a fraction of a nanosecond.',
      'Every carbon atom in you was assembled inside a star that died before the sun existed.',
      'Carbon bonds with itself more readily than any other element. That is why there is an entire branch of chemistry named after it.',
    ],
    // Oxygen
    3: [
      'Oxygen is the third most abundant element in the universe and most of the mass of the ocean.',
      'The oxygen in a single breath was made in the cores of several different stars.',
    ],
    // Neon
    4: [
      'Neon burning is not really burning. Gamma rays knock a helium loose and a neighbour catches it.',
      'Neon is almost perfectly unreactive. It has never been persuaded into a stable compound.',
    ],
    // Magnesium
    5: [
      'There is a magnesium atom at the centre of every chlorophyll molecule. Green is what magnesium looks like at scale.',
      'Magnesium burns hot enough that water makes it worse.',
    ],
    // Silicon
    6: [
      'Silicon and oxygen make up most of the rock beneath you. Sand, glass, and the chip in your phone.',
      'A star burns through its silicon in about a day. Every earlier stage took years or millennia.',
    ],
    // Sulfur
    7: [
      'Sulfur is one of the few elements known to antiquity by itself. It was called brimstone.',
      'Sulfur compounds are why garlic, onions and skunks are all difficult to ignore.',
    ],
    // Argon
    8: [
      'Argon is the third most common gas in the air you are breathing and does essentially nothing.',
      "Almost all of Earth's argon is the decay product of potassium, not the kind stars make.",
    ],
    // Calcium
    9: [
      'You are carrying about a kilogram of stellar calcium in your skeleton.',
      'Calcium is what makes bone, shell, chalk and limestone. Most of it passed through a supernova first.',
    ],
    // Iron
    10: [
      'Iron is where fusion stops paying. Every atom past this point cost the universe a dying star.',
      'Iron-56 is the most tightly bound nucleus there is. Nothing releases energy by making it heavier.',
      'The iron in your blood was forged in a star and delivered by an explosion.',
    ],
  };

  static String endingPoolKey(RunEnding ending) =>
      ending == RunEnding.supernova ? 'ending_supernova' : 'ending_white_dwarf';

  static String elementPoolKey(int tier) => 'element_$tier';

  static List<String> endingLines(RunEnding ending) =>
      ending == RunEnding.supernova ? supernovaPool : whiteDwarfPool;

  static String? milestoneFor(
    EndingMessageContext ctx,
    Set<String> fired,
  ) {
    for (final id in milestoneOrder) {
      if (fired.contains(id)) continue;
      if (_milestoneMet(id, ctx)) return id;
    }
    return null;
  }

  static bool _milestoneMet(String id, EndingMessageContext ctx) {
    switch (id) {
      case 'first_carbon':
        return ctx.peakTier >= ElementTier.carbon.tier;
      case 'first_silicon':
        return ctx.peakTier >= ElementTier.silicon.tier;
      case 'first_iron':
        return ctx.peakTier >= ElementTier.iron.tier;
      case 'first_supernova':
        return ctx.ending == RunEnding.supernova;
      case 'first_white_dwarf':
        return ctx.ending == RunEnding.whiteDwarf;
      case 'new_best':
        return ctx.score > ctx.previousHighScore;
      case 'full_ladder':
        return ctx.tiersCreatedThisRun.length >= ElementTier.values.length &&
            ElementTier.values.every(
              (t) => ctx.tiersCreatedThisRun.contains(t.tier),
            );
      default:
        return false;
    }
  }

  /// Priority: milestone → 40% ending pool → element pool.
  /// Avoids repeating [lastMessageId] once when possible.
  static EndingMessagePick select({
    required EndingMessageContext ctx,
    required Set<String> firedMilestones,
    required Map<String, Set<int>> bagSeen,
    String? lastMessageId,
    Random? random,
  }) {
    final rng = random ?? Random();

    final milestoneId = milestoneFor(ctx, firedMilestones);
    if (milestoneId != null) {
      firedMilestones.add(milestoneId);
      return EndingMessagePick(
        id: 'milestone:$milestoneId',
        text: milestones[milestoneId]!,
      );
    }

    if (rng.nextDouble() < 0.4) {
      return _drawPool(
        key: endingPoolKey(ctx.ending),
        lines: endingLines(ctx.ending),
        bagSeen: bagSeen,
        lastMessageId: lastMessageId,
        rng: rng,
      );
    }

    final elementLines = elementPools[ctx.peakTier];
    if (elementLines != null && elementLines.isNotEmpty) {
      return _drawPool(
        key: elementPoolKey(ctx.peakTier),
        lines: elementLines,
        bagSeen: bagSeen,
        lastMessageId: lastMessageId,
        rng: rng,
      );
    }

    // Peak hydrogen (or missing pool): fall back to ending lines.
    return _drawPool(
      key: endingPoolKey(ctx.ending),
      lines: endingLines(ctx.ending),
      bagSeen: bagSeen,
      lastMessageId: lastMessageId,
      rng: rng,
    );
  }

  static EndingMessagePick _drawPool({
    required String key,
    required List<String> lines,
    required Map<String, Set<int>> bagSeen,
    required String? lastMessageId,
    required Random rng,
  }) {
    final bag = MessageBag(lines, bagSeen[key]);
    var pick = bag.drawIndexed(rng);
    var id = '$key:${pick.index}';

    if (lastMessageId != null && id == lastMessageId && lines.length > 1) {
      pick = bag.drawIndexed(rng);
      id = '$key:${pick.index}';
    }

    bagSeen[key] = {...bag.seen};
    return EndingMessagePick(id: id, text: pick.text);
  }
}
