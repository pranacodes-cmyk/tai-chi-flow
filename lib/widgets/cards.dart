import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../logic/logic.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'ui.dart';

class QuickCard extends StatelessWidget {
  const QuickCard(this.q, {super.key, this.width = 220, this.height = 280});
  final QuickSession q;
  final double width, height;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => context.push('/session/quick:${q.id}'),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: S.card,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              EImage(img(q.image)),
              DecoratedBox(decoration: BoxDecoration(gradient: G.scrim)),
              Positioned(
                left: 14,
                top: 14,
                child: Glass(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.clock, size: 14, color: C.ivory),
                      const SizedBox(width: 4),
                      Text(
                        formatMinutes(totalSeconds(q.items)),
                        style: T.tiny.c(C.ivory),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.title,
                      style: T.title.c(C.ivory).copyWith(height: 1.15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      q.subtitle,
                      style: T.caption.c(C.ivory.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlanCard extends StatelessWidget {
  const PlanCard(
    this.plan, {
    super.key,
    this.progress = 0,
    this.width = 200,
    this.height = 260,
  });
  final Plan plan;
  final double progress, width, height;
  @override
  Widget build(BuildContext context) {
    final premium = context.select<AppState, bool>((a) => a.premium.active);
    final single = plan.isSingleSession;
    return Pressable(
      onTap: () => context.push(
        single ? '/session/${planSessionId(plan.id, 1)}' : '/plan/${plan.id}',
      ),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: S.card,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              EImage(img(plan.image)),
              DecoratedBox(decoration: BoxDecoration(gradient: G.scrim)),
              Positioned(
                left: 14,
                top: 14,
                child: Glass(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        single ? LucideIcons.clock : LucideIcons.calendarDays,
                        size: 13,
                        color: C.ivory,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        single
                            ? '${plan.minutesPerDay} min'
                            : '${plan.days.length} days',
                        style: T.tiny.c(C.ivory),
                      ),
                    ],
                  ),
                ),
              ),
              if (plan.premium && !premium)
                const Positioned(right: 12, top: 14, child: PremiumBadge()),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      single
                          ? '${plan.level} · ${plan.subtitle}'
                          : '${plan.minutesPerDay} min/day · ${plan.level}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.tiny.c(C.ivory.withValues(alpha: 0.75)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plan.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: T.title.c(C.ivory).copyWith(height: 1.15),
                    ),
                    if (progress > 0) ...[
                      const SizedBox(height: 10),
                      Bar(
                        value: progress,
                        track: C.ivory.withValues(alpha: 0.25),
                        color: C.ivory,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryTile extends StatelessWidget {
  const CategoryTile(this.c, {super.key, this.height = 150, this.width});
  final Category c;
  final double height;
  final double? width;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => context.push('/category/${c.id}'),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: S.soft,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              EImage(img(c.image)),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF111A15).withValues(alpha: 0.78),
                    ],
                    stops: const [0.35, 1],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Text(
                  c.name,
                  style: T.label.copyWith(
                    color: C.ivory,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
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

class MeditationRow extends StatelessWidget {
  const MeditationRow(
    this.m, {
    super.key,
    required this.locked,
    required this.onTap,
  });
  final Meditation m;
  final bool locked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.ivory,
          borderRadius: BorderRadius.circular(24),
          boxShadow: S.soft,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    EImage(img(m.image)),
                    if (locked)
                      Container(
                        color: C.ink.withValues(alpha: 0.35),
                        child: const Icon(
                          LucideIcons.lock,
                          size: 16,
                          color: C.ivory,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          m.title,
                          overflow: TextOverflow.ellipsis,
                          style: T.label.s(16),
                        ),
                      ),
                      if (m.premium) ...[
                        const SizedBox(width: 8),
                        const PremiumBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.caption,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${m.category} · ${m.minutes} min',
                    style: T.tiny.c(C.jade),
                  ),
                ],
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: C.sand,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 22,
                color: C.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// List row with thumbnail + title + subtitle + trailing.
class ThumbRow extends StatelessWidget {
  const ThumbRow({
    super.key,
    required this.image,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.size = 64,
  });
  final String image, title, subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
        decoration: BoxDecoration(
          color: C.ivory,
          borderRadius: BorderRadius.circular(22),
          boxShadow: S.soft,
        ),
        child: Row(
          children: [
            RoundedImage(image, size: size, radius: 16),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.label,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.caption,
                  ),
                ],
              ),
            ),
            trailing ??
                const Icon(LucideIcons.chevronRight, size: 20, color: C.muted),
          ],
        ),
      ),
    );
  }
}

/// Who a course suits at a glance: standing, chair, wall or mat.
String equipmentLabel(String equipment) => switch (equipment) {
  'chair' => 'Chair',
  'wall' => 'Wall',
  'mat' => 'Mat',
  _ => 'Standing',
};

/// Full-width cover card for a multi-day course (web `CourseCard`).
class CourseCard extends StatelessWidget {
  const CourseCard(this.plan, {super.key, this.progress = 0});
  final Plan plan;
  final double progress;
  @override
  Widget build(BuildContext context) {
    final premium = context.select<AppState, bool>((a) => a.premium.active);
    final started = progress > 0;
    return Semantics(
      button: true,
      label: '${plan.title}, ${plan.days.length} days',
      child: Pressable(
        onTap: () => context.push('/plan/${plan.id}'),
        child: Container(
          height: 212,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: S.card,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Stack(
              fit: StackFit.expand,
              children: [
                EImage(img(plan.image)),
                DecoratedBox(decoration: BoxDecoration(gradient: G.scrim)),
                Positioned(
                  left: 14,
                  top: 14,
                  child: Glass(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.calendarDays,
                          size: 13,
                          color: C.ivory,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${plan.days.length} days · ${plan.minutesPerDay} min',
                          style: T.tiny.c(C.ivory),
                        ),
                      ],
                    ),
                  ),
                ),
                if (started)
                  Positioned(
                    right: 14,
                    top: 14,
                    child: Glass(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Text(
                        '${(progress * 100).round()}% done',
                        style: T.tiny.c(C.ivory),
                      ),
                    ),
                  )
                else if (plan.premium && !premium && plan.freeDays > 0)
                  Positioned(
                    right: 14,
                    top: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: C.ivory,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${plan.freeDays} days free',
                        style: T.tiny.copyWith(
                          color: C.jadeDeep,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${plan.level} · ${equipmentLabel(plan.equipment)}'
                            .toUpperCase(),
                        style: T.eyebrow.c(C.ivory.withValues(alpha: 0.78)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: T.title.s(22).c(C.ivory).copyWith(height: 1.1),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        plan.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.caption.c(C.ivory.withValues(alpha: 0.8)),
                      ),
                      if (started) ...[
                        const SizedBox(height: 10),
                        Bar(
                          value: progress,
                          track: C.ivory.withValues(alpha: 0.25),
                          color: C.ivory,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
