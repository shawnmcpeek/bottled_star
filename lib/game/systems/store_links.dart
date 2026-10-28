import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Store listing URLs and share / rate helpers.
abstract final class StoreLinks {
  static const packageId = 'pro.daddoodev.bottledstar';
  static const appStoreId = '6798914010';

  static const playStoreUrl =
      'https://play.google.com/store/apps/details?id=$packageId';
  static const appStoreUrl = 'https://apps.apple.com/app/id$appStoreId';

  static String get listingUrl {
    if (kIsWeb) return playStoreUrl;
    return defaultTargetPlatform == TargetPlatform.iOS
        ? appStoreUrl
        : playStoreUrl;
  }

  static String get shareMessage =>
      'I\'m playing Bottled Star — a fusion game where you hold a star '
      'in a bottle.\n$listingUrl';

  /// Opens the public store listing (Rate button destination).
  static Future<bool> openListing() async {
    final uri = Uri.parse(listingUrl);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// System share sheet with store link.
  static Future<void> shareApp() async {
    await SharePlus.instance.share(ShareParams(text: shareMessage));
  }

  /// Native in-app review sheet when the store allows it.
  static Future<bool> requestInAppReview() async {
    if (kIsWeb) return false;
    final review = InAppReview.instance;
    if (!await review.isAvailable()) return false;
    await review.requestReview();
    return true;
  }
}
