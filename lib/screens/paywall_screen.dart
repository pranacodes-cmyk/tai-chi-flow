import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../services/purchase_service.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/confetti.dart';
import '../widgets/scaffold.dart';
import '../widgets/sheet.dart';
import '../widgets/toast.dart';
import '../widgets/ui.dart';

const _benefits = [
  'All 19 plans & 55+ guided movements',
  'Full meditation & sleep library',
  'Voice coaching & calming soundscapes',
  'Progress insights & achievements',
];

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, required this.from});
  final String from;
  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  String selected = 'yearly';
  bool busy = false;
  bool showClose = false;
  bool giftShown = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => showClose = true);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _leave() {
    if (widget.from == 'onboarding' || !context.canPop()) {
      context.go('/');
    } else {
      context.pop();
    }
  }

  Future<void> _close() async {
    if (widget.from == 'onboarding' && !giftShown) {
      giftShown = true;
      context.read<AppState>().ensureOffer();
      final claimed = await showEnsoSheet<bool>(context, builder: (_) => const _GiftSheet());
      if (!mounted) return;
      if (claimed == true) {
        await _buy('gift');
      } else {
        _leave();
      }
      return;
    }
    _leave();
  }

  Future<void> _buy(String plan) async {
    setState(() => busy = true);
    final ok = await PurchaseService.purchase(plan);
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    context.read<AppState>().setPremium(plan);
    await showEnsoSheet<void>(context, builder: (_) => const _SuccessSheet());
    if (mounted) _leave();
  }

  @override
  Widget build(BuildContext context) {
    final offer = offers.firstWhere((o) => o.id == selected);
    final top = topInset(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && showClose) _close();
      },
      child: EnsoScaffold(
        lightIcons: true,
        body: Stack(children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: bottomInset(context) + 170),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                height: 340,
                child: Stack(fit: StackFit.expand, children: [
                  ClipRect(child: KenBurns(child: EImage(img('hero-paywall')))),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [const Color(0xFF1F2B25).withValues(alpha: 0.25), Colors.transparent, C.cream],
                        stops: const [0, 0.35, 1],
                      ),
                    ),
                  ),
                ]),
              ),
              Transform.translate(
                offset: const Offset(0, -96),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(gradient: G.gold, borderRadius: BorderRadius.circular(99)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(LucideIcons.crown, size: 14, color: C.ink),
                        const SizedBox(width: 6),
                        Text('ENSO PLUS', style: T.tiny.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.7, color: C.ink)),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Unlock your '),
                        TextSpan(text: 'full', style: T.serifAccent.copyWith(fontSize: 36, color: C.jade)),
                        const TextSpan(text: ' practice'),
                      ]),
                      style: T.displayLg,
                    ),
                    const SizedBox(height: 20),
                    for (final (i, b) in _benefits.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Reveal(
                          delay: 0.1 + i * 0.07,
                          dy: 0,
                          child: Row(children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(color: C.jade, shape: BoxShape.circle),
                              child: const Icon(LucideIcons.check, size: 14, color: C.ivory),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(b, style: T.bodySm.w(FontWeight.w500))),
                          ]),
                        ),
                      ),
                    const SizedBox(height: 16),
                    for (final o in offers)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _OfferCard(offer: o, selected: selected == o.id, onTap: () => setState(() => selected = o.id)),
                      ),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(LucideIcons.shieldCheck, size: 16, color: C.jade),
                      const SizedBox(width: 8),
                      Text(offer.trialDays != null ? 'No payment today · Cancel anytime' : 'Cancel anytime in Google Play', style: T.caption),
                    ]),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -96),
                child: Column(children: [
                  HScroll(
                    gap: 12,
                    children: [
                      for (final t in Content.i.testimonials)
                        Container(
                          width: 260,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: C.ivory, borderRadius: BorderRadius.circular(24), boxShadow: S.soft),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [for (var i = 0; i < t.rating; i++) const Icon(Icons.star_rounded, size: 16, color: C.gold)]),
                            const SizedBox(height: 8),
                            Text('“${t.text}”', style: T.caption.copyWith(fontSize: 14, color: C.ink, height: 1.55)),
                            const SizedBox(height: 8),
                            Text(t.name, style: T.tiny),
                          ]),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Pressable(
                      onTap: () async {
                        final r = await PurchaseService.restore();
                        Toast.show(r ? 'Purchase restored' : 'No previous purchase found', description: r ? null : 'Purchases made on this Google account will appear here.');
                      },
                      child: Text('Restore purchase', style: T.tiny.w(FontWeight.w500)),
                    ),
                    const SizedBox(width: 20),
                    Text('Terms', style: T.tiny.w(FontWeight.w500)),
                    const SizedBox(width: 20),
                    Text('Privacy', style: T.tiny.w(FontWeight.w500)),
                  ]),
                ]),
              ),
            ]),
          ),
          Positioned(
            right: 20,
            top: top + 12,
            child: AnimatedScale(
              scale: showClose ? 1 : 0.8,
              duration: const Duration(milliseconds: 300),
              child: AnimatedOpacity(
                opacity: showClose ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(ignoring: !showClose, child: CircleBtn(icon: LucideIcons.x, tone: Tone.dark, onTap: _close, label: 'Close')),
              ),
            ),
          ),
          BottomCta(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              EnsoButton(label: offer.trialDays != null ? 'Start my free trial' : 'Continue', loading: busy, onTap: () => _buy(selected)),
              const SizedBox(height: 10),
              Text(
                '${offer.trialDays != null ? '${offer.trialDays} days free, then ${offer.price}/${offer.period}.' : '${offer.price} per ${offer.period}.'} Test mode — no real charge.',
                textAlign: TextAlign.center,
                style: T.tiny.w(FontWeight.w400),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, required this.selected, required this.onTap});
  final Offer offer;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: selected ? C.ivory : C.ivory.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: selected ? C.jade : C.line, width: selected ? 2.5 : 1),
            boxShadow: selected ? S.card : null,
          ),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? C.jade : Colors.transparent,
                border: Border.all(color: selected ? C.jade : C.ink.withValues(alpha: 0.2), width: 2),
              ),
              child: selected ? const Icon(LucideIcons.check, size: 14, color: C.ivory) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(offer.title, style: T.label.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
                  if (offer.save != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: C.terracottaSoft, borderRadius: BorderRadius.circular(99)),
                      child: Text(offer.save!, style: T.tiny.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: C.terracotta)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text('${offer.trialDays != null ? '${offer.trialDays}-day free trial · ' : ''}${offer.price}/${offer.period}', style: T.caption),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(offer.perWeek, style: T.label.copyWith(fontSize: 17, fontWeight: FontWeight.w700).tab),
              Text('per week', style: T.tiny.copyWith(fontSize: 11, fontWeight: FontWeight.w400)),
            ]),
          ]),
        ),
        if (offer.badge != null)
          Positioned(
            left: 20,
            top: -10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(99)),
              child: Text(offer.badge!.toUpperCase(), style: const TextStyle(fontFamily: T.family, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: C.ivory)),
            ),
          ),
      ]),
    );
  }
}

class _GiftSheet extends StatefulWidget {
  const _GiftSheet();
  @override
  State<_GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends State<_GiftSheet> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expires = context.read<AppState>().offerExpiresAt ?? DateTime.now();
    final left = expires.difference(DateTime.now());
    final secs = left.isNegative ? 0 : left.inSeconds;
    final countdown = '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
          builder: (_, v, child) => Transform.rotate(angle: -0.21 * (1 - v), child: Transform.scale(scale: 0.6 + 0.4 * v, child: child)),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(gradient: G.ember, borderRadius: BorderRadius.circular(26), boxShadow: S.float),
            child: const Icon(LucideIcons.gift, size: 40, color: C.ivory),
          ),
        ),
        const SizedBox(height: 20),
        const Eyebrow('New user gift', color: C.terracotta),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: '60% off your '),
            TextSpan(text: 'first year', style: T.serifAccent.copyWith(fontSize: 34)),
          ]),
          textAlign: TextAlign.center,
          style: T.displayLg,
        ),
        const SizedBox(height: 8),
        Text('A one-time welcome offer, just for you.', style: T.bodySm.c(C.muted)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(99)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Expires in', style: T.tiny.copyWith(color: C.ivory.withValues(alpha: 0.7), fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            Text(countdown, style: T.label.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: C.ivory).tab),
          ]),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: C.ivory, borderRadius: BorderRadius.circular(24), boxShadow: S.soft),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(giftOffer.strike!, style: T.title.copyWith(color: C.muted, fontWeight: FontWeight.w600, decoration: TextDecoration.lineThrough)),
              const SizedBox(width: 12),
              Text(giftOffer.price, style: T.displayXl.c(C.jadeDeep)),
            ]),
            const SizedBox(height: 4),
            Text('for your first year · just ${giftOffer.perWeek}/week', style: T.caption),
          ]),
        ),
        const SizedBox(height: 24),
        EnsoButton(label: 'Claim my gift', variant: BtnVariant.gold, onTap: () => Navigator.of(context).pop(true)),
        const SizedBox(height: 4),
        EnsoButton(label: 'No thanks', variant: BtnVariant.ghost, size: BtnSize.md, onTap: () => Navigator.of(context).pop(false)),
      ]),
    );
  }
}

class _SuccessSheet extends StatelessWidget {
  const _SuccessSheet();
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(child: Confetti()),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Column(children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(gradient: G.gold, shape: BoxShape.circle, boxShadow: S.float),
              child: const Icon(LucideIcons.crown, size: 40, color: C.ink),
            ),
          ),
          const SizedBox(height: 20),
          Text('Welcome to Plus', style: T.displayLg),
          const SizedBox(height: 8),
          Text('Every plan, meditation and soundscape is now yours. Enjoy the journey.', textAlign: TextAlign.center, style: T.bodySm.c(C.muted)),
          const SizedBox(height: 28),
          EnsoButton(label: 'Start practicing', onTap: () => Navigator.of(context).pop()),
        ]),
      ),
    ]);
  }
}
