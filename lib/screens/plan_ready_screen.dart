import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../logic/logic.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';
import '../widgets/confetti.dart';
import '../i18n/i18n.dart';

const _checklist = [
  'planReady.analyzingGoals',
  'planReady.adaptingBody',
  'planReady.choosingMovements',
  'planReady.buildingSchedule',
];

class PlanReadyScreen extends StatefulWidget {
  const PlanReadyScreen({super.key});
  @override
  State<PlanReadyScreen> createState() => _PlanReadyScreenState();
}

class _PlanReadyScreenState extends State<PlanReadyScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double progress = 0;
  bool celebrating = false, done = false;
  int _lastTick = 0, _lastStep = 0;
  late final bool _haptics = context.read<AppState>().audio.haptics;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final p = (elapsed.inMilliseconds / 4800 * 100).clamp(0.0, 100.0);
      // haptics follow the ring: a soft tick every 5%, a firmer tap as each checklist step completes
      final tick = (p / 5).floor();
      final step = (p / 24).floor().clamp(0, 4);
      if (_haptics && step > _lastStep && step <= 4) {
        HapticFeedback.mediumImpact();
      } else if (_haptics && tick > _lastTick && p < 100) {
        HapticFeedback.selectionClick();
      }
      _lastTick = tick;
      _lastStep = step;
      setState(() => progress = p);
      if (p >= 100) {
        _ticker.stop();
        _celebrate();
      }
    })..start();
  }

  /// 100%: a strong double tap, confetti and "Your plan is ready" before the plan itself.
  Future<void> _celebrate() async {
    if (_haptics) {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 140), HapticFeedback.heavyImpact);
    }
    setState(() => celebrating = true);
    await Future.delayed(const Duration(milliseconds: 2000));
    if (mounted) setState(() => done = true);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: EnsoScaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: kEase,
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(a),
              child: c,
            ),
          ),
          child: done
              ? const _Result(key: ValueKey('res'))
              : celebrating
                  ? const _PlanReadyBurst(key: ValueKey('burst'))
                  : _Generating(key: const ValueKey('gen'), progress: progress),
        ),
      ),
    );
  }
}

/// Short celebration between the loading ring and the plan: confetti, a check that pops in
/// with an elastic bounce and "Your plan is ready" (web mirrors it).
class _PlanReadyBurst extends StatelessWidget {
  const _PlanReadyBurst({super.key});
  @override
  Widget build(BuildContext context) {
    final name = context.read<AppState>().profile.name;
    return Stack(children: [
      const Positioned.fill(child: Confetti(height: 900)),
      Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(shape: BoxShape.circle, color: C.jade, boxShadow: S.card),
              child: const Icon(LucideIcons.check, size: 56, color: C.ivory),
            ),
          ),
          const SizedBox(height: 28),
          Reveal(
            delay: 0.25,
            dy: 10,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: name.isNotEmpty ? tr('planReady.yourPlanIsReadyNamed', {'name': name}) : tr('planReady.yourPlanIsReady')),
                TextSpan(text: tr('planReady.ready'), style: T.serifAccent.copyWith(fontSize: 38, color: C.jade)),
              ]),
              textAlign: TextAlign.center,
              style: T.displayLg,
            ),
          ),
        ]),
      )),
    ]);
  }
}

class _Generating extends StatelessWidget {
  const _Generating({super.key, required this.progress});
  final double progress;
  @override
  Widget build(BuildContext context) {
    final list = Content.i.testimonials;
    final t = list[math.max(0, (progress / 26).floor()) % list.length];
    final active = math.min(_checklist.length - 1, (progress / 25).floor());
    return Stack(
      children: [
        Positioned(
          top: -100,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    C.jade.withValues(alpha: 0.16),
                    C.jade.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Scrolls only when a short phone or large text needs more room.
        LayoutBuilder(builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
          padding: EdgeInsets.fromLTRB(
            28,
            topInset(context) + 56,
            28,
            bottomInset(context) + 24,
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  const _Ripple(size: 164),
                  const _SpinningDash(size: 216),
                  Ring(
                    value: progress / 100,
                    size: 188,
                    stroke: 10,
                    child: Text('${progress.round()}%', style: T.displayXl.tab),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Text(
                tr('planReady.creatingPlan'),
                textAlign: TextAlign.center,
                style: T.displayMd,
              ),
              const SizedBox(height: 8),
              Text(
                tr('planReady.matchingMovements'),
                textAlign: TextAlign.center,
                style: T.bodySm.c(C.muted),
              ),
              const SizedBox(height: 28),
              for (final (i, c) in _checklist.indexed)
                Builder(
                  builder: (context) {
                    final on = progress > (i + 1) * 24;
                    final current = !on && i == active;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Reveal(
                        delay: 0.1 + i * 0.12,
                        dy: 8,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: on
                                ? C.ivory
                                : (current
                                      ? C.ivory.withValues(alpha: 0.6)
                                      : Colors.transparent),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: on ? S.soft : null,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 500,
                                      ),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: on ? C.jade : C.sand,
                                      ),
                                      child: on
                                          ? const Center(
                                              child: Icon(
                                                LucideIcons.check,
                                                size: 16,
                                                color: C.ivory,
                                              ),
                                            )
                                          : null,
                                    ),
                                    if (current)
                                      const SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: C.jade,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 500),
                                style: T.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: on || current ? C.ink : C.muted,
                                ),
                                child: Text(tr(c)),
                              ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Container(
                  key: ValueKey(t.name),
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: C.ivory,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: S.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Avatar(t.avatar ?? 'onb-age-f-50', size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.name,
                                style: T.label.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Stars(count: t.rating, size: 13),
                            ],
                          ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('“${t.text}”', style: T.bodySm),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
            ),
          ),
        )),
      ],
    );
  }
}

class _SpinningDash extends StatefulWidget {
  const _SpinningDash({required this.size});
  final double size;
  @override
  State<_SpinningDash> createState() => _SpinningDashState();
}

class _SpinningDashState extends State<_SpinningDash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _c,
    child: CustomPaint(size: Size.square(widget.size), painter: _DashPainter()),
  );
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final p = Paint()
      ..color = C.jade.withValues(alpha: 0.25)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const n = 72;
    for (var i = 0; i < n; i += 2) {
      canvas.drawArc(
        Rect.fromCircle(center: size.center(Offset.zero), radius: r),
        i * 2 * math.pi / n,
        2 * math.pi / n,
        false,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Ripple extends StatefulWidget {
  const _Ripple({required this.size});
  final double size;
  @override
  State<_Ripple> createState() => _RippleState();
}

class _RippleState extends State<_Ripple> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => Transform.scale(
      scale: 0.9 + 0.5 * _c.value,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: C.jade.withValues(alpha: 0.2 * (1 - _c.value)),
        ),
      ),
    ),
  );
}

class _Result extends StatelessWidget {
  const _Result({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.profile;
    final planId = recommendFor(p);
    final plan = Content.i.plan(planId)!;
    final losing = p.goals.contains('weight') && p.targetWeightKg < p.weightKg;
    final targetDate = predictTargetDate(
      p.weightKg,
      p.targetWeightKg,
      DateTime.now(),
    );
    final curve = losing
        ? predictionCurve(p.weightKg, p.targetWeightKg)
        : const [30.0, 52.0, 66.0, 76.0, 83.0, 88.0];
    final goalLabels = {
      for (final o in Content.i.step('goals')?.options ?? const <OnbOption>[])
        o.id: o.label,
    };
    final zoneLabels = {
      for (final o in Content.i.step('zones')?.options ?? const <OnbOption>[])
        o.id: o.label,
    };
    final summary = [
      (
        tr('planReady.mainGoal'),
        (goalLabels[p.goals.firstOrNull ?? ''] ?? tr('planReady.overallWellbeing'))
            .replaceFirst(RegExp(r'^Improve '), ''),
      ),
      (tr('planReady.focusArea'), zoneLabels[p.zones.firstOrNull ?? ''] ?? tr('planReady.fullBody')),
      (tr('planReady.dailyTime'), tr('common.minutes', {'n': p.dailyMinutes})),
      (tr('planReady.level'), trTag(plan.level)),
    ];
    final week = plan.days.take(7).toList();

    return Stack(
      children: [
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(24, topInset(context) + 24, 24, 170),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: C.jadeSoft,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.sparkles,
                      size: 14,
                      color: C.jadeDeep,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tr('planReady.planReadyBadge'),
                      style: T.tiny.copyWith(
                        fontWeight: FontWeight.w700,
                        color: C.jadeDeep,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: p.name.isNotEmpty
                          ? tr('planReady.yourPlanIsReadyNamed', {'name': p.name})
                          : tr('planReady.yourPlanIsReady'),
                    ),
                    TextSpan(
                      text: tr('planReady.ready'),
                      style: T.serifAccent.copyWith(
                        fontSize: 36,
                        color: C.jade,
                      ),
                    ),
                  ],
                ),
                style: T.displayLg,
              ),
              const SizedBox(height: 10),
              if (losing)
                Text(
                  tr('planReady.weightForecast', {
                    'weight': formatWeight(p.targetWeightKg, p.units),
                    'date': DateFormat('MMMM d', appLocale).format(targetDate),
                  }),
                  style: T.body.c(C.muted),
                )
              else
                Text(
                  tr('planReady.balanceForecast'),
                  style: T.body.c(C.muted),
                ),
              const SizedBox(height: 24),
              _PredictionChart(
                curve: curve,
                losing: losing,
                imperial: p.imperial,
                endLabel: DateFormat('MMM d', appLocale).format(targetDate),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, c) {
                  final w = (c.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final (label, value) in summary)
                        Container(
                          width: w,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: C.ivory,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: S.soft,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label.toUpperCase(),
                                style: T.tiny.copyWith(
                                  fontSize: 11,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: T.label.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              ECard(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 176,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            EImage(img(plan.image)),
                            DecoratedBox(
                              decoration: BoxDecoration(gradient: G.scrim),
                            ),
                            Positioned(
                              left: 20,
                              right: 20,
                              bottom: 16,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Eyebrow(
                                    tr('planReady.yourProgram'),
                                    color: C.ivory.withValues(alpha: 0.75),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    plan.title,
                                    style: T.displayMd.c(C.ivory),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    plan.subtitle,
                                    style: T.caption.c(
                                      C.ivory.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              for (final (i, x) in [
                                (
                                  LucideIcons.calendarDays,
                                  tr('common.days', {'n': plan.days.length}),
                                ),
                                (
                                  LucideIcons.clock,
                                  tr('planReady.minPerDay', {'n': plan.minutesPerDay}),
                                ),
                                (LucideIcons.target, trTag(plan.level)),
                              ].indexed) ...[
                                if (i > 0)
                                  const VerticalDivider(
                                    width: 1,
                                    color: C.line,
                                  ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Icon(x.$1, size: 20, color: C.jade),
                                      const SizedBox(height: 6),
                                      Text(
                                        x.$2,
                                        style: T.caption.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: C.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(tr('planReady.yourFirstWeek'), style: T.title.s(20)),
                  ),
                  Text(
                    tr('planReady.minADay', {'n': plan.minutesPerDay}),
                    style: T.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: C.jade,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Stack(
                children: [
                  Positioned(
                    left: 26,
                    top: 24,
                    bottom: 24,
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: C.sandDeep.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      for (final (i, d) in week.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Reveal(
                            delay: 0.25 + i * 0.06,
                            dy: 10,
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
                                  SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: Stack(
                                      children: [
                                        RoundedImage(
                                          img(
                                            Content.i
                                                    .exercise(
                                                      d.items.firstOrNull?.e ??
                                                          '',
                                                    )
                                                    ?.image ??
                                                plan.image,
                                          ),
                                          size: 52,
                                          radius: 16,
                                        ),
                                        Positioned(
                                          left: 4,
                                          top: 4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: C.ink.withValues(
                                                alpha: 0.7,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${d.day}',
                                              style: T.tiny.copyWith(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: C.ivory,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          d.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: T.label,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          tr('planReady.dayMeta', {
                                            'restore': d.restore,
                                            'minutes': math.max(1, (totalSeconds(d.items) / 60).round()),
                                            'moves': d.items.length,
                                          }),
                                          style: T.tiny.w(FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (i == 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: C.jadeSoft,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        tr('common.today'),
                                        style: T.tiny.copyWith(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: C.jadeDeep,
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
                ],
              ),
              const SizedBox(height: 18),
              Text(tr('planReady.whatYoullFeel'), style: T.title.s(20)),
              const SizedBox(height: 14),
              for (final (i, b) in plan.benefits.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Reveal(
                    delay: 0.3 + i * 0.08,
                    dy: 0,
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: C.jade,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.check,
                            size: 16,
                            color: C.ivory,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(b, style: T.body.w(FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        BottomCta(
          child: Shimmer(
            child: EnsoButton(
              label: tr('planReady.getMyPlan'),
              onTap: () {
                app.completeOnboarding(planId);
                context.go('/paywall?from=onboarding');
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PredictionChart extends StatefulWidget {
  const _PredictionChart({
    required this.curve,
    required this.losing,
    required this.imperial,
    required this.endLabel,
  });
  final List<double> curve;
  final bool losing, imperial;
  final String endLabel;
  @override
  State<_PredictionChart> createState() => _PredictionChartState();
}

class _PredictionChartState extends State<_PredictionChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ECard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.losing
                      ? tr('planReady.weightForecastTitle')
                      : tr('planReady.balanceFlexibilityTitle'),
                  style: T.title,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: C.jadeSoft,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  tr('planReady.personalized'),
                  style: T.tiny.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: C.jadeDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 320 / 170,
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) =>
                  CustomPaint(painter: _ChartPainter(widget, _c.value)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('planReady.forecastDisclaimer'),
            style: T.tiny.w(FontWeight.w400),
          ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.w, this.t);
  final _PredictionChart w;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 320;
    canvas.scale(sx, sx);
    const W = 320.0, H = 170.0, l = 12.0, r = 12.0, top = 28.0, b = 30.0;
    final curve = w.curve;
    final mn = curve.reduce(math.min), mx = curve.reduce(math.max);
    final range = (mx - mn) == 0 ? 1 : mx - mn;
    final pts = [
      for (var i = 0; i < curve.length; i++)
        Offset(
          l + i / (curve.length - 1) * (W - l - r),
          top + (mx - curve[i]) / range * (H - top - b),
        ),
    ];
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < pts.length; i++) {
      final cx = (pts[i - 1].dx + pts[i].dx) / 2;
      path.cubicTo(cx, pts[i - 1].dy, cx, pts[i].dy, pts[i].dx, pts[i].dy);
    }
    final dash = Paint()
      ..color = C.line
      ..strokeWidth = 1;
    for (final f in [0.25, 0.5, 0.75]) {
      final y = top + f * (H - top - b);
      for (var x = l; x < W - r; x += 10) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, W - r), y), dash);
      }
    }
    final lineT = Curves.easeOutQuart.transform((t / 0.72).clamp(0.0, 1.0));
    final areaT = ((t - 0.36) / 0.36).clamp(0.0, 1.0);
    final area = Path.from(path)
      ..lineTo(pts.last.dx, H - b)
      ..lineTo(pts.first.dx, H - b)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            C.jade.withValues(alpha: 0.28 * areaT),
            C.jade.withValues(alpha: 0),
          ],
        ).createShader(const Rect.fromLTWH(0, 0, W, H)),
    );
    final metric = path.computeMetrics().first;
    final partial = metric.extractPath(0, metric.length * lineT);
    canvas.drawPath(
      partial,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(colors: [C.terracotta, C.gold, C.jade])
            .createShader(const Rect.fromLTWH(0, 0, W, H)),
    );
    void dot(Offset o, double rad, Color c) {
      canvas.drawCircle(o, rad + 3, Paint()..color = C.ivory);
      canvas.drawCircle(o, rad, Paint()..color = c);
    }

    dot(pts.first, 6, C.terracotta);
    final endT = ((t - 0.63) / 0.2).clamp(0.0, 1.0);
    if (endT > 0) dot(pts.last, 8 * Curves.easeOutBack.transform(endT), C.jade);
    String fmt(double v) => w.imperial
        ? tr('planReady.weightLb', {'n': (v * 2.20462).round()})
        : tr('planReady.weightKg', {'n': v == v.roundToDouble() ? v.toInt() : v});
    void text(
      String s,
      Offset o, {
      bool end = false,
      Color color = C.ink,
      double size = 12,
      FontWeight weight = FontWeight.w700,
    }) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: T.family,
            fontSize: size,
            fontWeight: weight,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(end ? o.dx - tp.width : o.dx, o.dy - tp.height + 3),
      );
    }

    // A rising curve leaves the start dot steeply, so a label above it would sit on
    // the line: the balance chart names the start on the axis instead.
    if (w.losing) {
      text(fmt(curve.first), Offset(pts.first.dx + 4, pts.first.dy - 14));
    }
    if (endT > 0) {
      text(
        w.losing ? fmt(curve.last) : '+58%',
        Offset(pts.last.dx, pts.last.dy - 16),
        end: true,
        color: C.jadeDeep,
      );
    }
    text(
      w.losing ? tr('planReady.now') : tr('common.today'),
      const Offset(l, H - 6),
      color: w.losing ? C.muted : C.terracotta,
      size: w.losing ? 11 : 12,
      weight: w.losing ? FontWeight.w500 : FontWeight.w700,
    );
    text(
      w.losing ? w.endLabel : tr('planReady.week4'),
      const Offset(W - r, H - 6),
      end: true,
      color: C.muted,
      size: 11,
      weight: FontWeight.w500,
    );
  }

  @override
  bool shouldRepaint(covariant _ChartPainter o) => o.t != t;
}
