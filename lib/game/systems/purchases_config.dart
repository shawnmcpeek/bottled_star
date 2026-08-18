import 'package:flutter/foundation.dart';

/// Entitlement identifiers — internal, not store-facing.
abstract final class Entitlements {
  static const challengePack1 = 'challenge_pack_1';
  static const challengePack2 = 'challenge_pack_2';
  static const challengePack3 = 'challenge_pack_3';
  static const noAds = 'no_ads';

  static const allChallengePacks = <String>{
    challengePack1,
    challengePack2,
    challengePack3,
  };
}

/// Store-facing product identifiers. Must match Play Console / App Store
/// Connect / RevenueCat exactly.
abstract final class ProductIds {
  static const noAds = 'no_ads';
  static const challengePack1 = 'challenge_pack_1';
  static const challengePack2 = 'challenge_pack_2';
  static const challengePack3 = 'challenge_pack_3';

  /// Pre-split SKU still live in both store consoles and RevenueCat.
  /// Grants pack 1 + no_ads for anyone who already bought it.
  static const legacyChallengeUnlock = 'challenge_unlock';

  static const all = <String>{
    noAds,
    challengePack1,
    challengePack2,
    challengePack3,
  };
}

/// Which entitlements a given purchased product grants.
/// Pack purchases grant [Entitlements.noAds] as a side effect — the
/// "first purchase carries it" rule, expressed as data rather than branching.
const Map<String, Set<String>> productGrants = {
  ProductIds.noAds: {Entitlements.noAds},
  ProductIds.challengePack1: {
    Entitlements.challengePack1,
    Entitlements.noAds,
  },
  ProductIds.challengePack2: {
    Entitlements.challengePack2,
    Entitlements.noAds,
  },
  ProductIds.challengePack3: {
    Entitlements.challengePack3,
    Entitlements.noAds,
  },
  // Legacy — pre-split entitlement. Grants pack 1 and no_ads.
  ProductIds.legacyChallengeUnlock: {
    Entitlements.challengePack1,
    Entitlements.noAds,
  },
};

/// Recomputes the full entitlement set from the set of owned product IDs.
/// Pure function — no I/O, no side effects. Trivially unit-testable.
Set<String> deriveEntitlements(Set<String> ownedProductIds) {
  final entitlements = <String>{};
  for (final productId in ownedProductIds) {
    final grants = productGrants[productId];
    if (grants != null) entitlements.addAll(grants);
  }
  return entitlements;
}

bool adsEnabled(Set<String> entitlements) =>
    !entitlements.contains(Entitlements.noAds);

bool hasAnyChallengePack(Set<String> entitlements) =>
    entitlements.any(Entitlements.allChallengePacks.contains);

/// RevenueCat public SDK keys and platform helpers.
abstract final class PurchasesConfig {
  /// @deprecated Prefer [Entitlements] / [ProductIds]. Kept for any leftover
  /// references during the pack split.
  static const String entitlementChallenge = 'challenge';
  static const String productChallengeUnlock = ProductIds.legacyChallengeUnlock;

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
