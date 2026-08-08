import 'package:flutter/material.dart';

import '../../game/modes/game_mode.dart';
import '../../game/systems/score_store.dart';
import '../../theme/game_colors.dart';
import '../../theme/game_fonts.dart';
import 'menu_page_scaffold.dart';

class ModeSelectScreen extends StatefulWidget {
  const ModeSelectScreen({super.key});

  @override
  State<ModeSelectScreen> createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends State<ModeSelectScreen> {
  final ScoreStore _classicScores = ScoreStore(mode: GameMode.classic);
  final ScoreStore _collapseScores = ScoreStore(mode: GameMode.collapse);
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.wait([_classicScores.load(), _collapseScores.load()]);
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _open(GameMode mode) async {
    await Navigator.of(context).pushNamed('/play', arguments: mode);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return MenuPageScaffold(
      title: 'Play',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose a mode',
                textAlign: TextAlign.center,
                style: GameFonts.prose(
                  fontSize: 16,
                  color: GameColors.mutedText,
                ),
              ),
              const SizedBox(height: 28),
          _ModeCard(
            mode: GameMode.classic,
            bestLabel: _ready && _classicScores.highScore > 0
                ? 'Best  ${_classicScores.highScore}'
                : null,
            onTap: () => _open(GameMode.classic),
          ),
          const SizedBox(height: 18),
          _ModeCard(
            mode: GameMode.collapse,
            bestLabel: _ready && _collapseScores.hasCollapseBest
                ? 'Best  ${_collapseScores.collapseBestLabel}'
                : null,
            onTap: () => _open(GameMode.collapse),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.onTap,
    this.bestLabel,
  });

  final GameMode mode;
  final VoidCallback onTap;
  final String? bestLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                mode.label,
                textAlign: TextAlign.center,
                style: GameFonts.ui(
                  fontSize: 22,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                mode.blurb,
                textAlign: TextAlign.center,
                style: GameFonts.prose(
                  fontSize: 15,
                  color: GameColors.mutedText,
                ),
              ),
              if (bestLabel != null) ...[
                const SizedBox(height: 10),
                Text(
                  bestLabel!,
                  textAlign: TextAlign.center,
                  style: GameFonts.ui(
                    fontSize: 13,
                    weight: FontWeight.w500,
                    color: GameColors.mutedText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
