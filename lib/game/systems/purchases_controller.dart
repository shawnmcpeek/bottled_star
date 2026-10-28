import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import 'achievement_defs.dart';
import 'achievement_store.dart';
import 'purchases_config.dart';

/// RevenueCat wrapper — owned products in, derived entitlements out.
///
/// [Entitlements.noAds] is never persisted. Only the owned product ID set is
/// written to prefs; entitlements always come from [deriveEntitlements].
class PurchasesController extends ChangeNotifier {
  PurchasesController._();
  static final PurchasesController instance = PurchasesController._();

  bool _configured = false;
  bool _debugUnlock = false;
  Offering? _currentOffering;
  String? _lastError;

  /// Persisted / store-backed owned SKUs. Never store derived entitlements.
  Set<String> _ownedProductIds = {};

  /// In-memory only — always recomputed via [deriveEntitlements].
  Set<String> _entitlements = {};

  bool get isConfigured => _configured;
  bool get debugUnlock => _debugUnlock;
  Offering? get currentOffering => _currentOffering;
  String? get lastError => _lastError;

  Set<String> get ownedProductIds => Set.unmodifiable(_ownedProductIds);
  Set<String> get entitlements => Set.unmodifiable(_entitlements);

  bool get adsEnabledFlag => adsEnabled(_entitlements);

  /// Owns at least one Challenge pack.
  bool get hasChallenge => _debugUnlock || hasAnyChallengePack(_entitlements);

  bool ownsPack(int pack) =>
      _debugUnlock || _entitlements.contains(Entitlements.forPack(pack));

  bool get ownsAnyPack => hasChallenge;

  Package? packageForProduct(String productId) {
    final offering = _currentOffering;
    if (offering == null) return null;
    final byId = offering.getPackage(productId);
    if (byId != null) return byId;
    for (final p in offering.availablePackages) {
      final id = p.storeProduct.identifier;
      // Play one-time products may report as "productId:purchaseOptionId".
      if (id == productId || id.startsWith('$productId:')) return p;
    }
    return null;
  }

  /// Localized store price, or [fallback] until the store answers.
  String priceLabel(String productId, {required String fallback}) {
    final price = packageForProduct(productId)?.storeProduct.priceString;
    return (price != null && price.isNotEmpty) ? price : fallback;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _debugUnlock = kDebugMode &&
        (prefs.getBool(GameConstants.prefsChallengeUnlockedDebug) ?? false);

    // Provisional owned set before the store query resolves — so a paying
    // user offline on a cold launch does not briefly see ads.
    final stored = prefs.getStringList(GameConstants.prefsOwnedProducts);
    if (stored != null) {
      _applyOwnedProducts(stored.toSet(), persist: false);
    }

    final apiKey = PurchasesConfig.apiKeyForPlatform;
    if (apiKey == null) {
      _configured = false;
      notifyListeners();
      return;
    }

    try {
      final config = PurchasesConfiguration(apiKey);
      await Purchases.configure(config);
      _configured = true;
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
      await refresh();
    } catch (e) {
      _lastError = e.toString();
      debugPrint('PurchasesController init failed: $e');
      _configured = false;
      notifyListeners();
    }
  }

  void _onCustomerInfo(CustomerInfo info) {
    _applyCustomerInfo(info);
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!_configured) {
      notifyListeners();
      return;
    }
    try {
      final info = await Purchases.getCustomerInfo();
      _applyCustomerInfo(info);
      final offerings = await Purchases.getOfferings();
      _currentOffering = offerings.current;
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('PurchasesController refresh failed: $e');
    }
    notifyListeners();
  }

  /// Single path: owned products → derive → optional persist.
  void _applyOwnedProducts(Set<String> owned, {required bool persist}) {
    _ownedProductIds = Set<String>.from(owned);
    _entitlements = deriveEntitlements(_ownedProductIds);
    if (hasAnyChallengePack(_entitlements)) {
      // ignore: unawaited_futures
      AchievementStore.instance.unlock(AchievementId.unlockChallenge);
    }
    if (persist) {
      // ignore: unawaited_futures
      _persistOwnedProducts();
    }
  }

  Future<void> _persistOwnedProducts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      GameConstants.prefsOwnedProducts,
      _ownedProductIds.toList()..sort(),
    );
  }

  void _applyCustomerInfo(CustomerInfo info) {
    final owned = info.allPurchasedProductIdentifiers.toSet();
    _applyOwnedProducts(owned, persist: true);
  }

  /// Buys [productId]. True when the purchase landed.
  Future<bool> purchaseProduct(String productId) async {
    final pkg = packageForProduct(productId);
    if (!_configured || pkg == null) {
      _lastError = 'Purchase unavailable right now';
      notifyListeners();
      return false;
    }
    try {
      final result = await Purchases.purchase(PurchaseParams.package(pkg));
      _applyCustomerInfo(result.customerInfo);
      _lastError = null;
      notifyListeners();
      return _ownedProductIds.contains(productId);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      _lastError = code == PurchasesErrorCode.purchaseCancelledError
          ? null
          : (e.message ?? e.toString());
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> restore() async {
    if (!_configured) {
      _lastError = 'Restore unavailable on this platform';
      notifyListeners();
      return false;
    }
    try {
      final info = await Purchases.restorePurchases();
      _applyCustomerInfo(info);
      _lastError = null;
      notifyListeners();
      return hasChallenge;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Linux / web / CI — unlock Challenge without a store.
  /// Does not invent a persisted `no_ads` flag; debug challenge access only.
  Future<void> setDebugUnlock(bool value) async {
    _debugUnlock = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(GameConstants.prefsChallengeUnlockedDebug, value);
    if (value) {
      await AchievementStore.instance.unlock(AchievementId.unlockChallenge);
    }
    notifyListeners();
  }

  /// Test / restore simulation: apply an owned set as if the store responded.
  @visibleForTesting
  Future<void> applyOwnedProductsForTest(Set<String> owned) async {
    _applyOwnedProducts(owned, persist: true);
    notifyListeners();
  }

  @visibleForTesting
  void resetForTest() {
    _configured = false;
    _debugUnlock = false;
    _currentOffering = null;
    _lastError = null;
    _ownedProductIds = {};
    _entitlements = {};
  }
}
