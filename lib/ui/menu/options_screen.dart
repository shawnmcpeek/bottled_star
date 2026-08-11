import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../game/systems/haptics_controller.dart';
import '../../game/systems/leaderboard_service.dart';
import '../../game/systems/music_controller.dart';
import '../../game/systems/purchases_controller.dart';
import '../../game/systems/settings_store.dart';
import '../../game/systems/sfx_controller.dart';
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
    await MusicController.instance.setVolume(_settings.musicVolume);
    await SfxController.instance.setVolume(_settings.sfxVolume);
    SfxController.instance.enabled = _settings.sfxEnabled;
    HapticsController.instance.enabled = _settings.hapticsEnabled;
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
                  label: 'Music',
                  subtitle: 'Ambient loops during play',
                  value: _settings.soundEnabled,
                  onChanged: (v) async {
                    await _settings.setSoundEnabled(v);
                    setState(() {});
                  },
                ),
                _OptionsVolumeSlider(
                  label: 'Music volume',
                  value: _settings.musicVolume,
                  enabled: _settings.soundEnabled,
                  onChanged: (v) {
                    setState(() => _settings.musicVolume = v);
                    MusicController.instance.setVolume(v);
                  },
                  onChangeEnd: (v) async {
                    await _settings.setMusicVolume(v);
                    await MusicController.instance.setVolume(v);
                  },
                ),
                _OptionsToggle(
                  label: 'SFX',
                  subtitle: 'Merge plucks and blast hits',
                  value: _settings.sfxEnabled,
                  onChanged: (v) async {
                    await _settings.setSfxEnabled(v);
                    SfxController.instance.enabled = v;
                    if (!v) await SfxController.instance.stopAll();
                    setState(() {});
                  },
                ),
                _OptionsVolumeSlider(
                  label: 'SFX volume',
                  value: _settings.sfxVolume,
                  enabled: _settings.sfxEnabled,
                  onChanged: (v) {
                    setState(() => _settings.sfxVolume = v);
                    SfxController.instance.setVolume(v);
                  },
                  onChangeEnd: (v) async {
                    await _settings.setSfxVolume(v);
                    await SfxController.instance.setVolume(v);
                  },
                ),
                _OptionsToggle(
                  label: 'Haptics',
                  subtitle: 'Buzz on supernova and kilonova',
                  value: _settings.hapticsEnabled,
                  onChanged: (v) async {
                    await _settings.setHapticsEnabled(v);
                    HapticsController.instance.enabled = v;
                    setState(() {});
                  },
                ),
                if (!kIsWeb &&
                    (defaultTargetPlatform == TargetPlatform.linux ||
                        defaultTargetPlatform == TargetPlatform.windows ||
                        defaultTargetPlatform == TargetPlatform.macOS ||
                        kDebugMode)) ...[
                  _OptionsToggle(
                    label: 'Unlock Challenge (dev)',
                    subtitle: 'Bypass store for testing',
                    value: PurchasesController.instance.debugUnlock,
                    onChanged: (v) async {
                      await PurchasesController.instance.setDebugUnlock(v);
                      setState(() {});
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'IAP review screenshot',
                      style: GameFonts.ui(
                        fontSize: 16,
                        weight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'iPhone 6.7" frame for App Store Connect',
                      style: GameFonts.ui(
                        fontSize: 13,
                        color: GameColors.mutedText.withValues(alpha: 0.85),
                      ),
                    ),
                    onTap: () =>
                        Navigator.of(context).pushNamed('/iap-preview'),
                  ),
                ],
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
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      activeThumbColor: GameColors.space,
      activeTrackColor: GameColors.chamberGlow,
      inactiveThumbColor: GameColors.mutedText,
      inactiveTrackColor: GameColors.spaceDeep,
      title: Text(
        label,
        style: GameFonts.ui(
          fontSize: 16,
          weight: FontWeight.w600,
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

class _OptionsVolumeSlider extends StatelessWidget {
  const _OptionsVolumeSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
    this.enabled = true,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final labelColor = enabled ? GameColors.scoreText : GameColors.mutedText;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GameFonts.ui(
                    fontSize: 14,
                    weight: FontWeight.w500,
                    color: labelColor,
                  ),
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: GameFonts.label(fontSize: 11),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: GameColors.chamberGlow,
              inactiveTrackColor: GameColors.spaceDeep,
              thumbColor: GameColors.rimMetal,
              overlayColor: GameColors.chamberGlowSoft,
              disabledActiveTrackColor:
                  GameColors.chamberGlow.withValues(alpha: 0.35),
              disabledInactiveTrackColor: GameColors.spaceDeep,
              disabledThumbColor: GameColors.mutedText,
            ),
            child: Slider(
              value: value,
              onChanged: enabled ? onChanged : null,
              onChangeEnd: enabled ? onChangeEnd : null,
            ),
          ),
        ],
      ),
    );
  }
}
