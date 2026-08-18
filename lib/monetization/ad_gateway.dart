/// Interstitial ad boundary. Currently a no-op stub.
///
/// SDK integration replaces the body of [showInterstitial] and [initialize]
/// only — no call site outside this file should change.
class AdGateway {
  AdGateway._();
  static final instance = AdGateway._();

  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    // STUB: SDK init goes here.
    // Must be a no-op when the user holds `no_ads` — do not initialize
    // an ad SDK for a purchaser. Some SDKs begin collecting on init,
    // which would make the privacy disclosure apply to users who paid
    // specifically to avoid it.
    _initialized = true;
  }

  Future<void> showInterstitial() async {
    // STUB: SDK interstitial show goes here.
    // Real implementation must handle: not-yet-loaded (skip silently,
    // do not block the dismiss), no-fill (skip silently), and
    // show-failure (skip silently). An ad failure must never block
    // the player's return to the menu.
    assert(() {
      // Debug-only visibility that the cadence fired correctly.
      // ignore: avoid_print
      print('[AdGateway] interstitial would show here');
      return true;
    }());
  }

  /// Test helper — resets stub state between unit tests.
  void resetForTest() {
    _initialized = false;
  }
}
