import '../element_tuning.dart';
import 'game_mode.dart';

/// Per-mode gameplay rules (IAP modes share Classic defaults unless noted).
class ModeRules {
  const ModeRules({required this.ironCollapses});

  /// When true, touching Fe+Fe pairs trigger a mid-run supernova shell.
  /// Collapse always uses true. Classic uses false only when
  /// [ElementTuning.kIronInertClassicEnabled] is flipped for playtests.
  final bool ironCollapses;

  static ModeRules forMode(GameMode mode) => switch (mode) {
        GameMode.collapse => const ModeRules(ironCollapses: true),
        GameMode.classic => ModeRules(
            ironCollapses: !ElementTuning.kIronInertClassicEnabled,
          ),
        GameMode.challenge => const ModeRules(ironCollapses: true),
      };
}
