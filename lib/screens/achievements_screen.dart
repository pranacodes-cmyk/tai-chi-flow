import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../logic/logic.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';
import 'history_screen.dart';
import '../i18n/i18n.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final stats = app.stats;
    final unlocked = app.unlocked;
    final all = Content.i.achievements;
    return EnsoScaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          top: topInset(context) + 10,
          bottom: bottomInset(context) + 48,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: BackBtn(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('achievements.title'), style: T.displayLg),
                  const SizedBox(height: 4),
                  Text(
                    tr('achievements.unlockedOf', {'unlocked': unlocked.length, 'total': all.length}),
                    style: T.bodySm.c(C.muted),
                  ),
                  const SizedBox(height: 16),
                  Bar(
                    value: unlocked.length / all.length,
                    height: 8,
                    gradient: G.gold,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = (c.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final (i, a) in all.indexed)
                        SizedBox(
                          width: w,
                          child: Reveal(
                            delay: i * 0.03,
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 190),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: unlocked.contains(a.id)
                                    ? C.ivory
                                    : C.ivory.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: S.soft,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AchievementBadge(
                                    on: unlocked.contains(a.id),
                                    icon: a.icon,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    a.title,
                                    style: T.label.copyWith(
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    a.description,
                                    style: T.tiny.copyWith(
                                      fontWeight: FontWeight.w400,
                                      height: 1.35,
                                    ),
                                  ),
                                  if (!unlocked.contains(a.id)) ...[
                                    const SizedBox(height: 12),
                                    Bar(
                                      value:
                                          achievementValue(a, stats) /
                                          a.threshold,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${achievementValue(a, stats).clamp(0, a.threshold)} / ${a.threshold}',
                                      style: T.tiny.copyWith(fontSize: 11).tab,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
