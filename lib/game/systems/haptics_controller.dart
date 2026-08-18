import 'dart:async';

import 'package:flutter/services.dart';

/// Device vibration for big in-run blasts (Fe+Fe supernova, remnant kilonova).
///
/// Uses Flutter's built-in [HapticFeedback] — no-ops on desktop/web where the
/// platform has no vibrator. Respect [enabled] from [SettingsStore].
class HapticsController {
  HapticsController._();
  static final HapticsController instance = HapticsController._();

  bool enabled = true;

  /// Strong buzz for supernova / neutron-star (kilonova) explosions.
  ///
  /// Two stacked [heavyImpact] pulses roughly doubles feel vs a single
  /// [HapticFeedback.vibrate] on Android (which is often faint on mid-range
  /// motors). Same pattern reads clearly on iPhone SE Taptic Engine.
  void playBlast() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
    unawaited(_secondPulse());
  }

  Future<void> _secondPulse() async {
    await Future<void>.delayed(const Duration(milliseconds: 45));
    if (!enabled) return;
    HapticFeedback.heavyImpact();
  }
}
