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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose a mode',
            style: GameFonts.prose(
              fontSize: 16,
              color: GameColors.mutedText,
            ),
          ),
          const SizedBox(height: 22),
          _ModeCard(
            mode: GameMode.classic,
            best: _ready ? _classicScores.highScore : null,
            onTap: () => _open(GameMode.classic),
          ),
          const SizedBox(height: 14),
          _ModeCard(
            mode: GameMode.collapse,
            best: _ready ? _collapseScores.highScore : null,
            onTap: () => _open(GameMode.collapse),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.onTap,
    this.best,
  });

  final GameMode mode;
  final VoidCallback onTap;
  final int? best;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mode.label,
                style: GameFonts.ui(
                  fontSize: 22,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                mode.blurb,
                style: GameFonts.prose(
                  fontSize: 15,
                  color: GameColors.mutedText,
                ),
              ),
              if (best != null && best! > 0) ...[
                const SizedBox(height: 10),
                Text(
                  'Best  $best',
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
