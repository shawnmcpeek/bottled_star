import 'package:flutter/material.dart';

import '../game/bottled_star_game.dart';
import '../game/challenge/challenge_progress.dart';
import '../game/challenge/challenge_run.dart';
import '../game/challenge/level_library.dart';
import '../game/challenge/level_spec.dart';
import '../game/modes/game_mode.dart';
import '../game/modes/play_args.dart';
import '../theme/game_colors.dart';
import '../theme/game_fonts.dart';
import 'menu/menu_page_scaffold.dart';

class ChallengeEndOverlay extends StatelessWidget {
  const ChallengeEndOverlay({super.key, required this.game});

  final BottledStarGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ChallengeRunStatus?>(
      valueListenable: game.challengeStatusNotifier,
      builder: (_, status, _) {
        if (status == null) return const SizedBox.shrink();
        return _ChallengeEndCard(game: game, status: status);
      },
    );
  }
}

class _ChallengeEndCard extends StatefulWidget {
  const _ChallengeEndCard({required this.game, required this.status});

  final BottledStarGame game;
  final ChallengeRunStatus status;

  @override
  State<_ChallengeEndCard> createState() => _ChallengeEndCardState();
}

class _ChallengeEndCardState extends State<_ChallengeEndCard> {
  LevelSpec? _next;
  bool _nextReady = false;

  bool get _won => widget.status == ChallengeRunStatus.won;

  @override
  void initState() {
    super.initState();
    _loadNext();
  }

  Future<void> _loadNext() async {
    final current = widget.game.challengeLevel;
    if (current == null) {
      if (mounted) setState(() => _nextReady = true);
      return;
    }
    final library = LevelLibrary();
    await library.loadAll();
    if (!mounted) return;
    setState(() {
      _next = library.nextAfter(current.id);
      _nextReady = true;
    });
  }

  void _levelSelect() {
    Navigator.of(context).pop();
  }

  void _quit() {
    Navigator.of(
      context,
    ).popUntil((route) => route.settings.name == '/mode' || route.isFirst);
  }

  Future<void> _nextLevel() async {
    var next = _next;
    if (!_nextReady) {
      final current = widget.game.challengeLevel;
      if (current != null) {
        final library = LevelLibrary();
        await library.loadAll();
        next = library.nextAfter(current.id);
      }
    }
    if (!mounted) return;
    if (next == null) {
      _levelSelect();
      return;
    }
    Navigator.of(context).pushReplacementNamed(
      '/play',
      arguments: PlayArgs(mode: GameMode.challenge, challengeLevel: next),
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.game.challengeLevel;
    if (level == null) return const SizedBox.shrink();
    final shots = widget.game.world.shotCount;
    final best = ChallengeProgress.instance.bestShots(level.id);
    final failMessage = widget.game.world.challengeTracker?.failMessage;
    final screenW = MediaQuery.sizeOf(context).width;
    final accent = _won ? GameColors.chamberGlow : GameColors.rimWarning;

    return ColoredBox(
      color: _won
          ? GameColors.challengeWinScrim
          : GameColors.challengeFailScrim,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: screenW * 0.8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _won
                      ? GameColors.challengeWinPanel
                      : GameColors.challengeFailPanel,
                  border: Border.all(color: accent),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _won ? 'CLEARED' : 'FAILED',
                        style: GameFonts.endingEyebrow(color: accent),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        level.name,
                        textAlign: TextAlign.center,
                        style: GameFonts.endingTitle(
                          color: _won
                              ? GameColors.scoreText
                              : GameColors.rimWarning,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _won
                            ? 'The vessel holds. Advance.'
                            : (failMessage ??
                                  'A constraint broke. The vessel is lost.'),
                        textAlign: TextAlign.center,
                        style: GameFonts.prose(
                          fontSize: 14,
                          color: GameColors.mutedText,
                        ),
                      ),
                      if (_won) ...[
                        const SizedBox(height: 22),
                        _StatLine(label: 'Shots used', value: '$shots'),
                        const SizedBox(height: 10),
                        _StatLine(label: 'Par', value: '${level.parShots}'),
                        if (best != null) ...[
                          const SizedBox(height: 10),
                          _StatLine(label: 'Best', value: '$best'),
                        ],
                      ],
                      const SizedBox(height: 32),
                      if (_won) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _nextLevel,
                            child: Text(
                              _next == null && _nextReady
                                  ? 'Level Select'
                                  : 'Next',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        MenuLinkButton(
                          label: 'Retry',
                          onPressed: widget.game.restart,
                        ),
                        MenuLinkButton(
                          label: 'Level Select',
                          onPressed: _levelSelect,
                        ),
                        MenuLinkButton(label: 'Quit', onPressed: _quit),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: widget.game.restart,
                            child: const Text('Retry'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        MenuLinkButton(
                          label: 'Level Select',
                          onPressed: _levelSelect,
                        ),
                        MenuLinkButton(label: 'Quit', onPressed: _quit),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GameFonts.ui(
              fontSize: 14,
              weight: FontWeight.w500,
              color: GameColors.mutedText,
            ),
          ),
        ),
        Text(value, style: GameFonts.ui(fontSize: 18, weight: FontWeight.w600)),
      ],
    );
  }
}
