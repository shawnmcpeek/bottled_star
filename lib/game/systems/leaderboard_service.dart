import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../modes/game_mode.dart';

/// Top-10 daily (UTC) and all-time boards on Firestore — per mode.
class LeaderboardService {
  LeaderboardService({
    this._auth,
    this._firestore,
  });

  static const int topN = 10;
  static const int maxDisplayNameLength = 16;
  static const int maxScore = 1000000;
  static const int maxKilonovas = 10000;
  static const int maxShotsExclusive = 1000000;
  static const Duration boardCacheTtl = Duration(seconds: 45);

  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;

  final Map<String, List<LeaderboardEntry>> _cache = {};
  final Map<String, DateTime> _fetchedAt = {};

  bool get isAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseAuth get auth => _auth ??= FirebaseAuth.instance;
  FirebaseFirestore get db => _firestore ??= FirebaseFirestore.instance;

  /// UTC calendar day, e.g. `2026-08-06`.
  static String utcDayKey([DateTime? now]) {
    final d = (now ?? DateTime.now()).toUtc();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Collapse sort key: more kilonovas win; fewer shots break ties.
  static int collapseRankScore({required int kilonovas, required int shots}) {
    final k = kilonovas.clamp(0, maxKilonovas);
    final s = shots.clamp(0, maxShotsExclusive - 1);
    return k * maxShotsExclusive - s;
  }

  static String? sanitizeDisplayName(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty || trimmed.length > maxDisplayNameLength) {
      return null;
    }
    if (!RegExp(r"^[\w .'\-]+$", unicode: true).hasMatch(trimmed)) {
      return null;
    }
    return trimmed;
  }

  static String allTimeCollection(GameMode mode) => switch (mode) {
        GameMode.classic => 'classic_all_time',
        GameMode.collapse => 'collapse_all_time',
        // Challenge levels are deterministic — fixed seed, fixed queue, fixed
        // goal. Every competent player converges on the same optimal solution,
        // so a best-shots board collapses into a thousand-way tie at par,
        // ordered by submission time. That is not a leaderboard. Challenge
        // feeds achievements instead. Never alias onto Classic collections.
        GameMode.challenge => throw UnsupportedError(
            'Challenge has no leaderboard collections',
          ),
      };

  static String dailyCollection(GameMode mode) => switch (mode) {
        GameMode.classic => 'classic_daily',
        GameMode.collapse => 'collapse_daily',
        GameMode.challenge => throw UnsupportedError(
            'Challenge has no leaderboard collections',
          ),
      };

  Future<User?> ensureSignedIn() async {
    if (!isAvailable) return null;
    final current = auth.currentUser;
    if (current != null) return current;
    final cred = await auth.signInAnonymously();
    return cred.user;
  }

  Future<LeaderboardSubmitResult> submitBest({
    required GameMode mode,
    required String displayName,
    required int peakTier,
    required String ending,
    int score = 0,
    int kilonovas = 0,
    int shots = 0,
  }) async {
    // Challenge is deterministic (fixed seed/queue/goal). A best-shots board
    // would be a time-ordered tie at par — not a leaderboard. Feed
    // achievements instead. Guard here so a future refactor cannot quietly
    // write Challenge rows into Firestore.
    if (mode == GameMode.challenge) {
      return LeaderboardSubmitResult.rejected;
    }
    if (!isAvailable) {
      return LeaderboardSubmitResult.unavailable;
    }
    final name = sanitizeDisplayName(displayName);
    if (name == null) {
      return LeaderboardSubmitResult.invalidName;
    }
    if (mode == GameMode.classic) {
      if (score < 0 || score > maxScore) {
        return LeaderboardSubmitResult.rejected;
      }
    } else {
      if (kilonovas < 0 ||
          kilonovas > maxKilonovas ||
          shots < 0 ||
          shots >= maxShotsExclusive) {
        return LeaderboardSubmitResult.rejected;
      }
    }

    try {
      final user = await ensureSignedIn();
      if (user == null) {
        return LeaderboardSubmitResult.unavailable;
      }

      final uid = user.uid;
      final dayKey = utcDayKey();
      final now = FieldValue.serverTimestamp();
      final payload = mode == GameMode.classic
          ? <String, dynamic>{
              'uid': uid,
              'displayName': name,
              'mode': mode.name,
              'score': score,
              'peakTier': peakTier,
              'ending': ending,
              'updatedAt': now,
            }
          : <String, dynamic>{
              'uid': uid,
              'displayName': name,
              'mode': mode.name,
              'kilonovas': kilonovas,
              'shots': shots,
              'rankScore':
                  collapseRankScore(kilonovas: kilonovas, shots: shots),
              'peakTier': peakTier,
              'ending': ending,
              'updatedAt': now,
            };

      final improvedAllTime = await _writeBest(
        ref: db.collection(allTimeCollection(mode)).doc(uid),
        payload: payload,
        name: name,
        now: now,
        mode: mode,
        score: score,
        rankScore: collapseRankScore(kilonovas: kilonovas, shots: shots),
      );

      final improvedDaily = await _writeBest(
        ref: db.collection(dailyCollection(mode)).doc('${dayKey}_$uid'),
        payload: {
          ...payload,
          'dayKey': dayKey,
        },
        name: name,
        now: now,
        mode: mode,
        score: score,
        rankScore: collapseRankScore(kilonovas: kilonovas, shots: shots),
      );

      if (improvedAllTime || improvedDaily) {
        invalidateCache(mode: mode);
        return LeaderboardSubmitResult.submitted;
      }
      return LeaderboardSubmitResult.notImproved;
    } on FirebaseAuthException {
      return LeaderboardSubmitResult.unavailable;
    } on FirebaseException {
      return LeaderboardSubmitResult.unavailable;
    } catch (_) {
      return LeaderboardSubmitResult.unavailable;
    }
  }

  Future<bool> _writeBest({
    required DocumentReference<Map<String, dynamic>> ref,
    required Map<String, dynamic> payload,
    required String name,
    required FieldValue now,
    required GameMode mode,
    required int score,
    required int rankScore,
  }) async {
    var improved = false;
    await db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      final better = mode == GameMode.classic
          ? _isBetterClassic(data, score)
          : _isBetterCollapse(data, rankScore);
      if (better) {
        tx.set(ref, payload, SetOptions(merge: true));
        improved = true;
      } else if (snap.exists) {
        tx.set(
          ref,
          {'displayName': name, 'updatedAt': now},
          SetOptions(merge: true),
        );
      }
    });
    return improved;
  }

  static bool _isBetterClassic(Map<String, dynamic>? data, int score) {
    if (data == null) return true;
    final existing = data['score'];
    final prev = existing is int
        ? existing
        : existing is num
            ? existing.toInt()
            : null;
    return prev == null || score > prev;
  }

  static bool _isBetterCollapse(Map<String, dynamic>? data, int rankScore) {
    if (data == null) return true;
    final existing = data['rankScore'];
    final prev = existing is int
        ? existing
        : existing is num
            ? existing.toInt()
            : null;
    return prev == null || rankScore > prev;
  }

  void invalidateCache({GameMode? mode}) {
    if (mode == null) {
      _cache.clear();
      _fetchedAt.clear();
      return;
    }
    for (final period in ['daily', 'all']) {
      final key = _cacheKey(mode, period);
      _cache.remove(key);
      _fetchedAt.remove(key);
    }
  }

  String _cacheKey(GameMode mode, String period) => '${mode.name}_$period';

  Future<List<LeaderboardEntry>> fetchAllTime({
    required GameMode mode,
    bool force = false,
  }) async {
    if (!isAvailable || mode == GameMode.challenge) return const [];
    final key = _cacheKey(mode, 'all');
    final now = DateTime.now();
    if (!force &&
        _cache[key] != null &&
        _fetchedAt[key] != null &&
        now.difference(_fetchedAt[key]!) < boardCacheTtl) {
      return _cache[key]!;
    }

    final Query<Map<String, dynamic>> query = mode == GameMode.classic
        ? db
            .collection(allTimeCollection(mode))
            .orderBy('score', descending: true)
            .limit(topN)
        : db
            .collection(allTimeCollection(mode))
            .orderBy('rankScore', descending: true)
            .limit(topN);

    final snap = await query.get();
    final entries = [
      for (var i = 0; i < snap.docs.length; i++)
        LeaderboardEntry.fromMap(
          rank: i + 1,
          mode: mode,
          data: snap.docs[i].data(),
        ),
    ];
    _cache[key] = entries;
    _fetchedAt[key] = now;
    return entries;
  }

  Future<List<LeaderboardEntry>> fetchDaily({
    required GameMode mode,
    bool force = false,
  }) async {
    if (!isAvailable || mode == GameMode.challenge) return const [];
    final dayKey = utcDayKey();
    final key = _cacheKey(mode, 'daily');
    final now = DateTime.now();
    if (!force &&
        _cache[key] != null &&
        _fetchedAt[key] != null &&
        now.difference(_fetchedAt[key]!) < boardCacheTtl) {
      return _cache[key]!;
    }

    final Query<Map<String, dynamic>> query = mode == GameMode.classic
        ? db
            .collection(dailyCollection(mode))
            .where('dayKey', isEqualTo: dayKey)
            .orderBy('score', descending: true)
            .limit(topN)
        : db
            .collection(dailyCollection(mode))
            .where('dayKey', isEqualTo: dayKey)
            .orderBy('rankScore', descending: true)
            .limit(topN);

    final snap = await query.get();
    final entries = [
      for (var i = 0; i < snap.docs.length; i++)
        LeaderboardEntry.fromMap(
          rank: i + 1,
          mode: mode,
          data: snap.docs[i].data(),
        ),
    ];
    _cache[key] = entries;
    _fetchedAt[key] = now;
    return entries;
  }
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.displayName,
    required this.uid,
    required this.mode,
    this.score = 0,
    this.kilonovas = 0,
    this.shots = 0,
    this.peakTier = 0,
  });

  final int rank;
  final String displayName;
  final String uid;
  final GameMode mode;
  final int score;
  final int kilonovas;
  final int shots;
  final int peakTier;

  String get valueLabel => mode == GameMode.collapse
      ? 'K$kilonovas · $shots shots'
      : '$score';

  factory LeaderboardEntry.fromMap({
    required int rank,
    required GameMode mode,
    required Map<String, dynamic> data,
  }) {
    int asInt(dynamic raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return 0;
    }

    return LeaderboardEntry(
      rank: rank,
      displayName: (data['displayName'] as String?)?.trim().isNotEmpty == true
          ? (data['displayName'] as String).trim()
          : 'Anonymous',
      uid: (data['uid'] as String?) ?? '',
      mode: mode,
      score: asInt(data['score']),
      kilonovas: asInt(data['kilonovas']),
      shots: asInt(data['shots']),
      peakTier: asInt(data['peakTier']),
    );
  }
}

enum LeaderboardSubmitResult {
  submitted,
  notImproved,
  invalidName,
  rejected,
  unavailable,
}
