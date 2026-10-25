import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'single_classes_section.dart';
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

/// Courses tab: every multi-day journey, shelved by style (web `/courses`).
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key, this.view = 'courses'});
  final String view;
  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  String shelf = 'All';

  @override
  void didUpdateWidget(covariant CoursesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.view != widget.view) shelf = 'All';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = Content.i;
    final courses = c.plans.where((p) => !p.isSingleSession).toList();
    final shelves = [
      for (final g in c.planGroups)
        if (courses.any((p) => p.group == g)) g,
    ];
    final shown = shelf == 'All' ? shelves : [shelf];
    final classes = widget.view == 'classes';
    return EnsoScaffold(
      body: SingleChildScrollView(
        key: const PageStorageKey('courses'),
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
                  Text(tr('courses.title'), style: T.displayLg),
                  const SizedBox(height: 4),
                  Text(
                    tr('courses.subtitle'),
                    style: T.bodySm.c(C.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                for (final v in ['courses', 'classes']) ...[
                  if (v == 'classes') const SizedBox(width: 8),
                  Expanded(child: ChipPill(
                    label: v == 'courses' ? tr('courses.toggleCourses') : tr('courses.toggleSingleClasses'),
                    active: widget.view == v,
                    onTap: () => context.go('/courses?view=$v'),
                  )),
                ],
              ]),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: EnsoButton(
                label: tr('courses.stylesLibrary'),
                variant: BtnVariant.secondary,
                onTap: () => context.push('/movements'),
              ),
            ),
            if (classes) const SingleClassesSection(),
            if (!classes) ...[
            const SizedBox(height: 24),
            const Reveal(delay: 0.05, child: _ContinueCard()),
            const SizedBox(height: 28),
            HScroll(
              gap: 8,
              padding: 20,
              children: [
                for (final s in ['All', ...shelves])
                  ChipPill(
                    label: trTag(s),
                    active: shelf == s,
                    onTap: () => setState(() => shelf = s),
                  ),
              ],
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: kEase,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.02),
                    end: Offset.zero,
                  ).animate(a),
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey(shelf),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (gi, g) in shown.indexed)
                    Padding(
                      padding: EdgeInsets.only(top: gi == 0 ? 20 : 32),
                      child: Reveal(
                        delay: 0.08 + gi * 0.03,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader(trTag(g)),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Column(
                                children: [
                                  for (final (i, p)
                                      in courses
                                          .where((p) => p.group == g)
                                          .indexed)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        top: i == 0 ? 0 : 14,
                                      ),
                                      child: CourseCard(
                                        p,
                                        progress:
                                            (app
                                                    .planProgress[p.id]
                                                    ?.completedDays
                                                    .length ??
                                                0) /
                                            p.days.length,
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
            const SizedBox(height: 36),
            Reveal(
              delay: 0.12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(tr('courses.learnTheArt')),
                  HScroll(children: [for (final g in c.guides) _GuideCard(g)]),
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

/// A short Tai Chi article: principles, breath, balance and habit.
class _GuideCard extends StatelessWidget {
  const _GuideCard(this.guide);
  final Guide guide;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tr('courses.guideReadLabel', {'title': guide.title, 'minutes': guide.minutes}),
      excludeSemantics: true,
      child: Pressable(
        onTap: () => context.push('/guide/${guide.id}'),
        child: Container(
          width: 240,
          height: 168,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: S.card,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              EImage(img(guide.image)),
              DecoratedBox(decoration: BoxDecoration(gradient: G.scrim)),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(
                      tr('courses.guideTagMinRead', {'tag': trTag(guide.tag), 'minutes': guide.minutes}),
                      color: C.ivory.withValues(alpha: 0.75),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      guide.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: T.title.copyWith(fontSize: 17, color: C.ivory),
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

/// The plan the user is following, with their next day.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard();
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final plan = app.activePlan;
    final completed = app.activeCompleted;
    final pct = completed.length / plan.days.length;
    final next = nextPlanDay(plan.days.length, completed);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Pressable(
        onTap: () => context.push('/plan/${plan.id}'),
        child: ECard(
          padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
          child: Row(
            children: [
              RoundedImage(img(plan.image), size: 84, radius: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(tr('courses.yourCourse'), color: C.jade),
                    const SizedBox(height: 4),
                    Text(
                      plan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.title,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      completed.length >= plan.days.length
                          ? tr('courses.completed')
                          : tr('courses.nextDayOfTotal', {'day': next, 'total': plan.days.length}),
                      style: T.caption,
                    ),
                  ],
                ),
              ),
              Ring(
                value: pct,
                size: 52,
                stroke: 5,
                child: Text(
                  '${(pct * 100).round()}%',
                  style: T.tiny
                      .copyWith(fontWeight: FontWeight.w700, color: C.ink)
                      .tab,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
