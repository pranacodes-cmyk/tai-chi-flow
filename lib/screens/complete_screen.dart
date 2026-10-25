import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../logic/logic.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/confetti.dart';
import '../widgets/rate_sheet.dart';
import '../widgets/scaffold.dart';
import '../widgets/toast.dart';
import '../widgets/ui.dart';
import '../i18n/i18n.dart';

List<(int, String, String)> get _feelings => [
  (1, tr('complete.feelingTense'), 'frown'),
  (2, tr('complete.feelingOkay'), 'meh'),
  (3, tr('complete.feelingGood'), 'smile'),
  (4, tr('complete.feelingGreat'), 'sparkles'),
  (5, tr('complete.feelingBlissful'), 'lotus'),
];

class CompleteScreen extends StatelessWidget {
  const CompleteScreen({super.key, required this.entryId});
  final String entryId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final entry =
        app.history.where((h) => h.id == entryId).firstOrNull ??
        (app.history.isEmpty ? null : app.history.last);
    if (entry == null) {
      return EnsoScaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('complete.nothingToCelebrate'), style: T.displayMd),
              const SizedBox(height: 24),
              EnsoButton(
                label: tr('complete.goToToday'),
                expand: false,
                onTap: () => context.go('/'),
              ),
            ],
          ),
        ),
      );
    }
    final now = DateTime.now();
    final stats = computeStats(app.history, now, app.plansCompleted);
    final before = computeStats(
      app.history.where((h) => h.id != entry.id).toList(),
      now,
      app.plansCompleted,
    );
    final beforeSet = unlockedAchievements(before).toSet();
    final newBadges = unlockedAchievements(stats)
        .where((a) => !beforeSet.contains(a))
        .toList();
    final session = resolveSession(entry.sessionId);
    final moves = session?.items.length ?? 0;
    final minutes = (entry.durationSec / 60).round().clamp(1, 10000);
    final isMed = entry.kind == 'meditation';
    // finishing the last free day previews the next, locked lesson with a Plus offer
    final plan = entry.planId == null ? null : Content.i.plan(entry.planId!);
    final nextLocked = plan == null || entry.day == null
        ? null
        : lockedNextDay(plan, entry.day!, app.premium.active);

    final statTiles = [
      (LucideIcons.clock, minutes, tr('complete.statMinutes')),
      isMed
          ? (LucideIcons.award, stats.meditations, tr('complete.statMeditations'))
          : (LucideIcons.flame, entry.kcal, tr('complete.statKcal')),
      isMed
          ? (LucideIcons.flame, stats.streak, tr('complete.statDayStreak'))
          : (LucideIcons.layers, moves, tr('complete.statMoves')),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/');
      },
      child: EnsoScaffold(
        background: C.forest,
        lightIcons: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Opacity(
                opacity: 0.35,
                child: Transform.scale(
                  scale: 1.1,
                  child: EImage(img(entry.image)),
                ),
              ),
            ),
            Opacity(
              opacity: 0.9,
              child: Container(
                decoration: const BoxDecoration(gradient: G.forest),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 400,
              child: Confetti(),
            ),
            RatePromptTrigger(app: app),
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                24,
                topInset(context) + 36,
                24,
                bottomInset(context) + 24,
              ),
              child: Column(
                children: [
                  const _CheckMark(),
                  const SizedBox(height: 20),
                  Reveal(
                    delay: 0.4,
                    dy: 12,
                    child: Column(
                      children: [
                        Eyebrow(
                          isMed ? tr('complete.meditationComplete') : tr('complete.sessionComplete'),
                          color: C.sage,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.title,
                          textAlign: TextAlign.center,
                          style: T.displayLg.c(C.ivory),
                        ),
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: Text(
                            isMed
                                ? tr('complete.stillnessSkill')
                                : tr('complete.notWorkout'),
                            textAlign: TextAlign.center,
                            style: T.serifAccent.copyWith(
                              fontSize: 22.4,
                              height: 1.3,
                              color: C.ivory.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Reveal(
                    delay: 0.6,
                    child: Row(
                      children: [
                        for (final (i, s) in statTiles.indexed) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(
                            child: Glass(
                              radius: 22,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 8,
                              ),
                              child: Column(
                                children: [
                                  Icon(s.$1, size: 20, color: C.sage),
                                  const SizedBox(height: 6),
                                  CountUp(
                                    value: s.$2,
                                    delay: Duration(
                                      milliseconds: 650 + i * 120,
                                    ),
                                    style: T.displayMd.c(C.ivory).tab,
                                  ),
                                  Text(
                                    s.$3,
                                    style: T.tiny.copyWith(
                                      fontWeight: FontWeight.w400,
                                      color: C.ivory.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isMed) ...[
                    const SizedBox(height: 12),
                    Reveal(
                      delay: 0.7,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: G.ember,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: C.ivory.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.local_fire_department_rounded,
                                size: 26,
                                color: C.ivory,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr('complete.streakTitle', {'n': stats.streak}),
                                    style: T.label.copyWith(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: C.ivory,
                                    ),
                                  ),
                                  Text(
                                    stats.streak > 1
                                        ? tr('complete.consistencyBuilding')
                                        : tr('complete.dayOneBeautiful'),
                                    style: T.caption.c(
                                      C.ivory.withValues(alpha: 0.85),
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
                  if (plan != null && nextLocked != null) ...[
                    const SizedBox(height: 12),
                    Reveal(
                      delay: 0.8,
                      child: _NextDayOffer(
                        plan: plan,
                        dayNumber: nextLocked,
                        weightKg: app.profile.weightKg,
                        onUnlock: () => context.push('/paywall?from=plan'),
                      ),
                    ),
                  ],
                  if (newBadges.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Reveal(
                      delay: 0.9,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: C.ivory,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  LucideIcons.trophy,
                                  size: 14,
                                  color: C.gold,
                                ),
                                const SizedBox(width: 6),
                                Eyebrow(
                                  tr('complete.newAchievements', {'n': newBadges.length}),
                                  color: C.gold,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            for (final id in newBadges)
                              Builder(
                                builder: (_) {
                                  final a = Content.i.achievement(id)!;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            gradient: G.gold,
                                            shape: BoxShape.circle,
                                          ),
                                          child: ContentIcon(
                                            a.icon,
                                            size: 20,
                                            color: C.ink,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                a.title,
                                                style: T.label.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                a.description,
                                                style: T.caption,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Reveal(
                    delay: 1,
                    dy: 0,
                    child: Column(
                      children: [
                        Text(
                          tr('complete.howDoYouFeel'),
                          style: T.label.c(C.ivory.withValues(alpha: 0.8)),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            for (final (i, f) in _feelings.indexed) ...[
                              if (i > 0) const SizedBox(width: 6),
                              Expanded(
                                child: Pressable(
                                  onTap: () => app.rateEntry(entry.id, f.$1),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: entry.feeling == f.$1
                                          ? C.ivory
                                          : C.ivory.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Column(
                                      children: [
                                        ContentIcon(
                                          f.$3,
                                          size: 24,
                                          color: entry.feeling == f.$1
                                              ? C.ink
                                              : C.ivory.withValues(alpha: 0.8),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          f.$2,
                                          style: T.tiny.copyWith(
                                            fontSize: 11,
                                            color: entry.feeling == f.$1
                                                ? C.ink
                                                : C.ivory.withValues(
                                                    alpha: 0.8,
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      CircleBtn(
                        icon: LucideIcons.share2,
                        tone: Tone.dark,
                        size: 56,
                        label: tr('complete.share'),
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(
                              text:
                                  tr('complete.shareMessage', {'title': entry.title, 'minutes': minutes, 'streak': stats.streak}),
                            ),
                          );
                          Toast.show(
                            tr('complete.copiedToClipboard'),
                            description: tr('complete.shareProgressAnywhere'),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: EnsoButton(
                          label: tr('common.done'),
                          variant: BtnVariant.ivory,
                          onTap: () => context.go('/'),
                        ),
                      ),
                    ],
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

/// "Day N is ready": the next lesson's preview with a single Plus action, shown after the last free day.
class _NextDayOffer extends StatelessWidget {
  const _NextDayOffer({
    required this.plan,
    required this.dayNumber,
    required this.weightKg,
    required this.onUnlock,
  });
  final Plan plan;
  final int dayNumber;
  final double weightKg;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final day = plan.days[dayNumber - 1];
    final learn = [
      for (final it in day.items)
        if (it.p == 'New today') Content.i.exercise(it.e),
    ].whereType<Exercise>().toList();
    final total = plan.days.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.ivory,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: G.gold,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.crown, size: 13, color: C.ink),
                const SizedBox(width: 5),
                Text(tr('complete.dayReady', {'day': dayNumber}), style: T.tiny.c(C.ink)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RoundedImage(
                img(learn.isNotEmpty ? learn.first.image : plan.image),
                size: 88,
                radius: 20,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('complete.dayTitle', {'day': dayNumber, 'title': day.title}),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: T.title.copyWith(fontSize: 17, color: C.ink),
                    ),
                    if (learn.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        tr('complete.newExercises', {'names': learn.map((e) => e.name).join(' & ')}),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: T.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: C.jadeDeep,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      tr('complete.timeKcal', {'time': formatMinutes(totalSeconds(day.items)), 'kcal': kcalForWeight(day.kcal, weightKg)}),
                      style: T.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tr('complete.finishedFreeDays', {'day': dayNumber, 'total': total}),
            style: T.caption.copyWith(color: C.ink),
          ),
          const SizedBox(height: 14),
          Semantics(
            button: true,
            label: tr('common.continueWithPlus'),
            excludeSemantics: true,
            child: Pressable(
              onTap: onUnlock,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: G.gold,
                  borderRadius: BorderRadius.circular(52),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.crown, size: 18, color: C.ink),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        tr('common.continueWithPlus'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.label.copyWith(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckMark extends StatefulWidget {
  const _CheckMark();
  @override
  State<_CheckMark> createState() => _CheckMarkState();
}

class _CheckMarkState extends State<_CheckMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final pop = Curves.elasticOut.transform(
          (_c.value / 0.6).clamp(0.0, 1.0),
        );
        return Transform.scale(
          scale: 0.4 + 0.6 * pop,
          child: Transform.rotate(
            angle: -0.5 * (1 - pop),
            child: SizedBox(
              width: 112,
              height: 112,
              child: CustomPaint(painter: _CheckPainter(_c.value)),
            ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.scale(s);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = C.sage;
    final ringT = kEase.transform((t / 0.9).clamp(0.0, 1.0));
    const start = -70 * 3.14159 / 180;
    canvas.drawArc(
      const Rect.fromLTWH(8, 8, 84, 84),
      start,
      2 * 3.14159 * 0.92 * ringT,
      false,
      ring,
    );
    final checkT = ((t - 0.54) / 0.38).clamp(0.0, 1.0);
    if (checkT > 0) {
      final path = Path()
        ..moveTo(33, 51)
        ..lineTo(45, 63)
        ..lineTo(68, 39);
      final m = path.computeMetrics().first;
      canvas.drawPath(
        m.extractPath(0, m.length * checkT),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = C.ivory,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter o) => o.t != t;
}
