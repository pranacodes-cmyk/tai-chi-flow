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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final now = DateTime.now();
    final today = dateKey(now);
    final plan = app.activePlan;
    final completed = app.activeCompleted;
    final stats = app.stats;
    final dayNumber = nextPlanDay(plan.days.length, completed);
    final day = plan.days[dayNumber - 1];
    final planDone = completed.length >= plan.days.length;
    final todayDone =
        completed.contains(dayNumber) ||
        app.history.any(
          (h) =>
              h.planId == plan.id &&
              h.day == dayNumber &&
              dateKey(h.completedAt) == today,
        );
    final todayEntries = app.history
        .where((h) => dateKey(h.completedAt) == today)
        .toList();
    final minutesToday =
        (todayEntries.fold<int>(0, (s, h) => s + h.durationSec) / 60).round();
    final kcalToday = todayEntries.fold<int>(0, (s, h) => s + h.kcal);
    final minuteGoal = app.profile.dailyMinutes == 0
        ? 10
        : app.profile.dailyMinutes;
    final kcalGoal = (minuteGoal * 4).clamp(30, 1000);
    final c = Content.i;
    final challenge = dailyPick(c.dailyChallenges, now);
    final challengeKey = '$today:${challenge.id}';
    final challengeState = app.challenges[challengeKey];
    final quote = dailyPick(c.quotes, now, 3);
    final tip = dailyPick(c.tips, now, 7);
    final evening = now.hour >= 17 || now.hour < 5;
    final med = c.meditation(
      evening ? 'evening-wind-down' : 'morning-clarity',
    )!;
    final days = app.history.map((h) => dateKey(h.completedAt)).toSet();
    final weekStart = addDays(now, -(now.weekday % 7));
    final pct = completed.length / plan.days.length;
    final name = app.profile.name;
    final premium = app.premium.active;
    final heroLocked = !planDone && isDayLocked(plan, dayNumber, premium);
    // the 60-day daily practice (seated or standing); offer the other one if it's already the main plan
    var dailyId = dailyPlanId(
      limitations: app.profile.limitations,
      style: app.profile.style,
    );
    if (dailyId == plan.id) {
      dailyId = c.dailyPlanIds.firstWhere(
        (id) => id != plan.id,
        orElse: () => dailyId,
      );
    }
    final daily = c.plan(dailyId)!;
    final dailyDone =
        app.planProgress[daily.id]?.completedDays ?? const <int>[];
    final dailyDay = nextPlanDay(daily.days.length, dailyDone);
    final dailyToday = app.history.any(
      (h) => h.planId == daily.id && dateKey(h.completedAt) == today,
    );
    final dailyLocked = isDayLocked(daily, dailyDay, premium);

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
            // header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(DateFormat('EEEE, MMM d').format(now)),
                        const SizedBox(height: 6),
                        Text(
                          '${greeting(now.hour)}${name.isNotEmpty ? ',' : ''}',
                          style: T.displayMd,
                        ),
                        Text(
                          name.isNotEmpty ? name : 'friend',
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
                        Pressable(
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
                                  stats.streak > 0
                                      ? Icons.local_fire_department_rounded
                                      : LucideIcons.flame,
                                  size: 19,
                                  color: stats.streak > 0
                                      ? C.terracotta
                                      : C.muted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${stats.streak}',
                                  style: T.label
                                      .copyWith(fontWeight: FontWeight.w700)
                                      .tab,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Pressable(
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // today hero
            Reveal(
              delay: 0.05,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 430,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: S.float,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      KenBurns(child: EImage(img(plan.image))),
                      DecoratedBox(
                        decoration: BoxDecoration(gradient: G.scrim),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        top: 16,
                        child: Row(
                          children: [
                            Glass(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Text(
                                planDone
                                    ? 'Plan complete'
                                    : 'Day $dayNumber of ${plan.days.length}',
                                style: T.tiny.c(C.ivory),
                              ),
                            ),
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
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Eyebrow(
                              plan.title,
                              color: C.ivory.withValues(alpha: 0.7),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              planDone
                                  ? 'You did it.'
                                  : 'Day $dayNumber · ${day.title}',
                              style: T.displayLg.copyWith(
                                fontSize: 29.6,
                                color: C.ivory,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  formatMinutes(totalSeconds(day.items)),
                                  style: T.caption.copyWith(
                                    fontSize: 14,
                                    color: C.ivory.withValues(alpha: 0.8),
                                  ),
                                ),
                                const Dot(),
                                Text(
                                  '${kcalForWeight(day.kcal, app.profile.weightKg)} kcal',
                                  style: T.caption.copyWith(
                                    fontSize: 14,
                                    color: C.ivory.withValues(alpha: 0.8),
                                  ),
                                ),
                                const Dot(),
                                Text(
                                  '${day.items.length} moves',
                                  style: T.caption.copyWith(
                                    fontSize: 14,
                                    color: C.ivory.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Pressable(
                                    onTap: () => planDone
                                        ? context.go('/courses')
                                        : heroLocked
                                        ? context.push('/paywall?from=plan')
                                        : context.push(
                                            '/session/${planSessionId(plan.id, dayNumber)}',
                                          ),
                                    child: Container(
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: heroLocked ? null : C.ivory,
                                        gradient: heroLocked ? G.gold : null,
                                        borderRadius: BorderRadius.circular(56),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            heroLocked
                                                ? LucideIcons.crown
                                                : planDone
                                                ? LucideIcons.arrowRight
                                                : (todayDone
                                                      ? LucideIcons.check
                                                      : Icons
                                                            .play_arrow_rounded),
                                            size:
                                                planDone ||
                                                    todayDone ||
                                                    heroLocked
                                                ? 20
                                                : 24,
                                            color: C.ink,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            heroLocked
                                                ? 'Unlock Day $dayNumber'
                                                : planDone
                                                ? 'Choose next plan'
                                                : (todayDone
                                                      ? 'Done · Practice again'
                                                      : "Start today's session"),
                                            style: T.label.copyWith(
                                              fontSize: 17,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                CircleBtn(
                                  icon: LucideIcons.arrowRight,
                                  tone: Tone.dark,
                                  size: 56,
                                  label: 'View plan',
                                  onTap: () => context.push('/plan/${plan.id}'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // rings + week
            Reveal(
              delay: 0.12,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ECard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 108,
                            height: 108,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Ring(
                                  value: minutesToday / minuteGoal,
                                  size: 108,
                                  stroke: 10,
                                  track: C.jade.withValues(alpha: 0.12),
                                  bar: C.jade,
                                ),
                                Ring(
                                  value: kcalToday / kcalGoal,
                                  size: 82,
                                  stroke: 10,
                                  track: C.terracotta.withValues(alpha: 0.14),
                                  bar: C.terracotta,
                                ),
                                Ring(
                                  value: (stats.streak / 7)
                                      .clamp(0, 1)
                                      .toDouble(),
                                  size: 56,
                                  stroke: 10,
                                  track: C.gold.withValues(alpha: 0.18),
                                  bar: C.gold,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              children: [
                                _Legend(
                                  color: C.jade,
                                  label: 'Minutes',
                                  value: '$minutesToday/$minuteGoal',
                                ),
                                const SizedBox(height: 10),
                                _Legend(
                                  color: C.terracotta,
                                  label: 'Calories',
                                  value: '$kcalToday/$kcalGoal',
                                ),
                                const SizedBox(height: 10),
                                _Legend(
                                  color: C.gold,
                                  label: 'Streak',
                                  value:
                                      '${stats.streak} ${stats.streak == 1 ? 'day' : 'days'}',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1, color: C.line),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (var i = 0; i < 7; i++)
                            Builder(
                              builder: (_) {
                                final d = addDays(weekStart, i);
                                final k = dateKey(d);
                                final done = days.contains(k);
                                final isToday = k == today;
                                final future = d.isAfter(now) && !isToday;
                                return Column(
                                  children: [
                                    Text(
                                      weekLetters[i],
                                      style: T.tiny.copyWith(
                                        fontSize: 11,
                                        color: isToday ? C.jade : C.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      width: 36,
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: done
                                            ? C.jade
                                            : (isToday || future
                                                  ? Colors.transparent
                                                  : C.sand),
                                        border: isToday && !done
                                            ? Border.all(
                                                color: C.jade,
                                                width: 2,
                                              )
                                            : null,
                                      ),
                                      child: done
                                          ? const Icon(
                                              LucideIcons.check,
                                              size: 16,
                                              color: C.ivory,
                                            )
                                          : Text(
                                              '${d.day}',
                                              style: T.caption
                                                  .copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    color: isToday
                                                        ? C.jadeDeep
                                                        : (future
                                                              ? C.muted
                                                                    .withValues(
                                                                      alpha:
                                                                          0.6,
                                                                    )
                                                              : C.muted),
                                                  )
                                                  .tab,
                                            ),
                                    ),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // daily tai chi challenge (60 days)
            Reveal(
              delay: 0.15,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _DailyPracticeCard(
                  plan: daily,
                  day: dailyDay,
                  doneDays: dailyDone.length,
                  doneToday: dailyToday,
                  locked: dailyLocked,
                  weightKg: app.profile.weightKg,
                  onTap: () => context.push(
                    dailyLocked
                        ? '/paywall?from=plan'
                        : '/session/${planSessionId(daily.id, dailyDay)}',
                  ),
                  onOpen: () => context.push('/plan/${daily.id}'),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // mindful habit
            Reveal(
              delay: 0.18,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: challengeState == 'done' ? G.jade : null,
                    color: challengeState == 'done' ? null : C.ivory,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: S.card,
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: challengeState == 'done'
                                  ? C.ivory.withValues(alpha: 0.15)
                                  : C.terracottaSoft,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: challengeState == 'done'
                                ? const Icon(
                                    LucideIcons.check,
                                    size: 28,
                                    color: C.ivory,
                                  )
                                : ContentIcon(
                                    challenge.icon,
                                    size: 28,
                                    color: C.terracotta,
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Eyebrow(
                                  'Mindful habit',
                                  color: challengeState == 'done'
                                      ? C.ivory.withValues(alpha: 0.7)
                                      : C.terracotta,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  challenge.title,
                                  style: T.title.c(
                                    challengeState == 'done' ? C.ivory : C.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  challengeState == 'done'
                                      ? 'Beautifully done. Small steps, big change.'
                                      : challenge.description,
                                  style: T.caption.copyWith(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: challengeState == 'done'
                                        ? C.ivory.withValues(alpha: 0.8)
                                        : C.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (challengeState != 'done') ...[
                        const SizedBox(height: 16),
                        Pressable(
                          onTap: () => app.setChallenge(
                            challengeKey,
                            challengeState == 'accepted' ? 'done' : 'accepted',
                          ),
                          child: Container(
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: challengeState == 'accepted'
                                  ? C.jade
                                  : C.ink,
                              borderRadius: BorderRadius.circular(48),
                            ),
                            child: Text(
                              challengeState == 'accepted'
                                  ? 'Mark as done'
                                  : 'Accept challenge',
                              style: T.label.c(C.ivory),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 36),

            // quick sessions
            Reveal(
              delay: 0.22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    'Quick sessions',
                    action: 'See all',
                    onAction: () => context.go('/courses?view=classes'),
                  ),
                  HScroll(
                    children: [for (final q in c.quickSessions) QuickCard(q)],
                  ),
                ],
              ),
            ),

            if (!app.premium.active) ...[
              const SizedBox(height: 28),
              Reveal(
                delay: 0.24,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Pressable(
                    onTap: () => context.push('/paywall?from=home'),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: C.ink,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: S.card,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            right: -60,
                            top: -60,
                            child: Container(
                              width: 144,
                              height: 144,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: C.gold.withValues(alpha: 0.25),
                                    blurRadius: 50,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: G.gold,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  LucideIcons.crown,
                                  size: 24,
                                  color: C.ink,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Unlock every plan & challenge',
                                      style: T.label.copyWith(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: C.ivory,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'All courses with TaiChi Flow Plus',
                                      style: T.caption.c(
                                        C.ivory.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                LucideIcons.arrowRight,
                                size: 20,
                                color: C.gold,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),

            // quote
            Reveal(
              delay: 0.26,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: C.jadeSoft,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        right: -72,
                        bottom: -72,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: C.jade.withValues(alpha: 0.1),
                              width: 14,
                            ),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            LucideIcons.quote,
                            size: 28,
                            color: C.jade.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            quote.text,
                            style: T.serifAccent.copyWith(
                              fontSize: 25.6,
                              height: 1.2,
                              color: C.jadeDeep,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '— ${quote.author}',
                            style: T.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: C.jadeDeep.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // daily tip
            Reveal(
              delay: 0.27,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ECard(
                  radius: 26,
                  shadow: S.soft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: G.jade,
                          shape: BoxShape.circle,
                          boxShadow: S.glow,
                        ),
                        child: ContentIcon(tip.icon, size: 20, color: C.ivory),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Eyebrow("Today's tip", color: C.jade),
                            const SizedBox(height: 4),
                            Text(
                              tip.title,
                              style: T.label.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tip.body,
                              style: T.bodySm.copyWith(
                                fontSize: 14,
                                color: C.muted,
                                height: 1.55,
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
            const SizedBox(height: 36),

            // meditation pick
            Reveal(
              delay: 0.28,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    evening ? 'Wind down tonight' : 'Start with stillness',
                    action: 'Meditate',
                    onAction: () => context.go('/meditate'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Pressable(
                      onTap: () => context.push('/meditation/${med.id}'),
                      child: Container(
                        height: 190,
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
                                    const Color(0xFF111A15)
                                        .withValues(alpha: 0.85),
                                    const Color(0xFF111A15)
                                        .withValues(alpha: 0.1),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 20,
                              top: 0,
                              bottom: 0,
                              width: 220,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        LucideIcons.sparkles,
                                        size: 12,
                                        color: C.ivory.withValues(alpha: 0.7),
                                      ),
                                      const SizedBox(width: 4),
                                      Eyebrow(
                                        '${med.category} · ${med.minutes} min',
                                        color: C.ivory.withValues(alpha: 0.7),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    med.title,
                                    style: T.displayMd.c(C.ivory),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    med.subtitle,
                                    style: T.caption.c(
                                      C.ivory.withValues(alpha: 0.75),
                                    ),
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
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // discover
            Reveal(
              delay: 0.3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    'Practice styles',
                    action: 'See all',
                    onAction: () => context.go('/courses?view=classes'),
                  ),
                  HScroll(
                    gap: 12,
                    children: [
                      for (var i = 0; i < c.categories.length; i += 2)
                        Column(
                          children: [
                            CategoryTile(
                              c.categories[i],
                              width: 150,
                              height: 150,
                            ),
                            if (i + 1 < c.categories.length) ...[
                              const SizedBox(height: 12),
                              CategoryTile(
                                c.categories[i + 1],
                                width: 150,
                                height: 150,
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // learn
            Reveal(
              delay: 0.34,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader('Learn the art'),
                  HScroll(
                    gap: 14,
                    children: [
                      for (final g in c.guides)
                        Pressable(
                          onTap: () => context.push('/guide/${g.id}'),
                          child: Container(
                            width: 180,
                            height: 230,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: C.ivory,
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: S.soft,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 120,
                                  width: double.infinity,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      EImage(img(g.image)),
                                      Positioned(
                                        left: 10,
                                        top: 10,
                                        child: Glass(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          child: Text(
                                            g.tag.toUpperCase(),
                                            style: T.tiny.copyWith(
                                              fontSize: 10,
                                              letterSpacing: 1,
                                              fontWeight: FontWeight.w700,
                                              color: C.ivory,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        g.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: T.label.copyWith(
                                          fontWeight: FontWeight.w700,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            LucideIcons.bookOpen,
                                            size: 12,
                                            color: C.muted,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${g.minutes} min read',
                                            style: T.tiny.w(FontWeight.w500),
                                          ),
                                        ],
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
                ],
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: Reveal(
                delay: 0.6,
                dy: 0,
                child: Text(
                  "This isn't a workout. It's meditation in motion.",
                  textAlign: TextAlign.center,
                  style: T.serifAccent.copyWith(fontSize: 18.4, color: C.muted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyPracticeCard extends StatelessWidget {
  const _DailyPracticeCard({
    required this.plan,
    required this.day,
    required this.doneDays,
    required this.doneToday,
    required this.locked,
    required this.weightKg,
    required this.onTap,
    required this.onOpen,
  });
  final Plan plan;
  final int day, doneDays;
  final bool doneToday, locked;
  final double weightKg;
  final VoidCallback onTap, onOpen;

  @override
  Widget build(BuildContext context) {
    final d = plan.days[day - 1];
    final hasAffirmation = d.items.any(
      (it) => Content.i.exercise(it.e)?.isAffirmation ?? false,
    );
    return Pressable(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.ivory,
          borderRadius: BorderRadius.circular(30),
          boxShadow: S.card,
        ),
        child: Column(
          children: [
            Row(
              children: [
                RoundedImage(img(plan.image), size: 92, radius: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow(
                        'Daily challenge · Day $day',
                        color: C.terracotta,
                      ),
                      const SizedBox(height: 4),
                      Text(plan.title, style: T.title),
                      const SizedBox(height: 2),
                      Text(
                        '${formatMinutes(totalSeconds(d.items))} · ${d.items.length} moves${hasAffirmation ? ' · affirmation' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.caption,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Bar(
                              value: doneDays / plan.days.length,
                              height: 6,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$doneDays/${plan.days.length}',
                            style: T.tiny
                                .copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: C.ink,
                                )
                                .tab,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Pressable(
              onTap: onTap,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: locked ? null : (doneToday ? C.jadeSoft : C.ink),
                  gradient: locked ? G.gold : null,
                  borderRadius: BorderRadius.circular(48),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      locked
                          ? LucideIcons.crown
                          : (doneToday
                                ? LucideIcons.check
                                : Icons.play_arrow_rounded),
                      size: locked || doneToday ? 18 : 22,
                      color: locked
                          ? C.ink
                          : (doneToday ? C.jadeDeep : C.ivory),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      locked
                          ? 'Unlock Day $day with TaiChi Flow Plus'
                          : (doneToday
                                ? 'Done today · Practice Day $day'
                                : 'Start Day $day · ${d.title}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.label.c(
                        locked ? C.ink : (doneToday ? C.jadeDeep : C.ivory),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
  });
  final Color color;
  final String label, value;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: T.caption.copyWith(fontSize: 14))),
        Text(value, style: T.label.copyWith(fontWeight: FontWeight.w700).tab),
      ],
    );
  }
}
