import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/bottled_star_game.dart';
import '../game/constants.dart';
import '../game/element_art.dart';
import '../game/element_tier.dart';
import '../game/modes/game_mode.dart';
import '../game/systems/first_run_guide.dart';
import '../game/systems/leaderboard_service.dart';
import '../game/systems/score_store.dart';
import '../game/systems/settings_store.dart';
import '../theme/game_colors.dart';
import '../theme/game_fonts.dart';
import 'howto/how_to_play_overlay.dart';
import 'menu/display_name_dialog.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.mode = GameMode.classic});

  final GameMode mode;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final ScoreStore _scoreStore;
  late final SettingsStore _settings;
  late final BottledStarGame _game;
  FirstRunGuide? _guide;
  bool _showGuide = false;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    _scoreStore = ScoreStore(mode: widget.mode);
    _settings = SettingsStore();
    _game = BottledStarGame(scoreStore: _scoreStore, mode: widget.mode);
    _game.gameOverNotifier.addListener(_onGameOverChanged);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _settings.load();
    if (!mounted) return;
    if (!_settings.howToPlaySeen) {
      final guide = FirstRunGuide(onCompleted: _finishGuide);
      _game.firstRunGuide = guide;
      setState(() {
        _guide = guide;
        _showGuide = true;
        _bootstrapped = true;
      });
    } else {
      setState(() => _bootstrapped = true);
    }
  }

  Future<void> _finishGuide() async {
    await _settings.markHowToPlaySeen();
    if (!mounted) return;
    _game.firstRunGuide = null;
    final guide = _guide;
    setState(() {
      _showGuide = false;
      _guide = null;
    });
    if (guide != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        guide.dispose();
      });
    }
  }

  void _skipGuide() {
    _guide?.skip();
  }

  void _onGameOverChanged() {
    if (_game.gameOverNotifier.value) {
      _game.overlays.add('ending');
    } else {
      _game.overlays.remove('ending');
    }
  }

  @override
  void dispose() {
    _game.gameOverNotifier.removeListener(_onGameOverChanged);
    _game.firstRunGuide = null;
    _guide?.dispose();
    _game.pauseEngine();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        autofocus: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GameWidget(
              game: _game,
              overlayBuilderMap: {
                'hud': (_, _) => HudOverlay(game: _game),
                'ending': (_, _) => EndingOverlay(game: _game),
              },
              initialActiveOverlays: const ['hud'],
            ),
            ValueListenableBuilder<double>(
              valueListenable: _game.flashNotifier,
              builder: (_, flash, _) {
                if (flash <= 0.01) return const SizedBox.shrink();
                return IgnorePointer(
                  child: ColoredBox(
                    color: Colors.white.withValues(alpha: flash * 0.9),
                  ),
                );
              },
            ),
            if (_bootstrapped && _showGuide && _guide != null)
              HowToPlayOverlay(
                guide: _guide!,
                onSkip: _skipGuide,
              ),
          ],
        ),
      ),
    );
  }
}

class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key, required this.game});

  final BottledStarGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: game.scoreNotifier,
                    builder: (_, score, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SCORE', style: GameFonts.label()),
                          Text(
                            '$score',
                            style: GameFonts.score(weight: FontWeight.w500),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('BEST', style: GameFonts.label()),
                    ValueListenableBuilder<int>(
                      valueListenable: game.highScoreNotifier,
                      builder: (_, best, _) {
                        return Text(
                          '$best',
                          style: GameFonts.score(
                            fontSize: 22,
                            weight: FontWeight.w500,
                            color: GameColors.rimMetal,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    ValueListenableBuilder<String>(
                      valueListenable: game.bestElementNotifier,
                      builder: (_, symbol, _) {
                        return Text(
                          'PEAK  $symbol',
                          style: GameFonts.label(fontSize: 12),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            ValueListenableBuilder<ElementTier?>(
              valueListenable: game.lastUnlockNotifier,
              builder: (_, tier, _) {
                if (tier == null || tier.tier < ElementTier.carbon.tier) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '${tier.symbol}  ·  ${tier.displayName}',
                    style: GameFonts.ui(
                      fontSize: 14,
                      weight: FontWeight.w600,
                      color: GameColors.chamberGlow.withValues(alpha: 0.85),
                      letterSpacing: 0.8,
                    ),
                  ),
                );
              },
            ),
            ShotPreviewRow(game: game),
            const SizedBox(height: 10),
            Text(
              'Drag to aim  ·  Hold to charge  ·  Release to inject',
              textAlign: TextAlign.center,
              style: GameFonts.ui(
                fontSize: 12,
                weight: FontWeight.w500,
                color: GameColors.mutedText.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShotPreviewRow extends StatelessWidget {
  const ShotPreviewRow({super.key, required this.game});

  final BottledStarGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ElementTier>(
      valueListenable: game.currentShotNotifier,
      builder: (_, current, _) {
        return ValueListenableBuilder<ElementTier>(
          valueListenable: game.nextShotNotifier,
          builder: (_, next, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ShotChip(label: 'NOW', tier: current, emphasis: true),
                const SizedBox(width: 18),
                _ShotChip(label: 'NEXT', tier: next, emphasis: false),
              ],
            );
          },
        );
      },
    );
  }
}

class _ShotChip extends StatelessWidget {
  const _ShotChip({
    required this.label,
    required this.tier,
    required this.emphasis,
  });

  final String label;
  final ElementTier tier;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final fill = TierPalette.fills[tier.tier];
    final size = emphasis ? 52.0 : 40.0;
    final symbolSize = emphasis
        ? (tier.symbol.length > 1 ? 16.0 : 18.0)
        : (tier.symbol.length > 1 ? 12.0 : 14.0);
    final artPath = ElementArt.assetPath(tier);

    final Widget chipFace;
    if (artPath != null) {
      chipFace = ClipOval(
        child: Image.asset(
          artPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      );
    } else {
      chipFace = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.35, -0.4),
            colors: [
              Color.lerp(fill, const Color(0xFFFFFFFF), 0.55)!,
              fill,
              Color.lerp(fill, const Color(0xFF1A0508), 0.3)!,
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          tier.symbol,
          style: GameFonts.symbol(
            fontSize: symbolSize,
            multiLetter: tier.symbol.length > 1,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: GameFonts.label(fontSize: 10)),
        const SizedBox(height: 6),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: fill.withValues(alpha: emphasis ? 0.55 : 0.3),
                blurRadius: emphasis ? 16 : 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: chipFace,
        ),
      ],
    );
  }
}

class EndingOverlay extends StatelessWidget {
  const EndingOverlay({super.key, required this.game});

  final BottledStarGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: game.endingCardNotifier,
      builder: (_, showCard, _) {
        if (!showCard) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: game.world.trySkipEnding,
            child: const ColoredBox(color: Color(0x00000000)),
          );
        }

        return ValueListenableBuilder<RunEnding?>(
          valueListenable: game.endingNotifier,
          builder: (_, ending, _) {
            if (ending == null) return const SizedBox.shrink();
            return _EndingCard(game: game, ending: ending);
          },
        );
      },
    );
  }
}

class _EndingCard extends StatefulWidget {
  const _EndingCard({required this.game, required this.ending});

  final BottledStarGame game;
  final RunEnding ending;

  @override
  State<_EndingCard> createState() => _EndingCardState();
}

class _EndingCardState extends State<_EndingCard> {
  final SettingsStore _settings = SettingsStore();
  final LeaderboardService _boards = LeaderboardService();
  bool _submitStarted = false;
  String? _boardStatus;

  bool get _isSupernova => widget.ending == RunEnding.supernova;
  bool get _isBlackHole => widget.ending == RunEnding.blackHole;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeSubmit());
  }

  Future<void> _maybeSubmit() async {
    if (_submitStarted || !mounted) return;
    _submitStarted = true;

    final score = widget.game.scoreNotifier.value;
    if (score <= 0) return;

    await _settings.load();
    if (!mounted) return;

    var name = _settings.displayName;
    if (name == null || name.isEmpty) {
      name = await promptDisplayName(context);
      if (!mounted) return;
      if (name == null) {
        setState(() => _boardStatus = 'Score kept local');
        return;
      }
      await _settings.setDisplayName(name);
    }

    setState(() => _boardStatus = 'Submitting…');
    final result = await _boards.submitBest(
      score: score,
      displayName: name,
      peakTier: widget.game.peakTierNotifier.value,
      ending: widget.ending.name,
    );
    if (!mounted) return;

    setState(() {
      _boardStatus = switch (result) {
        LeaderboardSubmitResult.submitted => 'Posted to boards',
        LeaderboardSubmitResult.notImproved => 'Personal best unchanged',
        LeaderboardSubmitResult.invalidName => 'Name not accepted',
        LeaderboardSubmitResult.rejected => 'Score rejected',
        LeaderboardSubmitResult.unavailable => 'Board offline — kept local',
      };
    });
  }

  String get _eyebrow => _isBlackHole
      ? 'EVENT HORIZON'
      : _isSupernova
          ? 'CORE COLLAPSE'
          : 'CONTAINMENT LOST';

  String get _title => _isBlackHole
      ? 'COLLAPSE'
      : _isSupernova
          ? 'SUPERNOVA'
          : 'WHITE DWARF';

  Color get _eyebrowColor => _isBlackHole || _isSupernova
      ? GameColors.rimWarning
      : GameColors.mutedText;

  @override
  Widget build(BuildContext context) {
    final peak = ElementTier.fromTier(widget.game.peakTierNotifier.value);
    final remnant = widget.game.world.remnant?.state;
    final screenW = MediaQuery.sizeOf(context).width;
    final maxW = screenW * 0.8;

    return ColoredBox(
      color: const Color(0x99050308),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _eyebrow,
                    style: GameFonts.endingEyebrow(color: _eyebrowColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _title,
                    style: GameFonts.endingTitle(),
                  ),
                  const SizedBox(height: 24),
                  if (_isBlackHole) ...[
                    Text(
                      '${remnant?.supernovaCount ?? 0} supernovae  ·  '
                      '${remnant?.consumedCount ?? 0} nuclei consumed',
                      textAlign: TextAlign.center,
                      style: GameFonts.ui(
                        fontSize: 14,
                        weight: FontWeight.w500,
                        color: GameColors.mutedText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<int>(
                      valueListenable: widget.game.scoreNotifier,
                      builder: (_, score, _) =>
                          _StatLine(label: 'Score', value: '$score'),
                    ),
                  ] else ...[
                    _StatLine(
                      label: 'Peak element',
                      value: '${peak.symbol} · ${peak.displayName}',
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<int>(
                      valueListenable: widget.game.scoreNotifier,
                      builder: (_, score, _) =>
                          _StatLine(label: 'Score', value: '$score'),
                    ),
                  ],
                  const SizedBox(height: 22),
                  ValueListenableBuilder<String?>(
                    valueListenable: widget.game.endingLineNotifier,
                    builder: (_, line, _) => _FadingEndingLine(text: line ?? ''),
                  ),
                  if (_boardStatus != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _boardStatus!,
                      textAlign: TextAlign.center,
                      style: GameFonts.ui(
                        fontSize: 12,
                        color: GameColors.mutedText.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.game.restart,
                      child: const Text('Inject again'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Menu',
                      style: GameFonts.ui(
                        fontSize: 15,
                        weight: FontWeight.w600,
                        color: GameColors.mutedText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FadingEndingLine extends StatefulWidget {
  const _FadingEndingLine({required this.text});

  final String text;

  @override
  State<_FadingEndingLine> createState() => _FadingEndingLineState();
}

class _FadingEndingLineState extends State<_FadingEndingLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    // Land on fixed stats first, then fade the variable line.
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didUpdateWidget(covariant _FadingEndingLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();
    return FadeTransition(
      opacity: _opacity,
      child: Text(
        widget.text,
        textAlign: TextAlign.center,
        softWrap: true,
        style: GameFonts.prose(fontSize: 15, height: 1.4),
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
    final counting = label.toLowerCase() == 'score';
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
        Text(
          value,
          style: counting
              ? GameFonts.score(
                  fontSize: 18,
                  weight: FontWeight.w500,
                )
              : GameFonts.ui(
                  fontSize: 18,
                  weight: FontWeight.w600,
                ),
        ),
      ],
    );
  }
}
