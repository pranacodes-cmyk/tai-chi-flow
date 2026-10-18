import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../logic/logic.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';

const _checklist = ['Analyzing your goals', 'Adapting to your body', 'Choosing your movements', 'Building your daily schedule'];

class PlanReadyScreen extends StatefulWidget {
  const PlanReadyScreen({super.key});
  @override
  State<PlanReadyScreen> createState() => _PlanReadyScreenState();
}

class _PlanReadyScreenState extends State<PlanReadyScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double progress = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final p = (elapsed.inMilliseconds / 4800 * 100).clamp(0.0, 100.0);
      setState(() => progress = p);
      if (p >= 100) _ticker.stop();
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = progress >= 100;
    return PopScope(
      canPop: false,
      child: EnsoScaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: kEase,
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(a), child: c),
          ),
          child: done ? const _Result(key: ValueKey('res')) : _Generating(key: const ValueKey('gen'), progress: progress),
        ),
      ),
    );
  }
}

class _Generating extends StatelessWidget {
  const _Generating({super.key, required this.progress});
  final double progress;
  @override
  Widget build(BuildContext context) {
    final list = Content.i.testimonials;
    final t = list[math.max(0, (progress / 34).floor()) % list.length];
    return Padding(
      padding: EdgeInsets.fromLTRB(28, topInset(context) + 70, 28, bottomInset(context) + 28),
      child: Column(children: [
        Stack(alignment: Alignment.center, children: [
          const _Ripple(size: 196),
          Ring(
            value: progress / 100,
            size: 196,
            stroke: 10,
            child: Text('${progress.round()}%', style: T.displayXl.tab),
          ),
        ]),
        const SizedBox(height: 40),
        Text('Creating your personal plan', textAlign: TextAlign.center, style: T.displayMd),
        const SizedBox(height: 32),
        for (final (i, c) in _checklist.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 28,
                height: 28,
                decoration: BoxDecoration(shape: BoxShape.circle, color: progress > (i + 1) * 23 ? C.jade : C.sand),
                child: progress > (i + 1) * 23 ? const Icon(LucideIcons.check, size: 16, color: C.ivory) : null,
              ),
              const SizedBox(width: 12),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 500),
                style: T.body.copyWith(fontWeight: FontWeight.w500, color: progress > (i + 1) * 23 ? C.ink : C.muted),
                child: Text(c),
              ),
            ]),
          ),
        const Spacer(),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Container(
            key: ValueKey(t.name),
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: C.ivory, borderRadius: BorderRadius.circular(26), boxShadow: S.soft),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [for (var i = 0; i < t.rating; i++) const Icon(Icons.star_rounded, size: 18, color: C.gold)]),
              const SizedBox(height: 8),
              Text('“${t.text}”', style: T.bodySm),
              const SizedBox(height: 8),
              Text(t.name, style: T.caption.w(FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Ripple extends StatefulWidget {
  const _Ripple({required this.size});
  final double size;
  @override
  State<_Ripple> createState() => _RippleState();
}

class _RippleState extends State<_Ripple> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
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
            decoration: BoxDecoration(shape: BoxShape.circle, color: C.jade.withValues(alpha: 0.2 * (1 - _c.value))),
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
    final targetDate = predictTargetDate(p.weightKg, p.targetWeightKg, DateTime.now());
    final curve = losing ? predictionCurve(p.weightKg, p.targetWeightKg) : const [30.0, 52.0, 66.0, 76.0, 83.0, 88.0];

    return Stack(children: [
      SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(24, topInset(context) + 24, 24, 160),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: C.jadeSoft, borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(LucideIcons.sparkles, size: 14, color: C.jadeDeep),
              const SizedBox(width: 6),
              Text('Plan ready', style: T.tiny.copyWith(fontWeight: FontWeight.w700, color: C.jadeDeep)),
            ]),
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '${p.name.isNotEmpty ? '${p.name}, your' : 'Your'} plan is '),
              TextSpan(text: 'ready', style: T.serifAccent.copyWith(fontSize: 36, color: C.jade)),
            ]),
            style: T.displayLg,
          ),
          const SizedBox(height: 10),
          if (losing)
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Based on your answers, you could reach '),
                TextSpan(text: formatWeight(p.targetWeightKg, p.units), style: const TextStyle(fontWeight: FontWeight.w700, color: C.ink)),
                const TextSpan(text: ' by '),
                TextSpan(text: DateFormat('MMMM d').format(targetDate), style: const TextStyle(fontWeight: FontWeight.w700, color: C.ink)),
                const TextSpan(text: '.'),
              ]),
              style: T.body.c(C.muted),
            )
          else
            Text('Expect noticeably better balance and flexibility within 4 weeks of gentle daily practice.', style: T.body.c(C.muted)),
          const SizedBox(height: 24),
          _PredictionChart(curve: curve, losing: losing, imperial: p.imperial, endLabel: DateFormat('MMM d').format(targetDate)),
          const SizedBox(height: 24),
          ECard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Column(children: [
                SizedBox(
                  height: 160,
                  child: Stack(fit: StackFit.expand, children: [
                    EImage(img(plan.image)),
                    DecoratedBox(decoration: BoxDecoration(gradient: G.scrim)),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 16,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Eyebrow('Your program', color: C.ivory.withValues(alpha: 0.75)),
                        const SizedBox(height: 4),
                        Text(plan.title, style: T.displayMd.c(C.ivory)),
                      ]),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: IntrinsicHeight(
                    child: Row(children: [
                      for (final (i, x) in [(LucideIcons.calendarDays, '${plan.days.length} days'), (LucideIcons.clock, '${plan.minutesPerDay} min/day'), (LucideIcons.target, plan.level)].indexed) ...[
                        if (i > 0) const VerticalDivider(width: 1, color: C.line),
                        Expanded(
                          child: Column(children: [
                            Icon(x.$1, size: 20, color: C.jade),
                            const SizedBox(height: 6),
                            Text(x.$2, style: T.caption.copyWith(fontWeight: FontWeight.w600, color: C.ink)),
                          ]),
                        ),
                      ],
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          for (final (i, b) in plan.benefits.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Reveal(
                delay: 0.3 + i * 0.08,
                dy: 0,
                child: Row(children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(color: C.jade, shape: BoxShape.circle),
                    child: const Icon(LucideIcons.check, size: 16, color: C.ivory),
                  ),
                  const SizedBox(width: 12),
                  Text(b, style: T.body.w(FontWeight.w500)),
                ]),
              ),
            ),
        ]),
      ),
      BottomCta(
        child: EnsoButton(
          label: 'Get my plan',
          onTap: () {
            app.completeOnboarding(planId);
            context.go('/paywall?from=onboarding');
          },
        ),
      ),
    ]);
  }
}

class _PredictionChart extends StatefulWidget {
  const _PredictionChart({required this.curve, required this.losing, required this.imperial, required this.endLabel});
  final List<double> curve;
  final bool losing, imperial;
  final String endLabel;
  @override
  State<_PredictionChart> createState() => _PredictionChartState();
}

class _PredictionChartState extends State<_PredictionChart> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ECard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(widget.losing ? 'Your weight forecast' : 'Balance & flexibility', style: T.title)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: C.jadeSoft, borderRadius: BorderRadius.circular(99)),
            child: Text('Personalized', style: T.tiny.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: C.jadeDeep)),
          ),
        ]),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 320 / 170,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => CustomPaint(painter: _ChartPainter(widget, _c.value)),
          ),
        ),
        const SizedBox(height: 8),
        Text('Forecast based on members with similar goals practicing daily. Individual results vary.', style: T.tiny.w(FontWeight.w400)),
      ]),
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
      for (var i = 0; i < curve.length; i++) Offset(l + i / (curve.length - 1) * (W - l - r), top + (mx - curve[i]) / range * (H - top - b)),
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
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.jade.withValues(alpha: 0.28 * areaT), C.jade.withValues(alpha: 0)])
            .createShader(const Rect.fromLTWH(0, 0, W, H)),
    );
    final metric = path.computeMetrics().first;
    final partial = metric.extractPath(0, metric.length * lineT);
    canvas.drawPath(
      partial,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(colors: [C.terracotta, C.gold, C.jade]).createShader(const Rect.fromLTWH(0, 0, W, H)),
    );
    void dot(Offset o, double rad, Color c) {
      canvas.drawCircle(o, rad + 3, Paint()..color = C.ivory);
      canvas.drawCircle(o, rad, Paint()..color = c);
    }

    dot(pts.first, 6, C.terracotta);
    final endT = ((t - 0.63) / 0.2).clamp(0.0, 1.0);
    if (endT > 0) dot(pts.last, 8 * Curves.easeOutBack.transform(endT), C.jade);
    String fmt(double v) => w.imperial ? '${(v * 2.20462).round()} lb' : '${v == v.roundToDouble() ? v.toInt() : v} kg';
    void text(String s, Offset o, {bool end = false, Color color = C.ink, double size = 12, FontWeight weight = FontWeight.w700}) {
      final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(fontFamily: T.family, fontSize: size, fontWeight: weight, color: color)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(end ? o.dx - tp.width : o.dx, o.dy - tp.height + 3));
    }

    text(w.losing ? fmt(curve.first) : 'Today', Offset(pts.first.dx + 4, pts.first.dy - 14));
    if (endT > 0) text(w.losing ? fmt(curve.last) : '+58%', Offset(pts.last.dx, pts.last.dy - 16), end: true, color: C.jadeDeep);
    text('Now', const Offset(l, H - 6), color: C.muted, size: 11, weight: FontWeight.w500);
    text(w.losing ? w.endLabel : 'Week 4', const Offset(W - r, H - 6), end: true, color: C.muted, size: 11, weight: FontWeight.w500);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter o) => o.t != t;
}
