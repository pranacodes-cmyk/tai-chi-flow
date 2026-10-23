import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'tracking_service.dart';

/// Purchase layer — RevenueCat-backed, with a demo fallback so the app still
/// works in previews, tests and before store products propagate.
/// Mirrors src/lib/purchases.ts.
///
/// Funnel (mirrors the competitor flow, with truthful terms):
/// - regular paywall: yearly with a 7-day free trial + monthly
/// - gift paywall ("View all plans"): discounted yearly, monthly, lifetime — no trial
/// - exit offer (after "price feels high"): lower yearly — no trial
class Offer {
  final String id, title, price, period, perWeek;
  final String? badge, strike, save;
  final int trialDays;
  const Offer({
    required this.id,
    required this.title,
    required this.price,
    required this.period,
    required this.perWeek,
    this.badge,
    this.trialDays = 0,
    this.strike,
    this.save,
  });
}

/// Regular paywall plans. The yearly plan carries the 7-day trial.
const regularOffers = [
  Offer(
    id: 'yearly',
    title: 'Yearly',
    price: r'$79.99',
    period: 'year',
    perWeek: r'$1.54',
    badge: 'Best value',
    trialDays: 7,
    save: 'Save 67%',
  ),
  Offer(
    id: 'monthly',
    title: 'Monthly',
    price: r'$9.99',
    period: 'month',
    perWeek: r'$2.50',
  ),
];

/// "View all plans" gift screen — discounted, no trial.
const giftOffers = [
  Offer(
    id: 'gift',
    title: 'Yearly · New user gift',
    price: r'$39.99',
    period: 'year',
    perWeek: r'$0.77',
    badge: '50% off first year',
    strike: r'$79.99',
    save: '50% OFF',
  ),
  Offer(
    id: 'monthly',
    title: 'Monthly',
    price: r'$9.99',
    period: 'month',
    perWeek: r'$2.50',
  ),
  Offer(
    id: 'lifetime',
    title: 'Lifetime',
    price: r'$99.99',
    period: 'once',
    perWeek: 'Pay once',
    badge: 'One-time payment',
  ),
];

/// Shown after the exit survey answer "the price feels high" — no trial.
const exitOffer = Offer(
  id: 'exit',
  title: 'Yearly · Special price',
  price: r'$34.99',
  period: 'year',
  perWeek: r'$0.67',
  strike: r'$79.99',
  save: 'Save 56%',
);

/// RevenueCat public SDK keys (safe to ship in the binary).
const _androidKey = 'goog_GyHEQVmzxdmjrBbOftPqYDhdSDI';
const _iosKey = 'appl_LzxCTyHxRgkmrTZagRVvixodgJa';

/// Offering lookup keys configured in RevenueCat.
const _offeringRegular = 'regular';
const _offeringGift = 'gift';
const _offeringExit = 'exit';
const _entitlement = 'plus';

class PurchaseService {
  PurchaseService._();

  static bool _ready = false;

  /// Call once at app start. Never throws — falls back to demo mode.
  static Future<void> init() async {
    if (kIsWeb || _ready) return;
    try {
      await Purchases.configure(
        PurchasesConfiguration(Platform.isAndroid ? _androidKey : _iosKey),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// True when the user currently holds the Plus entitlement.
  static Future<bool> hasPlus() async => await plusStatus() ?? false;

  /// Plus status from the store: true / false, or null when unknown
  /// (demo mode, offline, store unavailable) so callers never revoke on errors.
  static Future<bool?> plusStatus() async {
    if (!_ready) return null;
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(_entitlement);
    } catch (_) {
      return null;
    }
  }

  /// RevenueCat app user ID, shown as a support code so purchase and data
  /// requests can be matched. Null in demo mode.
  static Future<String?> supportCode() async {
    if (!_ready) return null;
    try {
      return await Purchases.appUserID;
    } catch (_) {
      return null;
    }
  }

  /// Plan id for an active Plus entitlement, from its store product id.
  static String planForProduct(String productId) {
    final id = productId.toLowerCase();
    if (id.contains('lifetime')) return 'lifetime';
    if (id.contains('month')) return 'monthly';
    if (id.contains('exit')) return 'exit';
    if (id.contains('gift')) return 'gift';
    return 'yearly';
  }

  /// Keeps the app's Plus flag in step with the store: renewals, refunds,
  /// expiries and purchases made on another device. Call once at start-up.
  static Future<void> syncEntitlement({
    required bool Function() isActive,
    required void Function(String plan) grant,
    required void Function() revoke,
  }) async {
    if (!_ready) return;
    void apply(CustomerInfo info) {
      final ent = info.entitlements.active[_entitlement];
      if (ent != null && !isActive()) grant(planForProduct(ent.productIdentifier));
      if (ent == null && isActive()) revoke();
    }

    try {
      apply(await Purchases.getCustomerInfo());
      Purchases.addCustomerInfoUpdateListener(apply);
    } catch (_) {}
    unawaited(warmUp());
  }

  static Package? _package(String offeringKey, String packageType) {
    // Best-effort lookup; returns null when offerings are unavailable.
    for (final p in _cache?[offeringKey]?.availablePackages ?? const <Package>[]) {
      if (p.packageType.name == packageType) return p;
    }
    return null;
  }

  static Map<String, Offering>? _cache;

  /// Pre-fetch offerings so paywalls render with real store prices.
  static Future<void> warmUp() async {
    if (!_ready) return;
    try {
      final o = await Purchases.getOfferings();
      _cache = o.all;
    } catch (_) {
      _cache = null;
    }
  }

  static Package? _packageFor(String plan) => switch (plan) {
    'yearly' => _package(_offeringRegular, 'annual'),
    'monthly' => _package(_offeringGift, 'monthly') ??
        _package(_offeringRegular, 'monthly'),
    'gift' => _package(_offeringGift, 'annual'),
    'exit' => _package(_offeringExit, 'annual'),
    'lifetime' => _package(_offeringGift, 'lifetime'),
    _ => null,
  };

  /// The offer with the store's real, localised price when it is known
  /// (falls back to the demo USD values before offerings load).
  static Offer localized(Offer o) {
    final product = _packageFor(o.id)?.storeProduct;
    if (product == null) return o;
    final weeks = switch (o.period) {
      'year' => 52.0,
      'month' => 52.0 / 12,
      _ => 0.0,
    };
    final yearly = _packageFor('yearly')?.storeProduct;
    final strike = o.strike != null && yearly != null && o.id != 'yearly'
        ? yearly.priceString
        : o.strike;
    String? save = o.save;
    if (o.strike != null && yearly != null && yearly.price > 0 && o.id != 'yearly') {
      final pct = ((1 - product.price / yearly.price) * 100).round();
      if (pct > 0) save = o.save!.contains('OFF') ? '$pct% OFF' : 'Save $pct%';
    }
    return Offer(
      id: o.id,
      title: o.title,
      price: product.priceString,
      period: o.period,
      perWeek: weeks == 0
          ? o.perWeek
          : _money(product.price / weeks, product.currencyCode, product.priceString),
      badge: o.badge,
      trialDays: o.trialDays,
      strike: strike,
      save: save,
    );
  }

  /// Formats [amount] like the store's own price string (symbol position kept).
  static String _money(double amount, String currency, String sample) {
    final digits = RegExp(r'[\d.,\s]+').firstMatch(sample);
    final fixed = amount.toStringAsFixed(2);
    if (digits == null) return '$currency $fixed';
    final usesComma = digits.group(0)!.trim().contains(',') &&
        !digits.group(0)!.trim().contains('.');
    final text = usesComma ? fixed.replaceAll('.', ',') : fixed;
    return sample.replaceFirst(digits.group(0)!.trim(), text);
  }

  /// Human-readable reason for the last failed purchase (null when the person
  /// cancelled or it succeeded).
  static String? lastError;

  static Future<bool> purchase(String plan) async {
    lastError = null;
    if (!_ready) {
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      return true; // demo mode
    }
    if (_cache == null) await warmUp();
    final pkg = _packageFor(plan);
    if (pkg == null) {
      lastError = 'Plans could not load from ${Platform.isIOS ? 'the App Store' : 'Google Play'}. Check your connection and try again.';
      return false;
    }
    final product = pkg.storeProduct;
    unawaited(TrackingService.checkoutStarted(
      plan: plan,
      price: product.price,
      currency: product.currencyCode,
    ));
    try {
      final result = await Purchases.purchase(PurchaseParams.package(pkg));
      final ok = result.customerInfo.entitlements.active.containsKey(_entitlement);
      if (ok) {
        final intro = product.introductoryPrice;
        final freeTrial = (intro != null && intro.price == 0) ||
            product.defaultOption?.freePhase != null;
        unawaited(TrackingService.purchaseCompleted(
          plan: plan,
          trial: freeTrial,
          lifetime: plan == 'lifetime',
          price: product.price,
          currency: product.currencyCode,
          orderId: result.storeTransaction.transactionIdentifier,
        ));
      }
      return ok;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      lastError = switch (code) {
        PurchasesErrorCode.purchaseCancelledError => null,
        PurchasesErrorCode.paymentPendingError =>
          'Your payment is pending. Plus unlocks as soon as the store confirms it.',
        PurchasesErrorCode.productAlreadyPurchasedError =>
          'You already own this. Tap Restore purchase to unlock it.',
        PurchasesErrorCode.networkError =>
          'No connection. Check your internet and try again.',
        PurchasesErrorCode.purchaseNotAllowedError =>
          'Purchases are turned off on this device.',
        _ => 'The store could not finish the purchase. Please try again — if you were charged, tap Restore purchase.',
      };
      return false;
    } catch (_) {
      lastError = 'The store could not finish the purchase. Please try again — if you were charged, tap Restore purchase.';
      return false;
    }
  }

  static Future<bool> restore() async {
    if (!_ready) {
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      return false;
    }
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey(_entitlement);
    } catch (_) {
      return false;
    }
  }
}
