import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../content/endings/kilonova_messages.dart';
import '../constants.dart';
import '../modes/game_mode.dart';
import 'ending_messages.dart';

class ScoreStore {
  ScoreStore({this.mode = GameMode.classic});

  GameMode mode;

  int highScore = 0;
  int highestTier = 0;
  int totalRuns = 0;
  RunEnding? lastEnding;

  /// Collapse board: lexicographic (kilonovas desc, then shots asc).
  int bestKilonovas = 0;
  int bestShots = 0;
  bool hasCollapseBest = false;

  final Set<String> firedMilestones = {};
  final Map<String, Set<int>> messageBagSeen = {};
  String? lastMessageId;
  String? lastEndingLine;

  String get _scoreKey => mode.scoreKey;
  String get _tierKey => mode.highestTierKey;
  String get _kilonovaKey => 'kilonovas_${mode.name}';
  String get _shotsKey => 'shots_${mode.name}';

  String get collapseBestLabel {
    if (!hasCollapseBest) return '';
    return 'Kilonovas $bestKilonovas · $bestShots shots';
  }

  /// HUD best: the better of the saved record and the score of this run.
  int displayedHighScore(int currentScore) =>
      currentScore > highScore ? currentScore : highScore;

  static int compareCollapse({
    required int aKilonovas,
    required int aShots,
    required int bKilonovas,
    required int bShots,
  }) {
    final byKilonova = bKilonovas.compareTo(aKilonovas);
    if (byKilonova != 0) return byKilonova;
    return aShots.compareTo(bShots);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    highScore = prefs.getInt(_scoreKey) ??
        (mode == GameMode.classic
            ? prefs.getInt(GameConstants.prefsHighScore) ?? 0
            : 0);
    highestTier = prefs.getInt(_tierKey) ??
        (mode == GameMode.classic
            ? prefs.getInt(GameConstants.prefsHighestTier) ?? 0
            : 0);
    bestKilonovas = prefs.getInt(_kilonovaKey) ?? 0;
    bestShots = prefs.getInt(_shotsKey) ?? 0;
    hasCollapseBest = mode == GameMode.collapse &&
        (bestKilonovas > 0 || prefs.containsKey(_kilonovaKey));
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
    int supernovaCount = 0,
    int kilonovaCount = 0,
    int shotCount = 0,
    bool voluntaryEnd = false,
    Random? random,
  }) async {
    final previousHighScore = highScore;
    final rng = random ?? Random();

    final EndingMessagePick pick;
    if (ending == RunEnding.kilonova) {
      pick = _selectKilonova(
        kilonovaCount: kilonovaCount,
        voluntaryEnd: voluntaryEnd,
        rng: rng,
      );
    } else {
      pick = EndingMessages.select(
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
        random: rng,
      );
    }

    totalRuns += 1;
    lastEnding = ending;
    lastMessageId = pick.id;
    lastEndingLine = pick.text;

    if (mode == GameMode.collapse) {
      final better = !hasCollapseBest ||
          compareCollapse(
                aKilonovas: kilonovaCount,
                aShots: shotCount,
                bKilonovas: bestKilonovas,
                bShots: bestShots,
              ) <
              0;
      if (better) {
        bestKilonovas = kilonovaCount;
        bestShots = shotCount;
        hasCollapseBest = true;
      }
      // Keep a scalar highScore as total points for legacy UI paths.
      if (score > highScore) highScore = score;
    } else {
      if (score > highScore) {
        highScore = score;
      }
    }

    if (highestTierReached > highestTier) {
      highestTier = highestTierReached;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(GameConstants.prefsTotalRuns, totalRuns);
    await prefs.setInt(_scoreKey, highScore);
    await prefs.setInt(_tierKey, highestTier);
    if (mode == GameMode.collapse && hasCollapseBest) {
      await prefs.setInt(_kilonovaKey, bestKilonovas);
      await prefs.setInt(_shotsKey, bestShots);
    }
    if (mode == GameMode.classic) {
      await prefs.setInt(GameConstants.prefsHighScore, highScore);
      await prefs.setInt(GameConstants.prefsHighestTier, highestTier);
    }
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

  EndingMessagePick _selectKilonova({
    required int kilonovaCount,
    required bool voluntaryEnd,
    required Random rng,
  }) {
    final milestoneId = KilonovaMessages.milestoneFor(
      kilonovaCount: kilonovaCount,
      voluntaryEnd: voluntaryEnd,
      fired: firedMilestones,
    );
    if (milestoneId != null) {
      firedMilestones.add(milestoneId);
      return EndingMessagePick(
        id: 'milestone:$milestoneId',
        text: KilonovaMessages.milestones[milestoneId]!,
      );
    }

    final drawn = KilonovaMessages.drawPool(
      kilonovaCount: kilonovaCount,
      bagSeen: messageBagSeen,
      rng: rng,
      lastMessageId: lastMessageId,
    );
    return EndingMessagePick(id: drawn.id, text: drawn.text);
  }
}
