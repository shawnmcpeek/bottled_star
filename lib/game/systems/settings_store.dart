import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

/// Local player preferences (sound, tutorial, display name, etc.).
class SettingsStore {
  bool soundEnabled = true;
  bool sfxEnabled = true;
  bool hapticsEnabled = true;
  bool howToPlaySeen = false;

  /// 0..1 user volumes (independent of on/off toggles).
  double musicVolume = 0.7;
  double sfxVolume = 0.75;

  /// Leaderboard display name — survives app closes on this device.
  String? displayName;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    soundEnabled = prefs.getBool(GameConstants.prefsSoundEnabled) ?? true;
    sfxEnabled = prefs.getBool(GameConstants.prefsSfxEnabled) ?? true;
    hapticsEnabled = prefs.getBool(GameConstants.prefsHapticsEnabled) ?? true;
    howToPlaySeen = prefs.getBool(GameConstants.prefsHowToPlaySeen) ?? false;
    musicVolume =
        (prefs.getDouble(GameConstants.prefsMusicVolume) ?? 0.7).clamp(0.0, 1.0);
    sfxVolume =
        (prefs.getDouble(GameConstants.prefsSfxVolume) ?? 0.75).clamp(0.0, 1.0);
    final rawName = prefs.getString(GameConstants.prefsDisplayName);
    displayName = (rawName == null || rawName.trim().isEmpty)
        ? null
        : rawName.trim();
  }

  Future<void> setSoundEnabled(bool value) async {
    soundEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(GameConstants.prefsSoundEnabled, value);
  }

  Future<void> setSfxEnabled(bool value) async {
    sfxEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(GameConstants.prefsSfxEnabled, value);
  }

  Future<void> setMusicVolume(double value) async {
    musicVolume = value.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(GameConstants.prefsMusicVolume, musicVolume);
  }

  Future<void> setSfxVolume(double value) async {
    sfxVolume = value.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(GameConstants.prefsSfxVolume, sfxVolume);
  }

  Future<void> setHapticsEnabled(bool value) async {
    hapticsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(GameConstants.prefsHapticsEnabled, value);
  }

  Future<void> markHowToPlaySeen() async {
    howToPlaySeen = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(GameConstants.prefsHowToPlaySeen, true);
  }

  Future<void> setDisplayName(String value) async {
    final trimmed = value.trim();
    displayName = trimmed.isEmpty ? null : trimmed;
    final prefs = await SharedPreferences.getInstance();
    if (displayName == null) {
      await prefs.remove(GameConstants.prefsDisplayName);
    } else {
      await prefs.setString(GameConstants.prefsDisplayName, displayName!);
    }
  }
}
