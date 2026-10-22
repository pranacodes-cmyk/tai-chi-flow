import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../logic/coach.dart';
import '../services/audio_service.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';
import 'plan_detail_screen.dart';

/// Short original article from the "Learn the art" shelf (web /guide/$guideId).
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key, required this.guideId});
  final String guideId;
  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  bool listening = false;

  @override
  void dispose() {
    if (listening) Voice.stop();
    Voice.clearHandlers();
    super.dispose();
  }

  void _toggleListen(Guide g) {
    Haptics.select();
    if (listening) {
      Voice.stop();
      setState(() => listening = false);
      return;
    }
    setState(() => listening = true);
    Voice.speakParts(CoachLines.guide(g), () {
      if (mounted) setState(() => listening = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = Content.i.guide(widget.guideId);
    if (g == null) return const NotFoundView();
    final cat = Content.i.category(g.category);
    final more = Content.i.guides.where((x) => x.id != g.id).take(3).toList();
    return EnsoScaffold(
      lightIcons: true,
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: bottomInset(context) + 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 380,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRect(child: KenBurns(child: EImage(img(g.image)))),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x73202B25),
                              Color(0x00202B25),
                              Color(0x26202B25),
                              C.cream,
                            ],
                            stops: [0, 0.35, 0.6, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        top: topInset(context) + 10,
                        child: const BackBtn(),
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -80),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Reveal(
                          dy: 14,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: C.jade,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      g.tag.toUpperCase(),
                                      style: T.tiny.copyWith(
                                        fontSize: 11,
                                        letterSpacing: 1.1,
                                        fontWeight: FontWeight.w700,
                                        color: C.ivory,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: C.ivory.withValues(alpha: 0.92),
                                      borderRadius: BorderRadius.circular(99),
                                      boxShadow: S.soft,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          LucideIcons.clock,
                                          size: 13,
                                          color: C.ink,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${g.minutes} min read',
                                          style: T.tiny.copyWith(color: C.ink),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Semantics(
                                    button: true,
                                    label: listening
                                        ? 'Stop listening'
                                        : 'Listen to this guide',
                                    child: Pressable(
                                      onTap: () => _toggleListen(g),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: listening ? C.forest : C.ivory,
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                          boxShadow: S.soft,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              listening
                                                  ? LucideIcons.square
                                                  : LucideIcons.headphones,
                                              size: 13,
                                              color: listening
                                                  ? C.ivory
                                                  : C.jadeDeep,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              listening ? 'Stop' : 'Listen',
                                              style: T.tiny.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: listening
                                                    ? C.ivory
                                                    : C.jadeDeep,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(g.title, style: T.displayLg),
                              const SizedBox(height: 4),
                              Text(
                                g.subtitle,
                                style: T.serifAccent.copyWith(
                                  fontSize: 21.6,
                                  color: C.jadeDeep,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                g.intro,
                                style: T.body.copyWith(
                                  fontSize: 17,
                                  height: 1.7,
                                  color: C.ink.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        for (final (i, s) in g.sections.indexed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Reveal(
                              delay: 0.1 + i * 0.06,
                              dy: 14,
                              child: ECard(
                                radius: 26,
                                shadow: S.soft,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.heading, style: T.title.s(17)),
                                    const SizedBox(height: 8),
                                    Text(
                                      s.body,
                                      style: T.bodySm.copyWith(
                                        height: 1.7,
                                        color: C.ink.withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: G.jade,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: S.glow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Eyebrow(
                                'Remember',
                                color: C.ivory.withValues(alpha: 0.7),
                              ),
                              const SizedBox(height: 12),
                              for (final t in g.takeaways)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: C.ivory.withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          LucideIcons.check,
                                          size: 14,
                                          color: C.ivory,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          t,
                                          style: T.label.c(C.ivory),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text('Keep learning', style: T.title.s(20)),
                        const SizedBox(height: 12),
                        for (final m in more)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Pressable(
                              onTap: () =>
                                  context.pushReplacement('/guide/${m.id}'),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  10,
                                  16,
                                  10,
                                ),
                                decoration: BoxDecoration(
                                  color: C.ivory,
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: S.soft,
                                ),
                                child: Row(
                                  children: [
                                    RoundedImage(
                                      img(m.image),
                                      size: 56,
                                      radius: 16,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            m.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: T.label,
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Icon(
                                                LucideIcons.bookOpen,
                                                size: 12,
                                                color: C.muted,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${m.tag} · ${m.minutes} min',
                                                style: T.tiny.w(
                                                  FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      LucideIcons.arrowRight,
                                      size: 16,
                                      color: C.muted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (cat != null)
            BottomCta(
              child: EnsoButton(
                label: 'Practice ${cat.name}',
                trailing: LucideIcons.arrowRight,
                onTap: () => context.push('/category/${cat.id}'),
              ),
            ),
        ],
      ),
    );
  }
}
