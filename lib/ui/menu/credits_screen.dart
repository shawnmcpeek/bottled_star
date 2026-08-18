import 'package:flutter/material.dart';

import '../../theme/game_colors.dart';
import '../../theme/game_fonts.dart';
import 'menu_atmosphere.dart';
import 'menu_page_scaffold.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuPageScaffold(
      title: 'Credits',
      driftCast: MenuDriftCast.creditsFamily,
      child: ListView(
        children: [
          Text(
            'Bottled Star',
            style: GameFonts.brandWordmark(fontSize: 28),
          ),
          const SizedBox(height: 8),
          Text(
            'A star, held in a bottle.',
            style: GameFonts.prose(
              fontSize: 15,
              color: GameColors.mutedText,
            ),
          ),
          const SizedBox(height: 28),
          const _CreditBlock(
            heading: 'Studio',
            body: 'Daddoo Dev',
          ),
          const _CreditBlock(
            heading: 'Element art',
            body: 'SakiVoid',
          ),
          Text('Type', style: GameFonts.label(fontSize: 11)),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              style: GameFonts.ui(
                fontSize: 16,
                weight: FontWeight.w500,
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: 'Space Grotesk',
                  style: GameFonts.ui(
                    fontSize: 16,
                    weight: FontWeight.w500,
                  ),
                ),
                const TextSpan(text: '  ·  '),
                TextSpan(
                  text: 'Fraunces',
                  style: GameFonts.prose(
                    fontSize: 16,
                    color: GameColors.scoreText,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'SIL Open Font License',
            style: GameFonts.ui(
              fontSize: 14,
              color: GameColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditBlock extends StatelessWidget {
  const _CreditBlock({required this.heading, required this.body});

  final String heading;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: GameFonts.label(fontSize: 11)),
          const SizedBox(height: 6),
          Text(
            body,
            style: GameFonts.ui(
              fontSize: 16,
              weight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
