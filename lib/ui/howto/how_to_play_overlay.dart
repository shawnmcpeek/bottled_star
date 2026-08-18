import 'package:flutter/material.dart';

import '../../game/systems/first_run_guide.dart';
import '../../theme/game_colors.dart';
import '../../theme/game_fonts.dart';

/// Non-blocking coach caption for the guided live first run.
///
/// Only [skipButtonKey] participates in hit testing. Everything else is
/// [IgnorePointer] so Flame's drag recognizer can still aim/inject.
class HowToPlayOverlay extends StatelessWidget {
  const HowToPlayOverlay({
    super.key,
    required this.guide,
    required this.onSkip,
  });

  static const skipButtonKey = Key('how-to-play-skip');

  /// Minimum visual + hit size. 48pt is Apple's floor; we go larger so a
  /// thumb on iPhone SE cannot miss it into the opaque game behind.
  static const double skipExtent = 56;

  final FirstRunGuide guide;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    // Status-bar taps never reach Flutter. Keep Skip fully below it even
    // when MediaQuery.padding.top is 0 (seen on some iOS SE builds).
    final top = (padding.top < 20 ? 20.0 : padding.top) + 8;
    final left = padding.left + 8;

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, top + skipExtent, 24, 24),
            child: Align(
              alignment: const Alignment(0, 0.18),
              child: ValueListenableBuilder<String?>(
                valueListenable: guide.tipText,
                builder: (_, text, _) {
                  if (text == null || text.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return AnimatedSwitcher(
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
                            color: GameColors.rimMetal.withValues(alpha: 0.35),
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
                              color: GameColors.scoreText.withValues(
                                alpha: 0.92,
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
        ),
        Positioned(
          top: top,
          left: left,
          width: skipExtent + 16,
          height: skipExtent,
          child: GestureDetector(
            key: skipButtonKey,
            behavior: HitTestBehavior.opaque,
            onTap: onSkip,
            child: Center(
              child: Text(
                'Skip',
                style: GameFonts.ui(
                  fontSize: 16,
                  weight: FontWeight.w600,
                  color: GameColors.mutedText,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
