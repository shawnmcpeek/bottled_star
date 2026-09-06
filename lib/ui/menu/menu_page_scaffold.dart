import 'package:flutter/material.dart';

import '../../theme/game_colors.dart';
import '../../theme/game_fonts.dart';
import 'menu_atmosphere.dart';

/// Shared chrome for secondary menu routes (Options, Credits).
class MenuPageScaffold extends StatelessWidget {
  const MenuPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.driftCast = MenuDriftCast.gameElements,
    this.pinToStar = false,
  });

  static const EdgeInsets bodyPadding = EdgeInsets.fromLTRB(28, 12, 28, 28);
  static const EdgeInsets starPinnedPadding = EdgeInsets.fromLTRB(
    28,
    0,
    28,
    28,
  );

  final String title;
  final Widget child;
  final MenuDriftCast driftCast;

  /// When true, [child] fills the screen so it can sit on the bottled-star
  /// core. The back row overlays the top and does not steal vertical space.
  final bool pinToStar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          MenuAtmosphere(driftCast: driftCast),
          if (pinToStar) ...[
            Positioned.fill(child: child),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(bottom: false, child: _TitleBar(title: title)),
            ),
          ] else
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TitleBar(title: title),
                  Expanded(
                    child: Padding(padding: bodyPadding, child: child),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: GameColors.scoreText,
            tooltip: 'Back',
          ),
          Expanded(
            child: Text(
              title,
              style: GameFonts.ui(fontSize: 18, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class MenuLinkButton extends StatelessWidget {
  const MenuLinkButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: GameColors.mutedText,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      child: Text(
        label,
        style: GameFonts.ui(
          fontSize: 15,
          weight: FontWeight.w600,
          color: GameColors.mutedText,
        ),
      ),
    );
  }
}
