import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/audio_service.dart';
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
import '../widgets/paywall_film.dart';

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
  late String variant;
  bool busy = false;
  bool surveyOpen = false;
  String? reveal;

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

  @override
  void dispose() {
    // Onboarding music runs until the person leaves the onboarding paywall.
    if (widget.from == 'onboarding' && Ambient.state.value.key == 'music-bamboo') Ambient.stop();
    super.dispose();
  }

  void _leave() {
    if (widget.from == 'onboarding' || !context.canPop()) {
      context.go('/');
    } else {
      context.pop();
    }
  }

  /// Ask once, then reveal the relevant offer before showing its paywall.
  Future<void> _close() async {
    if (surveyOpen) return;
    final app = context.read<AppState>();
    if (!shouldAskExitSurvey(variant, app.exitSurveyAsked)) {
      _leave();
      return;
    }
    app.markExitSurveyAsked();
    surveyOpen = true;
    final reason = await showEnsoSheet<String>(
      context,
      builder: (_) => const _ExitSurvey(),
    );
    if (!mounted) return;
    surveyOpen = false;
    final next = paywallSurveyOffer(reason);
    if (next == null) return;
    setState(() => reveal = next);
  }

  void _showRevealedOffer() {
    final next = reveal;
    if (next == null) return;
    setState(() {
      variant = next;
      selected = _offers.first.id;
      reveal = null;
    });
    context.read<AppState>().setPaywallOffer(next);
    TrackingService.paywallViewed(next);
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
    final isExit = variant == 'exit';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) {
          if (reveal != null) { _leave(); } else { _close(); }
        }
      },
      child: reveal != null ? _OfferReveal(
        lower: reveal == 'exit',
        offer: PurchaseService.localized(reveal == 'exit' ? exitOffer : regularOffers.first),
        onContinue: _showRevealedOffer,
        onSkip: _leave,
      ) : EnsoScaffold(
        body: Column(
          children: [
            Expanded(
              child: LayoutBuilder(builder: (context, bounds) => SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height > 720 ? math.max(bounds.maxWidth * 9 / 16, math.min(MediaQuery.sizeOf(context).height * 0.4, 420.0)) : math.min(bounds.maxWidth * 9 / 16, MediaQuery.sizeOf(context).height <= 600 ? 180.0 : 230.0),
                      child: Stack(fit: StackFit.expand, children: [
                        const PaywallFilm(),
                        Positioned(top: topInset(context) + 6, right: 16, child: CircleBtn(icon: LucideIcons.x, tone: Tone.dark, label: 'Close', onTap: busy ? null : _close)),
                        // dark glass keeps the label readable over any film frame
                        Positioned(left: 14, bottom: 10, child: Glass(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(LucideIcons.crown, size: 12, color: C.gold),
                          const SizedBox(width: 6),
                          Text('TAICHI FLOW PLUS', style: T.tiny.copyWith(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w700, color: C.ivory)),
                        ]))),
                      ]),
                    ),
                    Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Find your strength.\nMove with calm.', style: T.displayMd.copyWith(fontSize: 25, height: 1.12)),
                      const SizedBox(height: 12),
                      for (final (icon, text) in [
                        (LucideIcons.layers, '${Content.i.plans.where((p) => !p.isSingleSession).length} progressive courses · beginner to advanced'),
                        (LucideIcons.leaf, 'Tai Chi, Qigong & mindful walking'),
                        (LucideIcons.moon, '${Content.i.meditations.length} guided meditations · unwind deeply'),
                      ]) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Icon(icon, size: 17, color: C.jade), const SizedBox(width: 10), Expanded(child: Text(text, style: T.bodySm.copyWith(fontSize: 13, fontWeight: FontWeight.w500)))])),
                      SizedBox(height: 22, child: Row(children: [
                        Icon(isExit ? LucideIcons.gift : offer.trialDays > 0 ? LucideIcons.check : LucideIcons.crown, size: 15, color: C.jade),
                        const SizedBox(width: 7),
                        Expanded(child: Text(isExit ? 'Your exclusive yearly saving' : offer.trialDays > 0 ? '7 days on us · explore all of Plus' : 'Every course. Every class. All yours.', style: T.caption.c(C.jadeDeep))),
                      ])),
                      const SizedBox(height: 8),
                      IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final (i, o) in _offers.indexed) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(child: _OfferCard(offer: o, compact: !isExit, selected: selected == o.id, onTap: busy ? null : () => setState(() => selected = o.id))),
                      ]])),
                      Wrap(alignment: WrapAlignment.center, children: [
                        if (variant == 'regular' && widget.from == 'onboarding') EnsoButton(label: 'View all plans', variant: BtnVariant.ghost, size: BtnSize.sm, expand: false, onTap: busy ? null : () => context.push('/paywall?from=${widget.from}&offer=gift')),
                        EnsoButton(label: 'Restore purchase', variant: BtnVariant.ghost, size: BtnSize.sm, expand: false, onTap: busy ? null : () async {
                          final app = context.read<AppState>();
                          final restored = await PurchaseService.restore();
                          Toast.show(restored ? 'Purchase restored' : 'No previous purchase found');
                          if (restored && mounted) { if (!app.premium.active) app.setPremium('yearly'); _leave(); }
                        }),
                      ]),
                    ])),
                  ],
                ),
              )),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                bottomInset(context) + 10,
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
                  const SizedBox(height: 7),
                  Text(
                    _terms(offer),
                    textAlign: TextAlign.center,
                    style: T.tiny.copyWith(
                      height: 1.35,
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

/// Exit survey shown once, the first time the regular paywall is closed.
class _ExitSurvey extends StatelessWidget {
  const _ExitSurvey();
  @override
  Widget build(BuildContext context) {
    const reasons = [
      ('price', LucideIcons.tag, 'The price feels a bit high', 'Show me a better deal'),
      ('later', LucideIcons.leaf, 'I need to check it first', 'See the 7-day trial'),
      ('unsure', LucideIcons.circleHelp, "I'm not sure it's for me", 'Explore the trial offer'),
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

/// Pre-purchase offer reveal, deliberately separate from purchase success.
class _OfferReveal extends StatelessWidget {
  const _OfferReveal({required this.lower, required this.offer, required this.onContinue, required this.onSkip});
  final bool lower;
  final Offer offer;
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Material(color: C.cream, child: Stack(children: [
      if (!reduceMotion) const Positioned.fill(child: Confetti(height: 650)),
      SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(28, 24, 28, 20), child: Column(children: [
        Align(alignment: Alignment.centerRight, child: CircleBtn(icon: LucideIcons.x, label: 'Close offer', onTap: onSkip)),
        Expanded(child: Center(child: SingleChildScrollView(child: Column(children: [
          TweenAnimationBuilder<double>(tween: Tween(begin: reduceMotion ? 1 : 0, end: 1), duration: Duration(milliseconds: reduceMotion ? 0 : 900), curve: Curves.elasticOut,
            builder: (_, t, child) => Transform.scale(scale: t, child: child),
            child: Container(width: 116, height: 116, decoration: BoxDecoration(shape: BoxShape.circle, color: C.goldSoft, boxShadow: S.soft), child: Icon(lower ? LucideIcons.gift : LucideIcons.crown, size: 52, color: C.jadeDeep))),
          const SizedBox(height: 28),
          Text(lower ? 'Your lower price\nis ready' : 'Your 7-day free trial\nis ready', textAlign: TextAlign.center, style: T.displayMd.copyWith(fontSize: 30)),
          const SizedBox(height: 12),
          Text(lower ? '${offer.price}/year · full Plus access' : '7 days to explore every course, class and meditation.', textAlign: TextAlign.center, style: T.body.c(C.jadeDeep)),
          const SizedBox(height: 12),
          Text(lower ? 'Billed yearly. Auto-renews. Cancel anytime.' : 'For eligible yearly subscribers. Starts only after store confirmation.', textAlign: TextAlign.center, style: T.bodySm.c(C.muted)),
        ])))),
        EnsoButton(label: lower ? 'See my lower price' : 'See my trial plan', onTap: onContinue),
        const SizedBox(height: 8),
        EnsoButton(label: 'Continue with free sessions', variant: BtnVariant.ghost, onTap: onSkip),
      ]))),
    ]));
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

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });
  final Offer offer;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? C.jadeSoft : C.ivory,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? C.jade : C.line, width: 2),
        ),
        child: compact ? ConstrainedBox(constraints: const BoxConstraints(minHeight: 72), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, spacing: 4, children: [
          Row(children: [Expanded(child: Text(offer.id == 'gift' ? 'Yearly' : offer.title, style: T.caption.copyWith(fontWeight: FontWeight.w700, color: C.ink))), Icon(selected ? LucideIcons.circleCheck : LucideIcons.circle, size: 16, color: selected ? C.jade : C.muted)]),
          Text(offer.price, style: T.body.copyWith(fontWeight: FontWeight.w700)),
          Text(offer.trialDays > 0 ? '7 days free' : offer.period == 'once' ? 'Pay once' : 'Per ${offer.period}', style: T.tiny.c(selected ? C.jadeDeep : C.muted)),
        ])) : Row(
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
                  Text(offer.id == 'gift' ? 'Yearly' : offer.id == 'exit' ? 'Yearly · special price' : offer.title, style: T.bodySm.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    offer.trialDays > 0
                        ? '${offer.trialDays}-day free trial'
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
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if (offer.strike != null) ...[
                    Text(offer.strike ?? '', style: T.tiny.copyWith(decoration: TextDecoration.lineThrough, color: C.muted)),
                    const SizedBox(width: 5),
                  ],
                  Text(offer.price, style: T.bodySm.copyWith(fontWeight: FontWeight.w800).tab),
                ]),
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
