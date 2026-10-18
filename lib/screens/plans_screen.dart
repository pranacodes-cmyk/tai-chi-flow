import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../logic/logic.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/cards.dart';
import '../widgets/scaffold.dart';
import '../widgets/tab_shell.dart';
import '../widgets/ui.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key, this.initialTab = 'programs'});
  final String initialTab;
  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  late String tab = widget.initialTab;

  @override
  void didUpdateWidget(covariant PlansScreen old) {
    super.didUpdateWidget(old);
    if (old.initialTab != widget.initialTab) tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    return EnsoScaffold(
      body: SingleChildScrollView(
        key: PageStorageKey('plans-$tab'),
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(top: topInset(context) + 18, bottom: tabBarSpace(context)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Plans', style: T.displayLg),
              const SizedBox(height: 4),
              Text('Guided journeys and a library of mindful movement.', style: T.bodySm.c(C.muted)),
              const SizedBox(height: 20),
              Segmented(
                value: tab,
                options: const [('programs', 'Programs'), ('library', 'Library')],
                onChanged: (v) => setState(() => tab = v),
              ),
            ]),
          ),
          if (tab == 'programs') const _Programs() else const _Library(),
        ]),
      ),
    );
  }
}

/// Sand pill segmented control with sliding ivory thumb.
class Segmented extends StatelessWidget {
  const Segmented({super.key, required this.value, required this.options, required this.onChanged});
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final idx = options.indexWhere((o) => o.$1 == value);
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: C.sand, borderRadius: BorderRadius.circular(48)),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth / options.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutBack,
            left: w * idx,
            width: w,
            top: 0,
            bottom: 0,
            child: Container(decoration: BoxDecoration(color: C.ivory, borderRadius: BorderRadius.circular(40), boxShadow: S.soft)),
          ),
          Row(children: [
            for (final o in options)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(o.$1),
                  child: Center(child: Text(o.$2, style: T.label.copyWith(color: value == o.$1 ? C.ink : C.ink.withValues(alpha: 0.6)))),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}

class _Programs extends StatelessWidget {
  const _Programs();
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final plan = app.activePlan;
    final completed = app.activeCompleted;
    final pct = completed.length / plan.days.length;
    final next = nextPlanDay(plan.days.length, completed);
    final c = Content.i;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 24),
      Reveal(
        delay: 0.05,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Pressable(
            onTap: () => context.push('/plan/${plan.id}'),
            child: ECard(
              padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
              child: Row(children: [
                RoundedImage(img(plan.image), size: 92, radius: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Eyebrow('Your plan', color: C.jade),
                    const SizedBox(height: 4),
                    Text(plan.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title),
                    const SizedBox(height: 2),
                    Text(completed.length >= plan.days.length ? 'Completed' : 'Next: Day $next of ${plan.days.length}', style: T.caption),
                  ]),
                ),
                Ring(value: pct, size: 52, stroke: 5, child: Text('${(pct * 100).round()}%', style: T.tiny.copyWith(fontWeight: FontWeight.w700, color: C.ink).tab)),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 32),
      Reveal(
        delay: 0.1,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader('Quick sessions'),
          HScroll(children: [for (final q in c.quickSessions) QuickCard(q, width: 180, height: 220)]),
        ]),
      ),
      for (final (gi, g) in c.planGroups.indexed)
        if (c.plans.any((p) => p.group == g))
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Reveal(
              delay: 0.12 + gi * 0.03,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SectionHeader(g),
                HScroll(children: [
                  for (final p in c.plans.where((p) => p.group == g)) PlanCard(p, progress: (app.planProgress[p.id]?.completedDays.length ?? 0) / p.days.length),
                ]),
              ]),
            ),
          ),
    ]);
  }
}

class _Library extends StatelessWidget {
  const _Library();
  @override
  Widget build(BuildContext context) {
    final c = Content.i;
    // a varied sampler: the first movement of each category
    final all = c.exercises.where((e) => !e.isAffirmation).toList();
    final sampler = [for (final cat in c.categories) ...all.where((e) => e.category == cat.id).take(1)];
    final moves = [...sampler, ...all.where((e) => !sampler.contains(e))];
    final rows = <Widget>[];
    for (var i = 0; i < c.categories.length;) {
      if (i % 3 == 0) {
        rows.add(CategoryTile(c.categories[i], height: 180));
        i++;
      } else {
        final a = c.categories[i];
        final b = i + 1 < c.categories.length && (i + 1) % 3 != 0 ? c.categories[i + 1] : null;
        rows.add(Row(children: [
          Expanded(child: CategoryTile(a, height: 170)),
          const SizedBox(width: 12),
          Expanded(child: b == null ? const SizedBox() : CategoryTile(b, height: 170)),
        ]));
        i += b == null ? 1 : 2;
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 24),
      Reveal(
        delay: 0.05,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [for (final (i, r) in rows.indexed) Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 12), child: r)]),
        ),
      ),
      const SizedBox(height: 36),
      SectionHeader('All movements', action: 'See all ${moves.length}', onAction: () => context.push('/movements')),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(children: [
          for (final e in moves.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ThumbRow(image: img(e.image), title: e.name, subtitle: e.focus.take(3).join(' · '), onTap: () => context.push('/exercise/${e.id}')),
            ),
          const SizedBox(height: 4),
          EnsoButton(label: 'Browse all ${moves.length} movements', variant: BtnVariant.secondary, icon: LucideIcons.search, onTap: () => context.push('/movements')),
        ]),
      ),
    ]);
  }
}
