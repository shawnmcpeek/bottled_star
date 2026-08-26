import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../constants.dart';
import '../element_tier.dart';
import 'fixed_queue.dart';

/// Thrown when a pack or level fails strict validation.
class LevelParseException implements Exception {
  LevelParseException(this.message, {this.levelId});

  final String message;
  final String? levelId;

  @override
  String toString() {
    if (levelId == null) return 'LevelParseException: $message';
    return 'LevelParseException ($levelId): $message';
  }
}

/// Angle convention matches [Injector.orbitAngle] / `atan2(y, x)`:
/// 0° = chamber right (+X), increasing counter-clockwise (90° = +Y / up).
@immutable
class LevelSpec {
  const LevelSpec({
    required this.id,
    required this.name,
    this.blurb,
    required this.seed,
    this.injectionArc,
    required this.queue,
    required this.budgetShots,
    required this.goals,
    required this.constraints,
    required this.rules,
    required this.parShots,
    required this.pack,
  });

  final String id;
  final String name;
  final String? blurb;
  final SeedSpec seed;
  final InjectionArcSpec? injectionArc;
  final QueueSpec queue;
  final int budgetShots;
  final List<LevelGoal> goals;
  final List<LevelConstraint> constraints;
  final LevelRules rules;
  final int parShots;
  final int pack;

  bool get noSameTier =>
      constraints.any((c) => c is NoSameTierConstraint);

  bool get remnantsEnabled => rules.remnants;

  FixedInjectionQueue createQueue() => queue.toFixedQueue();

  /// Resolved starting nuclei. Prefer [seed.baked] when present.
  List<ResolvedBody> resolveSeed({
    double chamberRadius = GameConstants.chamberRadius,
  }) =>
      seed.resolve(chamberRadius: chamberRadius);

  factory LevelSpec.fromJson(
    Map<String, dynamic> json, {
    required int pack,
    String? levelIdHint,
  }) {
    final id = _reqString(json, 'id', levelId: levelIdHint);
    try {
      final name = _reqString(json, 'name', levelId: id);
      final blurb = json['blurb'] is String ? json['blurb'] as String : null;

      final seedRaw = json['seed'];
      if (seedRaw is! Map) {
        throw LevelParseException('seed must be an object', levelId: id);
      }
      final seed = SeedSpec.fromJson(
        Map<String, dynamic>.from(seedRaw),
        levelId: id,
      );

      InjectionArcSpec? injectionArc;
      final arcRaw = json['injectionArc'];
      if (arcRaw != null) {
        if (arcRaw is! Map) {
          throw LevelParseException(
            'injectionArc must be an object',
            levelId: id,
          );
        }
        injectionArc = InjectionArcSpec.fromJson(
          Map<String, dynamic>.from(arcRaw),
          levelId: id,
        );
      }

      final queueRaw = json['queue'];
      if (queueRaw is! Map) {
        throw LevelParseException('queue must be an object', levelId: id);
      }
      final queue = QueueSpec.fromJson(
        Map<String, dynamic>.from(queueRaw),
        levelId: id,
      );

      final budgetRaw = json['budget'];
      if (budgetRaw is! Map) {
        throw LevelParseException('budget must be an object', levelId: id);
      }
      final budgetShots = _reqInt(
        Map<String, dynamic>.from(budgetRaw),
        'shots',
        levelId: id,
      );
      if (budgetShots < 1) {
        throw LevelParseException('budget.shots must be >= 1', levelId: id);
      }

      final goalsRaw = json['goals'];
      if (goalsRaw is! List || goalsRaw.isEmpty) {
        throw LevelParseException(
          'goals must be a non-empty array',
          levelId: id,
        );
      }
      final goals = [
        for (final g in goalsRaw)
          LevelGoal.fromJson(_asMap(g, 'goal', levelId: id), levelId: id),
      ];

      final constraintsRaw = json['constraints'];
      if (constraintsRaw is! List) {
        throw LevelParseException(
          'constraints must be an array',
          levelId: id,
        );
      }
      final constraints = [
        for (final c in constraintsRaw)
          LevelConstraint.fromJson(
            _asMap(c, 'constraint', levelId: id),
            levelId: id,
          ),
      ];

      LevelRules rules = const LevelRules();
      final rulesRaw = json['rules'];
      if (rulesRaw != null) {
        if (rulesRaw is! Map) {
          throw LevelParseException('rules must be an object', levelId: id);
        }
        rules = LevelRules.fromJson(
          Map<String, dynamic>.from(rulesRaw),
          levelId: id,
        );
      }

      final parRaw = json['par'];
      if (parRaw is! Map) {
        throw LevelParseException('par must be an object', levelId: id);
      }
      final parShots = _reqInt(
        Map<String, dynamic>.from(parRaw),
        'shots',
        levelId: id,
      );
      if (parShots < 1) {
        throw LevelParseException('par.shots must be >= 1', levelId: id);
      }
      if (parShots > budgetShots) {
        throw LevelParseException(
          'par.shots ($parShots) > budget.shots ($budgetShots)',
          levelId: id,
        );
      }

      if (queue.sequence.length < budgetShots) {
        throw LevelParseException(
          'sequence.length (${queue.sequence.length}) < budget.shots '
          '($budgetShots)',
          levelId: id,
        );
      }

      return LevelSpec(
        id: id,
        name: name,
        blurb: blurb,
        seed: seed,
        injectionArc: injectionArc,
        queue: queue,
        budgetShots: budgetShots,
        goals: goals,
        constraints: constraints,
        rules: rules,
        parShots: parShots,
        pack: pack,
      );
    } on LevelParseException {
      rethrow;
    } catch (e) {
      throw LevelParseException(e.toString(), levelId: id);
    }
  }
}

@immutable
class SeedSpec {
  const SeedSpec({required this.bodies, this.baked});

  final List<SeedBodySpec> bodies;
  final List<BakedBody>? baked;

  factory SeedSpec.fromJson(Map<String, dynamic> json, {String? levelId}) {
    final bodiesRaw = json['bodies'];
    if (bodiesRaw is! List) {
      throw LevelParseException('seed.bodies must be an array', levelId: levelId);
    }
    final bodies = [
      for (final b in bodiesRaw)
        SeedBodySpec.fromJson(
          _asMap(b, 'seed body', levelId: levelId),
          levelId: levelId,
        ),
    ];

    List<BakedBody>? baked;
    final bakedRaw = json['baked'];
    if (bakedRaw != null) {
      if (bakedRaw is! List) {
        throw LevelParseException(
          'seed.baked must be an array or null',
          levelId: levelId,
        );
      }
      baked = [
        for (final b in bakedRaw)
          BakedBody.fromJson(
            _asMap(b, 'baked body', levelId: levelId),
            levelId: levelId,
          ),
      ];
    }

    return SeedSpec(bodies: bodies, baked: baked);
  }

  /// If [baked] is non-null it is used verbatim and [bodies] is ignored.
  List<ResolvedBody> resolve({
    double chamberRadius = GameConstants.chamberRadius,
  }) {
    final frozen = baked;
    if (frozen != null) {
      return [
        for (final b in frozen)
          ResolvedBody(
            element: b.element,
            x: b.x,
            y: b.y,
            angle: b.angle,
          ),
      ];
    }
    return [
      for (final spec in bodies)
        ...spec.expand(chamberRadius: chamberRadius),
    ];
  }
}

@immutable
class BakedBody {
  const BakedBody({
    required this.element,
    required this.x,
    required this.y,
    required this.angle,
  });

  final ElementTier element;
  final double x;
  final double y;
  final double angle;

  factory BakedBody.fromJson(Map<String, dynamic> json, {String? levelId}) {
    return BakedBody(
      element: _reqElement(json, 'element', levelId: levelId),
      x: _reqDouble(json, 'x', levelId: levelId),
      y: _reqDouble(json, 'y', levelId: levelId),
      angle: _reqDouble(json, 'angle', levelId: levelId),
    );
  }
}

@immutable
class ResolvedBody {
  const ResolvedBody({
    required this.element,
    required this.x,
    required this.y,
    this.angle = 0,
  });

  final ElementTier element;
  final double x;
  final double y;
  final double angle;
}

enum SeedPlacement { point, ring, cluster }

@immutable
class SeedBodySpec {
  const SeedBodySpec({
    required this.element,
    required this.count,
    required this.placement,
    this.angleDeg,
    this.radiusFrac,
    this.phaseDeg,
    this.arcDeg,
  });

  final ElementTier element;
  final int count;
  final SeedPlacement placement;
  final double? angleDeg;
  final double? radiusFrac;
  final double? phaseDeg;
  final List<double>? arcDeg;

  factory SeedBodySpec.fromJson(Map<String, dynamic> json, {String? levelId}) {
    final element = _reqElement(json, 'element', levelId: levelId);
    final count = _reqInt(json, 'count', levelId: levelId);
    if (count < 1) {
      throw LevelParseException('seed body count must be >= 1', levelId: levelId);
    }

    final placementRaw = _reqString(json, 'placement', levelId: levelId);
    final placement = switch (placementRaw) {
      'point' => SeedPlacement.point,
      'ring' => SeedPlacement.ring,
      'cluster' => SeedPlacement.cluster,
      _ => throw LevelParseException(
          'unknown placement "$placementRaw"',
          levelId: levelId,
        ),
    };

    if (placement == SeedPlacement.point && count != 1) {
      throw LevelParseException(
        'placement "point" requires count == 1',
        levelId: levelId,
      );
    }

    final radiusFrac = _optDouble(json, 'radiusFrac');
    if (radiusFrac == null) {
      throw LevelParseException('radiusFrac is required', levelId: levelId);
    }
    if (radiusFrac < 0.0 || radiusFrac > 1.0) {
      throw LevelParseException(
        'radiusFrac must be in [0.0, 1.0]',
        levelId: levelId,
      );
    }

    double? angleDeg;
    double? phaseDeg;
    List<double>? arcDeg;

    switch (placement) {
      case SeedPlacement.point:
        angleDeg = _reqDouble(json, 'angleDeg', levelId: levelId);
        _validateAngle(angleDeg, 'angleDeg', levelId: levelId);
      case SeedPlacement.ring:
        phaseDeg = _optDouble(json, 'phaseDeg') ?? 0;
        _validateAngle(phaseDeg, 'phaseDeg', levelId: levelId);
      case SeedPlacement.cluster:
        final arcRaw = json['arcDeg'];
        if (arcRaw is! List || arcRaw.length != 2) {
          throw LevelParseException(
            'cluster requires arcDeg: [start, end]',
            levelId: levelId,
          );
        }
        arcDeg = [
          _asDouble(arcRaw[0], 'arcDeg[0]', levelId: levelId),
          _asDouble(arcRaw[1], 'arcDeg[1]', levelId: levelId),
        ];
        _validateAngle(arcDeg[0], 'arcDeg[0]', levelId: levelId);
        _validateAngle(arcDeg[1], 'arcDeg[1]', levelId: levelId);
    }

    return SeedBodySpec(
      element: element,
      count: count,
      placement: placement,
      angleDeg: angleDeg,
      radiusFrac: radiusFrac,
      phaseDeg: phaseDeg,
      arcDeg: arcDeg,
    );
  }

  List<ResolvedBody> expand({
    double chamberRadius = GameConstants.chamberRadius,
  }) {
    final r = radiusFrac! * chamberRadius;
    switch (placement) {
      case SeedPlacement.point:
        final rad = _degToRad(angleDeg!);
        return [
          ResolvedBody(
            element: element,
            x: math.cos(rad) * r,
            y: math.sin(rad) * r,
            angle: rad,
          ),
        ];
      case SeedPlacement.ring:
        final phase = _degToRad(phaseDeg ?? 0);
        final out = <ResolvedBody>[];
        for (var i = 0; i < count; i++) {
          final a = phase + (2 * math.pi * i / count);
          out.add(
            ResolvedBody(
              element: element,
              x: math.cos(a) * r,
              y: math.sin(a) * r,
              angle: a,
            ),
          );
        }
        return out;
      case SeedPlacement.cluster:
        final start = _degToRad(arcDeg![0]);
        final end = _degToRad(arcDeg![1]);
        var span = end - start;
        if (span < 0) span += 2 * math.pi;
        final out = <ResolvedBody>[];
        for (var i = 0; i < count; i++) {
          final t = count == 1 ? 0.5 : i / (count - 1);
          final a = start + span * t;
          out.add(
            ResolvedBody(
              element: element,
              x: math.cos(a) * r,
              y: math.sin(a) * r,
              angle: a,
            ),
          );
        }
        return out;
    }
  }
}

@immutable
class InjectionArcSpec {
  const InjectionArcSpec({
    required this.centerDeg,
    required this.widthDeg,
  });

  final double centerDeg;
  final double widthDeg;

  factory InjectionArcSpec.fromJson(
    Map<String, dynamic> json, {
    String? levelId,
  }) {
    final center = _reqDouble(json, 'centerDeg', levelId: levelId);
    final width = _reqDouble(json, 'widthDeg', levelId: levelId);
    _validateAngle(center, 'centerDeg', levelId: levelId);
    if (width <= 0 || width > 360) {
      throw LevelParseException(
        'widthDeg must be in (0, 360]',
        levelId: levelId,
      );
    }
    return InjectionArcSpec(centerDeg: center, widthDeg: width);
  }
}

@immutable
class QueueSpec {
  const QueueSpec({
    required this.mode,
    required this.sequence,
    required this.visibleCount,
  });

  final String mode;
  final List<ElementTier> sequence;
  final int visibleCount;

  factory QueueSpec.fromJson(Map<String, dynamic> json, {String? levelId}) {
    final mode = _reqString(json, 'mode', levelId: levelId);
    if (mode != 'fixed') {
      throw LevelParseException(
        'queue.mode must be "fixed" (got "$mode")',
        levelId: levelId,
      );
    }

    final seqRaw = json['sequence'];
    if (seqRaw is! List || seqRaw.isEmpty) {
      throw LevelParseException(
        'queue.sequence must be a non-empty array',
        levelId: levelId,
      );
    }

    final sequence = <ElementTier>[];
    for (final raw in seqRaw) {
      if (raw is! String) {
        throw LevelParseException(
          'queue.sequence entries must be symbol strings',
          levelId: levelId,
        );
      }
      final tier = ElementTier.fromSymbol(raw);
      if (tier == null) {
        throw LevelParseException(
          'unknown element symbol "$raw"',
          levelId: levelId,
        );
      }
      // Queue only — seed may use heavier elements.
      if (tier.tier > GameConstants.maxInjectTier) {
        throw LevelParseException(
          'queue element "$raw" above maxInjectTier '
          '(${GameConstants.maxInjectTier}); seed may use heavy elements, '
          'the queue may not',
          levelId: levelId,
        );
      }
      sequence.add(tier);
    }

    final visibleCount = json.containsKey('visibleCount')
        ? _reqInt(json, 'visibleCount', levelId: levelId)
        : 3;
    if (visibleCount < 0) {
      throw LevelParseException(
        'visibleCount must be >= 0',
        levelId: levelId,
      );
    }

    return QueueSpec(
      mode: mode,
      sequence: sequence,
      visibleCount: visibleCount,
    );
  }

  FixedInjectionQueue toFixedQueue() => FixedInjectionQueue(
        sequence: sequence,
        visibleCount: visibleCount,
      );
}

@immutable
class LevelRules {
  const LevelRules({this.remnants = false});

  final bool remnants;

  factory LevelRules.fromJson(Map<String, dynamic> json, {String? levelId}) {
    final remnants = json.containsKey('remnants')
        ? _reqBool(json, 'remnants', levelId: levelId)
        : false;
    return LevelRules(remnants: remnants);
  }
}

sealed class LevelGoal {
  const LevelGoal();

  factory LevelGoal.fromJson(Map<String, dynamic> json, {String? levelId}) {
    final type = _reqString(json, 'type', levelId: levelId);
    return switch (type) {
      'produce' => ProduceGoal(
          element: _reqElement(json, 'element', levelId: levelId),
          count: _reqInt(json, 'count', levelId: levelId),
        ),
      'boardUnder' => BoardUnderGoal(
          value: _reqInt(json, 'value', levelId: levelId),
        ),
      'survive' => SurviveGoal(
          shots: _reqInt(json, 'shots', levelId: levelId),
        ),
      'eliminate' => EliminateGoal(
          element: _reqElement(json, 'element', levelId: levelId),
        ),
      'causeSupernova' => CauseSupernovaGoal(
          count: _reqInt(json, 'count', levelId: levelId),
        ),
      _ => throw LevelParseException(
          'unknown goal type "$type"',
          levelId: levelId,
        ),
    };
  }
}

@immutable
class ProduceGoal extends LevelGoal {
  const ProduceGoal({required this.element, required this.count});
  final ElementTier element;
  final int count;
}

@immutable
class BoardUnderGoal extends LevelGoal {
  const BoardUnderGoal({required this.value});
  final int value;
}

@immutable
class SurviveGoal extends LevelGoal {
  const SurviveGoal({required this.shots});
  final int shots;
}

/// Board must currently hold zero of [element]. Checked against live board
/// composition, not cumulative production — a seeded element consumed by a
/// same-tier fusion or a supernova blast satisfies this.
@immutable
class EliminateGoal extends LevelGoal {
  const EliminateGoal({required this.element});
  final ElementTier element;
}

/// At least [count] mid-run iron+iron supernovae this run.
@immutable
class CauseSupernovaGoal extends LevelGoal {
  const CauseSupernovaGoal({required this.count});
  final int count;
}

sealed class LevelConstraint {
  const LevelConstraint();

  factory LevelConstraint.fromJson(
    Map<String, dynamic> json, {
    String? levelId,
  }) {
    final type = _reqString(json, 'type', levelId: levelId);
    return switch (type) {
      'neverProduce' => NeverProduceConstraint(
          element: _reqElement(json, 'element', levelId: levelId),
        ),
      'maxBodies' => MaxBodiesConstraint(
          value: _reqInt(json, 'value', levelId: levelId),
        ),
      'maxOfElement' => MaxOfElementConstraint(
          element: _reqElement(json, 'element', levelId: levelId),
          value: _reqInt(json, 'value', levelId: levelId),
        ),
      'noSameTier' => const NoSameTierConstraint(),
      'maxTotalProduced' => MaxTotalProducedConstraint(
          element: _reqElement(json, 'element', levelId: levelId),
          value: _reqInt(json, 'value', levelId: levelId),
        ),
      _ => throw LevelParseException(
          'unknown constraint type "$type"',
          levelId: levelId,
        ),
    };
  }
}

@immutable
class NeverProduceConstraint extends LevelConstraint {
  const NeverProduceConstraint({required this.element});
  final ElementTier element;
}

/// Lifetime cap on how many of [element] may ever be created this run —
/// cumulative, unlike [MaxOfElementConstraint]'s simultaneous-board cap.
@immutable
class MaxTotalProducedConstraint extends LevelConstraint {
  const MaxTotalProducedConstraint({required this.element, required this.value});
  final ElementTier element;
  final int value;
}

@immutable
class MaxBodiesConstraint extends LevelConstraint {
  const MaxBodiesConstraint({required this.value});
  final int value;
}

@immutable
class MaxOfElementConstraint extends LevelConstraint {
  const MaxOfElementConstraint({required this.element, required this.value});
  final ElementTier element;
  final int value;
}

@immutable
class NoSameTierConstraint extends LevelConstraint {
  const NoSameTierConstraint();
}

@immutable
class LevelPack {
  const LevelPack({
    required this.schemaVersion,
    required this.pack,
    required this.levels,
  });

  final int schemaVersion;
  final int pack;
  final List<LevelSpec> levels;

  static const int supportedSchemaVersion = 1;

  factory LevelPack.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _reqInt(json, 'schemaVersion');
    if (schemaVersion != supportedSchemaVersion) {
      throw LevelParseException(
        'unrecognised schemaVersion $schemaVersion '
        '(supported: $supportedSchemaVersion)',
      );
    }
    final pack = _reqInt(json, 'pack');
    final levelsRaw = json['levels'];
    if (levelsRaw is! List) {
      throw LevelParseException('levels must be an array');
    }

    final seen = <String>{};
    final levels = <LevelSpec>[];
    for (final raw in levelsRaw) {
      final map = _asMap(raw, 'level');
      final level = LevelSpec.fromJson(map, pack: pack);
      if (!seen.add(level.id)) {
        throw LevelParseException(
          'duplicate level id "${level.id}" within pack $pack',
          levelId: level.id,
        );
      }
      levels.add(level);
    }
    return LevelPack(
      schemaVersion: schemaVersion,
      pack: pack,
      levels: levels,
    );
  }

  factory LevelPack.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw LevelParseException('pack root must be a JSON object');
    }
    return LevelPack.fromJson(Map<String, dynamic>.from(decoded));
  }
}

// --- JSON helpers -----------------------------------------------------------

Map<String, dynamic> _asMap(Object? raw, String label, {String? levelId}) {
  if (raw is! Map) {
    throw LevelParseException('$label must be an object', levelId: levelId);
  }
  return Map<String, dynamic>.from(raw);
}

String _reqString(Map<String, dynamic> json, String key, {String? levelId}) {
  final v = json[key];
  if (v is! String || v.isEmpty) {
    throw LevelParseException('$key must be a non-empty string', levelId: levelId);
  }
  return v;
}

int _reqInt(Map<String, dynamic> json, String key, {String? levelId}) {
  final v = json[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  throw LevelParseException('$key must be an int', levelId: levelId);
}

double _reqDouble(Map<String, dynamic> json, String key, {String? levelId}) {
  final v = json[key];
  if (v is double) return v;
  if (v is num) return v.toDouble();
  throw LevelParseException('$key must be a number', levelId: levelId);
}

double? _optDouble(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return null;
}

bool _reqBool(Map<String, dynamic> json, String key, {String? levelId}) {
  final v = json[key];
  if (v is bool) return v;
  throw LevelParseException('$key must be a bool', levelId: levelId);
}

ElementTier _reqElement(
  Map<String, dynamic> json,
  String key, {
  String? levelId,
}) {
  final raw = _reqString(json, key, levelId: levelId);
  final tier = ElementTier.fromSymbol(raw);
  if (tier == null) {
    throw LevelParseException(
      'unknown element symbol "$raw"',
      levelId: levelId,
    );
  }
  return tier;
}

double _asDouble(Object? raw, String label, {String? levelId}) {
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  throw LevelParseException('$label must be a number', levelId: levelId);
}

void _validateAngle(double deg, String label, {String? levelId}) {
  if (deg < 0 || deg > 360) {
    throw LevelParseException(
      '$label must be in [0, 360]',
      levelId: levelId,
    );
  }
}

double _degToRad(double deg) => deg * math.pi / 180.0;
