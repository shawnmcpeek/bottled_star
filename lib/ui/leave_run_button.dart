import 'package:flutter/material.dart';

import '../game/bottled_star_game.dart';
import '../theme/game_colors.dart';
import '../theme/game_fonts.dart';

/// Leaves the current run and returns to mode select. Confirms first.
class LeaveRunButton extends StatelessWidget {
  const LeaveRunButton({super.key, required this.game});

  final BottledStarGame game;

  Future<void> _confirm(BuildContext context) async {
    game.pauseEngine();
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: GameColors.spaceDeep,
          title: Text(
            'Leave this run?',
            style: GameFonts.ui(fontSize: 18, weight: FontWeight.w600),
          ),
          content: Text(
            'Progress will be lost. This run will not be saved.',
            style: GameFonts.ui(
              fontSize: 14,
              color: GameColors.mutedText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Keep playing',
                style: GameFonts.ui(
                  fontSize: 14,
                  weight: FontWeight.w600,
                  color: GameColors.mutedText,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Leave',
                style: GameFonts.ui(
                  fontSize: 14,
                  weight: FontWeight.w600,
                  color: GameColors.rimWarning,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (leave == true) {
      if (context.mounted) Navigator.of(context).pop();
      return;
    }
    game.resumeEngine();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: game.gameOverNotifier,
      builder: (_, over, _) {
        if (over) return const SizedBox.shrink();
        return IconButton(
          onPressed: () => _confirm(context),
          tooltip: 'Leave run',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: Icon(
            Icons.close_rounded,
            color: GameColors.mutedText.withValues(alpha: 0.85),
            size: 22,
          ),
        );
      },
    );
  }
}
