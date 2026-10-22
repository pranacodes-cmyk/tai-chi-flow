import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../services/purchase_service.dart';
import '../services/tracking_service.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/scaffold.dart';
import '../widgets/sheet.dart';
import '../widgets/toast.dart';
import '../widgets/ui.dart';

/// Paywall variants:
/// - regular: yearly with a 7-day free trial + monthly
/// - gift: discounted yearly, monthly and lifetime — no trial
/// - exit: one lower yearly offer after "the price feels high" — no trial
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, required this.from, this.offer = 'regular'});
  final String from;
  final String offer;
  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late String selected;
  bool busy = false;

  List<Offer> get _offers => [
    for (final o in switch (widget.offer) {
      'gift' => giftOffers,
      'exit' => [exitOffer],
      _ => regularOffers,
    })
      PurchaseService.localized(o),
  ];

  @override
  void initState() {
    super.initState();
    selected = _offers.first.id;
    TrackingService.paywallViewed(widget.offer);
    // Real store prices replace the placeholders as soon as they load.
    PurchaseService.warmUp().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _leave() {
    if (widget.from == 'onboarding' || !context.canPop()) {
      context.go('/');
    } else {
      context.pop();
    }
  }

  /// Closing the regular paywall asks why; "price feels high" opens the
  /// lower exit offer, anything else just leaves.
  Future<void> _close() async {
    if (widget.offer != 'regular') {
      _leave();
      return;
    }
    final reason = await showEnsoSheet<String>(
      context,
      builder: (_) => const _ExitSurvey(),
    );
    if (!mounted) return;
    if (reason == 'price') {
      context.push('/paywall?from=${widget.from}&offer=exit');
    } else {
      _leave();
    }
  }

  Future<void> _buy() async {
    if (busy) return;
    setState(() => busy = true);
    final ok = await PurchaseService.purchase(selected);
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) {
      final error = PurchaseService.lastError;
      if (error != null) {
        Toast.show("Purchase didn't go through", description: error);
      }
      return;
    }
    context.read<AppState>().setPremium(selected);
    await showEnsoSheet<void>(
      context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.crown, size: 48, color: C.gold),
            const SizedBox(height: 20),
            Text('Welcome to Plus', style: T.displayMd),
            const SizedBox(height: 12),
            Text(
              'Every plan, meditation and soundscape is now yours.',
              textAlign: TextAlign.center,
              style: T.bodySm.c(C.muted),
            ),
            const SizedBox(height: 24),
            EnsoButton(
              label: 'Start practicing',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
    if (mounted) _leave();
  }

  String _terms(Offer offer) {
    if (offer.id == 'lifetime') {
      return '${offer.price} once · Yours forever. No subscription.';
    }
    if (offer.trialDays > 0) {
      return '${offer.trialDays} days free, then ${offer.price}/${offer.period}.\nCancel anytime before the trial ends.';
    }
    return '${offer.price}/${offer.period} · Auto-renews. Cancel anytime.';
  }

  @override
  Widget build(BuildContext context) {
    final offer = _offers.firstWhere((o) => o.id == selected);
    final isGift = widget.offer == 'gift';
    final isExit = widget.offer == 'exit';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) _close();
      },
      child: EnsoScaffold(
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 180,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          EImage(img('hero-paywall')),
                          Positioned(
                            top: topInset(context) + 12,
                            right: 20,
                            child: CircleBtn(
                              icon: LucideIcons.x,
                              tone: Tone.dark,
                              label: 'Close',
                              onTap: busy ? null : _close,
                            ),
                          ),
                          Positioned(
                            left: 24,
                            bottom: 20,
                            child: Glass(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.crown,
                                    size: 16,
                                    color: C.gold,
                                  ),
                                  const SizedBox(width: 8),
                                  Text('TAICHI FLOW PLUS', style: T.label.c(C.ivory)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isExit
                                ? 'One last offer.\nJust for you.'
                                : isGift
                                    ? 'Pick your plan.\nStart today.'
                                    : 'Your practice.\nWithout limits.',
                            style: T.displayMd.copyWith(
                              fontSize: 28,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isExit
                                ? 'A lower yearly price, because you asked.'
                                : 'A little movement. A calmer mind. Every day.',
                            style: T.bodySm.c(C.muted),
                          ),
                          const SizedBox(height: 16),
                          if (!isExit) ...[
                            const _FreeVsPlus(),
                            const SizedBox(height: 18),
                          ],
                          if (offer.trialDays > 0) ...[
                            const _TrialTimeline(),
                            const SizedBox(height: 18),
                          ],
                          for (final o in _offers)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _OfferCard(
                                offer: o,
                                selected: selected == o.id,
                                onTap: () => setState(() => selected = o.id),
                              ),
                            ),
                          if (widget.offer == 'regular') ...[
                            const SizedBox(height: 6),
                            Center(
                              child: EnsoButton(
                                label: 'View all plans',
                                variant: BtnVariant.ghost,
                                size: BtnSize.sm,
                                onTap: () => context.push(
                                  '/paywall?from=${widget.from}&offer=gift',
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Center(
                            child: EnsoButton(
                              label: 'Restore purchase',
                              variant: BtnVariant.ghost,
                              size: BtnSize.sm,
                              onTap: () async {
                                final app = context.read<AppState>();
                                final restored =
                                    await PurchaseService.restore();
                                Toast.show(
                                  restored
                                      ? 'Purchase restored'
                                      : 'No previous purchase found',
                                );
                                if (restored && mounted) {
                                  if (!app.premium.active) {
                                    app.setPremium('yearly');
                                  }
                                  _leave();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                12,
                24,
                bottomInset(context) + 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EnsoButton(
                    label: offer.trialDays > 0
                        ? 'Start ${offer.trialDays}-day free trial'
                        : 'Continue with ${offer.title}',
                    loading: busy,
                    onTap: busy ? null : _buy,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _terms(offer),
                    textAlign: TextAlign.center,
                    style: T.tiny.copyWith(
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final (label, doc) in const [
                        ('Terms of use', 'terms'),
                        ('Privacy policy', 'privacy'),
                      ])
                        Pressable(
                          onTap: () => context.push('/legal/$doc'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              label,
                              style: T.tiny.copyWith(
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationColor: C.muted,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "How the trial works" timeline, like the competitor's trial screen.
class _TrialTimeline extends StatelessWidget {
  const _TrialTimeline();
  @override
  Widget build(BuildContext context) {
    const steps = [
      (LucideIcons.bell, 'Today', 'Full access starts — free for 7 days.'),
      (LucideIcons.mail, 'Day 5', 'We remind you before the trial ends.'),
      (LucideIcons.crown, 'Day 7', 'Your yearly plan begins. Cancel anytime.'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.ivory,
        borderRadius: BorderRadius.circular(24),
        boxShadow: S.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How your free trial works', style: T.label),
          const SizedBox(height: 12),
          for (final (icon, at, what) in steps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: C.jadeSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 16, color: C.jadeDeep),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(at, style: T.bodySm.copyWith(fontWeight: FontWeight.w700)),
                        Text(what, style: T.caption.c(C.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Exit survey shown when the regular paywall is closed.
class _ExitSurvey extends StatelessWidget {
  const _ExitSurvey();
  @override
  Widget build(BuildContext context) {
    const reasons = [
      ('price', 'The price feels a bit high'),
      ('later', 'I want to try the free version first'),
      ('unsure', 'I\'m not sure it\'s for me'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Not sure yet?', style: T.displayMd.copyWith(fontSize: 24)),
          const SizedBox(height: 6),
          Text('Tell us what\'s holding you back.', style: T.bodySm.c(C.muted)),
          const SizedBox(height: 18),
          for (final (id, label) in reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: EnsoButton(
                label: label,
                variant: BtnVariant.light,
                onTap: () => Navigator.of(context).pop(id),
              ),
            ),
        ],
      ),
    );
  }
}

/// What stays free and what Plus adds, counted from the shipped catalogue (web `FreeVsPlus`).
class _FreeVsPlus extends StatelessWidget {
  const _FreeVsPlus();
  @override
  Widget build(BuildContext context) {
    final c = Content.i;
    final courses = c.plans.where((p) => !p.isSingleSession).toList();
    final classes = c.plans.where((p) => p.isSingleSession && p.premium);
    final freeMeds = c.meditations.where((m) => !m.premium).length;
    final rows = [
      ('${c.quickSessions.length} quick sessions', true),
      ('$freeMeds free meditation', true),
      ('All ${courses.length} courses', false),
      ('${classes.length} single classes', false),
      ('All ${c.meditations.length} guided meditations', false),
    ];
    Widget mark(bool on, {bool plus = false}) => SizedBox(
      width: 64,
      child: Center(
        child: on
            ? Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: plus ? C.jade : C.jadeSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.check,
                  size: 14,
                  color: plus ? C.ivory : C.jadeDeep,
                ),
              )
            : Container(
                width: 12,
                height: 2,
                decoration: BoxDecoration(
                  color: C.muted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      decoration: BoxDecoration(
        color: C.ivory,
        borderRadius: BorderRadius.circular(24),
        boxShadow: S.soft,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('What you get', style: T.label)),
              SizedBox(
                width: 64,
                child: Center(child: Text('Free', style: T.caption)),
              ),
              const SizedBox(width: 64, child: Center(child: PremiumBadge())),
            ],
          ),
          const SizedBox(height: 6),
          for (final (label, free) in rows) ...[
            Container(height: 1, color: C.line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: T.bodySm)),
                  mark(free),
                  mark(true, plus: true),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.selected,
    required this.onTap,
  });
  final Offer offer;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? C.jadeSoft : C.ivory,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? C.jade : C.line, width: 2),
        ),
        child: Row(
          children: [
            Icon(
              selected ? LucideIcons.circleCheck : LucideIcons.circle,
              size: 22,
              color: selected ? C.jade : C.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(offer.title, style: T.title),
                  const SizedBox(height: 4),
                  Text(
                    offer.trialDays > 0
                        ? '${offer.trialDays}-day free trial · ${offer.save}'
                        : offer.save != null
                            ? offer.save!
                            : offer.period == 'once'
                                ? 'Pay once, keep forever'
                                : 'Billed ${offer.period == 'month' ? 'monthly' : 'yearly'}',
                    style: T.caption.c(selected ? C.jadeDeep : C.muted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (offer.strike != null)
                  Text(
                    offer.strike!,
                    style: T.caption.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: C.muted,
                    ),
                  ),
                Text(offer.price, style: T.title.tab),
                const SizedBox(height: 4),
                Text(
                  offer.period == 'once' ? 'one time' : 'per ${offer.period}',
                  style: T.caption,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
