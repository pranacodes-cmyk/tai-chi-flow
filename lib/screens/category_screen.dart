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
import '../widgets/ui.dart';
import 'plan_detail_screen.dart';
import '../i18n/i18n.dart';

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key, required this.categoryId});
  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final c = Content.i.category(categoryId);
    if (c == null) return const NotFoundView();
    final app = context.watch<AppState>();
    final weight = app.profile.weightKg;
    final premium = app.premium.active;
    final ids = c.exerciseIds.toSet();
    final related = Content.i.plans
        .where(
          (p) => p.days.any((d) => d.items.any((it) => ids.contains(it.e))),
        )
        .take(6)
        .toList();

    return EnsoScaffold(
      lightIcons: true,
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: bottomInset(context) + 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HeroHeader(
                  image: img(c.image),
                  height: 340,
                  topBar: const Row(children: [BackBtn(tone: Tone.dark)]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow(c.tagline, color: C.ivory.withValues(alpha: 0.7)),
                      const SizedBox(height: 8),
                      Text(c.name, style: T.displayLg.c(C.ivory)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.clock,
                            size: 16,
                            color: C.ivory.withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            formatMinutes(totalSeconds(c.items)),
                            style: T.caption.copyWith(
                              fontSize: 14,
                              color: C.ivory.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            LucideIcons.flame,
                            size: 16,
                            color: C.ivory.withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tr('common.kcal', {'n': kcalForWeight(c.kcal, weight)}),
                            style: T.caption.copyWith(
                              fontSize: 14,
                              color: C.ivory.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.description,
                        style: T.body.c(C.ink.withValues(alpha: 0.8)),
                      ),
                      const SizedBox(height: 28),
                      Text(tr('category.movements'), style: T.title.s(20)),
                      const SizedBox(height: 12),
                      for (final (i, id) in c.exerciseIds.take(10).indexed)
                        Builder(
                          builder: (context) {
                            final e = Content.i.exercise(id)!;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Reveal(
                                delay: (i * 0.03).clamp(0, 0.3).toDouble(),
                                child: ThumbRow(
                                  image: img(e.image),
                                  title: e.name,
                                  subtitle:
                                      '${trTag(e.level)} · ${e.focus.take(2).map(trTag).join(' · ')}',
                                  size: 68,
                                  onTap: () => context.push('/exercise/$id'),
                                ),
                              ),
                            );
                          },
                        ),
                      if (c.exerciseIds.length > 10)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: EnsoButton(
                            label: tr('category.seeAllMovements', {'n': c.exerciseIds.length}),
                            variant: BtnVariant.secondary,
                            onTap: () =>
                                context.push('/movements?category=${c.id}'),
                          ),
                        ),
                      if (related.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        Text(
                          tr('category.programsFeaturing', {'name': c.name}),
                          style: T.title.s(20),
                        ),
                        const SizedBox(height: 12),
                        for (final p in related)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ThumbRow(
                              image: img(p.image),
                              title: p.title,
                              subtitle: p.isSingleSession
                                  ? '${tr('common.minShort', {'n': p.minutesPerDay})} · ${trTag(p.level)}'
                                  : '${tr('common.days', {'n': p.days.length})} · ${tr('category.minPerDay', {'n': p.minutesPerDay})}',
                              size: 56,
                              trailing: p.premium && !premium
                                  ? const PremiumBadge()
                                  : null,
                              onTap: () => context.push(
                                p.isSingleSession
                                    ? '/session/${planSessionId(p.id, 1)}'
                                    : '/plan/${p.id}',
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          BottomCta(
            child: EnsoButton(
              label: tr('category.startSession', {'name': c.name}),
              icon: Icons.play_arrow_rounded,
              onTap: () => context.push('/session/cat:${c.id}'),
            ),
          ),
        ],
      ),
    );
  }
}
