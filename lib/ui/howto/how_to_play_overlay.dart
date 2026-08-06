import 'package:flutter/material.dart';

import '../../game/systems/first_run_guide.dart';
import '../../theme/game_colors.dart';
import '../../theme/game_fonts.dart';

/// Non-blocking coach caption for the guided live first run.
/// Pointers pass through except the Skip control.
class HowToPlayOverlay extends StatelessWidget {
  const HowToPlayOverlay({
    super.key,
    required this.guide,
    required this.onSkip,
  });

  final FirstRunGuide guide;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                child: TextButton(
                  onPressed: onSkip,
                  child: Text(
                    'Skip',
                    style: GameFonts.ui(
                      fontSize: 14,
                      weight: FontWeight.w600,
                      color: GameColors.mutedText,
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0, 0.28),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ValueListenableBuilder<String?>(
                  valueListenable: guide.tipText,
                  builder: (_, text, _) {
                    if (text == null || text.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IgnorePointer(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: ConstrainedBox(
                          key: ValueKey(text),
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xCC0A0710),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: GameColors.rimMetal.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              child: Text(
                                text,
                                textAlign: TextAlign.center,
                                style: GameFonts.prose(
                                  fontSize: 15,
                                  height: 1.4,
                                  color: GameColors.scoreText
                                      .withValues(alpha: 0.92),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
