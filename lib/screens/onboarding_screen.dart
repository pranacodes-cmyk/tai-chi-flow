import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../logic/logic.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/figures.dart';
import '../widgets/ruler_picker.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';

const _sections = ['About you', 'Your goals', 'Your body', 'Your routine'];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int index = 0;
  int direction = 1;
  List<OnbStep> get steps => Content.i.onboarding;

  bool _valid(OnbStep step, Profile p) {
    switch (step.type) {
      case 'single':
        return p.getString(step.id).isNotEmpty;
      case 'multi':
      case 'zones':
        return p.getList(step.id).isNotEmpty;
      case 'body':
        return p.bodyType.isNotEmpty;
      case 'name':
        return p.name.trim().isNotEmpty;
      default:
        return true;
    }
  }

  void next() {
    FocusScope.of(context).unfocus();
    if (index < steps.length - 1) {
      setState(() {
        direction = 1;
        index++;
      });
    } else {
      context.go('/plan-ready');
    }
  }

  void back() {
    FocusScope.of(context).unfocus();
    if (index == 0) {
      context.go('/welcome');
    } else {
      setState(() {
        direction = -1;
        index--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final step = steps[index];
    final profile = app.profile;
    final valid = _valid(step, profile);
    final sectionIdx = _sections.indexOf(step.section);
    final sectionSteps = steps.where((s) => s.section == step.section).toList();
    final inSection = sectionSteps.indexOf(step);
    final autoAdvance = step.type == 'single' || step.type == 'time';
    final showCta = !autoAdvance && step.type != 'reminder';
    final top = topInset(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: EnsoScaffold(
        body: Stack(children: [
          Column(children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, top + 10, 20, 0),
              child: Row(children: [
                CircleBtn(icon: LucideIcons.chevronLeft, onTap: back, label: 'Back'),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(children: [
                    for (var i = 0; i < _sections.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: Bar(
                          value: i < sectionIdx ? 1 : (i > sectionIdx ? 0 : (inSection + 1) / sectionSteps.length),
                          height: 6,
                        ),
                      ),
                    ],
                  ]),
                ),
                SizedBox(width: 44, child: Text('${index + 1}/${steps.length}', textAlign: TextAlign.right, style: T.caption.w(FontWeight.w600).tab)),
              ]),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                switchInCurve: kEase,
                switchOutCurve: kEase,
                transitionBuilder: (child, anim) {
                  final incoming = child.key == ValueKey(step.id);
                  final dx = (incoming ? 48.0 : -48.0) * direction;
                  return AnimatedBuilder(
                    animation: anim,
                    builder: (_, c) => Opacity(opacity: anim.value, child: Transform.translate(offset: Offset(dx * (1 - anim.value), 0), child: c)),
                    child: child,
                  );
                },
                child: SingleChildScrollView(
                  key: ValueKey(step.id),
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 150),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Eyebrow(step.section, color: C.jade),
                    const SizedBox(height: 10),
                    Text(step.title, style: T.displayLg),
                    if (step.subtitle != null && step.type != 'info') ...[
                      const SizedBox(height: 10),
                      Text(step.subtitle!, style: T.body.c(C.muted)),
                    ],
                    const SizedBox(height: 28),
                    _StepBody(step: step, onAdvance: next),
                  ]),
                ),
              ),
            ),
          ]),
          if (showCta)
            BottomCta(
              child: EnsoButton(
                label: step.type == 'name' ? 'Create my plan' : 'Continue',
                onTap: valid ? next : null,
              ),
            ),
        ]),
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({required this.step, required this.onAdvance});
  final OnbStep step;
  final VoidCallback onAdvance;

  void _pickAndGo(VoidCallback apply) {
    apply();
    Timer(const Duration(milliseconds: 380), onAdvance);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.profile;
    switch (step.type) {
      case 'single':
        if (step.id == 'ageGroup') {
          return _AgeGrid(step: step, value: p.ageGroup, onPick: (v) => _pickAndGo(() => app.setProfile((x) => x.ageGroup = v)));
        }
        return _SingleList(step: step, value: p.getString(step.id), onPick: (v) => _pickAndGo(() => app.setProfile((x) => _setString(x, step.id, v))));
      case 'multi':
        return _MultiGrid(
          step: step,
          value: p.getList(step.id),
          exclusive: step.id == 'limitations' ? 'none' : null,
          onChanged: (v) => app.setProfile((x) => _setList(x, step.id, v)),
        );
      case 'info':
        return _InfoCard(step: step);
      case 'body':
        return _BodyGrid(step: step, value: p.bodyType, onPick: (v) => app.setProfile((x) => x.bodyType = v));
      case 'zones':
        return _Zones(step: step, value: p.zones, onChanged: (v) => app.setProfile((x) => x.zones = v));
      case 'height':
        return const _HeightStep();
      case 'weight':
        return const _WeightStep(target: false);
      case 'targetWeight':
        return const _WeightStep(target: true);
      case 'slider':
        return _StressScale(value: p.stress, onChanged: (v) => app.setProfile((x) => x.stress = v));
      case 'time':
        return _TimeGrid(step: step, value: '${p.dailyMinutes}', onPick: (v) => _pickAndGo(() => app.setProfile((x) => x.dailyMinutes = int.parse(v))));
      case 'reminder':
        return _ReminderStep(onDone: onAdvance);
      case 'name':
        return _NameStep(onSubmit: onAdvance);
      default:
        return const SizedBox.shrink();
    }
  }
}

void _setString(Profile p, String field, String v) {
  switch (field) {
    case 'gender':
      p.gender = v;
    case 'ageGroup':
      p.ageGroup = v;
    case 'activity':
      p.activity = v;
    case 'flexibilityCheck':
      p.flexibilityCheck = v;
    case 'balanceCheck':
      p.balanceCheck = v;
    case 'style':
      p.style = v;
    case 'bodyType':
      p.bodyType = v;
  }
}

void _setList(Profile p, String field, List<String> v) {
  switch (field) {
    case 'goals':
      p.goals = v;
    case 'zones':
      p.zones = v;
    case 'limitations':
      p.limitations = v;
  }
}

class _OptionCheck extends StatelessWidget {
  const _OptionCheck(this.on);
  final bool on;
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? C.jade : Colors.transparent,
        border: Border.all(color: on ? C.jade : C.ink.withValues(alpha: 0.15), width: 2),
      ),
      child: on ? const Icon(LucideIcons.check, size: 14, color: C.ivory) : null,
    );
  }
}

BoxDecoration _optionDeco(bool on, {double radius = 24}) => BoxDecoration(
      color: on ? C.jadeSoft : C.ivory,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: on ? C.jade : Colors.transparent, width: 2),
      boxShadow: on ? null : S.soft,
    );

class _SingleList extends StatelessWidget {
  const _SingleList({required this.step, required this.value, required this.onPick});
  final OnbStep step;
  final String value;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (final (i, o) in step.options.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Reveal(
            delay: 0.05 * i,
            dy: 12,
            child: Pressable(
              onTap: () => onPick(o.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(14),
                decoration: _optionDeco(value == o.id),
                child: Row(children: [
                  if (o.icon != null) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: value == o.id ? C.jade : C.sand, borderRadius: BorderRadius.circular(16)),
                      child: ContentIcon(o.icon, size: 22, color: value == o.id ? C.ivory : C.jadeDeep),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(o.label, style: T.label.copyWith(fontSize: 17)),
                      if (o.description != null) ...[const SizedBox(height: 2), Text(o.description!, style: T.caption.s(14))],
                    ]),
                  ),
                  _OptionCheck(value == o.id),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}

class _AgeGrid extends StatelessWidget {
  const _AgeGrid({required this.step, required this.value, required this.onPick});
  final OnbStep step;
  final String value;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1 / 1.08,
      children: [
        for (final (i, o) in step.options.indexed)
          Reveal(
            delay: 0.06 * i,
            dy: 8,
            child: Pressable(
              onTap: () => onPick(o.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: value == o.id ? G.jade : null,
                  color: value == o.id ? null : C.ivory,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: value == o.id ? S.glow : S.soft,
                ),
                child: Stack(children: [
                  Positioned(
                    right: -24,
                    top: -24,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: value == o.id ? C.ivory.withValues(alpha: 0.1) : C.sand),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Opacity(opacity: 0.7, child: Eyebrow('Age', color: value == o.id ? C.ivory : C.ink)),
                      const Spacer(),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(o.label, style: T.displayLg.copyWith(fontSize: 36, color: value == o.id ? C.ivory : C.ink)),
                      ),
                      const SizedBox(height: 4),
                      Text(o.description ?? '', maxLines: 2, style: T.caption.copyWith(height: 1.3, color: value == o.id ? C.ivory.withValues(alpha: 0.8) : C.muted)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
      ],
    );
  }
}

class _MultiGrid extends StatelessWidget {
  const _MultiGrid({required this.step, required this.value, required this.onChanged, this.exclusive});
  final OnbStep step;
  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  final String? exclusive;

  void _toggle(String id) {
    if (exclusive != null && id == exclusive) {
      onChanged(value.contains(id) ? [] : [id]);
      return;
    }
    final base = exclusive != null ? value.where((v) => v != exclusive).toList() : [...value];
    onChanged(base.contains(id) ? base.where((v) => v != id).toList() : [...base, id]);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 12) / 2;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final (i, o) in step.options.indexed)
          SizedBox(
            width: w,
            child: Reveal(
              delay: 0.035 * i,
              dy: 12,
              child: Pressable(
                onTap: () => _toggle(o.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  constraints: const BoxConstraints(minHeight: 112),
                  padding: const EdgeInsets.all(14),
                  decoration: _optionDeco(value.contains(o.id)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: value.contains(o.id) ? C.jade : C.sand, borderRadius: BorderRadius.circular(14)),
                        child: ContentIcon(o.icon, size: 20, color: value.contains(o.id) ? C.ivory : C.jadeDeep),
                      ),
                      const Spacer(),
                      _OptionCheck(value.contains(o.id)),
                    ]),
                    const SizedBox(height: 12),
                    Text(o.label, style: T.label.copyWith(height: 1.2)),
                  ]),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.step});
  final OnbStep step;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        height: 300,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), boxShadow: S.card),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          KenBurns(child: EImage(img(step.image ?? 'hero-paywall'))),
          DecoratedBox(decoration: BoxDecoration(gradient: G.scrim)),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(step.stat ?? '', style: T.displayXl.copyWith(fontSize: 60, color: C.ivory)),
              const SizedBox(height: 4),
              Text('of members feel calmer after week one', style: T.bodySm.copyWith(color: C.ivory.withValues(alpha: 0.85), fontWeight: FontWeight.w500)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 24),
      Text(step.subtitle ?? '', style: T.body.copyWith(fontSize: 17, color: C.ink.withValues(alpha: 0.8))),
      const SizedBox(height: 24),
      Row(children: [
        for (final (i, s) in const [('50%', 'better balance'), ('12 wk', 'to transform'), ('10 min', 'a day')].indexed) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: C.ivory, borderRadius: BorderRadius.circular(22), boxShadow: S.soft),
              child: Column(children: [
                Text(s.$1, style: T.title.c(C.jadeDeep)),
                const SizedBox(height: 2),
                Text(s.$2, textAlign: TextAlign.center, style: T.tiny.w(FontWeight.w500)),
              ]),
            ),
          ),
        ],
      ]),
    ]);
  }
}

const _bodyWidths = {'slim': 0.82, 'average': 1.0, 'curvy': 1.18, 'plus': 1.36};

class _BodyGrid extends StatelessWidget {
  const _BodyGrid({required this.step, required this.value, required this.onPick});
  final OnbStep step;
  final String value;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.82,
      children: [
        for (final o in step.options)
          Pressable(
            onTap: () => onPick(o.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
              decoration: _optionDeco(value == o.id, radius: 28),
              child: Column(children: [
                Expanded(child: BodyFigure(width: _bodyWidths[o.id] ?? 1, active: value == o.id)),
                const SizedBox(height: 12),
                Text(o.label, style: T.label.s(16)),
              ]),
            ),
          ),
      ],
    );
  }
}

class _Zones extends StatelessWidget {
  const _Zones({required this.step, required this.value, required this.onChanged});
  final OnbStep step;
  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  void _toggle(String id) => onChanged(value.contains(id) ? value.where((v) => v != id).toList() : [...value, id]);
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        height: 340,
        width: (MediaQuery.sizeOf(context).width - 48) * 0.44,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.ivory, borderRadius: BorderRadius.circular(28), boxShadow: S.soft),
        child: ZonesFigure(selected: value, onToggle: _toggle),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(children: [
          for (final o in step.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Pressable(
                onTap: () => _toggle(o.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: value.contains(o.id) ? C.jade : C.ivory, borderRadius: BorderRadius.circular(18), boxShadow: value.contains(o.id) ? null : S.soft),
                  child: Row(children: [
                    Expanded(child: Text(o.label, style: T.label.copyWith(fontSize: 14, color: value.contains(o.id) ? C.ivory : C.ink))),
                    if (value.contains(o.id)) const Icon(LucideIcons.check, size: 16, color: C.ivory),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    ]);
  }
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({required this.value, required this.options, required this.onChanged});
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: C.sand, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final o in options)
            Pressable(
              onTap: () => onChanged(o.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: value == o.$1 ? C.ink : Colors.transparent, borderRadius: BorderRadius.circular(99)),
                child: Text(o.$2, style: T.label.copyWith(fontSize: 14, color: value == o.$1 ? C.ivory : C.ink.withValues(alpha: 0.7))),
              ),
            ),
        ]),
      ),
    );
  }
}

class _HeightStep extends StatelessWidget {
  const _HeightStep();
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.profile;
    final imperial = p.imperial;
    final inches = (p.heightCm / 2.54).round();
    final fi = cmToFtIn(p.heightCm);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(children: [
        _UnitToggle(value: p.units, options: const [('metric', 'cm'), ('imperial', 'ft / in')], onChanged: (v) => app.setProfile((x) => x.units = v)),
        const SizedBox(height: 48),
        Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(imperial ? '${fi.ft}′${fi.inch}″' : '${p.heightCm.round()}', style: T.displayXl.copyWith(fontSize: 72).tab),
          if (!imperial) ...[const SizedBox(width: 8), Text('cm', style: T.title.copyWith(fontSize: 20, color: C.muted, fontWeight: FontWeight.w600))],
        ]),
        const SizedBox(height: 32),
        RulerPicker(
          key: ValueKey('h-${p.units}'),
          min: imperial ? 48 : 120,
          max: imperial ? 90 : 230,
          majorEvery: imperial ? 12 : 10,
          value: imperial ? inches : p.heightCm.round(),
          onChanged: (v) => app.setProfile((x) => x.heightCm = imperial ? (v * 2.54).roundToDouble() : v.toDouble()),
        ),
      ]),
    );
  }
}

class _WeightStep extends StatefulWidget {
  const _WeightStep({required this.target});
  final bool target;
  @override
  State<_WeightStep> createState() => _WeightStepState();
}

class _WeightStepState extends State<_WeightStep> {
  @override
  void initState() {
    super.initState();
    if (widget.target) {
      final app = context.read<AppState>();
      final p = app.profile;
      if (p.targetWeightKg > p.weightKg + 20 || p.targetWeightKg < p.weightKg * 0.6 || p.targetWeightKg == 66) {
        WidgetsBinding.instance.addPostFrameCallback((_) => app.setProfile((x) => x.targetWeightKg = (p.weightKg * 0.93).roundToDouble()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.profile;
    final imperial = p.imperial;
    final kg = widget.target ? p.targetWeightKg : p.weightKg;
    final display = imperial ? kgToLb(kg) : kg.round();
    final currentBmi = bmi(p.heightCm, p.weightKg);
    final targetBmi = bmi(p.heightCm, p.targetWeightKg);
    final diff = ((p.weightKg - p.targetWeightKg) * 10).round() / 10;
    final pct = (diff.abs() / p.weightKg * 100).round();
    String fmt(double v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(children: [
        _UnitToggle(value: p.units, options: const [('metric', 'kg'), ('imperial', 'lb')], onChanged: (v) => app.setProfile((x) => x.units = v)),
        const SizedBox(height: 40),
        Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text('$display', style: T.displayXl.copyWith(fontSize: 72).tab),
          const SizedBox(width: 8),
          Text(imperial ? 'lb' : 'kg', style: T.title.copyWith(fontSize: 20, color: C.muted, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 24),
        RulerPicker(
          key: ValueKey('w-${widget.target}-${p.units}'),
          min: imperial ? 66 : 30,
          max: imperial ? 440 : 200,
          value: display,
          onChanged: (v) => app.setProfile((x) {
            final nv = imperial ? lbToKg(v) : v.toDouble();
            if (widget.target) {
              x.targetWeightKg = nv;
            } else {
              x.weightKg = nv;
            }
          }),
        ),
        const SizedBox(height: 24),
        if (!widget.target)
          _BmiCard(value: currentBmi)
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: C.ivory, borderRadius: BorderRadius.circular(24), boxShadow: S.soft),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (diff > 0) ...[
                Text.rich(TextSpan(children: [
                  TextSpan(text: 'Lose ${imperial ? '${kgToLb(diff)} lb' : '${fmt(diff)} kg'} '),
                  TextSpan(text: '· $pct% of your weight', style: T.title.c(C.muted)),
                ]), style: T.title),
                const SizedBox(height: 6),
                Text(
                  pct <= 10 ? 'A realistic, healthy target. Gentle daily movement gets you there.' : "An ambitious goal — we'll build up gradually and safely.",
                  style: T.caption.copyWith(fontSize: 14, height: 1.5),
                ),
              ] else ...[
                Text('Maintain & tone', style: T.title),
                const SizedBox(height: 6),
                Text("We'll focus on strength, balance and flexibility while you hold your weight.", style: T.caption.copyWith(fontSize: 14, height: 1.5)),
              ],
              const SizedBox(height: 16),
              Row(children: [
                _Pill('BMI $currentBmi', C.sand, C.ink),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('→', style: TextStyle(color: C.muted))),
                _Pill('BMI $targetBmi', C.jadeSoft, C.jadeDeep),
              ]),
            ]),
          ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.bg, this.fg);
  final String text;
  final Color bg, fg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: T.tiny.copyWith(fontSize: 13, color: fg)),
      );
}

class _BmiCard extends StatelessWidget {
  const _BmiCard({required this.value});
  final double value;
  static const copy = {
    'Underweight': "We'll focus on gentle strength and energy.",
    'Healthy': "Great range! We'll keep you strong and supple.",
    'Overweight': 'Low-impact movement is perfect for steady progress.',
    'Obese': 'Joint-friendly sessions will help you move with ease.',
  };
  @override
  Widget build(BuildContext context) {
    final cat = bmiCategory(value);
    final pos = ((value - 15) / (40 - 15)).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: C.ivory, borderRadius: BorderRadius.circular(24), boxShadow: S.soft),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text('Your BMI', style: T.title)), Text('$value', style: T.displayMd.tab)]),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          return SizedBox(
            height: 20,
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.centerLeft, children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(colors: [C.sage, C.jade, C.gold, C.terracotta], stops: [0, 0.35, 0.62, 1]),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutBack,
                left: pos * c.maxWidth - 10,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(color: C.ink, shape: BoxShape.circle, border: Border.all(color: C.ivory, width: 3), boxShadow: S.soft),
                ),
              ),
            ]),
          );
        }),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final l in const ['Under', 'Healthy', 'Over', 'Obese']) Text(l, style: T.tiny.copyWith(fontSize: 11, fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 12),
        Text.rich(TextSpan(children: [
          TextSpan(text: '$cat. ', style: const TextStyle(fontWeight: FontWeight.w600, color: C.ink)),
          TextSpan(text: copy[cat]),
        ]), style: T.caption.s(14)),
      ]),
    );
  }
}

const _stressCopy = ['Wonderfully calm', 'Mostly calm', 'A little stressed', 'Quite stressed', 'Overwhelmed'];
const _stressHelp = [
  "We'll keep your practice light and joyful.",
  'Regular flow will help you stay grounded.',
  'Breath-led qigong will help release tension.',
  "We'll add calming breathwork to every session.",
  "We'll start with soothing, slow sessions to help you reset.",
];

class _StressScale extends StatelessWidget {
  const _StressScale({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(children: [
        TweenAnimationBuilder<double>(
          key: ValueKey(value),
          tween: Tween(begin: 0.8, end: 1),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutBack,
          builder: (_, s, child) => Transform.scale(scale: s, child: child),
          child: Container(
            width: 112,
            height: 112,
            decoration: const BoxDecoration(color: C.jadeSoft, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$value', style: T.displayXl.c(C.jadeDeep)),
          ),
        ),
        const SizedBox(height: 20),
        Text(_stressCopy[value - 1], style: T.displayMd),
        const SizedBox(height: 8),
        Text(_stressHelp[value - 1], textAlign: TextAlign.center, style: T.bodySm.c(C.muted)),
        const SizedBox(height: 40),
        Row(children: [
          for (var v = 1; v <= 5; v++) ...[
            if (v > 1) const SizedBox(width: 8),
            Expanded(
              child: Pressable(
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: v == value ? C.ink : C.ivory, borderRadius: BorderRadius.circular(18), boxShadow: v == value ? null : S.soft),
                  child: Text('$v', style: T.title.copyWith(color: v == value ? C.ivory : C.ink)),
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Calm', style: T.tiny.w(FontWeight.w500)), Text('Overwhelmed', style: T.tiny.w(FontWeight.w500))]),
      ]),
    );
  }
}

class _TimeGrid extends StatelessWidget {
  const _TimeGrid({required this.step, required this.value, required this.onPick});
  final OnbStep step;
  final String value;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        for (final o in step.options)
          Pressable(
            onTap: () => onPick(o.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: value == o.id ? G.jade : null,
                color: value == o.id ? null : C.ivory,
                borderRadius: BorderRadius.circular(28),
                boxShadow: value == o.id ? S.glow : S.soft,
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (o.id == '10')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: value == o.id ? C.ivory.withValues(alpha: 0.2) : C.goldSoft, borderRadius: BorderRadius.circular(99)),
                    child: Text('Popular', style: T.tiny.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: value == o.id ? C.ivory : C.ink)),
                  ),
                const Spacer(),
                Text(o.label, style: T.displayLg.copyWith(color: value == o.id ? C.ivory : C.ink)),
                Text(o.description ?? '', style: T.caption.copyWith(color: value == o.id ? C.ivory.withValues(alpha: 0.8) : C.muted)),
              ]),
            ),
          ),
      ],
    );
  }
}

const dayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

({String time, String ampm}) formatTime(int h, int m) => (time: '${h % 12 == 0 ? 12 : h % 12}:${m.toString().padLeft(2, '0')}', ampm: h >= 12 ? 'PM' : 'AM');

class _ReminderStep extends StatelessWidget {
  const _ReminderStep({required this.onDone});
  final VoidCallback onDone;
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final r = app.reminders;
    final t = formatTime(r.hour, r.minute);
    void shift(int delta) {
      final total = (r.hour * 60 + r.minute + delta + 1440) % 1440;
      app.setReminders((x) {
        x.hour = total ~/ 60;
        x.minute = total % 60;
      });
    }

    const presets = [('Morning', 7, 30), ('Midday', 12, 30), ('Evening', 19, 0)];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.ivory, borderRadius: BorderRadius.circular(28), boxShadow: S.soft),
        child: Row(children: [
          CircleBtn(icon: LucideIcons.minus, tone: Tone.sand, size: 48, onTap: () => shift(-15), label: 'Earlier'),
          Expanded(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(t.time, style: T.displayXl.copyWith(fontSize: 52).tab),
              const SizedBox(width: 6),
              Text(t.ampm, style: T.title.copyWith(color: C.muted, fontWeight: FontWeight.w600)),
            ]),
          ),
          CircleBtn(icon: LucideIcons.plus, tone: Tone.sand, size: 48, onTap: () => shift(15), label: 'Later'),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        for (final (i, pr) in presets.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Pressable(
              onTap: () => app.setReminders((x) {
                x.hour = pr.$2;
                x.minute = pr.$3;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: r.hour == pr.$2 && r.minute == pr.$3 ? C.ink : C.ivory,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: r.hour == pr.$2 && r.minute == pr.$3 ? null : S.soft,
                ),
                child: Text(pr.$1, style: T.label.copyWith(fontSize: 14, color: r.hour == pr.$2 && r.minute == pr.$3 ? C.ivory : C.ink)),
              ),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 24),
      Text('Repeat on', style: T.caption.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      _DayPicker(days: r.days, onChanged: (d) => app.setReminders((x) => x.days = d), offColor: C.ivory),
      const SizedBox(height: 28),
      _NotificationPreview(name: '', minutes: app.profile.dailyMinutes, time: 'now'),
      const SizedBox(height: 32),
      EnsoButton(
        label: 'Remind me daily',
        onTap: () async {
          app.setReminders((x) => x.enabled = true);
          onDone();
          await NotificationService.requestPermission();
          await NotificationService.schedule(app.reminders, name: app.profile.name, minutes: app.profile.dailyMinutes);
        },
      ),
      const SizedBox(height: 8),
      EnsoButton(
        label: 'Not now',
        variant: BtnVariant.ghost,
        onTap: () {
          app.setReminders((x) => x.enabled = false);
          onDone();
        },
      ),
    ]);
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({super.key, required this.days, required this.onChanged, required this.offColor});
  final List<int> days;
  final ValueChanged<List<int>> onChanged;
  final Color offColor;
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      for (var i = 0; i < 7; i++)
        Pressable(
          onTap: () => onChanged(days.contains(i) ? days.where((x) => x != i).toList() : ([...days, i]..sort())),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: days.contains(i) ? C.jade : offColor, shape: BoxShape.circle, boxShadow: days.contains(i) || offColor == C.sand ? null : S.soft),
            child: Text(dayLetters[i], style: T.label.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: days.contains(i) ? C.ivory : C.ink.withValues(alpha: 0.6))),
          ),
        ),
    ]);
  }
}

class DayPicker extends _DayPicker {
  const DayPicker({super.key, required super.days, required super.onChanged, super.offColor = C.sand});
}

class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview({super.key, required this.name, required this.minutes, required this.time});
  final String name;
  final int minutes;
  final String time;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: C.ink.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(22), boxShadow: S.card),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(color: C.jade, borderRadius: BorderRadius.circular(6)),
            child: const Icon(LucideIcons.bell, size: 12, color: C.ivory),
          ),
          const SizedBox(width: 8),
          Text('Enso · $time', style: T.tiny.copyWith(color: C.ivory.withValues(alpha: 0.6))),
        ]),
        const SizedBox(height: 8),
        Text('${name.isNotEmpty ? '$name, your' : 'Your'} $minutes-minute practice is ready 🌿', style: T.label.c(C.ivory)),
        const SizedBox(height: 2),
        Text('A few mindful minutes for balance and calm.', style: T.caption.c(C.ivory.withValues(alpha: 0.7))),
      ]),
    );
  }
}

class NotificationPreview extends _NotificationPreview {
  const NotificationPreview({super.key, required super.name, required super.minutes, required super.time});
}

class _NameStep extends StatefulWidget {
  const _NameStep({required this.onSubmit});
  final VoidCallback onSubmit;
  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  late final TextEditingController _ctrl = TextEditingController(text: context.read<AppState>().profile.name);
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final initial = app.profile.name.trim().isEmpty ? '✿' : app.profile.name.trim()[0].toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(gradient: G.jade, shape: BoxShape.circle, boxShadow: S.glow),
          alignment: Alignment.center,
          child: Text(initial, style: T.displayLg.c(C.ivory)),
        ),
        const SizedBox(height: 32),
        Container(
          height: 64,
          decoration: BoxDecoration(color: C.ivory, borderRadius: BorderRadius.circular(22), boxShadow: S.soft),
          alignment: Alignment.center,
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            maxLength: 24,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.words,
            style: T.displayMd,
            cursorColor: C.jade,
            onChanged: (v) => app.setProfile((x) => x.name = v),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) widget.onSubmit();
            },
            decoration: InputDecoration(
              counterText: '',
              border: InputBorder.none,
              hintText: 'Your first name',
              hintStyle: T.displayMd.c(C.muted.withValues(alpha: 0.5)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text("We'll use it to cheer you on.", style: T.caption),
      ]),
    );
  }
}
