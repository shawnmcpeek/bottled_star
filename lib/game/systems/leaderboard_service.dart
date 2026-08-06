import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Top-10 daily (UTC) and all-time boards on Firestore.
class LeaderboardService {
  LeaderboardService({
    this._auth,
    this._firestore,
  });

  static const int topN = 10;
  static const int maxDisplayNameLength = 16;
  static const int maxScore = 1000000;
  static const Duration boardCacheTtl = Duration(seconds: 45);

  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;

  List<LeaderboardEntry>? _cachedAllTime;
  List<LeaderboardEntry>? _cachedDaily;
  DateTime? _allTimeFetchedAt;
  DateTime? _dailyFetchedAt;
  String? _cachedDailyKey;

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

  static String? sanitizeDisplayName(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty || trimmed.length > maxDisplayNameLength) {
      return null;
    }
    // Letters, numbers, spaces, a few safe punctuation marks.
    if (!RegExp(r"^[\w .'\-]+$", unicode: true).hasMatch(trimmed)) {
      return null;
    }
    return trimmed;
  }

  Future<User?> ensureSignedIn() async {
    if (!isAvailable) return null;
    final current = auth.currentUser;
    if (current != null) return current;
    final cred = await auth.signInAnonymously();
    return cred.user;
  }

  Future<LeaderboardSubmitResult> submitBest({
    required int score,
    required String displayName,
    required int peakTier,
    required String ending,
  }) async {
    if (!isAvailable) {
      return LeaderboardSubmitResult.unavailable;
    }
    final name = sanitizeDisplayName(displayName);
    if (name == null) {
      return LeaderboardSubmitResult.invalidName;
    }
    if (score < 0 || score > maxScore) {
      return LeaderboardSubmitResult.rejected;
    }

    try {
      final user = await ensureSignedIn();
      if (user == null) {
        return LeaderboardSubmitResult.unavailable;
      }

      final uid = user.uid;
      final dayKey = utcDayKey();
      final now = FieldValue.serverTimestamp();
      final payload = <String, dynamic>{
        'uid': uid,
        'displayName': name,
        'score': score,
        'peakTier': peakTier,
        'ending': ending,
        'updatedAt': now,
      };

      var improvedAllTime = false;
      var improvedDaily = false;

      final allTimeRef = db.collection('all_time_scores').doc(uid);
      await db.runTransaction((tx) async {
        final snap = await tx.get(allTimeRef);
        final existing = snap.data()?['score'];
        final prev = existing is int
            ? existing
            : existing is num
                ? existing.toInt()
                : null;
        if (prev == null || score > prev) {
          tx.set(allTimeRef, payload, SetOptions(merge: true));
          improvedAllTime = true;
        } else if (snap.exists) {
          // Keep board name in sync even if score didn't beat all-time.
          tx.set(
            allTimeRef,
            {'displayName': name, 'updatedAt': now},
            SetOptions(merge: true),
          );
        }
      });

      final dailyRef = db.collection('daily_scores').doc('${dayKey}_$uid');
      await db.runTransaction((tx) async {
        final snap = await tx.get(dailyRef);
        final existing = snap.data()?['score'];
        final prev = existing is int
            ? existing
            : existing is num
                ? existing.toInt()
                : null;
        if (prev == null || score > prev) {
          tx.set(
            dailyRef,
            {
              ...payload,
              'dayKey': dayKey,
            },
            SetOptions(merge: true),
          );
          improvedDaily = true;
        } else if (snap.exists) {
          tx.set(
            dailyRef,
            {'displayName': name, 'updatedAt': now},
            SetOptions(merge: true),
          );
        }
      });

      if (improvedAllTime || improvedDaily) {
        invalidateCache();
      }

      if (improvedAllTime || improvedDaily) {
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

  void invalidateCache() {
    _cachedAllTime = null;
    _cachedDaily = null;
    _allTimeFetchedAt = null;
    _dailyFetchedAt = null;
    _cachedDailyKey = null;
  }

  Future<List<LeaderboardEntry>> fetchAllTime({bool force = false}) async {
    if (!isAvailable) return const [];
    final now = DateTime.now();
    if (!force &&
        _cachedAllTime != null &&
        _allTimeFetchedAt != null &&
        now.difference(_allTimeFetchedAt!) < boardCacheTtl) {
      return _cachedAllTime!;
    }

    final snap = await db
        .collection('all_time_scores')
        .orderBy('score', descending: true)
        .limit(topN)
        .get();

    final entries = [
      for (var i = 0; i < snap.docs.length; i++)
        LeaderboardEntry.fromMap(
          rank: i + 1,
          data: snap.docs[i].data(),
        ),
    ];
    _cachedAllTime = entries;
    _allTimeFetchedAt = now;
    return entries;
  }

  Future<List<LeaderboardEntry>> fetchDaily({bool force = false}) async {
    if (!isAvailable) return const [];
    final dayKey = utcDayKey();
    final now = DateTime.now();
    if (!force &&
        _cachedDaily != null &&
        _cachedDailyKey == dayKey &&
        _dailyFetchedAt != null &&
        now.difference(_dailyFetchedAt!) < boardCacheTtl) {
      return _cachedDaily!;
    }

    final snap = await db
        .collection('daily_scores')
        .where('dayKey', isEqualTo: dayKey)
        .orderBy('score', descending: true)
        .limit(topN)
        .get();

    final entries = [
      for (var i = 0; i < snap.docs.length; i++)
        LeaderboardEntry.fromMap(
          rank: i + 1,
          data: snap.docs[i].data(),
        ),
    ];
    _cachedDaily = entries;
    _dailyFetchedAt = now;
    _cachedDailyKey = dayKey;
    return entries;
  }
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.displayName,
    required this.score,
    required this.uid,
    this.peakTier = 0,
  });

  final int rank;
  final String displayName;
  final int score;
  final String uid;
  final int peakTier;

  factory LeaderboardEntry.fromMap({
    required int rank,
    required Map<String, dynamic> data,
  }) {
    final scoreRaw = data['score'];
    final peakRaw = data['peakTier'];
    return LeaderboardEntry(
      rank: rank,
      displayName: (data['displayName'] as String?)?.trim().isNotEmpty == true
          ? (data['displayName'] as String).trim()
          : 'Anonymous',
      score: scoreRaw is int
          ? scoreRaw
          : scoreRaw is num
              ? scoreRaw.toInt()
              : 0,
      uid: (data['uid'] as String?) ?? '',
      peakTier: peakRaw is int
          ? peakRaw
          : peakRaw is num
              ? peakRaw.toInt()
              : 0,
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
