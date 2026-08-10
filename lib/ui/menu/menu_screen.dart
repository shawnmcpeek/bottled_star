import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/element_tier.dart';
import '../../game/systems/score_store.dart';
import '../../game/systems/sfx_controller.dart';
import '../../theme/game_colors.dart';
import '../../theme/game_fonts.dart';
import 'menu_atmosphere.dart';
import 'menu_page_scaffold.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final ScoreStore _scores = ScoreStore();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
    // Warm SFX while the player is still on the menu.
    unawaited(SfxController.instance.preload());
  }

  Future<void> _load() async {
    await _scores.load();
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _play() async {
    await Navigator.of(context).pushNamed('/mode');
    await _scores.load();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final best = _ready ? _scores.highScore : null;
    final peak = _ready && _scores.highestTier > 0
        ? ElementTier.fromTier(_scores.highestTier)
        : null;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MenuAtmosphere(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Image.asset(
                    'assets/branding/logo.png',
                    width: 168,
                    height: 168,
                    filterQuality: FilterQuality.medium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Bottled Star',
                    textAlign: TextAlign.center,
                    style: GameFonts.brandWordmark(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hold a star in a bottle.',
                    textAlign: TextAlign.center,
                    style: GameFonts.prose(
                      fontSize: 16,
                      color: GameColors.mutedText,
                    ),
                  ),
                  const Spacer(flex: 2),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _play,
                      child: const Text('Play'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  MenuLinkButton(
                    label: 'Scores',
                    onPressed: () => Navigator.of(context).pushNamed('/scores'),
                  ),
                  MenuLinkButton(
                    label: 'Options',
                    onPressed: () => Navigator.of(context).pushNamed('/options'),
                  ),
                  MenuLinkButton(
                    label: 'Credits',
                    onPressed: () => Navigator.of(context).pushNamed('/credits'),
                  ),
                  const SizedBox(height: 10),
                  AnimatedOpacity(
                    opacity: _ready ? 1 : 0,
                    duration: const Duration(milliseconds: 280),
                    child: Text(
                      _bestLine(best, peak),
                      textAlign: TextAlign.center,
                      style: GameFonts.ui(
                        fontSize: 13,
                        weight: FontWeight.w500,
                        color: GameColors.mutedText,
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _bestLine(int? best, ElementTier? peak) {
    if (best == null || best <= 0) {
      return 'No runs yet';
    }
    if (peak == null) {
      return 'Best  $best';
    }
    return 'Best  $best  ·  Peak  ${peak.symbol}';
  }
}
