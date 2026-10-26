import 'package:flutter_test/flutter_test.dart';
import 'package:enso/services/purchase_service.dart';

void main() {
  test('initial annual is full price and has no trial', () {
    expect(standardOffers.first.id, 'standardYearly');
    expect(standardOffers.first.price, r'$79.99');
    expect(standardOffers.map((o) => o.trialDays), [0, 0]);
  });
  test('initial and trial annual purchase identities are distinct', () {
    expect(standardOffers.first.id, isNot(regularOffers.first.id));
    expect(standardOffers.first.price, regularOffers.first.price);
  });
  test('only the regular yearly plan carries a trial, and it is 7 days', () {
    final yearly = regularOffers.firstWhere((o) => o.id == 'yearly');
    expect(yearly.trialDays, 7);
  });

  test('discounted offers (gift and exit) never have a trial', () {
    expect([...giftOffers, exitOffer].every((o) => o.trialDays == 0), isTrue);
  });

  test('the regular paywall has no weekly plan', () {
    expect(regularOffers.any((o) => o.id == 'weekly'), isFalse);
  });

  test('the gift screen offers yearly, monthly and lifetime', () {
    expect(giftOffers.map((o) => o.id).toList(), ['gift', 'monthly', 'lifetime']);
  });

  test('the exit offer is a cheaper yearly than the regular yearly', () {
    final yearly = regularOffers.firstWhere((o) => o.id == 'yearly');
    double price(String s) =>
        double.parse(s.replaceAll(RegExp('[^0-9.]'), ''));
    expect(price(exitOffer.price), lessThan(price(yearly.price)));
  });
}
