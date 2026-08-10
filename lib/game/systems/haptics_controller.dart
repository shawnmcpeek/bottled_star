import 'package:flutter/services.dart';

/// Device vibration for big in-run blasts (Fe+Fe supernova, remnant kilonova).
///
/// Uses Flutter's built-in [HapticFeedback] — no-ops on desktop/web where the
/// platform has no vibrator. Respect [enabled] from [SettingsStore].
class HapticsController {
  HapticsController._();
  static final HapticsController instance = HapticsController._();

  bool enabled = true;

  /// Short buzz for supernova / neutron-star (kilonova) explosions.
  void playBlast() {
    if (!enabled) return;
    HapticFeedback.vibrate();
  }
}
