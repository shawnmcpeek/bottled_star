import '../element_tier.dart';
import '../modes/game_mode.dart';

/// Local snapshot of an in-progress run. Versioned JSON for SharedPreferences.
class RunSnapshot {
  const RunSnapshot({
    required this.mode,
    required this.score,
    required this.highestTier,
    required this.shotCount,
    required this.kilonovaCount,
    required this.supernovaCount,
    required this.injectorAngle,
    required this.tiersCreated,
    required this.queue,
    required this.nuclei,
    required this.remnants,
    this.levelId,
    this.challengeSettleElapsed = 0,
    this.challenge,
  });

  static const int schemaVersion = 1;

  final GameMode mode;
  final String? levelId;
  final int score;
  final int highestTier;
  final int shotCount;
  final int kilonovaCount;
  final int supernovaCount;
  final double injectorAngle;
  final Set<int> tiersCreated;
  final QueueSnapshot queue;
  final List<NucleusSnapshot> nuclei;
  final List<BodySnapshot> remnants;
  final double challengeSettleElapsed;
  final ChallengeTrackerSnapshot? challenge;

  bool get isWorthSaving => shotCount > 0 || nuclei.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'v': schemaVersion,
        'mode': mode.name,
        'levelId': levelId,
        'score': score,
        'highestTier': highestTier,
        'shotCount': shotCount,
        'kilonovaCount': kilonovaCount,
        'supernovaCount': supernovaCount,
        'injectorAngle': injectorAngle,
        'tiersCreated': tiersCreated.toList()..sort(),
        'queue': queue.toJson(),
        'nuclei': [for (final n in nuclei) n.toJson()],
        'remnants': [for (final r in remnants) r.toJson()],
        'challengeSettleElapsed': challengeSettleElapsed,
        if (challenge != null) 'challenge': challenge!.toJson(),
      };

  static RunSnapshot? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final version = map['v'];
    if (version != schemaVersion) return null;

    final modeName = map['mode'] as String?;
    final mode = GameMode.values.where((m) => m.name == modeName).firstOrNull;
    if (mode == null) return null;

    final queue = QueueSnapshot.tryParse(map['queue']);
    if (queue == null) return null;

    final nucleiRaw = map['nuclei'];
    if (nucleiRaw is! List) return null;
    final nuclei = <NucleusSnapshot>[];
    for (final item in nucleiRaw) {
      final parsed = NucleusSnapshot.tryParse(item);
      if (parsed == null) return null;
      nuclei.add(parsed);
    }

    final remnantsRaw = map['remnants'];
    final remnants = <BodySnapshot>[];
    if (remnantsRaw is List) {
      for (final item in remnantsRaw) {
        final parsed = BodySnapshot.tryParse(item);
        if (parsed == null) return null;
        remnants.add(parsed);
      }
    }

    final tiersRaw = map['tiersCreated'];
    final tiers = <int>{};
    if (tiersRaw is List) {
      for (final item in tiersRaw) {
        if (item is int) {
          tiers.add(item);
        } else if (item is num) {
          tiers.add(item.toInt());
        }
      }
    }

    return RunSnapshot(
      mode: mode,
      levelId: map['levelId'] as String?,
      score: _asInt(map['score']) ?? 0,
      highestTier: _asInt(map['highestTier']) ?? 0,
      shotCount: _asInt(map['shotCount']) ?? 0,
      kilonovaCount: _asInt(map['kilonovaCount']) ?? 0,
      supernovaCount: _asInt(map['supernovaCount']) ?? 0,
      injectorAngle: _asDouble(map['injectorAngle']) ?? 0,
      tiersCreated: tiers,
      queue: queue,
      nuclei: nuclei,
      remnants: remnants,
      challengeSettleElapsed: _asDouble(map['challengeSettleElapsed']) ?? 0,
      challenge: ChallengeTrackerSnapshot.tryParse(map['challenge']),
    );
  }
}

class QueueSnapshot {
  const QueueSnapshot.weighted({
    required this.current,
    required this.next,
    required this.unlockedThrough,
  }) : index = 0,
       kind = QueueKind.weighted;

  const QueueSnapshot.fixed({
    required this.current,
    required this.next,
    required this.index,
  })  : unlockedThrough = 0,
        kind = QueueKind.fixed;

  final QueueKind kind;
  final int current;
  final int next;
  final int unlockedThrough;
  final int index;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'current': current,
        'next': next,
        'unlockedThrough': unlockedThrough,
        'index': index,
      };

  static QueueSnapshot? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final kindName = map['kind'] as String?;
    final kind = QueueKind.values.where((k) => k.name == kindName).firstOrNull;
    if (kind == null) return null;
    final current = _asInt(map['current']);
    final next = _asInt(map['next']);
    if (current == null || next == null) return null;
    return switch (kind) {
      QueueKind.weighted => QueueSnapshot.weighted(
          current: current,
          next: next,
          unlockedThrough: _asInt(map['unlockedThrough']) ?? 0,
        ),
      QueueKind.fixed => QueueSnapshot.fixed(
          current: current,
          next: next,
          index: _asInt(map['index']) ?? 0,
        ),
    };
  }
}

enum QueueKind { weighted, fixed }

class NucleusSnapshot {
  const NucleusSnapshot({
    required this.tier,
    required this.body,
    required this.rimPressure,
  });

  final int tier;
  final BodySnapshot body;
  final double rimPressure;

  Map<String, dynamic> toJson() => {
        't': tier,
        ...body.toJson(),
        'rp': rimPressure,
      };

  static NucleusSnapshot? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final tier = _asInt(map['t']);
    final body = BodySnapshot.tryParse(map);
    if (tier == null || body == null) return null;
    if (tier < 0 || tier > ElementTier.iron.tier) return null;
    return NucleusSnapshot(
      tier: tier,
      body: body,
      rimPressure: _asDouble(map['rp']) ?? 0,
    );
  }
}

class BodySnapshot {
  const BodySnapshot({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.angle,
    required this.angularVelocity,
  });

  final double x;
  final double y;
  final double vx;
  final double vy;
  final double angle;
  final double angularVelocity;

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'vx': vx,
        'vy': vy,
        'a': angle,
        'av': angularVelocity,
      };

  static BodySnapshot? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final x = _asDouble(map['x']);
    final y = _asDouble(map['y']);
    if (x == null || y == null) return null;
    return BodySnapshot(
      x: x,
      y: y,
      vx: _asDouble(map['vx']) ?? 0,
      vy: _asDouble(map['vy']) ?? 0,
      angle: _asDouble(map['a']) ?? 0,
      angularVelocity: _asDouble(map['av']) ?? 0,
    );
  }
}

class ChallengeTrackerSnapshot {
  const ChallengeTrackerSnapshot({
    required this.produced,
    required this.shotsFired,
    required this.supernovaCount,
  });

  final Map<int, int> produced;
  final int shotsFired;
  final int supernovaCount;

  Map<String, dynamic> toJson() => {
        'produced': {
          for (final e in produced.entries) e.key.toString(): e.value,
        },
        'shotsFired': shotsFired,
        'supernovaCount': supernovaCount,
      };

  static ChallengeTrackerSnapshot? tryParse(Object? raw) {
    if (raw == null) return null;
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final producedRaw = map['produced'];
    final produced = <int, int>{};
    if (producedRaw is Map) {
      for (final entry in producedRaw.entries) {
        final key = int.tryParse(entry.key.toString());
        final value = _asInt(entry.value);
        if (key != null && value != null) produced[key] = value;
      }
    }
    return ChallengeTrackerSnapshot(
      produced: produced,
      shotsFired: _asInt(map['shotsFired']) ?? 0,
      supernovaCount: _asInt(map['supernovaCount']) ?? 0,
    );
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

double? _asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return null;
}
