import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import 'achievement_defs.dart';
import 'achievement_store.dart';
import 'purchases_config.dart';

/// RevenueCat wrapper — Challenge entitlement unlock.
class PurchasesController extends ChangeNotifier {
  PurchasesController._();
  static final PurchasesController instance = PurchasesController._();

  bool _configured = false;
  bool _hasChallenge = false;
  bool _debugUnlock = false;
  Offering? _currentOffering;
  String? _lastError;

  bool get isConfigured => _configured;
  bool get hasChallenge => _hasChallenge || _debugUnlock;
  bool get debugUnlock => _debugUnlock;
  Offering? get currentOffering => _currentOffering;
  String? get lastError => _lastError;

  Package? get challengePackage {
    final offering = _currentOffering;
    if (offering == null) return null;
    return offering.lifetime ??
        offering.getPackage(PurchasesConfig.productChallengeUnlock) ??
        (offering.availablePackages.isNotEmpty
            ? offering.availablePackages.first
            : null);
  }

  String get challengePriceLabel {
    final pkg = challengePackage;
    final price = pkg?.storeProduct.priceString;
    if (price != null && price.isNotEmpty) return price;
    return '\$2.99';
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _debugUnlock =
        prefs.getBool(GameConstants.prefsChallengeUnlockedDebug) ??
            prefs.getBool(GameConstants.prefsCollapseUnlockedDebug) ??
            false;

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

  void _applyCustomerInfo(CustomerInfo info) {
    final active = info.entitlements.active
        .containsKey(PurchasesConfig.entitlementChallenge);
    _hasChallenge = active;
    if (active) {
      AchievementStore.instance.unlock(AchievementId.unlockChallenge);
    }
  }

  Future<bool> purchaseChallenge() async {
    final pkg = challengePackage;
    if (!_configured || pkg == null) {
      _lastError = 'Purchase unavailable on this platform';
      notifyListeners();
      return false;
    }
    try {
      final result = await Purchases.purchase(PurchaseParams.package(pkg));
      _applyCustomerInfo(result.customerInfo);
      _lastError = null;
      notifyListeners();
      return hasChallenge;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError) {
        _lastError = e.message ?? e.toString();
      } else {
        _lastError = null;
      }
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

  /// Linux / web / CI — unlock without a store.
  Future<void> setDebugUnlock(bool value) async {
    _debugUnlock = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(GameConstants.prefsChallengeUnlockedDebug, value);
    if (value) {
      await AchievementStore.instance.unlock(AchievementId.unlockChallenge);
    }
    notifyListeners();
  }
}
