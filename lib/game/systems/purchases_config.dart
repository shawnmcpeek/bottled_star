import 'package:flutter/foundation.dart';

/// RevenueCat public SDK keys and product identifiers.
///
/// Store products must also exist in Play Console / App Store Connect as
/// non-consumable `challenge_unlock` at $2.99, then link in RevenueCat.
abstract final class PurchasesConfig {
  static const String entitlementChallenge = 'challenge';
  static const String productChallengeUnlock = 'challenge_unlock';

  /// Reserved / unused — Collapse is free.
  static const String entitlementCollapse = 'collapse';

  static const String iosApiKey = 'appl_JErEOnMQweVmdDjqZuXVKDeYzJA';
  static const String androidApiKey = 'goog_unmCoheDNAiIzOwuzjAmAsEIbbT';

  static String? get apiKeyForPlatform {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => iosApiKey,
      TargetPlatform.android => androidApiKey,
      _ => null,
    };
  }

  static bool get isSupportedPlatform => apiKeyForPlatform != null;
}
