import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../logic/logic.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/cards.dart';
import '../widgets/scaffold.dart';
import '../widgets/tab_shell.dart';
import '../widgets/ui.dart';
import '../i18n/i18n.dart';

/// Today, kept to three things: today's lesson, journey progress and short practice.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = Content.i;
    final now = DateTime.now();
    final today = dateKey(now);
    final stats = app.stats;
    final name = app.profile.name;
    final premium = app.premium.active;

    // Today's lesson: the personal plan, or the journey's free day while one is left.
    final active = app.activePlan;
    final activeDone = app.activeCompleted;
    final activeLocked =
        activeDone.length < active.days.length &&
        isDayLocked(
          active,
          nextPlanDay(active.days.length, activeDone),
          premium,
        );
    final journey = c.plan(journeyId);
    final plan =
        c.plan(
          todayPlanId(
            active.id,
            activeLocked: activeLocked,
            journeyFreeDays: journey?.freeDays ?? 0,
            journeyCompleted:
                app.planProgress[journeyId]?.completedDays ?? const <int>[],
          ),
        ) ??
        active;
    final completed =
        app.planProgress[plan.id]?.completedDays ?? const <int>[];
    final dayNumber = nextPlanDay(plan.days.length, completed);
    final day = plan.days[dayNumber - 1];
    final planDone = completed.length >= plan.days.length;
    final locked = !planDone && isDayLocked(plan, dayNumber, premium);
    final todayDone =
        completed.contains(dayNumber) ||
        app.history.any(
          (h) =>
              h.planId == plan.id &&
              h.day == dayNumber &&
              dateKey(h.completedAt) == today,
        );
    final freeDay = !premium && plan.premium && dayNumber <= plan.freeDays;
    final newToday = [
      for (final it in day.items)
        if (it.p == 'New today') c.exercise(it.e)?.name,
    ].whereType<String>().toList();

    final pick = freePickQuickId(now.hour);
    final quick = [
      ...c.quickSessions.where((q) => q.id == pick),
      ...c.quickSessions.where((q) => q.id != pick),
    ];
    final med =
        c.meditation(featuredMeditationId(now.hour, premium)) ??
        c.meditations.first;

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
            _Header(now: now, name: name, streak: stats.streak),
            const SizedBox(height: 24),
            Reveal(
              delay: 0.05,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _LessonHero(
                  plan: plan,
                  day: day,
                  dayNumber: dayNumber,
                  completedCount: completed.length,
                  planDone: planDone,
                  locked: locked,
                  todayDone: todayDone,
                  freeDay: freeDay,
                  newToday: newToday,
                  weightKg: app.profile.weightKg,
                  onStart: () => planDone
                      ? context.go('/courses')
                      : locked
                      ? context.push('/paywall?from=plan')
                      : context.push(
                          '/session/${planSessionId(plan.id, dayNumber)}',
                        ),
                  onOpen: () => context.push('/plan/${plan.id}'),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Reveal(
              delay: 0.1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _JourneyProgress(
                  done: completed.length,
                  total: plan.days.length,
                  streak: stats.streak,
                  onOpen: () => context.push('/plan/${plan.id}'),
                ),
              ),
            ),
            const SizedBox(height: 36),
            Reveal(
              delay: 0.16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    tr('home.shortPractice'),
                    action: tr('common.seeAll'),
                    onAction: () => context.go('/courses?view=classes'),
                  ),
                  HScroll(children: [for (final q in quick) QuickCard(q)]),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _MeditationCard(
                      med: med,
                      evening: now.hour >= 17 || now.hour < 5,
                      onTap: () => context.push('/meditation/${med.id}'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: Reveal(
                delay: 0.4,
                dy: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    tr('home.notAWorkout'),
                    textAlign: TextAlign.center,
                    style: T.serifAccent.copyWith(
                      fontSize: 18.4,
                      color: C.muted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.now, required this.name, required this.streak});
  final DateTime now;
  final String name;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(DateFormat('EEEE, MMM d', appLocale).format(now)),
                const SizedBox(height: 6),
                Text(
                  tr('home.greetingLine', {
                    'greeting': greeting(now.hour),
                    'hasName': name.isNotEmpty ? 'yes' : 'no',
                  }),
                  style: T.displayMd,
                ),
                Text(
                  name.isNotEmpty ? name : tr('home.friendFallback'),
                  style: T.serifAccent.copyWith(
                    fontSize: 30,
                    color: C.jadeDeep,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: tr('home.streakSemantics', {'n': streak}),
                  child: Pressable(
                    onTap: () => context.push('/history'),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: C.ivory,
                        borderRadius: BorderRadius.circular(44),
                        boxShadow: S.soft,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            streak > 0
                                ? Icons.local_fire_department_rounded
                                : LucideIcons.flame,
                            size: 19,
                            color: streak > 0 ? C.terracotta : C.muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$streak',
                            style: T.label
                                .copyWith(fontWeight: FontWeight.w700)
                                .tab,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: tr('home.profileLabel'),
                  child: Pressable(
                    onTap: () => context.go('/profile'),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: G.jade,
                        shape: BoxShape.circle,
                        boxShadow: S.glow,
                      ),
                      child: Text(
                        (name.isNotEmpty ? name : 'E')[0].toUpperCase(),
                        style: T.label.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: C.ivory,
                        ),
                      ),
                    ),
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

/// Today's lesson: one big card with the day, what is new today and a single clear action.
class _LessonHero extends StatelessWidget {
  const _LessonHero({
    required this.plan,
    required this.day,
    required this.dayNumber,
    required this.completedCount,
    required this.planDone,
    required this.locked,
    required this.todayDone,
    required this.freeDay,
    required this.newToday,
    required this.weightKg,
    required this.onStart,
    required this.onOpen,
  });
  final Plan plan;
  final PlanDay day;
  final int dayNumber, completedCount;
  final bool planDone, locked, todayDone, freeDay;
  final List<String> newToday;
  final double weightKg;
  final VoidCallback onStart, onOpen;

  @override
  Widget build(BuildContext context) {
    final total = plan.days.length;
    final pct = completedCount / total;
    final meta = T.caption.copyWith(
      fontSize: 14,
      color: C.ivory.withValues(alpha: 0.8),
    );
    final cta = locked
        ? tr('home.unlockDay', {'day': dayNumber})
        : planDone
        ? tr('home.chooseNextCourse')
        : todayDone
        ? tr('home.doneTapPracticeAgain')
        : tr('home.startDay', {'day': dayNumber});
    // grows past its usual height instead of letting long titles or large text run under the top chips
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 456),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        boxShadow: S.float,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          Positioned.fill(child: KenBurns(child: EImage(img(plan.image)))),
          Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: G.scrim)),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Row(
              children: [
                Flexible(
                  child: Glass(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      planDone ? tr('home.courseComplete') : tr('home.dayOfTotal', {'day': dayNumber, 'total': total}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.tiny.c(C.ivory),
                    ),
                  ),
                ),
                if (freeDay) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: C.ivory,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Text(tr('common.free'), style: T.tiny.c(C.jadeDeep)),
                  ),
                ],
                const Spacer(),
                Ring(
                  value: pct,
                  size: 46,
                  stroke: 4.5,
                  track: C.ivory.withValues(alpha: 0.25),
                  bar: C.ivory,
                  child: Text(
                    '${(pct * 100).round()}%',
                    style: T.tiny
                        .copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: C.ivory,
                        )
                        .tab,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 78, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(
                  locked ? tr('home.todaysLessonPlus') : tr('home.todaysLesson'),
                  color: C.ivory.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 4),
                Text(
                  plan.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: C.ivory.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  planDone ? tr('home.youDidIt') : tr('home.dayTitle', {'day': dayNumber, 'title': day.title}),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: T.displayLg.copyWith(fontSize: 28, color: C.ivory),
                ),
                const SizedBox(height: 8),
                if (!planDone)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(formatMinutes(totalSeconds(day.items)), style: meta),
                      const Dot(),
                      Text(tr('common.kcal', {'n': kcalForWeight(day.kcal, weightKg)}), style: meta),
                      const Dot(),
                      Text(tr('home.moves', {'n': day.items.length}), style: meta),
                    ],
                  ),
                if (!planDone && !locked && newToday.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Glass(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.sparkles,
                          size: 13,
                          color: C.ivory,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            tr('home.newToday', {'items': newToday.join(' & ')}),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: T.tiny.c(C.ivory),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (locked) ...[
                  const SizedBox(height: 10),
                  Text(
                    plan.freeDays > 0
                        ? tr('home.freeDaysDoneUnlock', {'day': dayNumber, 'total': total})
                        : tr('home.coursePartOfPlus'),
                    style: T.caption.copyWith(
                      fontSize: 13.5,
                      color: C.ivory.withValues(alpha: 0.85),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: cta,
                        excludeSemantics: true,
                        child: Pressable(
                          onTap: onStart,
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: locked ? null : C.ivory,
                              gradient: locked ? G.gold : null,
                              borderRadius: BorderRadius.circular(56),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  locked
                                      ? LucideIcons.crown
                                      : planDone
                                      ? LucideIcons.arrowRight
                                      : todayDone
                                      ? LucideIcons.check
                                      : Icons.play_arrow_rounded,
                                  size: locked || planDone || todayDone
                                      ? 20
                                      : 24,
                                  color: C.ink,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    cta,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: T.label.copyWith(fontSize: 17),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    CircleBtn(
                      icon: LucideIcons.arrowRight,
                      tone: Tone.dark,
                      size: 56,
                      label: tr('home.viewAllDays', {'total': total}),
                      onTap: onOpen,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact journey progress: days done, streak and the way into every day of the course.
class _JourneyProgress extends StatelessWidget {
  const _JourneyProgress({
    required this.done,
    required this.total,
    required this.streak,
    required this.onOpen,
  });
  final int done, total, streak;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tr('home.journeyProgressSemantics', {'done': done, 'total': total, 'streak': streak}),
      excludeSemantics: true,
      child: Pressable(
        onTap: onOpen,
        child: ECard(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Eyebrow(tr('home.yourProgress'), color: C.jade),
                  ),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            tr('home.viewAllDays', {'total': total}),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: T.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: C.jadeDeep,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: C.jadeDeep,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    tr('home.doneOfTotalDays', {'done': done, 'total': total}),
                    style: T.title.copyWith(fontSize: 19),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        streak > 0
                            ? Icons.local_fire_department_rounded
                            : LucideIcons.flame,
                        size: 17,
                        color: streak > 0 ? C.terracotta : C.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tr('home.streakDayStreak', {'n': streak}),
                        style: T.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: C.ink,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Bar(value: total == 0 ? 0 : done / total, height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeditationCard extends StatelessWidget {
  const _MeditationCard({
    required this.med,
    required this.evening,
    required this.onTap,
  });
  final Meditation med;
  final bool evening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tr('home.meditationSemantics', {'title': med.title, 'minutes': med.minutes}),
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 172,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: S.card,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              EImage(img(med.image)),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF111A15).withValues(alpha: 0.85),
                      const Color(0xFF111A15).withValues(alpha: 0.1),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                top: 0,
                bottom: 0,
                right: 84,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(
                      evening
                          ? tr('home.windDownMin', {'n': med.minutes})
                          : tr('home.meditateMin', {'n': med.minutes}),
                      color: C.ivory.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      med.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: T.displayMd.c(C.ivory),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      med.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: T.caption.c(C.ivory.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 20,
                bottom: 20,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: C.ivory,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 28,
                    color: C.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
