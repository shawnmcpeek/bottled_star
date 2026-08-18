import 'package:shared_preferences/shared_preferences.dart';

import '../game/constants.dart';
import '../game/modes/game_mode.dart';
import '../game/systems/purchases_config.dart';
import 'ad_gateway.dart';

/// Ending-card playthrough counter that drives interstitial cadence.
///
/// Increments only on ending-card dismiss for Classic / Collapse when ads are
/// enabled. Challenge never increments. Purchasers do not increment-and-
/// suppress — the counter freezes at its pre-purchase value.
abstract final class AdPlaythrough {
  static const int adCadence = 2;

  /// Optional override for tests (inject prefs + gateway).
  static Future<void> Function()? showInterstitialOverride;
  static SharedPreferences? prefsOverride;

  static Future<int> currentCount() async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    return prefs.getInt(GameConstants.prefsAdPlaythroughCount) ?? 0;
  }

  /// Call when the ending card is dismissed (Inject again or Menu).
  ///
  /// Must run after the score is visible and after any kilonova has already
  /// played — never insert an interstitial between the kilonova and the card.
  static Future<void> onEndingCardDismissed({
    required GameMode mode,
    required Set<String> entitlements,
  }) async {
    if (mode == GameMode.challenge) return;
    if (!adsEnabled(entitlements)) return;

    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final next =
        (prefs.getInt(GameConstants.prefsAdPlaythroughCount) ?? 0) + 1;
    if (next >= adCadence) {
      await prefs.setInt(GameConstants.prefsAdPlaythroughCount, 0);
      try {
        final show = showInterstitialOverride;
        if (show != null) {
          await show();
        } else {
          await AdGateway.instance.showInterstitial();
        }
      } catch (_) {
        // Ad failure must never block menu return / restart.
      }
    } else {
      await prefs.setInt(GameConstants.prefsAdPlaythroughCount, next);
    }
  }

  /// Test helper.
  static void resetOverridesForTest() {
    showInterstitialOverride = null;
    prefsOverride = null;
  }
}
