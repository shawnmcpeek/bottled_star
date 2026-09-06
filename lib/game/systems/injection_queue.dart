import 'dart:math';

import '../constants.dart';
import '../element_tier.dart';
import 'injection_source.dart';

/// Suika-style injection queue: unlock pool by highest element created this run,
/// keep H/He common so helium contention stays central. Never inject above
/// [GameConstants.maxInjectTier] and never inject Fe.
class InjectionQueue implements InjectionSource {
  InjectionQueue({Random? random}) : _rng = random ?? Random() {
    reset();
  }

  final Random _rng;

  @override
  late ElementTier current;
  @override
  late ElementTier next;
  int unlockedThrough = 0;

  /// Weighted Classic queue never runs dry.
  @override
  bool get isExhausted => false;

  @override
  void reset() {
    unlockedThrough = 0;
    current = ElementTier.hydrogen;
    next = ElementTier.hydrogen;
  }

  /// Expand the drop pool when the run creates a new highest element.
  @override
  void onHighestTier(int highestTier) {
    final capped = highestTier.clamp(0, GameConstants.maxInjectTier);
    if (capped > unlockedThrough) {
      unlockedThrough = capped;
    }
  }

  void restore({
    required ElementTier current,
    required ElementTier next,
    required int unlockedThrough,
  }) {
    this.current = current;
    this.next = next;
    this.unlockedThrough =
        unlockedThrough.clamp(0, GameConstants.maxInjectTier);
  }

  @override
  ElementTier consume() {
    final fired = current;
    current = next;
    next = _roll();
    return fired;
  }

  List<ElementTier> get pool {
    final maxTier = unlockedThrough.clamp(0, GameConstants.maxInjectTier);
    return [
      for (var t = 0; t <= maxTier; t++) ElementTier.fromTier(t),
    ];
  }

  /// Relative drop weights — H/He stay common.
  static int weightFor(ElementTier tier) {
    return switch (tier) {
      ElementTier.hydrogen => 10,
      ElementTier.helium => 7,
      ElementTier.carbon => 4,
      ElementTier.oxygen => 3,
      ElementTier.neon => 2,
      _ => 1,
    };
  }

  ElementTier _roll() {
    final options = pool;
    var total = 0;
    for (final tier in options) {
      total += weightFor(tier);
    }
    if (total <= 0) return ElementTier.hydrogen;

    var pick = _rng.nextInt(total);
    for (final tier in options) {
      pick -= weightFor(tier);
      if (pick < 0) return tier;
    }
    return options.last;
  }
}
