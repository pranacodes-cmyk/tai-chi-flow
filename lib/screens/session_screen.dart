import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../logic/logic.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/exercise_body.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';
import 'plan_detail_screen.dart';

class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final session = resolveSession(sessionId);
    if (session == null) return const NotFoundView();
    final app = context.watch<AppState>();
    final audio = app.audio;
    final total = totalSeconds(session.items, session.restSec);
    final kcal = kcalForWeight(session.baseKcal, app.profile.weightKg);
    final exercises = [for (final it in session.items) (it: it, ex: Content.i.exercise(it.e)!)];
    final needs = exercises.map((x) => x.ex.equipment).where((e) => e != 'none').toSet().toList();
    final plan = session.planId == null ? null : Content.i.plan(session.planId!);
    final locked = plan != null && isDayLocked(plan, session.day ?? 1, app.premium.active);
    final fav = app.favorites.contains(sessionId);
    final trackName = Content.i.soundscapes.where((s) => s.id == audio.musicTrack).firstOrNull?.name ?? 'Zen Garden';

    return EnsoScaffold(
      lightIcons: true,
      body: Stack(children: [
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: bottomInset(context) + 120),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            HeroHeader(
              image: img(session.image),
              height: 360,
              topBar: Row(children: [
                const BackBtn(tone: Tone.dark),
                const Spacer(),
                CircleBtn(
                  icon: fav ? Icons.favorite_rounded : LucideIcons.heart,
                  iconColor: fav ? C.terracotta : C.ivory,
                  tone: Tone.dark,
                  label: 'Favorite',
                  onTap: () => app.toggleFavorite(sessionId),
                ),
              ]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Eyebrow(session.subtitle, color: C.ivory.withValues(alpha: 0.7)),
                const SizedBox(height: 8),
                Text(session.title, style: T.displayLg.c(C.ivory)),
                if (locked) ...[
                  const SizedBox(height: 10),
                  const PlusChip(label: 'Enso Plus'),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  _Meta(LucideIcons.clock, formatMinutes(total)),
                  const SizedBox(width: 16),
                  _Meta(LucideIcons.flame, '$kcal kcal'),
                  const SizedBox(width: 16),
                  _Meta(LucideIcons.layers, '${session.items.length} moves'),
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (needs.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: C.goldSoft, borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      Icon(LucideIcons.armchair, size: 20, color: C.ink.withValues(alpha: 0.7)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text.rich(TextSpan(children: [
                          const TextSpan(text: "You'll need: "),
                          TextSpan(text: needs.map((n) => n[0].toUpperCase() + n.substring(1)).join(', '), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ]), style: T.caption.copyWith(fontSize: 14, color: C.ink, fontWeight: FontWeight.w500)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(children: [
                  Expanded(child: _Toggle(icon: LucideIcons.mic, label: 'Voice coach', sub: audio.voice ? 'On' : 'Off', on: audio.voice, onTap: () => app.setAudio((a) => a.voice = !a.voice))),
                  const SizedBox(width: 12),
                  Expanded(child: _Toggle(icon: LucideIcons.music, label: 'Music', sub: audio.music ? trackName : 'Off', on: audio.music, onTap: () => app.setAudio((a) => a.music = !a.music))),
                ]),
                const SizedBox(height: 28),
                Text('Movements', style: T.title.s(20)),
                const SizedBox(height: 12),
                for (final (i, x) in exercises.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Reveal(
                      delay: (i * 0.03).clamp(0, 0.4).toDouble(),
                      child: Pressable(
                        onTap: () => showExerciseSheet(context, x.ex),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
                          decoration: BoxDecoration(color: C.ivory, borderRadius: BorderRadius.circular(22), boxShadow: S.soft),
                          child: Row(children: [
                            RoundedImage(img(x.ex.image), size: 68),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(x.ex.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.label),
                                const SizedBox(height: 2),
                                Text(x.ex.isAffirmation ? 'Affirmation · Breath' : x.ex.focus.take(2).join(' · '), style: T.caption),
                              ]),
                            ),
                            Text(formatClock(x.it.s), style: T.label.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: C.jadeDeep).tab),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
        BottomCta(
          child: locked
              ? EnsoButton(label: 'Unlock with Enso Plus', variant: BtnVariant.gold, onTap: () => context.push('/paywall?from=session'))
              : EnsoButton(label: 'Begin practice', icon: Icons.play_arrow_rounded, onTap: () => context.push('/player/$sessionId')),
        ),
      ]),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: C.ivory.withValues(alpha: 0.85)),
        const SizedBox(width: 6),
        Text(text, style: T.caption.copyWith(fontSize: 14, color: C.ivory.withValues(alpha: 0.85))),
      ]);
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.icon, required this.label, required this.sub, required this.on, required this.onTap});
  final IconData icon;
  final String label, sub;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: on ? C.jadeSoft : C.ivory, borderRadius: BorderRadius.circular(22), boxShadow: on ? null : S.soft),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: on ? C.jade : C.sand, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: on ? C.ivory : C.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: T.label.s(14)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny.w(FontWeight.w400)),
            ]),
          ),
        ]),
      ),
    );
  }
}
