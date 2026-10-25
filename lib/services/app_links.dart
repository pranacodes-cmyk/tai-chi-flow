import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/content.dart';
import '../i18n/i18n.dart';

/// Store, support and version links (web `src/lib/app-links.ts`).
class AppLinks {
  AppLinks._();

  static const appStoreId = '6825866994';
  static const androidPackage = 'com.ensoapp.enso';

  static bool get _ios => !kIsWeb && Platform.isIOS;

  /// Name of the store that bills subscriptions on this device.
  static String get storeName =>
      _ios ? tr('links.storeNameAppStore') : tr('links.storeNameGooglePlay');

  static String? _version;

  /// "1.8.0 (1012)" from the installed build.
  static Future<String> version() async {
    if (_version != null) return _version!;
    try {
      final info = await PackageInfo.fromPlatform();
      _version = '${info.version} (${info.buildNumber})';
    } catch (_) {
      _version = '';
    }
    return _version!;
  }

  static Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Native rating prompt when the store allows it, otherwise the store page.
  static Future<void> rate() async {
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
        return;
      }
      await review.openStoreListing(appStoreId: appStoreId);
    } catch (_) {
      await _open(
        Uri.parse(
          _ios
              ? 'https://apps.apple.com/app/id$appStoreId?action=write-review'
              : 'https://play.google.com/store/apps/details?id=$androidPackage',
        ),
      );
    }
  }

  /// Opens the store's subscription management page.
  static Future<bool> manageSubscription() => _open(
    Uri.parse(
      _ios
          ? 'https://apps.apple.com/account/subscriptions'
          : 'https://play.google.com/store/account/subscriptions?package=$androidPackage',
    ),
  );

  /// Email to support with the app version filled in.
  static Future<bool> contact({String? subject}) async {
    final s = subject ?? tr('links.contactSubject');
    final v = await version();
    final to = Content.i.legal.contact;
    return _open(
      Uri(
        scheme: 'mailto',
        path: to,
        query:
            'subject=${Uri.encodeComponent(s)}&body=${Uri.encodeComponent(tr('links.emailSignature', {'version': v, 'device': _ios ? 'iPhone' : 'Android'}))}',
      ),
    );
  }

  /// Public store-listing pages (privacy / terms / support).
  static Future<bool> openSite(String page) =>
      _open(Uri.parse('${Content.i.legal.site}/$page'));
}
