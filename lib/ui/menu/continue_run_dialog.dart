import 'package:flutter/material.dart';

import '../../theme/game_colors.dart';
import '../../theme/game_fonts.dart';

/// Returns true to resume the saved run, false to discard it and start new.
Future<bool> promptContinueRun(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: GameColors.spaceDeep,
        title: Text(
          'Continue last game?',
          style: GameFonts.ui(fontSize: 18, weight: FontWeight.w600),
        ),
        content: Text(
          'Do you want to continue your last game or start a new one?',
          style: GameFonts.ui(
            fontSize: 14,
            color: GameColors.mutedText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'New game',
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
              'Continue',
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
  return result ?? false;
}
