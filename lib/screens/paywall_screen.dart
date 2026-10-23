import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../logic/logic.dart';
import '../services/purchase_service.dart';
import '../services/tracking_service.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/scaffold.dart';
import '../widgets/sheet.dart';
import '../widgets/toast.dart';
import '../widgets/confetti.dart';
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
  late final String variant;
  bool busy = false;

  List<Offer> get _offers => [
    for (final o in switch (variant) {
      'gift' => giftOffers,
      'exit' => [exitOffer],
      _ => regularOffers,
    })
      PurchaseService.localized(o),
  ];

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    variant = paywallVariant(widget.from, widget.offer, app.paywallOffer);
    // The last offer seen in onboarding is the one the app keeps offering.
    if (widget.from == 'onboarding') {
      WidgetsBinding.instance.addPostFrameCallback((_) => app.setPaywallOffer(variant));
    }
    selected = _offers.first.id;
    TrackingService.paywallViewed(variant);
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
    final app = context.read<AppState>();
    if (!shouldAskExitSurvey(variant, app.exitSurveyAsked)) {
      _leave();
      return;
    }
    app.markExitSurveyAsked();
    final reason = await showEnsoSheet<String>(
      context,
      builder: (_) => const _ExitSurvey(),
    );
    if (!mounted) return;
    if (reason == 'price') {
      context.pushReplacement('/paywall?from=${widget.from}&offer=exit');
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
    final bought = _offers.firstWhere((o) => o.id == selected);
    context.read<AppState>().setPremium(selected);
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, _, _) => _Celebration(offer: bought),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
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
    final isGift = variant == 'gift';
    final isExit = variant == 'exit';
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
                          if (isExit) ...[
                            const _OfferUnlocked(),
                            const SizedBox(height: 16),
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
                          // Other variants are only explored during onboarding;
                          // afterwards the app keeps the offer chosen there.
                          if (variant == 'regular' && widget.from == 'onboarding') ...[
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

/// Exit survey shown once, the first time the regular paywall is closed.
class _ExitSurvey extends StatelessWidget {
  const _ExitSurvey();
  @override
  Widget build(BuildContext context) {
    const reasons = [
      ('price', LucideIcons.tag, 'The price feels a bit high', 'Show me a better deal'),
      ('later', LucideIcons.leaf, 'I want to try the free version', 'Start with free sessions'),
      ('unsure', LucideIcons.circleHelp, "I'm not sure it's for me", 'Keep exploring first'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [C.jadeSoft, C.sand],
              ),
              boxShadow: S.soft,
            ),
            child: const Icon(LucideIcons.heartHandshake, size: 28, color: C.jadeDeep),
          ),
          const SizedBox(height: 16),
          Text('Before you go…', textAlign: TextAlign.center, style: T.displayMd.copyWith(fontSize: 26)),
          const SizedBox(height: 6),
          Text(
            "One quick tap helps us shape your plan.\nWhat's holding you back?",
            textAlign: TextAlign.center,
            style: T.bodySm.c(C.muted),
          ),
          const SizedBox(height: 20),
          for (final (i, (id, icon, label, hint)) in reasons.indexed)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 380 + i * 90),
              curve: Curves.easeOutCubic,
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Pressable(
                  onTap: () => Navigator.of(context).pop(id),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: C.ivory,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: C.line),
                      boxShadow: S.soft,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: id == 'price' ? C.goldSoft : C.jadeSoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, size: 20, color: id == 'price' ? C.ink : C.jadeDeep),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: T.bodySm.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(hint, style: T.caption.c(C.muted)),
                            ],
                          ),
                        ),
                        const Icon(LucideIcons.chevronRight, size: 18, color: C.muted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Animated "special offer unlocked" ribbon on the exit offer.
class _OfferUnlocked extends StatelessWidget {
  const _OfferUnlocked();
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (_, t, child) => Transform.scale(scale: 0.6 + 0.4 * t, child: child),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(colors: [C.goldSoft, C.ivory]),
          border: Border.all(color: C.gold.withValues(alpha: 0.5)),
          boxShadow: S.soft,
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.gift, size: 26, color: C.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Special offer unlocked', style: T.label),
                  Text('Kept for you whenever you come back.', style: T.caption.c(C.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen celebration after a purchase or trial start (web `Celebration`).
class _Celebration extends StatelessWidget {
  const _Celebration({required this.offer});
  final Offer offer;
  @override
  Widget build(BuildContext context) {
    final trial = offer.trialDays > 0;
    final ends = DateTime.now().add(Duration(days: offer.trialDays));
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final perks = [
      'Every course and single class',
      'All guided meditations',
      if (trial) 'Reminder before your trial ends' else 'Cancel anytime in your store account',
    ];
    Widget rise(int i, Widget child) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + i * 120),
      curve: Curves.easeOutCubic,
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: c),
      ),
      child: child,
    );
    return Material(
      color: C.cream,
      child: Stack(
        children: [
          const Positioned.fill(child: Confetti(height: 900)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
              child: Column(
                children: [
                  const Spacer(),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.elasticOut,
                    builder: (_, t, c) => Transform.scale(scale: t, child: c),
                    child: Container(
                      width: 116,
                      height: 116,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [C.goldSoft, C.gold],
                        ),
                        boxShadow: [
                          BoxShadow(color: C.gold.withValues(alpha: 0.45), blurRadius: 40, offset: const Offset(0, 12)),
                        ],
                      ),
                      child: const Icon(LucideIcons.crown, size: 52, color: C.ink),
                    ),
                  ),
                  const SizedBox(height: 28),
                  rise(0, Text(
                    trial ? 'Your free trial\nhas started' : 'Welcome to Plus',
                    textAlign: TextAlign.center,
                    style: T.displayMd.copyWith(fontSize: 32),
                  )),
                  const SizedBox(height: 10),
                  rise(1, Text(
                    trial
                        ? 'Enjoy everything free until ${ends.day} ${months[ends.month - 1]}.'
                        : 'Every course, class and meditation is now yours.',
                    textAlign: TextAlign.center,
                    style: T.body.c(C.muted),
                  )),
                  const SizedBox(height: 24),
                  for (final (i, p) in perks.indexed)
                    rise(2 + i, Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(color: C.jade, shape: BoxShape.circle),
                            child: const Icon(LucideIcons.check, size: 15, color: C.ivory),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(p, style: T.bodySm.copyWith(fontWeight: FontWeight.w600))),
                        ],
                      ),
                    )),
                  const Spacer(),
                  rise(6, EnsoButton(
                    label: 'Start practicing',
                    onTap: () => Navigator.of(context).pop(),
                  )),
                ],
              ),
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
