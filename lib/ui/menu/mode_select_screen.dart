import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/modes/game_mode.dart';
import '../../game/systems/haptics_controller.dart';
import '../../game/systems/music_controller.dart';
import '../../game/systems/purchases_controller.dart';
import '../../game/systems/score_store.dart';
import '../../game/systems/settings_store.dart';
import '../../game/systems/sfx_controller.dart';
import '../../theme/game_colors.dart';
import '../../theme/game_fonts.dart';
import 'challenge_unlock_sheet.dart';
import 'menu_page_scaffold.dart';

class ModeSelectScreen extends StatefulWidget {
  const ModeSelectScreen({super.key});

  @override
  State<ModeSelectScreen> createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends State<ModeSelectScreen> {
  final ScoreStore _classicScores = ScoreStore(mode: GameMode.classic);
  final ScoreStore _collapseScores = ScoreStore(mode: GameMode.collapse);
  final SettingsStore _settings = SettingsStore();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    PurchasesController.instance.addListener(_onPurchases);
    _load();
  }

  @override
  void dispose() {
    PurchasesController.instance.removeListener(_onPurchases);
    super.dispose();
  }

  void _onPurchases() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await Future.wait([
      _classicScores.load(),
      _collapseScores.load(),
      _settings.load(),
      SfxController.instance.preload().catchError((_) {}),
      PurchasesController.instance.refresh(),
    ]);
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _open(GameMode mode) async {
    if (mode == GameMode.challenge) {
      if (!PurchasesController.instance.hasChallenge) {
        await showChallengeUnlockSheet(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Challenge levels coming soon',
              style: GameFonts.ui(fontSize: 14),
            ),
            backgroundColor: GameColors.space,
          ),
        );
      }
      return;
    }

    SfxController.instance.enabled = _settings.sfxEnabled;
    HapticsController.instance.enabled = _settings.hapticsEnabled;
    await Future.wait([
      MusicController.instance.setVolume(_settings.musicVolume),
      SfxController.instance.setVolume(_settings.sfxVolume),
      SfxController.instance.preload().catchError((_) {}),
    ]);
    // Never await music play — iOS used to hang here on unsupported formats
    // and block navigation into Classic / Collapse entirely.
    unawaited(
      MusicController.instance.startForRun(
        enabled: _settings.soundEnabled,
        mode: mode,
      ),
    );
    if (!mounted) return;
    await Navigator.of(context).pushNamed('/play', arguments: mode);
    await MusicController.instance.stop();
    await SfxController.instance.stopAll();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final hasChallenge = PurchasesController.instance.hasChallenge;

    return MenuPageScaffold(
      title: 'Play',
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Choose a mode',
                        textAlign: TextAlign.center,
                        style: GameFonts.prose(
                          fontSize: 16,
                          color: GameColors.mutedText,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _ModeCard(
                        mode: GameMode.classic,
                        bestLabel: _ready && _classicScores.highScore > 0
                            ? 'Best  ${_classicScores.highScore}'
                            : null,
                        onTap: () => _open(GameMode.classic),
                      ),
                      const SizedBox(height: 18),
                      _ModeCard(
                        mode: GameMode.collapse,
                        bestLabel: _ready && _collapseScores.hasCollapseBest
                            ? 'Best  ${_collapseScores.collapseBestLabel}'
                            : null,
                        onTap: () => _open(GameMode.collapse),
                      ),
                      const SizedBox(height: 18),
                      _ModeCard(
                        mode: GameMode.challenge,
                        badge: hasChallenge ? 'Coming soon' : 'Unlock',
                        onTap: () => _open(GameMode.challenge),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.onTap,
    this.bestLabel,
    this.badge,
  });

  final GameMode mode;
  final VoidCallback onTap;
  final String? bestLabel;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                mode.label,
                textAlign: TextAlign.center,
                style: GameFonts.ui(fontSize: 22, weight: FontWeight.w600),
              ),
              if (badge != null) ...[
                const SizedBox(height: 4),
                Text(
                  badge!,
                  textAlign: TextAlign.center,
                  style: GameFonts.label(fontSize: 11),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                mode.blurb,
                textAlign: TextAlign.center,
                style: GameFonts.prose(
                  fontSize: 15,
                  color: GameColors.mutedText,
                ),
              ),
              if (bestLabel != null) ...[
                const SizedBox(height: 10),
                Text(
                  bestLabel!,
                  textAlign: TextAlign.center,
                  style: GameFonts.ui(
                    fontSize: 13,
                    weight: FontWeight.w500,
                    color: GameColors.mutedText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
