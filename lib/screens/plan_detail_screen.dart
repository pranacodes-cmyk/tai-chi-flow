import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../logic/logic.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/scaffold.dart';
import '../widgets/sheet.dart';
import '../widgets/toast.dart';
import '../widgets/ui.dart';
import 'session_screen.dart';

const equipmentLabel = {'none': 'No equipment', 'chair': 'Chair', 'wall': 'Wall', 'mat': 'Mat'};

class PlanDetailScreen extends StatelessWidget {
  const PlanDetailScreen({super.key, required this.planId});
  final String planId;

  @override
  Widget build(BuildContext context) {
    final plan = Content.i.plan(planId);
    if (plan == null) return const _NotFound();
    // single workouts have no day list — show the session itself
    if (plan.isSingleSession) return SessionScreen(sessionId: planSessionId(plan.id, 1));
    final app = context.watch<AppState>();
    final premium = app.premium.active;
    final completed = app.planProgress[planId]?.completedDays ?? const <int>[];
    final next = nextPlanDay(plan.days.length, completed);
    final isActive = app.activePlanId == planId;
    final pct = completed.length / plan.days.length;
    final nextLocked = isDayLocked(plan, next, premium);

    void openDay(int day) {
      if (isDayLocked(plan, day, premium)) {
        context.push('/paywall?from=plan');
        return;
      }
      context.push('/session/${planSessionId(plan.id, day)}');
    }

    void cta() {
      if (!isActive) {
        app.startPlan(plan.id);
        Toast.show('New plan started', description: '${plan.title} is now on your Today screen.', tone: 'success');
      }
      openDay(next);
    }

    void menu() {
      showEnsoSheet<void>(context, builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(left: 4), child: Text(plan.title, style: T.title)),
            const SizedBox(height: 16),
            _MenuRow(
              icon: LucideIcons.rotateCcw,
              label: 'Restart from Day 1',
              onTap: () {
                app.restartPlan(plan.id);
                Navigator.pop(ctx);
                Toast.show('Plan restarted', description: 'Fresh start from Day 1.');
              },
            ),
            if (!isActive) ...[
              const SizedBox(height: 10),
              _MenuRow(
                icon: LucideIcons.target,
                label: 'Make this my plan',
                onTap: () {
                  app.startPlan(plan.id);
                  Navigator.pop(ctx);
                  Toast.show('Set as your plan', description: "You'll see it on Today.", tone: 'success');
                },
              ),
            ],
          ]),
        );
      });
    }

    return EnsoScaffold(
      lightIcons: true,
      body: Stack(children: [
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: bottomInset(context) + 120),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            HeroHeader(
              image: img(plan.image),
              height: 380,
              topBar: Row(children: [
                const BackBtn(tone: Tone.dark),
                const Spacer(),
                CircleBtn(icon: LucideIcons.ellipsis, tone: Tone.dark, onTap: menu, label: 'More'),
              ]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Eyebrow(plan.group, color: C.ivory.withValues(alpha: 0.7)),
                const SizedBox(height: 8),
                Text(plan.title, style: T.displayLg.c(C.ivory)),
                const SizedBox(height: 4),
                Text(plan.subtitle, style: T.bodySm.c(C.ivory.withValues(alpha: 0.8))),
                if (plan.premium && !premium) ...[
                  const SizedBox(height: 12),
                  PlusChip(label: plan.freeDays > 0 ? 'First ${plan.freeDays} days free' : 'Enso Plus'),
                ],
              ]),
            ),
            Transform.translate(
              offset: const Offset(0, -16),
              child: Container(
                decoration: const BoxDecoration(color: C.cream, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    for (final (i, s) in [
                      (LucideIcons.calendarDays, '${plan.days.length}', 'days'),
                      (LucideIcons.clock, '${plan.minutesPerDay}', 'min/day'),
                      (LucideIcons.target, plan.level, 'level'),
                      (LucideIcons.armchair, equipmentLabel[plan.equipment] ?? '', 'needs'),
                    ].indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          decoration: BoxDecoration(color: C.ivory, borderRadius: BorderRadius.circular(20), boxShadow: S.soft),
                          child: Column(children: [
                            Icon(s.$1, size: 18, color: C.jade),
                            const SizedBox(height: 6),
                            Text(s.$2, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(fontWeight: FontWeight.w700, color: C.ink, height: 1.2)),
                            Text(s.$3, style: T.tiny.copyWith(fontSize: 11, fontWeight: FontWeight.w400)),
                          ]),
                        ),
                      ),
                    ],
                  ]),
                  if (completed.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: C.jadeSoft, borderRadius: BorderRadius.circular(24)),
                      child: Row(children: [
                        Ring(value: pct, size: 54, stroke: 5, track: C.ivory, child: Text('${(pct * 100).round()}%', style: T.tiny.copyWith(fontWeight: FontWeight.w700, color: C.jadeDeep).tab)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${completed.length} of ${plan.days.length} days complete', style: T.label.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: C.jadeDeep)),
                            Text(completed.length >= plan.days.length ? 'Journey complete — beautiful work.' : 'Keep the rhythm going.', style: T.caption.c(C.jadeDeep.withValues(alpha: 0.7))),
                          ]),
                        ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(plan.description, style: T.body.c(C.ink.withValues(alpha: 0.8))),
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final b in plan.benefits)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: C.sand, borderRadius: BorderRadius.circular(99)),
                        child: Text(b, style: T.caption.copyWith(fontWeight: FontWeight.w600, color: C.ink)),
                      ),
                  ]),
                  const SizedBox(height: 32),
                  Text('Your days', style: T.title.s(20)),
                  const SizedBox(height: 14),
                  for (final d in plan.days)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DayRow(
                        day: d.day,
                        title: d.title,
                        subtitle: '${formatMinutes(totalSeconds(d.items))} · ${d.items.length} moves · ${d.focus.join(', ')}',
                        restore: d.restore,
                        done: completed.contains(d.day),
                        locked: isDayLocked(plan, d.day, premium),
                        isNext: d.day == next && !completed.contains(d.day),
                        onTap: () => openDay(d.day),
                      ),
                    ),
                ]),
              ),
            ),
          ]),
        ),
        BottomCta(
          child: nextLocked
              ? EnsoButton(label: 'Unlock Day $next with Enso Plus', variant: BtnVariant.gold, icon: LucideIcons.crown, onTap: () => context.push('/paywall?from=plan'))
              : EnsoButton(
                  label: !isActive
                      ? 'Start this plan'
                      : completed.length >= plan.days.length
                          ? 'Practice again'
                          : completed.isNotEmpty
                              ? 'Continue · Day $next'
                              : 'Start Day $next',
                  onTap: cta,
                ),
        ),
      ]),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.title,
    required this.subtitle,
    required this.restore,
    required this.done,
    required this.locked,
    required this.isNext,
    required this.onTap,
  });
  final int day;
  final String title, subtitle;
  final bool restore, done, locked, isNext;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final Widget badge;
    if (done) {
      badge = const Icon(LucideIcons.check, size: 20, color: C.ivory);
    } else if (restore) {
      badge = const Icon(LucideIcons.leaf, size: 20, color: C.jadeDeep);
    } else {
      badge = Text('$day', style: T.label.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: isNext ? C.ivory : C.ink.withValues(alpha: 0.7)).tab);
    }
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.ivory,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: isNext ? C.jade : Colors.transparent, width: 2),
          boxShadow: isNext ? S.card : S.soft,
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: done ? C.jade : (restore ? C.jadeSoft : (isNext ? null : C.sand)),
              gradient: !done && !restore && isNext ? G.jade : null,
            ),
            child: badge,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Day $day · $title', style: T.label),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption),
            ]),
          ),
          if (locked)
            Container(width: 32, height: 32, decoration: const BoxDecoration(color: C.sand, shape: BoxShape.circle), child: const Icon(LucideIcons.lock, size: 14, color: C.muted))
          else if (isNext)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: C.jade, borderRadius: BorderRadius.circular(99)),
              child: Text('NEXT', style: T.tiny.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: C.ivory)),
            ),
        ]),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: C.ivory, borderRadius: BorderRadius.circular(20), boxShadow: S.soft),
          child: Row(children: [Icon(icon, size: 20, color: C.jade), const SizedBox(width: 12), Text(label, style: T.label)]),
        ),
      );
}

class _NotFound extends StatelessWidget {
  const _NotFound({super.key});
  @override
  Widget build(BuildContext context) => EnsoScaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Not found', style: T.displayMd),
              const SizedBox(height: 8),
              Text("This page doesn't exist or has moved.", style: T.bodySm.c(C.muted)),
              const SizedBox(height: 24),
              EnsoButton(label: 'Back to Today', expand: false, onTap: () => context.go('/')),
            ]),
          ),
        ),
      );
}

class NotFoundView extends _NotFound {
  const NotFoundView({super.key});
}
