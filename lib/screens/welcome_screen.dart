import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/content.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final top = topInset(context);
    final bottom = bottomInset(context);
    return EnsoScaffold(
      background: C.forest,
      lightIcons: true,
      body: Stack(fit: StackFit.expand, children: [
        ClipRect(child: KenBurns(child: EImage(img('hero-welcome')))),
        DecoratedBox(decoration: BoxDecoration(gradient: G.scrim)),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 160,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.forest.withValues(alpha: 0.4), Colors.transparent]),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(28, top + 22, 28, bottom + 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Reveal(
              delay: 0.2,
              dy: -8,
              child: Row(children: [
                Image.asset(img('logo-enso-light.png'), width: 32, height: 32),
                const SizedBox(width: 10),
                Text('Enso', style: T.label.copyWith(fontSize: 17, fontWeight: FontWeight.w700, color: C.ivory, letterSpacing: -0.34)),
              ]),
            ),
            const Spacer(),
            Reveal(delay: 0.35, dy: 14, child: Eyebrow('Tai Chi · Qigong · Chair Yoga', color: C.ivory.withValues(alpha: 0.75))),
            const SizedBox(height: 12),
            Reveal(
              delay: 0.45,
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Meditation\n'),
                  TextSpan(text: 'in motion.', style: T.serifAccent.copyWith(fontSize: 52.8, color: C.ivory, height: 1.0)),
                ]),
                style: T.displayXl.copyWith(fontSize: 45.6, color: C.ivory),
              ),
            ),
            const SizedBox(height: 16),
            Reveal(
              delay: 0.6,
              dy: 14,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 310),
                child: Text(
                  'Gentle daily practice for better balance, flexibility and calm — at any age.',
                  style: T.body.copyWith(fontSize: 17, color: C.ivory.withValues(alpha: 0.85)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Reveal(
              delay: 0.75,
              dy: 0,
              child: Row(children: [
                for (var i = 0; i < 5; i++) const Icon(Icons.star_rounded, size: 18, color: C.gold),
                const SizedBox(width: 12),
                Text('Loved by people of every age', style: T.caption.copyWith(color: C.ivory.withValues(alpha: 0.8))),
              ]),
            ),
            const SizedBox(height: 28),
            Reveal(
              delay: 0.85,
              dy: 20,
              child: Column(children: [
                EnsoButton(
                  label: 'Start my journey',
                  variant: BtnVariant.ivory,
                  trailing: LucideIcons.arrowRight,
                  onTap: () => context.go('/onboarding'),
                ),
                const SizedBox(height: 14),
                Text('1-minute quiz · Personalized plan', style: T.caption.copyWith(color: C.ivory.withValues(alpha: 0.65))),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
