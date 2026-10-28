import 'package:flutter/foundation.dart';

/// Number of Challenge packs on sale.
const int challengePackCount = 3;

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

  static String forPack(int pack) => switch (pack) {
        1 => challengePack1,
        2 => challengePack2,
        3 => challengePack3,
        _ => throw ArgumentError.value(pack, 'pack'),
      };
}

/// Store-facing product identifiers. Must match Play Console / App Store
/// Connect / RevenueCat exactly.
abstract final class ProductIds {
  static const noAds = 'no_ads';
  static const challengePack1 = 'challenge_pack_1';
  static const challengePack2 = 'challenge_pack_2';
  static const challengePack3 = 'challenge_pack_3';

  /// "All Challenge Packs" bundle. Keeps the original SKU so the existing
  /// App Store product carries over.
  static const challengeAllPacks = 'challenge_unlock';

  static const all = <String>{
    noAds,
    challengePack1,
    challengePack2,
    challengePack3,
    challengeAllPacks,
  };

  static String forPack(int pack) => switch (pack) {
        1 => challengePack1,
        2 => challengePack2,
        3 => challengePack3,
        _ => throw ArgumentError.value(pack, 'pack'),
      };
}

/// Shown when the store has not returned a localized price yet.
abstract final class FallbackPrices {
  static const singlePack = r'$1.49';
  static const allPacks = r'$2.99';
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
  ProductIds.challengeAllPacks: {
    Entitlements.challengePack1,
    Entitlements.challengePack2,
    Entitlements.challengePack3,
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
