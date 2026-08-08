import 'package:flutter/material.dart';

import '../theme/game_colors.dart';
import '../theme/game_fonts.dart';

/// Collapse-only voluntary end control. Bottom-left, away from the injector.
class QuietEndButton extends StatelessWidget {
  const QuietEndButton({
    super.key,
    required this.kilonovaCount,
    required this.shotCount,
    required this.onConfirmEnd,
  });

  final int kilonovaCount;
  final int shotCount;
  final VoidCallback onConfirmEnd;

  Future<void> _confirm(BuildContext context) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: GameColors.spaceDeep,
          title: Text(
            'End the run here?',
            style: GameFonts.ui(fontSize: 18, weight: FontWeight.w600),
          ),
          content: Text(
            'Kilonovas: $kilonovaCount  ·  Shots: $shotCount',
            style: GameFonts.ui(
              fontSize: 14,
              color: GameColors.mutedText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Keep going',
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
                'Let it go',
                style: GameFonts.ui(
                  fontSize: 14,
                  weight: FontWeight.w600,
                  color: GameColors.chamberGlow,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (go == true) onConfirmEnd();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 72),
          child: TextButton(
            onPressed: () => _confirm(context),
            style: TextButton.styleFrom(
              foregroundColor: GameColors.mutedText.withValues(alpha: 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            child: Text(
              'Let it go quiet',
              style: GameFonts.ui(
                fontSize: 13,
                weight: FontWeight.w500,
                color: GameColors.mutedText.withValues(alpha: 0.75),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
