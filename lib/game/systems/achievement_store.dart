import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import 'achievement_defs.dart';

/// Local unlock store. Sync to Play / Game Center later using the same IDs.
class AchievementStore extends ChangeNotifier {
  AchievementStore._();
  static final AchievementStore instance = AchievementStore._();

  final Map<String, DateTime> _unlockedAt = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  bool isUnlocked(AchievementId id) => _unlockedAt.containsKey(id.id);

  DateTime? unlockedAt(AchievementId id) => _unlockedAt[id.id];

  List<AchievementId> get unlocked => [
        for (final a in AchievementId.values)
          if (isUnlocked(a)) a,
      ];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _unlockedAt.clear();
    final raw = prefs.getString(GameConstants.prefsAchievements);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final e in decoded.entries) {
            final ms = e.value;
            if (ms is int) {
              _unlockedAt[e.key.toString()] =
                  DateTime.fromMillisecondsSinceEpoch(ms);
            } else if (ms is num) {
              _unlockedAt[e.key.toString()] =
                  DateTime.fromMillisecondsSinceEpoch(ms.toInt());
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

  /// Returns true if this call newly unlocked the achievement.
  Future<bool> unlock(AchievementId id) async {
    if (!_loaded) await load();
    if (_unlockedAt.containsKey(id.id)) return false;
    _unlockedAt[id.id] = DateTime.now();
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, int>{
      for (final e in _unlockedAt.entries)
        e.key: e.value.millisecondsSinceEpoch,
    };
    await prefs.setString(GameConstants.prefsAchievements, jsonEncode(map));
  }
}
