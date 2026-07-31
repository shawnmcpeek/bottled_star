import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/bottled_star_game.dart';
import '../game/constants.dart';
import '../game/element_tier.dart';
import '../game/systems/score_store.dart';
import '../theme/game_colors.dart';
import '../theme/game_fonts.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final ScoreStore _scoreStore;
  late final BottledStarGame _game;

  @override
  void initState() {
    super.initState();
    _scoreStore = ScoreStore();
    _game = BottledStarGame(scoreStore: _scoreStore);
    _game.gameOverNotifier.addListener(_onGameOverChanged);
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
            gradient: RadialGradient(
              center: const Alignment(-0.35, -0.4),
              colors: [
                Color.lerp(fill, const Color(0xFFFFFFFF), 0.55)!,
                fill,
                Color.lerp(fill, const Color(0xFF1A0508), 0.3)!,
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: fill.withValues(alpha: emphasis ? 0.55 : 0.3),
                blurRadius: emphasis ? 16 : 10,
                spreadRadius: 1,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            tier.symbol,
            style: GameFonts.symbol(
              fontSize: symbolSize,
              multiLetter: tier.symbol.length > 1,
            ),
          ),
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
            return ending == RunEnding.supernova
                ? _SupernovaCard(game: game)
                : _WhiteDwarfCard(game: game);
          },
        );
      },
    );
  }
}

class _WhiteDwarfCard extends StatelessWidget {
  const _WhiteDwarfCard({required this.game});

  final BottledStarGame game;

  @override
  Widget build(BuildContext context) {
    final peak = ElementTier.fromTier(game.peakTierNotifier.value);
    return ColoredBox(
      color: const Color(0x99050308),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CONTAINMENT LOST',
                    style: GameFonts.endingEyebrow(),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Your star was not massive enough to reach iron.\n'
                    'The envelope drifted away over ten thousand years.\n'
                    'What remains will cool, quietly, for longer than\n'
                    'the universe has existed so far.',
                    textAlign: TextAlign.center,
                    style: GameFonts.prose(),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'WHITE DWARF',
                    style: GameFonts.endingTitle(),
                  ),
                  const SizedBox(height: 24),
                  _StatLine(
                    label: 'Peak element',
                    value: '${peak.symbol} · ${peak.displayName}',
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<int>(
                    valueListenable: game.scoreNotifier,
                    builder: (_, score, _) =>
                        _StatLine(label: 'Score', value: '$score'),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: game.restart,
                      child: const Text('Inject again'),
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

class _SupernovaCard extends StatelessWidget {
  const _SupernovaCard({required this.game});

  final BottledStarGame game;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x99050308),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CORE COLLAPSE',
                    style: GameFonts.endingEyebrow(
                      color: GameColors.rimWarning,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Iron cannot fuse. The core gave way and the star\n'
                    'tore itself apart in seconds.\n\n'
                    'Everything heavier than iron in the universe was\n'
                    'made in a moment like this one. The gold in the\n'
                    'ground. The iodine in your blood.',
                    textAlign: TextAlign.center,
                    style: GameFonts.prose(),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'SUPERNOVA',
                    style: GameFonts.endingTitle(),
                  ),
                  const SizedBox(height: 24),
                  const _StatLine(
                    label: 'Peak element',
                    value: 'Fe · Iron',
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<int>(
                    valueListenable: game.scoreNotifier,
                    builder: (_, score, _) =>
                        _StatLine(label: 'Score', value: '$score'),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: game.restart,
                      child: const Text('Inject again'),
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
