import 'package:bottled_star/game/constants.dart';
import 'package:bottled_star/game/modes/game_mode.dart';
import 'package:bottled_star/game/systems/purchases_config.dart';
import 'package:bottled_star/game/systems/purchases_controller.dart';
import 'package:bottled_star/monetization/ad_gateway.dart';
import 'package:bottled_star/monetization/ad_playthrough.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('deriveEntitlements', () {
    test('empty owned set → empty entitlements, ads on', () {
      final e = deriveEntitlements({});
      expect(e, isEmpty);
      expect(adsEnabled(e), isTrue);
    });

    test('{no_ads} → no_ads only, ads off', () {
      final e = deriveEntitlements({ProductIds.noAds});
      expect(e, {Entitlements.noAds});
      expect(adsEnabled(e), isFalse);
    });

    test('{challenge_pack_2} → pack + no_ads', () {
      final e = deriveEntitlements({ProductIds.challengePack2});
      expect(
        e,
        {Entitlements.challengePack2, Entitlements.noAds},
      );
      expect(adsEnabled(e), isFalse);
    });

    test('{no_ads, challenge_pack_1} → both, no duplicate error', () {
      final e = deriveEntitlements({
        ProductIds.noAds,
        ProductIds.challengePack1,
      });
      expect(
        e,
        {Entitlements.noAds, Entitlements.challengePack1},
      );
      expect(adsEnabled(e), isFalse);
    });

    test('all three packs → three packs + one no_ads', () {
      final e = deriveEntitlements({
        ProductIds.challengePack1,
        ProductIds.challengePack2,
        ProductIds.challengePack3,
      });
      expect(
        e,
        {
          Entitlements.challengePack1,
          Entitlements.challengePack2,
          Entitlements.challengePack3,
          Entitlements.noAds,
        },
      );
      expect(adsEnabled(e), isFalse);
    });

    test('unknown product ID ignored', () {
      final e = deriveEntitlements({'totally_fake_sku'});
      expect(e, isEmpty);
      expect(adsEnabled(e), isTrue);
    });

    test('legacy challenge_unlock grants pack1 + no_ads', () {
      final e = deriveEntitlements({ProductIds.legacyChallengeUnlock});
      expect(
        e,
        {Entitlements.challengePack1, Entitlements.noAds},
      );
      expect(hasAnyChallengePack(e), isTrue);
      expect(adsEnabled(e), isFalse);
    });
  });

  group('AdPlaythrough counter', () {
    late int stubShows;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AdPlaythrough.resetOverridesForTest();
      AdGateway.instance.resetForTest();
      stubShows = 0;
      AdPlaythrough.showInterstitialOverride = () async {
        stubShows++;
      };
    });

    tearDown(() {
      AdPlaythrough.resetOverridesForTest();
    });

    test('two dismisses with ads enabled → stub fires once, count 0', () async {
      const entitlements = <String>{};
      await AdPlaythrough.onEndingCardDismissed(
        mode: GameMode.classic,
        entitlements: entitlements,
      );
      expect(await AdPlaythrough.currentCount(), 1);
      expect(stubShows, 0);

      await AdPlaythrough.onEndingCardDismissed(
        mode: GameMode.collapse,
        entitlements: entitlements,
      );
      expect(await AdPlaythrough.currentCount(), 0);
      expect(stubShows, 1);
    });

    test('one dismiss → no fire, count persists as 1', () async {
      await AdPlaythrough.onEndingCardDismissed(
        mode: GameMode.classic,
        entitlements: const {},
      );
      expect(await AdPlaythrough.currentCount(), 1);
      expect(stubShows, 0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(GameConstants.prefsAdPlaythroughCount), 1);
    });

    test('dismiss with ads disabled → no increment, no fire', () async {
      await AdPlaythrough.onEndingCardDismissed(
        mode: GameMode.classic,
        entitlements: {Entitlements.noAds},
      );
      expect(await AdPlaythrough.currentCount(), 0);
      expect(stubShows, 0);
    });

    test('Challenge mode never increments', () async {
      await AdPlaythrough.onEndingCardDismissed(
        mode: GameMode.challenge,
        entitlements: const {},
      );
      expect(await AdPlaythrough.currentCount(), 0);
      expect(stubShows, 0);
    });

    test('count of 1 persisted, restart, one dismiss → fires', () async {
      SharedPreferences.setMockInitialValues({
        GameConstants.prefsAdPlaythroughCount: 1,
      });
      AdPlaythrough.resetOverridesForTest();
      stubShows = 0;
      AdPlaythrough.showInterstitialOverride = () async {
        stubShows++;
      };

      await AdPlaythrough.onEndingCardDismissed(
        mode: GameMode.classic,
        entitlements: const {},
      );
      expect(stubShows, 1);
      expect(await AdPlaythrough.currentCount(), 0);
    });

    test('ad stub failure does not throw', () async {
      SharedPreferences.setMockInitialValues({
        GameConstants.prefsAdPlaythroughCount: 1,
      });
      AdPlaythrough.resetOverridesForTest();
      AdPlaythrough.showInterstitialOverride = () async {
        throw StateError('no fill');
      };

      await expectLater(
        AdPlaythrough.onEndingCardDismissed(
          mode: GameMode.classic,
          entitlements: const {},
        ),
        completes,
      );
      expect(await AdPlaythrough.currentCount(), 0);
    });
  });

  group('PurchasesController owned-product derivation', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      PurchasesController.instance.resetForTest();
    });

    test('restore-path flips adsEnabled without restart', () async {
      final purchases = PurchasesController.instance;
      expect(purchases.adsEnabledFlag, isTrue);
      expect(purchases.entitlements, isEmpty);

      await purchases.applyOwnedProductsForTest({ProductIds.challengePack2});

      expect(purchases.adsEnabledFlag, isFalse);
      expect(
        purchases.entitlements,
        {Entitlements.challengePack2, Entitlements.noAds},
      );
      expect(purchases.hasChallenge, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(GameConstants.prefsOwnedProducts),
        contains(ProductIds.challengePack2),
      );
      // no_ads must not appear as a persisted boolean / fake product flag.
      expect(prefs.getBool(Entitlements.noAds), isNull);
      expect(
        prefs.getStringList(GameConstants.prefsOwnedProducts),
        isNot(contains(Entitlements.noAds)),
      );
    });

    test('provisional owned set survives as launch cache', () async {
      SharedPreferences.setMockInitialValues({
        GameConstants.prefsOwnedProducts: [ProductIds.noAds],
      });
      PurchasesController.instance.resetForTest();

      // Simulate the prefs-load half of init without configuring RevenueCat.
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(GameConstants.prefsOwnedProducts)!;
      await PurchasesController.instance.applyOwnedProductsForTest(
        stored.toSet(),
      );

      expect(PurchasesController.instance.adsEnabledFlag, isFalse);
      expect(
        PurchasesController.instance.entitlements,
        {Entitlements.noAds},
      );
    });

    test('no_ads is derived, never stored as its own product when only pack',
        () async {
      await PurchasesController.instance.applyOwnedProductsForTest({
        ProductIds.challengePack1,
      });
      final prefs = await SharedPreferences.getInstance();
      final owned = prefs.getStringList(GameConstants.prefsOwnedProducts)!;
      expect(owned, [ProductIds.challengePack1]);
      expect(owned.contains(ProductIds.noAds), isFalse);
      expect(
        PurchasesController.instance.entitlements.contains(Entitlements.noAds),
        isTrue,
      );
    });
  });

  group('AdGateway init gate', () {
    test('initialize is a no-op stub that marks ready', () async {
      AdGateway.instance.resetForTest();
      expect(AdGateway.instance.isInitialized, isFalse);
      await AdGateway.instance.initialize();
      expect(AdGateway.instance.isInitialized, isTrue);
    });
  });
}
