import 'package:flutter/material.dart';

import '../../game/systems/leaderboard_service.dart';
import '../../game/systems/settings_store.dart';
import '../../theme/game_colors.dart';
import '../../theme/game_fonts.dart';
import 'display_name_dialog.dart';
import 'menu_page_scaffold.dart';

class OptionsScreen extends StatefulWidget {
  const OptionsScreen({super.key});

  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  final SettingsStore _settings = SettingsStore();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _settings.load();
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return MenuPageScaffold(
      title: 'Options',
      child: !_ready
          ? const SizedBox.shrink()
          : ListView(
              children: [
                Text(
                  'Playback',
                  style: GameFonts.label(fontSize: 11),
                ),
                const SizedBox(height: 8),
                _OptionsToggle(
                  label: 'Sound',
                  subtitle: 'Effects when audio arrives',
                  value: _settings.soundEnabled,
                  onChanged: (v) async {
                    await _settings.setSoundEnabled(v);
                    setState(() {});
                  },
                ),
                _OptionsToggle(
                  label: 'Haptics',
                  subtitle: 'Coming soon',
                  value: _settings.hapticsEnabled,
                  enabled: false,
                  onChanged: null,
                ),
                const SizedBox(height: 28),
                Text(
                  'Leaderboard',
                  style: GameFonts.label(fontSize: 11),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Display name',
                    style: GameFonts.ui(
                      fontSize: 16,
                      weight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _settings.displayName ?? 'Not set yet',
                    style: GameFonts.ui(
                      fontSize: 13,
                      color: GameColors.mutedText.withValues(alpha: 0.85),
                    ),
                  ),
                  onTap: () async {
                    final name = await promptDisplayName(
                      context,
                      initial: _settings.displayName,
                    );
                    if (name == null) return;
                    final cleaned = LeaderboardService.sanitizeDisplayName(name);
                    if (cleaned == null) return;
                    await _settings.setDisplayName(cleaned);
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(height: 28),
                Text(
                  'Data',
                  style: GameFonts.label(fontSize: 11),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Clear local scores',
                    style: GameFonts.ui(
                      fontSize: 16,
                      weight: FontWeight.w600,
                      color: GameColors.mutedText,
                    ),
                  ),
                  subtitle: Text(
                    'Coming soon',
                    style: GameFonts.ui(
                      fontSize: 13,
                      color: GameColors.mutedText.withValues(alpha: 0.7),
                    ),
                  ),
                  enabled: false,
                ),
              ],
            ),
    );
  }
}

class _OptionsToggle extends StatelessWidget {
  const _OptionsToggle({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: enabled ? onChanged : null,
      activeThumbColor: GameColors.space,
      activeTrackColor: GameColors.chamberGlow,
      inactiveThumbColor: GameColors.mutedText,
      inactiveTrackColor: GameColors.spaceDeep,
      title: Text(
        label,
        style: GameFonts.ui(
          fontSize: 16,
          weight: FontWeight.w600,
          color: enabled ? GameColors.scoreText : GameColors.mutedText,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GameFonts.ui(
          fontSize: 13,
          color: GameColors.mutedText.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}
