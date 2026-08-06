import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import 'ending_messages.dart';

class ScoreStore {
  int highScore = 0;
  int highestTier = 0;
  int totalRuns = 0;
  RunEnding? lastEnding;

  final Set<String> firedMilestones = {};
  final Map<String, Set<int>> messageBagSeen = {};
  String? lastMessageId;
  String? lastEndingLine;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    highScore = prefs.getInt(GameConstants.prefsHighScore) ?? 0;
    highestTier = prefs.getInt(GameConstants.prefsHighestTier) ?? 0;
    totalRuns = prefs.getInt(GameConstants.prefsTotalRuns) ?? 0;
    lastEnding =
        RunEnding.fromPrefs(prefs.getString(GameConstants.prefsLastEnding));
    lastMessageId = prefs.getString(GameConstants.prefsLastMessageId);

    firedMilestones
      ..clear()
      ..addAll(prefs.getStringList(GameConstants.prefsFiredMilestones) ?? []);

    messageBagSeen.clear();
    final rawBags = prefs.getString(GameConstants.prefsMessageBags);
    if (rawBags != null && rawBags.isNotEmpty) {
      final decoded = jsonDecode(rawBags);
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          final key = entry.key.toString();
          final value = entry.value;
          if (value is List) {
            messageBagSeen[key] = {
              for (final item in value)
                if (item is int)
                  item
                else if (item is num)
                  item.toInt(),
            };
          }
        }
      }
    }
  }

  Future<EndingMessagePick> recordRun({
    required int score,
    required int highestTierReached,
    required RunEnding ending,
    required Set<int> tiersCreatedThisRun,
    Random? random,
  }) async {
    final previousHighScore = highScore;
    final pick = EndingMessages.select(
      ctx: EndingMessageContext(
        ending: ending,
        peakTier: highestTierReached,
        score: score,
        previousHighScore: previousHighScore,
        tiersCreatedThisRun: tiersCreatedThisRun,
      ),
      firedMilestones: firedMilestones,
      bagSeen: messageBagSeen,
      lastMessageId: lastMessageId,
      random: random,
    );

    totalRuns += 1;
    lastEnding = ending;
    lastMessageId = pick.id;
    lastEndingLine = pick.text;

    if (score > highScore) {
      highScore = score;
    }
    if (highestTierReached > highestTier) {
      highestTier = highestTierReached;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(GameConstants.prefsTotalRuns, totalRuns);
    await prefs.setInt(GameConstants.prefsHighScore, highScore);
    await prefs.setInt(GameConstants.prefsHighestTier, highestTier);
    await prefs.setString(GameConstants.prefsLastEnding, ending.prefsValue);
    await prefs.setStringList(
      GameConstants.prefsFiredMilestones,
      firedMilestones.toList()..sort(),
    );
    await prefs.setString(
      GameConstants.prefsMessageBags,
      jsonEncode({
        for (final e in messageBagSeen.entries) e.key: e.value.toList()..sort(),
      }),
    );
    await prefs.setString(GameConstants.prefsLastMessageId, pick.id);

    return pick;
  }
}
