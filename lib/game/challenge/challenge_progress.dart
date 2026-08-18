import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

/// Per-level Challenge completion and best cleared shot count.
class ChallengeProgress extends ChangeNotifier {
  ChallengeProgress._();
  static final ChallengeProgress instance = ChallengeProgress._();

  final Map<String, LevelProgress> _levels = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  LevelProgress forLevel(String id) =>
      _levels[id] ?? const LevelProgress(completed: false);

  bool isCompleted(String id) => forLevel(id).completed;

  int? bestShots(String id) => forLevel(id).bestShots;

  /// Next unlocked level id given play order. First incomplete, or null if all
  /// cleared. Levels before the first incomplete are playable when completed
  /// (replay) or when they are the first incomplete.
  bool isUnlocked(String id, List<String> playOrder) {
    if (playOrder.isEmpty) return false;
    if (id == playOrder.first) return true;
    final index = playOrder.indexOf(id);
    if (index < 0) return false;
    // Unlock when the previous level is cleared.
    return isCompleted(playOrder[index - 1]);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _levels.clear();
    final raw = prefs.getString(GameConstants.prefsChallengeProgress);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final e in decoded.entries) {
            final value = e.value;
            if (value is Map) {
              _levels[e.key.toString()] = LevelProgress.fromJson(
                Map<String, dynamic>.from(value),
              );
            }
          }
        }
      } catch (_) {
        // Ignore corrupt prefs.
      }
    }
    _loaded = true;
    notifyListeners();
  }

  /// Record a cleared run. Failed attempts write nothing.
  Future<void> recordClear({
    required String levelId,
    required int shots,
  }) async {
    if (!_loaded) await load();
    final prev = forLevel(levelId);
    final best = prev.bestShots;
    final nextBest = best == null ? shots : (shots < best ? shots : best);
    _levels[levelId] = LevelProgress(completed: true, bestShots: nextBest);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, Object?>{
      for (final e in _levels.entries) e.key: e.value.toJson(),
    };
    await prefs.setString(
      GameConstants.prefsChallengeProgress,
      jsonEncode(map),
    );
  }

  /// Test helper.
  @visibleForTesting
  void resetForTest() {
    _levels.clear();
    _loaded = false;
  }
}

@immutable
class LevelProgress {
  const LevelProgress({required this.completed, this.bestShots});

  final bool completed;
  final int? bestShots;

  factory LevelProgress.fromJson(Map<String, dynamic> json) {
    final completed = json['completed'] == true;
    final rawBest = json['bestShots'];
    int? bestShots;
    if (rawBest is int) {
      bestShots = rawBest;
    } else if (rawBest is num) {
      bestShots = rawBest.toInt();
    }
    return LevelProgress(completed: completed, bestShots: bestShots);
  }

  Map<String, Object?> toJson() => {
        'completed': completed,
        'bestShots': bestShots,
      };
}
