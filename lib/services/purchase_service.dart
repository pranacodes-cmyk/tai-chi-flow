/// Purchase layer — simulated today; swap for RevenueCat later. Mirrors src/lib/purchases.ts.
class Offer {
  final String id, title, price, period, perWeek;
  final String? badge, strike, save;
  final int? trialDays;
  const Offer({
    required this.id,
    required this.title,
    required this.price,
    required this.period,
    required this.perWeek,
    this.badge,
    this.trialDays,
    this.strike,
    this.save,
  });
}

const offers = [
  Offer(id: 'yearly', title: 'Yearly', price: r'$39.99', period: 'year', perWeek: r'$0.77', badge: 'Most popular', trialDays: 7, save: 'Save 85%'),
  Offer(id: 'monthly', title: 'Monthly', price: r'$12.99', period: 'month', perWeek: r'$3.00'),
  Offer(id: 'weekly', title: 'Weekly', price: r'$4.99', period: 'week', perWeek: r'$4.99'),
];

const giftOffer = Offer(
  id: 'gift',
  title: 'Yearly · New user gift',
  price: r'$15.99',
  period: 'first year',
  perWeek: r'$0.31',
  strike: r'$39.99',
  save: '60% OFF',
);

class PurchaseService {
  PurchaseService._();
  static Future<bool> purchase(String plan) async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    return true;
  }

  static Future<bool> restore() async {
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    return false;
  }
}
