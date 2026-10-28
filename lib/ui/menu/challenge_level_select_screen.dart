import 'package:flutter/material.dart';

import '../../game/challenge/challenge_brief.dart';
import '../../game/challenge/challenge_progress.dart';
import '../../game/challenge/level_library.dart';
import '../../game/challenge/level_spec.dart';
import '../../game/modes/game_mode.dart';
import '../../game/modes/play_args.dart';
import '../../game/systems/purchases_controller.dart';
import '../../game/systems/run_save_store.dart';
import '../../theme/game_colors.dart';
import '../../theme/game_fonts.dart';
import 'challenge_unlock_sheet.dart';
import 'continue_run_dialog.dart';
import 'menu_page_scaffold.dart';

/// Level picker for Challenge, grouped by pack. Each owned pack unlocks in
/// play order from its own first level (see [ChallengeProgress.isUnlocked]).
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
    var resume = false;
    if (await RunSaveStore.hasSaved(
      mode: GameMode.challenge,
      levelId: level.id,
    )) {
      if (!mounted) return;
      resume = await promptContinueRun(context);
      if (!mounted) return;
      if (!resume) {
        await RunSaveStore.clear(
          mode: GameMode.challenge,
          levelId: level.id,
        );
      }
    }
    if (!mounted) return;
    await Navigator.of(context).pushNamed(
      '/play',
      arguments: PlayArgs(
        mode: GameMode.challenge,
        challengeLevel: level,
        resumeSavedRun: resume,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MenuPageScaffold(
      title: 'Challenge',
      child: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: Listenable.merge([
                ChallengeProgress.instance,
                PurchasesController.instance,
              ]),
              builder: (context, _) {
                final packs = [
                  for (var n = 1; _library.pack(n) != null; n++)
                    _library.pack(n)!,
                ];
                if (packs.isEmpty) {
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
                final purchases = PurchasesController.instance;
                final progress = ChallengeProgress.instance;
                return ListView(
                  children: [
                    for (final pack in packs) ...[
                      _PackHeader(
                        pack: pack.pack,
                        owned: purchases.ownsPack(pack.pack),
                        onUnlock: () =>
                            showPackUnlockSheet(context, pack: pack.pack),
                      ),
                      const SizedBox(height: 12),
                      for (final (i, level) in pack.levels.indexed) ...[
                        _levelRow(
                          index: i + 1,
                          level: level,
                          owned: purchases.ownsPack(pack.pack),
                          playOrder: [for (final l in pack.levels) l.id],
                          progress: progress,
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 18),
                    ],
                  ],
                );
              },
            ),
    );
  }

  Widget _levelRow({
    required int index,
    required LevelSpec level,
    required bool owned,
    required List<String> playOrder,
    required ChallengeProgress progress,
  }) {
    final unlocked = owned && progress.isUnlocked(level.id, playOrder);
    return _LevelRow(
      index: index,
      level: level,
      unlocked: unlocked,
      lockedReason: owned
          ? 'Locked — clear the previous level first'
          : 'Unlock Pack ${level.pack} to play',
      completed: progress.isCompleted(level.id),
      bestShots: progress.bestShots(level.id),
      onTap: unlocked ? () => _open(level) : null,
    );
  }
}

class _PackHeader extends StatelessWidget {
  const _PackHeader({
    required this.pack,
    required this.owned,
    required this.onUnlock,
  });

  final int pack;
  final bool owned;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text('PACK $pack', style: GameFonts.label(fontSize: 12)),
        ),
        if (!owned)
          ElevatedButton(
            onPressed: onUnlock,
            child: const Text('Unlock'),
          ),
      ],
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.index,
    required this.level,
    required this.unlocked,
    required this.lockedReason,
    required this.completed,
    required this.bestShots,
    required this.onTap,
  });

  final int index;
  final LevelSpec level;
  final bool unlocked;
  final String lockedReason;
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
                          ? challengeLevelSummary(level)
                          : lockedReason,
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

