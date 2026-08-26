import 'package:flutter/material.dart';

import '../../game/challenge/challenge_progress.dart';
import '../../game/challenge/level_library.dart';
import '../../game/challenge/level_spec.dart';
import '../../game/modes/game_mode.dart';
import '../../game/modes/play_args.dart';
import '../../theme/game_colors.dart';
import '../../theme/game_fonts.dart';
import 'menu_page_scaffold.dart';

/// Level picker for Challenge. Levels unlock in play order — clearing one
/// unlocks the next (see [ChallengeProgress.isUnlocked]).
class ChallengeLevelSelectScreen extends StatefulWidget {
  const ChallengeLevelSelectScreen({super.key});

  @override
  State<ChallengeLevelSelectScreen> createState() =>
      _ChallengeLevelSelectScreenState();
}

class _ChallengeLevelSelectScreenState
    extends State<ChallengeLevelSelectScreen> {
  final LevelLibrary _library = LevelLibrary();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.wait([
      _library.loadAll(),
      ChallengeProgress.instance.load(),
    ]);
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _open(LevelSpec level) async {
    await Navigator.of(context).pushNamed(
      '/play',
      arguments: PlayArgs(mode: GameMode.challenge, challengeLevel: level),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MenuPageScaffold(
      title: 'Challenge',
      child: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: ChallengeProgress.instance,
              builder: (context, _) {
                final levels = _library.allLevels;
                if (levels.isEmpty) {
                  return Center(
                    child: Text(
                      'No levels yet.',
                      style: GameFonts.prose(
                        fontSize: 15,
                        color: GameColors.mutedText,
                      ),
                    ),
                  );
                }
                final playOrder = levels.map((l) => l.id).toList();
                return ListView.separated(
                  itemCount: levels.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final level = levels[index];
                    final progress = ChallengeProgress.instance;
                    final unlocked = progress.isUnlocked(level.id, playOrder);
                    final completed = progress.isCompleted(level.id);
                    final best = progress.bestShots(level.id);
                    return _LevelRow(
                      index: index + 1,
                      level: level,
                      unlocked: unlocked,
                      completed: completed,
                      bestShots: best,
                      onTap: unlocked ? () => _open(level) : null,
                    );
                  },
                );
              },
            ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.index,
    required this.level,
    required this.unlocked,
    required this.completed,
    required this.bestShots,
    required this.onTap,
  });

  final int index;
  final LevelSpec level;
  final bool unlocked;
  final bool completed;
  final int? bestShots;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dim = !unlocked;

    return Material(
      color: GameColors.spaceDeep.withValues(alpha: dim ? 0.4 : 0.75),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _NumberBadge(index: index, completed: completed, dim: dim),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.name,
                      style: GameFonts.ui(
                        fontSize: 16,
                        weight: FontWeight.w600,
                        color: dim ? GameColors.mutedText : GameColors.scoreText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      unlocked
                          ? _goalSummary(level)
                          : 'Locked — clear the previous level first',
                      style: GameFonts.prose(
                        fontSize: 13,
                        color: GameColors.mutedText,
                      ),
                    ),
                    if (unlocked) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Budget ${level.budgetShots}  ·  Par ${level.parShots}'
                        '${bestShots != null ? '  ·  Best $bestShots' : ''}',
                        style: GameFonts.label(fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!unlocked)
                const Icon(
                  Icons.lock_outline,
                  color: GameColors.mutedText,
                  size: 20,
                )
              else if (completed)
                Icon(
                  Icons.check_circle,
                  color: GameColors.chamberGlow,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({
    required this.index,
    required this.completed,
    required this.dim,
  });

  final int index;
  final bool completed;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final fill = completed
        ? GameColors.chamberGlow.withValues(alpha: 0.25)
        : GameColors.space;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(
          color: dim
              ? GameColors.mutedText.withValues(alpha: 0.4)
              : GameColors.rimMetal.withValues(alpha: 0.6),
          width: 1.4,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '$index',
        style: GameFonts.ui(
          fontSize: 14,
          weight: FontWeight.w600,
          color: dim ? GameColors.mutedText : GameColors.scoreText,
        ),
      ),
    );
  }
}

String _goalSummary(LevelSpec level) {
  return level.goals.map(_describeGoal).join(' · ');
}

String _describeGoal(LevelGoal goal) {
  return switch (goal) {
    ProduceGoal(:final element, :final count) =>
      'Produce $count× ${element.symbol}',
    BoardUnderGoal(:final value) => 'Board under $value',
    SurviveGoal(:final shots) => 'Survive $shots shots',
    EliminateGoal(:final element) => 'Eliminate all ${element.symbol}',
    CauseSupernovaGoal(:final count) => 'Cause $count× supernova',
  };
}
