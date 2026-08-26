import 'package:flutter/material.dart';

import '../../theme/game_colors.dart';
import '../../theme/game_fonts.dart';
import 'challenge_unlock_sheet.dart';

/// iPhone 6.7" logical frame for App Store Connect IAP review screenshots.
/// Physical target often requested: 1290 × 2796.
class ChallengeIapPreviewScreen extends StatelessWidget {
  const ChallengeIapPreviewScreen({super.key});

  /// Points matching ~6.7" iPhone aspect (1290×2796 @3x ≈ 430×932).
  static const double phoneWidth = 430;
  static const double phoneHeight = 932;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1E),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(
                      'Back',
                      style: GameFonts.ui(
                        fontSize: 14,
                        color: GameColors.mutedText,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Capture the phone frame only',
                      textAlign: TextAlign.center,
                      style: GameFonts.ui(
                        fontSize: 12,
                        color: GameColors.mutedText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 64),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Container(
                    width: phoneWidth,
                    height: phoneHeight,
                    decoration: BoxDecoration(
                      color: GameColors.space,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: GameColors.rimMetal.withValues(alpha: 0.55),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Mode-select-ish backdrop so the sheet reads in-context.
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 72, 28, 28),
                          child: Column(
                            children: [
                              Text(
                                'Play',
                                style: GameFonts.ui(
                                  fontSize: 22,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Text(
                                'Challenge',
                                style: GameFonts.ui(
                                  fontSize: 22,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Unlock',
                                style: GameFonts.label(fontSize: 11),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Preset starts. Limited shots.',
                                textAlign: TextAlign.center,
                                style: GameFonts.prose(
                                  fontSize: 15,
                                  color: GameColors.mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Material(
                            color: GameColors.spaceDeep,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: const ChallengeUnlockPanel(previewMode: true),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
