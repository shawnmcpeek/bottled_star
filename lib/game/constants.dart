import 'dart:ui';

/// Physics and gameplay constants from the locked design doc.
abstract final class GameConstants {
  static const double chamberRadius = 320;
  static const int chamberSegments = 72;

  static const double gravityStrength = 40;
  static const double referenceAtomicMass = 4;

  static const double restitution = 0.15;
  static const double friction = 0.35;
  static const double linearDamping = 0.4;
  static const double angularDamping = 0.5;

  static const double injectionPowerMin = 300;
  static const double injectionPowerMax = 900;
  static const double injectorCooldownSeconds = 0.4;
  static const double chargeSeconds = 0.85;
  static const double injectorOrbitGap = 28;

  /// Geometric rim contact slack (world units).
  static const double rimContactEpsilon = 1.0;

  /// Rim pressure accumulator — fill > drain so jitter still accumulates.
  static const double kRimFillRate = 1.0;
  static const double kRimDrainRate = 0.6;
  static const double kRimPressureLimit = 2.0;

  static const double inertBumpImpulse = 180;
  static const double mergePairCooldown = 0.05;
  static const double mergeContactEpsilon = 2.0;

  /// Highest tier that can appear in the injector (neon). Never Fe / Ca / etc.
  static const int maxInjectTier = 4; // ElementTier.neon

  /// Iron+iron supernova (mid-run detonation).
  static const double kSupernovaContactEpsilon = 2.0;
  /// Outer-zone push. Design doc lists 30 for unit-mass toys; Forge2D fixture
  /// masses need ~12000 for a comparable Δv. Raise until crowded-rim blasts
  /// can lose the run.
  static const double kBlastImpulse = 12000.0;
  /// Inner vaporize zone base radius (0.35 × chamber). Tune first.
  static const double kVaporizeRadius = 112.0;
  /// Outer blast reach base radius (0.75 × chamber).
  static const double kBlastRadius = 240.0;
  /// Seconds for the shell to expand to [kBlastRadius].
  static const double kShellDuration = 0.4;
  /// Angular lobe strength: 0 = uniform, 0.9 = extreme.
  static const double kAsymmetry = 0.5;
  /// Fraction of [ElementTier.scoreOnCreate] awarded when vaporized.
  static const double kEjectCredit = 0.25;
  /// Probabilistic band width around the vaporize boundary (±).
  static const double kSoftEdge = 0.2;
  static const int kSupernovaScore = 500;
  static const double kSupernovaLockoutSeconds = 0.6;
  static const double kSupernovaFlashSeconds = 0.12;
  static const double kSupernovaShakeSeconds = 0.5;

  // Ending timings
  static const double endingSkipAfterSeconds = 1.5;
  static const double whiteDwarfHold = 0.8;
  static const double whiteDwarfVent = 3.5;
  static const double whiteDwarfRemnant = 1.5;
  static const double supernovaCompress = 0.5;
  static const double supernovaDetonate = 0.15;
  static const double supernovaExpand = 1.2;
  static const double supernovaSeed = 3.0;

  static const String prefsHighScore = 'high_score';
  static const String prefsHighestTier = 'highest_tier';
  static const String prefsTotalRuns = 'total_runs';
  static const String prefsLastEnding = 'last_ending';
  static const String prefsFiredMilestones = 'fired_milestones';
  static const String prefsMessageBags = 'message_bags';
  static const String prefsLastMessageId = 'last_message_id';
  static const String prefsHowToPlaySeen = 'how_to_play_seen';
  static const String prefsSoundEnabled = 'sound_enabled';
  static const String prefsSfxEnabled = 'sfx_enabled';
  static const String prefsMusicVolume = 'music_volume';
  static const String prefsSfxVolume = 'sfx_volume';
  static const String prefsHapticsEnabled = 'haptics_enabled';
  static const String prefsDisplayName = 'display_name';
  static const String prefsLastMusicIndex = 'last_music_index';
}

enum RunEnding {
  whiteDwarf,
  supernova,
  kilonova;

  String get prefsValue => name;
  static RunEnding? fromPrefs(String? value) {
    if (value == null) return null;
    // Migrate abandoned Collapse ending name.
    if (value == 'blackHole') return RunEnding.kilonova;
    for (final e in RunEnding.values) {
      if (e.name == value) return e;
    }
    return null;
  }
}

/// Cool-toned seed symbols for the supernova ending (never on the ladder).
abstract final class SeedElements {
  static const prioritized = [
    'Au', 'Ag', 'Pt', 'U', 'Cu', 'I',
    'Co', 'Ni', 'Zn', 'Se', 'Br', 'Sr',
    'Zr', 'Sn', 'Ba', 'Pb',
  ];

  static const colors = [
    Color(0xFF9EC8FF),
    Color(0xFFB8D4FF),
    Color(0xFF7EB6E8),
    Color(0xFFC9E0FF),
    Color(0xFF8FA8D8),
    Color(0xFFA8C4F0),
  ];
}
