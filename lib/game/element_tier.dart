import 'element_tuning.dart';
import 'modes/game_mode.dart';

enum ElementTier {
  hydrogen(0, 'H', 'Hydrogen', 14, 1, 0),
  helium(1, 'He', 'Helium', 18, 4, 1),
  carbon(2, 'C', 'Carbon', 23, 12, 3),
  oxygen(3, 'O', 'Oxygen', 28, 16, 6),
  neon(4, 'Ne', 'Neon', 34, 20, 10),
  magnesium(5, 'Mg', 'Magnesium', 41, 24, 15),
  silicon(6, 'Si', 'Silicon', 49, 28, 21),
  sulfur(7, 'S', 'Sulfur', 58, 32, 28),
  argon(8, 'Ar', 'Argon', 68, 40, 36),
  calcium(9, 'Ca', 'Calcium', 80, 40, 45),
  iron(10, 'Fe', 'Iron', 94, 56, 100),
  /// Seed-only hub. Not on the H→Fe ladder. Small, dense, helium-inert.
  lead(11, 'Pb', 'Lead', 40, 207, 0);

  const ElementTier(
    this.tier,
    this.symbol,
    this.displayName,
    this.baseRadius,
    this.atomicMass,
    this.scoreOnCreate,
  );

  final int tier;
  final String symbol;
  final String displayName;

  /// Unscaled table radius (Challenge seed layout uses this via [radiusFor]).
  final double baseRadius;
  final double atomicMass;
  final int scoreOnCreate;

  /// Gameplay collision / render radius for [mode], including scale.
  double radiusFor(GameMode mode) =>
      ElementTuning.tableRadiusForTier(tier) *
      ElementTuning.elementScaleFor(mode);

  /// Legacy alias — prefer [baseRadius] or [radiusFor].
  double get radius => baseRadius;

  bool get isHelium => this == ElementTier.helium;
  bool get isHydrogen => this == ElementTier.hydrogen;
  bool get isIron => this == ElementTier.iron;
  bool get isHub => this == ElementTier.lead;
  bool get isHeavy => !isHub && tier >= ElementTier.carbon.tier;

  double get relativeDensity =>
      atomicMass / 4.0; // reference = helium

  /// Fixture density for Box2D — compressed into a 4× band.
  double get fixtureDensity {
    if (isHub) return 4.0;
    final t = tier / ElementTier.iron.tier;
    return 1.0 + t * 3.0;
  }

  static ElementTier fromTier(int tier) => ElementTier.values[tier];

  /// Reverse lookup by periodic symbol (`'Si'`, not `'silicon'`).
  static ElementTier? fromSymbol(String symbol) {
    for (final e in ElementTier.values) {
      if (e.symbol == symbol) return e;
    }
    return null;
  }

  /// Same-tier fusion (skips two rungs). Mg/S/Ar/Ca same-tier stay inert.
  /// H+H and He+He live here too so one table owns all self-pairs.
  static const Map<ElementTier, ElementTier> sameTierMerges = {
    ElementTier.hydrogen: ElementTier.helium,
    ElementTier.helium: ElementTier.carbon,
    ElementTier.carbon: ElementTier.magnesium,
    ElementTier.oxygen: ElementTier.sulfur,
    ElementTier.neon: ElementTier.calcium,
    ElementTier.silicon: ElementTier.iron,
  };

  static bool isSameTierMerge(ElementTier a, ElementTier b) =>
      a == b && sameTierMerges.containsKey(a);

  static ElementTier? heliumCapture(ElementTier other) {
    if (other.isHub || other.isIron || !other.isHeavy) return null;
    final next = other.tier + 1;
    if (next > ElementTier.iron.tier) return null;
    return ElementTier.fromTier(next);
  }

  /// Lower resolves first when several legal pairs touch in one step.
  ///
  /// Heavy same-tier (C+C and up) still beats helium capture. Fuel same-tier
  /// (H+H, He+He) does **not** — two heliums on a post must climb it, not
  /// become carbon and steal both.
  static int mergeResolvePriority(ElementTier a, ElementTier b) {
    if (a == b && a.isHeavy && sameTierMerges.containsKey(a)) return 0;
    final capture = a.isHelium ? heliumCapture(b) : b.isHelium ? heliumCapture(a) : null;
    if (capture != null) return 1;
    return 2;
  }

  /// Returns the product of a legal merge, or null if inert.
  ///
  /// [allowSameTier] false is Challenge `noSameTier`: heavy self-pairs
  /// (C+C and up) are inert. H+H and He+He stay legal — those are fuel, not
  /// ladder skips. Pass via argument — never mutate static state.
  static ElementTier? mergeResult(
    ElementTier a,
    ElementTier b, {
    bool allowSameTier = true,
  }) {
    if (a == b) {
      if (!allowSameTier && a.isHeavy) return null;
      return sameTierMerges[a];
    }

    if (a.isHelium) return heliumCapture(b);
    if (b.isHelium) return heliumCapture(a);
    return null;
  }

  static bool isInertCollision(
    ElementTier a,
    ElementTier b, {
    bool allowSameTier = true,
  }) =>
      mergeResult(a, b, allowSameTier: allowSameTier) == null;
}
