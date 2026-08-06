import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/systems/leaderboard_service.dart';
import '../../theme/game_colors.dart';
import '../../theme/game_fonts.dart';

/// Asks for a leaderboard name. Returns sanitized name, or null if cancelled.
Future<String?> promptDisplayName(
  BuildContext context, {
  String? initial,
}) async {
  final controller = TextEditingController(text: initial ?? '');
  String? error;

  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            backgroundColor: GameColors.spaceDeep,
            title: Text(
              'Choose a name',
              style: GameFonts.ui(fontSize: 18, weight: FontWeight.w600),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Shown on daily and all-time boards. Saved on this device.',
                  style: GameFonts.prose(
                    fontSize: 14,
                    color: GameColors.mutedText,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: LeaderboardService.maxDisplayNameLength,
                  textInputAction: TextInputAction.done,
                  style: GameFonts.ui(fontSize: 16),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r"[\w .'\-]", unicode: true),
                    ),
                  ],
                  decoration: InputDecoration(
                    hintText: 'Name',
                    hintStyle: GameFonts.ui(
                      fontSize: 16,
                      color: GameColors.mutedText.withValues(alpha: 0.5),
                    ),
                    errorText: error,
                    counterStyle: GameFonts.ui(
                      fontSize: 11,
                      color: GameColors.mutedText,
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: GameColors.rimMetal),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: GameColors.chamberGlow),
                    ),
                  ),
                  onSubmitted: (_) {
                    final cleaned =
                        LeaderboardService.sanitizeDisplayName(controller.text);
                    if (cleaned == null) {
                      setLocal(() => error = '1–16 characters');
                      return;
                    }
                    Navigator.of(ctx).pop(cleaned);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'Not now',
                  style: GameFonts.ui(
                    fontSize: 14,
                    weight: FontWeight.w600,
                    color: GameColors.mutedText,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  final cleaned =
                      LeaderboardService.sanitizeDisplayName(controller.text);
                  if (cleaned == null) {
                    setLocal(() => error = '1–16 characters');
                    return;
                  }
                  Navigator.of(ctx).pop(cleaned);
                },
                child: Text(
                  'Save',
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
    },
  );

  controller.dispose();
  return result;
}
