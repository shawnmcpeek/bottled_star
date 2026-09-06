import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../modes/game_mode.dart';
import 'run_snapshot.dart';

/// Local in-progress run storage. One slot per Classic/Collapse run, and
/// one slot per Challenge level.
abstract final class RunSaveStore {
  static String keyFor({required GameMode mode, String? levelId}) {
    if (mode == GameMode.challenge) {
      final id = levelId ?? 'unknown';
      return 'in_progress_run_challenge_$id';
    }
    return 'in_progress_run_${mode.name}';
  }

  static Future<RunSnapshot?> load({
    required GameMode mode,
    String? levelId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyFor(mode: mode, levelId: levelId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      final snap = RunSnapshot.tryParse(decoded);
      if (snap == null || snap.mode != mode) return null;
      if (mode == GameMode.challenge && snap.levelId != levelId) return null;
      return snap;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> hasSaved({
    required GameMode mode,
    String? levelId,
  }) async {
    final snap = await load(mode: mode, levelId: levelId);
    return snap != null && snap.isWorthSaving;
  }

  static Future<void> save(RunSnapshot snapshot) async {
    if (!snapshot.isWorthSaving) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      keyFor(mode: snapshot.mode, levelId: snapshot.levelId),
      jsonEncode(snapshot.toJson()),
    );
  }

  static Future<void> clear({
    required GameMode mode,
    String? levelId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyFor(mode: mode, levelId: levelId));
  }
}
