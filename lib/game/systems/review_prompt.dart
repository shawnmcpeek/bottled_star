import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import 'store_links.dart';

/// Soft in-app review prompt after positive moments (not on launch).
abstract final class ReviewPrompt {
  static const cooldown = Duration(days: 60);

  /// Ask at most once per [cooldown], and only after a clear win / new best.
  static Future<void> maybeAskAfterPositiveMoment() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(GameConstants.prefsReviewLastAskedMs);
    if (lastMs != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
      if (DateTime.now().difference(last) < cooldown) return;
    }

    // Let ending / challenge cards settle before the system sheet.
    await Future<void>.delayed(const Duration(milliseconds: 900));

    final shown = await StoreLinks.requestInAppReview();
    if (shown) {
      await prefs.setInt(
        GameConstants.prefsReviewLastAskedMs,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }
}
