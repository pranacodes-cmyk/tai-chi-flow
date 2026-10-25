import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../logic/logic.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';
import '../i18n/i18n.dart';

const _feelingIcon = ['', 'frown', 'meh', 'smile', 'sparkles', 'lotus'];

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String selected = dateKey(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final stats = app.stats;
    final unlocked = app.unlocked;
    final byDay = <String, List<HistoryEntry>>{};
    for (final h in app.history) {
      byDay.putIfAbsent(dateKey(h.completedAt), () => []).add(h);
    }
    final now = DateTime.now();
    final todayKey = dateKey(now);
    final week = weekMinutes(app.history, now);
    final maxWeek = [
      10,
      ...week.map((w) => w.minutes),
    ].reduce((a, b) => a > b ? a : b);
    final recent = app.history.reversed.take(12).toList();
    final dayEntries = byDay[selected] ?? const [];
    final first = month.weekday % 7;
    final daysIn = DateTime(month.year, month.month + 1, 0).day;
    final cells = <DateTime?>[
      ...List.filled(first, null),
      for (var i = 1; i <= daysIn; i++) DateTime(month.year, month.month, i),
    ];
    final sel = selected.split('-').map(int.parse).toList();

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
                  Text(tr('history.title'), style: T.displayLg),
                  const SizedBox(height: 4),
                  Text(
                    tr('history.subtitle'),
                    style: T.bodySm.c(C.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Reveal(
              delay: 0.05,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: G.ember,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: S.card,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    right: -52,
                                    top: -52,
                                    child: Container(
                                      width: 112,
                                      height: 112,
                                      decoration: BoxDecoration(
                                        color: C.ivory.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.local_fire_department_rounded,
                                        size: 26,
                                        color: C.ivory,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '${stats.streak}',
                                        style: T.displayXl.c(C.ivory).tab,
                                      ),
                                      Text(
                                        tr('history.dayStreak'),
                                        style: T.caption.copyWith(
                                          fontSize: 14,
                                          color: C.ivory.withValues(
                                            alpha: 0.85,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        tr('history.bestStreak', {'n': stats.best}),
                                        style: T.tiny.copyWith(
                                          fontWeight: FontWeight.w400,
                                          color: C.ivory.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(
                                  child: _MiniStat(
                                    tr('history.totalMinutes'),
                                    '${stats.minutes}',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: _MiniStat(
                                    tr('history.caloriesBurned'),
                                    '${stats.kcal}',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _IconStat(
                            icon: const Icon(
                              LucideIcons.sparkles,
                              size: 20,
                              color: C.jadeDeep,
                            ),
                            bg: C.jadeSoft,
                            value: '${stats.workouts}',
                            label: tr('history.workouts'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _IconStat(
                            icon: const ContentIcon(
                              'lotus',
                              size: 20,
                              color: C.ink,
                            ),
                            bg: C.goldSoft,
                            value: '${stats.meditations}',
                            label: tr('history.meditations'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Reveal(
              delay: 0.1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ECard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('MMMM yyyy', appLocale).format(month),
                              style: T.title,
                            ),
                          ),
                          CircleBtn(
                            icon: LucideIcons.chevronLeft,
                            tone: Tone.sand,
                            size: 36,
                            iconSize: 16,
                            label: tr('history.previousMonth'),
                            onTap: () => setState(
                              () => month = DateTime(
                                month.year,
                                month.month - 1,
                                1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          CircleBtn(
                            icon: LucideIcons.chevronRight,
                            tone: Tone.sand,
                            size: 36,
                            iconSize: 16,
                            label: tr('history.nextMonth'),
                            onTap: () => setState(
                              () => month = DateTime(
                                month.year,
                                month.month + 1,
                                1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          for (final d in weekLetters)
                            Expanded(
                              child: Center(
                                child: Text(
                                  d,
                                  style: T.tiny.copyWith(fontSize: 11),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GridView.count(
                        crossAxisCount: 7,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 6,
                        children: [
                          for (final d in cells)
                            if (d == null)
                              const SizedBox()
                            else
                              Builder(
                                builder: (_) {
                                  final k = dateKey(d);
                                  final done = byDay.containsKey(k);
                                  final isToday = k == todayKey;
                                  final isSel = k == selected;
                                  return GestureDetector(
                                    onTap: () => setState(() => selected = k),
                                    child: Center(
                                      child: AnimatedScale(
                                        scale: isSel ? 1.1 : 1,
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: done
                                                ? C.jade
                                                : (isSel
                                                      ? C.sand
                                                      : Colors.transparent),
                                            border: isToday && !done
                                                ? Border.all(
                                                    color: C.jade,
                                                    width: 2,
                                                  )
                                                : null,
                                            boxShadow: isSel ? S.glow : null,
                                          ),
                                          child: Text(
                                            '${d.day}',
                                            style: T.caption
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: done
                                                      ? C.ivory
                                                      : (isToday
                                                            ? C.jadeDeep
                                                            : C.ink.withValues(
                                                                alpha: 0.7,
                                                              )),
                                                )
                                                .tab,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: C.line),
                      const SizedBox(height: 16),
                      Text(
                        DateFormat('EEEE, MMM d', appLocale)
                            .format(DateTime(sel[0], sel[1], sel[2])),
                        style: T.caption.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      if (dayEntries.isEmpty)
                        Text(tr('history.noPractice'), style: T.caption.s(14))
                      else
                        for (final h in dayEntries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    h.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: T.label.s(14),
                                  ),
                                ),
                                Text(
                                  tr('common.minShort', {'n': (h.durationSec / 60).round().clamp(1, 9999)}),
                                  style: T.caption.s(14).tab,
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
            Reveal(
              delay: 0.14,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ECard(
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(child: Text(tr('history.thisWeek'), style: T.title)),
                          Text(
                            tr('common.minShort', {'n': week.fold<int>(0, (s, w) => s + w.minutes)}),
                            style: T.caption
                                .copyWith(fontWeight: FontWeight.w600)
                                .tab,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 140,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final (i, w) in week.indexed) ...[
                              if (i > 0) const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      w.minutes > 0 ? '${w.minutes}' : '',
                                      style: T.tiny
                                          .copyWith(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          )
                                          .tab,
                                    ),
                                    const SizedBox(height: 8),
                                    Flexible(
                                      child: Container(
                                      height: 100,
                                      alignment: Alignment.bottomCenter,
                                      decoration: BoxDecoration(
                                        color: C.sand.withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: TweenAnimationBuilder<double>(
                                        tween: Tween(
                                          begin: 0,
                                          end: w.minutes / maxWeek,
                                        ),
                                        duration: Duration(
                                          milliseconds: 700 + i * 50,
                                        ),
                                        curve: kEase,
                                        builder: (_, v, _) =>
                                            FractionallySizedBox(
                                              heightFactor: v,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient: w.key == todayKey
                                                      ? G.jade
                                                      : null,
                                                  color: w.key == todayKey
                                                      ? null
                                                      : C.sage,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                      ),
                                    ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      w.label,
                                      style: T.tiny.copyWith(
                                        color: w.key == todayKey
                                            ? C.jade
                                            : C.muted,
                                      ),
                                    ),
                                  ],
                                ),
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
            const SizedBox(height: 36),
            SectionHeader(
              tr('history.achievements'),
              action: '${unlocked.length}/${Content.i.achievements.length}',
              onAction: () => context.push('/achievements'),
            ),
            HScroll(
              gap: 12,
              children: [
                for (final a in Content.i.achievements.take(10))
                  Pressable(
                    onTap: () => context.push('/achievements'),
                    child: Container(
                      width: 108,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: C.ivory,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: S.soft,
                      ),
                      child: Column(
                        children: [
                          _Badge(on: unlocked.contains(a.id), icon: a.icon),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 30,
                            child: Text(
                              a.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: T.tiny.copyWith(
                                fontWeight: FontWeight.w700,
                                color: C.ink,
                                height: 1.2,
                              ),
                            ),
                          ),
                          if (!unlocked.contains(a.id)) ...[
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 48,
                              child: Bar(
                                value: achievementValue(a, stats) / a.threshold,
                                height: 4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            SectionHeader(tr('history.recentSessions')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: recent.isEmpty
                  ? ECard(
                      shadow: S.soft,
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: C.jadeSoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.trophy,
                              size: 28,
                              color: C.jadeDeep,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(tr('history.journeyStart'), style: T.title),
                          const SizedBox(height: 6),
                          Text(
                            tr('history.journeyStartBody'),
                            textAlign: TextAlign.center,
                            style: T.caption.s(14),
                          ),
                          const SizedBox(height: 20),
                          EnsoButton(
                            label: tr('history.startPracticing'),
                            size: BtnSize.md,
                            expand: false,
                            onTap: () => context.go('/'),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        for (final h in recent)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                10,
                                10,
                                16,
                                10,
                              ),
                              decoration: BoxDecoration(
                                color: C.ivory,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: S.soft,
                              ),
                              child: Row(
                                children: [
                                  RoundedImage(
                                    img(h.image),
                                    size: 56,
                                    radius: 14,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          h.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: T.label,
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              DateFormat('MMM d', appLocale)
                                                  .format(h.completedAt),
                                              style: T.tiny.w(FontWeight.w400),
                                            ),
                                            const SizedBox(width: 10),
                                            const Icon(
                                              LucideIcons.clock,
                                              size: 12,
                                              color: C.muted,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              tr('common.minShort', {'n': (h.durationSec / 60).round().clamp(1, 9999)}),
                                              style: T.tiny.w(FontWeight.w400),
                                            ),
                                            if (h.kcal > 0) ...[
                                              const SizedBox(width: 10),
                                              const Icon(
                                                LucideIcons.flame,
                                                size: 12,
                                                color: C.muted,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                '${h.kcal}',
                                                style: T.tiny.w(
                                                  FontWeight.w400,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (h.feeling != null)
                                    ContentIcon(
                                      _feelingIcon[h.feeling!],
                                      size: 20,
                                      color: C.jade,
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: C.ivory,
      borderRadius: BorderRadius.circular(24),
      boxShadow: S.soft,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: T.tiny),
        const SizedBox(height: 4),
        Text(value, style: T.displayMd.tab),
      ],
    ),
  );
}

class _IconStat extends StatelessWidget {
  const _IconStat({
    required this.icon,
    required this.bg,
    required this.value,
    required this.label,
  });
  final Widget icon;
  final Color bg;
  final String value, label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: C.ivory,
      borderRadius: BorderRadius.circular(22),
      boxShadow: S.soft,
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Center(child: icon),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title.tab),
              Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.tiny.w(FontWeight.w400)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({super.key, required this.on, required this.icon});
  final bool on;
  final String icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: on ? G.gold : null,
      color: on ? null : C.sand,
      boxShadow: on
          ? [
              BoxShadow(
                color: C.gold.withValues(alpha: 0.8),
                blurRadius: 20,
                spreadRadius: -8,
                offset: const Offset(0, 8),
              ),
            ]
          : null,
    ),
    child: on
        ? ContentIcon(icon, size: 24, color: C.ink)
        : Icon(
            LucideIcons.lock,
            size: 20,
            color: C.muted.withValues(alpha: 0.6),
          ),
  );
}

class AchievementBadge extends _Badge {
  const AchievementBadge({super.key, required super.on, required super.icon});
}
