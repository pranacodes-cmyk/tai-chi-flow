import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../logic/logic.dart';
import '../services/audio_service.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/cards.dart';
import '../widgets/scaffold.dart';
import '../widgets/tab_shell.dart';
import '../widgets/ui.dart';
import '../i18n/i18n.dart';

class MeditateScreen extends StatefulWidget {
  const MeditateScreen({super.key});
  @override
  State<MeditateScreen> createState() => _MeditateScreenState();
}

class _MeditateScreenState extends State<MeditateScreen> {
  String cat = 'All';
  String? get playing =>
      Ambient.state.value.playing ? Ambient.state.value.key : null;

  void _onAmbient() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    Ambient.state.addListener(_onAmbient);
  }

  @override
  void dispose() {
    Ambient.state.removeListener(_onAmbient);
    super.dispose();
  }

  void _toggleSound(String id) {
    if (playing == id) {
      Ambient.pause();
    } else {
      Ambient.play(id, 0.55);
    }
  }

  void _open(String id, bool premium) {
    if (isMeditationLocked(id, premium)) {
      context.push('/paywall?from=meditation');
    } else {
      context.push('/meditation/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final premium = app.premium.active;
    final c = Content.i;
    final list = c.meditations
        .where((m) => cat == 'All' || m.category == cat)
        .toList();
    final featured = c.meditation(
      featuredMeditationId(DateTime.now().hour, app.premium.active),
    )!;
    final offline = c.meditations
        .where((m) => app.downloads.contains(m.id))
        .toList();

    return EnsoScaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          top: topInset(context) + 18,
          bottom: tabBarSpace(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('meditate.title'), style: T.displayLg),
                  const SizedBox(height: 4),
                  Text(
                    tr('meditate.subtitle'),
                    style: T.bodySm.c(C.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Reveal(
              delay: 0.05,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Pressable(
                  onTap: () => _open(featured.id, premium),
                  child: Container(
                    height: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: S.float,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        KenBurns(child: EImage(img(featured.image))),
                        DecoratedBox(
                          decoration: BoxDecoration(gradient: G.scrim),
                        ),
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 20,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Eyebrow(
                                      tr('meditate.featuredMinutes', {'n': featured.minutes}),
                                      color: C.ivory.withValues(alpha: 0.7),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      featured.title,
                                      style: T.displayMd.c(C.ivory),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      featured.subtitle,
                                      style: T.caption.copyWith(
                                        fontSize: 14,
                                        color: C.ivory.withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  color: C.ivory,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 32,
                                  color: C.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Reveal(
              delay: 0.1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Pressable(
                  onTap: () => context.push('/breathe'),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: G.jade,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: S.card,
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 64,
                          height: 64,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _BreathDot(),
                              Icon(LucideIcons.wind, size: 28, color: C.ivory),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('meditate.breathingCoach'),
                                style: T.title.c(C.ivory),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tr('meditate.breathingCoachSubtitle'),
                                style: T.caption.c(
                                  C.ivory.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            HScroll(
              gap: 8,
              children: [
                for (final m in c.meditationCategories)
                  ChipPill(
                    label: trTag(m),
                    active: cat == m,
                    onTap: () => setState(() => cat = m),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (final (i, m) in list.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Reveal(
                        key: ValueKey('$cat-${m.id}'),
                        delay: 0.04 + i * 0.025,
                        child: MeditationRow(
                          m,
                          locked: isMeditationLocked(m.id, premium),
                          onTap: () => _open(m.id, premium),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            SectionHeader(tr('meditate.soundscapes')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  for (final s in c.soundscapes)
                    Pressable(
                      onTap: () => _toggleSound(s.id),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: S.soft,
                          border: Border.all(
                            color: playing == s.id
                                ? C.jade
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            EImage(img(s.image)),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    const Color(0xFF111A15)
                                        .withValues(alpha: 0.8),
                                  ],
                                  stops: const [0.2, 1],
                                ),
                              ),
                            ),
                            Positioned(
                              right: 12,
                              top: 12,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: C.ivory.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  playing == s.id
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 20,
                                  color: C.ink,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 14,
                              bottom: 12,
                              child: Row(
                                children: [
                                  if (playing == s.id) ...[
                                    const _Equalizer(),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    s.name,
                                    style: T.label.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: C.ivory,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (offline.isNotEmpty) ...[
              const SizedBox(height: 36),
              SectionHeader(tr('meditate.availableOffline')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    for (final m in offline)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: MeditationRow(
                          m,
                          locked: isMeditationLocked(m.id, premium),
                          onTap: () => _open(m.id, premium),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BreathDot extends StatefulWidget {
  const _BreathDot();
  @override
  State<_BreathDot> createState() => _BreathDotState();
}

class _BreathDotState extends State<_BreathDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => Transform.scale(
      scale: 0.7 + 0.3 * (0.5 - 0.5 * math.cos(2 * math.pi * _c.value)),
      child: Container(
        decoration: BoxDecoration(
          color: C.ivory.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}

class _Equalizer extends StatefulWidget {
  const _Equalizer();
  @override
  State<_Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<_Equalizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => SizedBox(
      height: 14,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Container(
              width: 3,
              height:
                  14 *
                  (0.3 +
                      0.7 *
                          (0.5 -
                              0.5 *
                                  math.cos(
                                    2 * math.pi * ((_c.value + i * 0.15) % 1),
                                  ))),
              decoration: BoxDecoration(
                color: C.ivory,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
