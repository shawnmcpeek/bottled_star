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
  iron(10, 'Fe', 'Iron', 94, 56, 100);

  const ElementTier(
    this.tier,
    this.symbol,
    this.displayName,
    this.radius,
    this.atomicMass,
    this.scoreOnCreate,
  );

  final int tier;
  final String symbol;
  final String displayName;
  final double radius;
  final double atomicMass;
  final int scoreOnCreate;

  bool get isHelium => this == ElementTier.helium;
  bool get isHydrogen => this == ElementTier.hydrogen;
  bool get isIron => this == ElementTier.iron;
  bool get isHeavy => tier >= ElementTier.carbon.tier;

  double get relativeDensity =>
      atomicMass / 4.0; // reference = helium

  /// Fixture density for Box2D — compressed into a 4× band.
  double get fixtureDensity {
    final t = tier / ElementTier.iron.tier;
    return 1.0 + t * 3.0;
  }

  static ElementTier fromTier(int tier) => ElementTier.values[tier];

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
    if (!other.isHeavy || other.isIron) return null;
    final next = other.tier + 1;
    if (next > ElementTier.iron.tier) return null;
    return ElementTier.fromTier(next);
  }

  /// Returns the product of a legal merge, or null if inert.
  ///
  /// Precedence: same-tier self-pair before helium capture when both apply
  /// across different contacts — callers must sort candidate pairs accordingly.
  static ElementTier? mergeResult(ElementTier a, ElementTier b) {
    if (a == b) return sameTierMerges[a];

    if (a.isHelium) return heliumCapture(b);
    if (b.isHelium) return heliumCapture(a);
    return null;
  }

  static bool isInertCollision(ElementTier a, ElementTier b) =>
      mergeResult(a, b) == null;
}
