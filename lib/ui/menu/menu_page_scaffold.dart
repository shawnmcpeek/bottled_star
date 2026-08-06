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
  });

  final String title;
  final Widget child;
  final MenuDriftCast driftCast;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          MenuAtmosphere(driftCast: driftCast),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
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
                          style: GameFonts.ui(
                            fontSize: 18,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
                    child: child,
                  ),
                ),
              ],
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
