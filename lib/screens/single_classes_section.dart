import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../state/app_state.dart';
import '../widgets/cards.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';

/// Standalone classes, styles and movements inside the Courses catalogue.
class SingleClassesSection extends StatelessWidget {
  const SingleClassesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = Content.i;
    final sessions = c.plans
        .where((p) => p.isSingleSession && p.premium)
        .toList();
    final shelves = [
      for (final g in c.planGroups)
        if (sessions.any((p) => p.group == g)) g,
    ];
    final moves = c.exercises.where((e) => !e.isAffirmation).toList();
    final sampler = [
      for (final cat in c.categories)
        ...moves.where((e) => e.category == cat.id).take(1),
    ];
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 26),
            Reveal(
              delay: 0.05,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    app.premium.active ? 'Quick sessions' : 'Free for you',
                  ),
                  HScroll(
                    children: [
                      for (final q in c.quickSessions)
                        QuickCard(q, width: 180, height: 220),
                    ],
                  ),
                ],
              ),
            ),
            for (final (gi, g) in shelves.indexed)
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: Reveal(
                  delay: 0.08 + gi * 0.03,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader('$g classes'),
                      HScroll(
                        children: [
                          for (final p in sessions.where((p) => p.group == g))
                            PlanCard(p, width: 190, height: 240),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 34),
            const SectionHeader('Explore by style'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _StyleGrid(),
            ),
            const SizedBox(height: 34),
            SectionHeader(
              'Movement library',
              action: 'See all ${moves.length}',
              onAction: () => context.push('/movements'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (final e in sampler.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ThumbRow(
                        image: img(e.image),
                        title: e.name,
                        subtitle: e.focus.take(3).join(' · '),
                        onTap: () => context.push('/exercise/${e.id}'),
                      ),
                    ),
                  const SizedBox(height: 4),
                  EnsoButton(
                    label: 'Browse all ${moves.length} movements',
                    variant: BtnVariant.secondary,
                    icon: LucideIcons.search,
                    onTap: () => context.push('/movements'),
                  ),
                ],
              ),
            ),
          ],
    );
  }
}

/// Two-up grid of practice styles; every third tile spans the full width.
class _StyleGrid extends StatelessWidget {
  const _StyleGrid();
  @override
  Widget build(BuildContext context) {
    final cats = Content.i.categories;
    final rows = <Widget>[];
    for (var i = 0; i < cats.length;) {
      if (i % 3 == 0) {
        rows.add(CategoryTile(cats[i], height: 170));
        i++;
      } else {
        final a = cats[i];
        final b = i + 1 < cats.length && (i + 1) % 3 != 0 ? cats[i + 1] : null;
        rows.add(
          Row(
            children: [
              Expanded(child: CategoryTile(a, height: 150)),
              const SizedBox(width: 12),
              Expanded(
                child: b == null
                    ? const SizedBox()
                    : CategoryTile(b, height: 150),
              ),
            ],
          ),
        );
        i += b == null ? 1 : 2;
      }
    }
    return Column(
      children: [
        for (final (i, r) in rows.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
            child: r,
          ),
      ],
    );
  }
}
