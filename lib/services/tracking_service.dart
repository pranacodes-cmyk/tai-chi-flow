import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../logic/logic.dart';
import '../state/app_state.dart';

/// Meta app events and Apple App Tracking Transparency, gated by the in-app
/// privacy choice (`adsMeasurementAllowed`). Mirrors src/lib/tracking.ts.
///
/// What is shared: install/open, onboarding finished, first session finished,
/// paywall viewed, checkout started, trial / subscription / lifetime purchase
/// (with the store price and currency). Never shared: onboarding answers,
/// health or mobility details, names, practice history.
///
/// The Meta SDK stays uninitialised (auto-init, auto-logging and advertising
/// ID collection are off in the native manifests) until sharing is allowed;
/// then it reads the Google advertising ID / IDFA (iPhone: only after ATT
/// allows), the Play install referrer and the Facebook app attribution ID, and
/// sends every event immediately. On iPhone it also waits for the ATT answer,
/// so the first app-open event carries the right tracking status.
class TrackingService {
  TrackingService._();

  static final _fb = FacebookAppEvents();
  static AppState? _app;
  static bool _sdkReady = false;
  static bool _starting = false;
  static bool _attPending = false;
  static String _consentKey = '';
  static bool _wasOnboarded = false;
  static int _historyCount = 0;
  static final List<Future<void> Function()> _waiting = [];

  static bool get _native => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  /// Region the device reports (from the phone's language & region setting).
  static String? get deviceCountry =>
      PlatformDispatcher.instance.locale.countryCode;

  /// Whether app activity may be shared with Meta right now.
  static bool get allowed {
    final a = _app;
    if (a == null) return false;
    return adsMeasurementAllowed(a.privacy.ads, a.privacy.version, deviceCountry);
  }

  /// Whether the opt-in sheet must be shown (consent regions, unanswered).
  static bool get needsChoice {
    final a = _app;
    if (a == null) return false;
    return needsPrivacyChoice(a.privacy.ads, a.privacy.version, deviceCountry);
  }

  /// Call once after AppState.load(). Never throws.
  static Future<void> init(AppState app) async {
    _app = app;
    _wasOnboarded = app.onboarded;
    _historyCount = app.history.length;
    _consentKey = _keyOf(app);
    app.addListener(_onStateChange);
    if (!_native) return;
    if (isIOS) {
      _attPending = await attStatus() == TrackingStatus.notDetermined;
    }
    await _sync();
  }

  static String _keyOf(AppState a) => '${a.privacy.ads}:${a.privacy.version}';

  static void _onStateChange() {
    final a = _app;
    if (a == null) return;
    final key = _keyOf(a);
    if (key != _consentKey) {
      _consentKey = key;
      unawaited(_sync());
    }
    if (!_wasOnboarded && a.onboarded) unawaited(onboardingCompleted());
    _wasOnboarded = a.onboarded;
    if (_historyCount == 0 && a.history.isNotEmpty) {
      unawaited(firstSessionCompleted());
    }
    _historyCount = a.history.length;
  }

  // ------------------------------------------------------------ App Tracking Transparency

  static Future<TrackingStatus> attStatus() async {
    if (!isIOS) return TrackingStatus.notSupported;
    try {
      return await AppTrackingTransparency.trackingAuthorizationStatus;
    } catch (_) {
      return TrackingStatus.notSupported;
    }
  }

  /// iPhone only: should the ATT explainer be shown now? Only when the system
  /// question has not been asked and the person has not turned sharing off.
  static Future<bool> shouldAskAtt() async {
    if (!isIOS || !allowed) return false;
    return await attStatus() == TrackingStatus.notDetermined;
  }

  /// Shows Apple's system tracking question, then starts measurement if allowed.
  static Future<TrackingStatus> requestAtt() async {
    var status = TrackingStatus.notSupported;
    if (isIOS) {
      try {
        status = await AppTrackingTransparency.requestTrackingAuthorization();
      } catch (_) {}
    }
    _attPending = false;
    await _sync();
    return status;
  }

  /// When an iPhone user declines the explainer flow entirely, stop waiting.
  static Future<void> attSkipped() async {
    _attPending = false;
    await _sync();
  }

  // ------------------------------------------------------------ SDK lifecycle

  static Future<void> _sync() async {
    if (!_native) return;
    if (!allowed) {
      _waiting.clear();
      if (_sdkReady) {
        try {
          await _fb.setAdvertiserIdCollectionEnabled(false);
        } catch (_) {}
      }
      return;
    }
    if (isIOS && _attPending) return; // start once ATT is answered
    if (_sdkReady || _starting) {
      if (_sdkReady) {
        await _enableIds();
        await _linkPurchases(); // ad ID may only now be readable (ATT / opt-in)
      }
      return;
    }
    _starting = true;
    try {
      await _fb.initializeSdk();
      _sdkReady = true;
      await _enableIds();
      await _fb.activateApp();
      await _linkPurchases();
      final pending = List.of(_waiting);
      _waiting.clear();
      for (final send in pending) {
        await send();
      }
      // Push the install/open event now: people who quit during onboarding
      // never open a later session, so a buffered event would never reach Meta.
      await _flush();
    } catch (e) {
      debugPrint('TaiChi Flow: Meta SDK unavailable ($e)');
    } finally {
      _starting = false;
    }
  }

  static Future<void> _flush() async {
    try {
      await _fb.flush();
    } catch (_) {}
  }

  static Future<void> _enableIds() async {
    try {
      // On iPhone the advertising ID only exists after ATT is authorised.
      final idsAllowed =
          !isIOS || await attStatus() == TrackingStatus.authorized;
      await _fb.setAdvertiserIdCollectionEnabled(idsAllowed);
      if (isIOS) await _fb.setAdvertiserTracking(enabled: idsAllowed);
    } catch (_) {}
  }

  /// Lets RevenueCat forward renewals and trial conversions to Meta server-side,
  /// matched to this install by Meta's anonymous ID.
  static Future<void> _linkPurchases() async {
    try {
      final anon = await _fb.getAnonymousId();
      if (anon != null && anon.isNotEmpty) {
        await Purchases.setFBAnonymousID(anon);
      }
      await Purchases.collectDeviceIdentifiers();
    } catch (_) {}
  }

  /// App came back to the foreground.
  static Future<void> resumed() async {
    if (_sdkReady && allowed) {
      try {
        await _fb.activateApp();
      } catch (_) {}
    }
  }

  // ------------------------------------------------------------ events

  static Future<void> _log(Future<void> Function() send) async {
    if (!_native || !allowed) return;
    if (!_sdkReady) {
      // Only reachable while waiting for the iPhone ATT answer: hold briefly.
      if (_waiting.length < 20) _waiting.add(send);
      return;
    }
    try {
      await send();
      await _flush(); // funnel events are few; send now so an app close cannot drop them
    } catch (e) {
      debugPrint('TaiChi Flow: event not sent ($e)');
    }
  }

  static Future<void> onboardingCompleted() => _log(
    () => _fb.logCompletedRegistration(registrationMethod: 'onboarding'),
  );

  static Future<void> firstSessionCompleted() => _log(
    () => _fb.logEvent(
      name: FacebookAppEvents.eventNameCompletedTutorial,
      parameters: {
        FacebookAppEvents.paramNameContentId: 'first_session',
        'fb_success': FacebookAppEvents.paramValueYes,
      },
    ),
  );

  static Future<void> paywallViewed(String variant) => _log(
    () => _fb.logViewContent(id: 'paywall_$variant', type: 'paywall'),
  );

  static Future<void> checkoutStarted({
    required String plan,
    double? price,
    String? currency,
  }) => _log(
    () => _fb.logInitiatedCheckout(
      totalPrice: price,
      currency: currency,
      contentType: 'subscription',
      contentId: plan,
      numItems: 1,
    ),
  );

  /// Successful store purchase. [trial] = a free-trial start (no charge yet).
  static Future<void> purchaseCompleted({
    required String plan,
    required bool trial,
    required bool lifetime,
    required double price,
    required String currency,
    required String orderId,
  }) => _log(() async {
    final params = {FacebookAppEvents.paramNameContentId: plan};
    if (trial) {
      await _fb.logStartTrial(
        orderId: orderId,
        currency: currency,
        price: 0,
        parameters: params,
      );
    } else if (lifetime) {
      await _fb.logPurchase(
        amount: price,
        currency: currency,
        parameters: {...params, FacebookAppEvents.paramNameOrderId: orderId},
      );
    } else {
      await _fb.logSubscribe(
        orderId: orderId,
        currency: currency,
        price: price,
        parameters: params,
      );
    }
    await _fb.flush();
  });
}
