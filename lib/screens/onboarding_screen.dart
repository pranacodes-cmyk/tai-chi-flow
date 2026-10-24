import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../logic/coach.dart';
import '../logic/logic.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/ruler_picker.dart';
import '../widgets/onboarding_experience.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';

const _sections = ['About you', 'Your goals', 'Your body', 'Your routine'];

/// Soft music under the quiz; the coach's voice ducks it automatically (web `ONB_TRACK`).
const _onbTrack = 'music-bamboo';
const _onbVolume = 0.22;

/// How long a reply stays when the coach isn't speaking it (web `REPLY_MS`).
const _replyMs = 4000;
const _replyMaxMs = 8000;
const _replyMinMs = 3000;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int index = 0;
  int direction = 1;
  List<OnbStep> get steps => Content.i.onboarding;

  // sound: soft music + the coach's voice, one toggle for both
  bool sound = true;

  // chapter cards: shown once, when moving forward into a new section
  final _seenChapters = <String>{};
  bool chapterOpen = false;

  // the coach's reply after a pick
  ({String text, bool voiced})? reply;
  bool _advancing = false;
  VoidCallback? _finishReply;
  final _timers = <Timer>[];
  /// Finishing forward keeps the music playing through plan-ready and the paywall.
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    Ambient.play(_onbTrack, _onbVolume);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onStep());
  }

  @override
  void dispose() {
    _clearTimers();
    Voice.stop();
    if (!_finished) Ambient.stop();
    super.dispose();
  }

  void _later(VoidCallback fn, int ms) {
    _timers.add(Timer(Duration(milliseconds: ms), fn));
  }

  void _clearTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  bool _speak(List<String> lines, {VoidCallback? onDone}) {
    if (!sound || lines.isEmpty) return false;
    Voice.say(lines, onDone: onDone);
    return true;
  }

  void _toggleSound() {
    setState(() => sound = !sound);
    if (sound) {
      Ambient.play(_onbTrack, _onbVolume);
    } else {
      Voice.stop();
      Ambient.pause();
    }
  }

  OnbChapter? get _chapter => Content.i.chapter(steps[index].section);

  /// Runs after every step change (web: the effect keyed on the step index).
  void _onStep() {
    if (!mounted) return;
    _clearTimers();
    _advancing = false;
    _finishReply = null;
    final step = steps[index];
    final first = steps.indexWhere((s) => s.section == step.section) == index;
    final ch = _chapter;
    final open =
        direction > 0 &&
        first &&
        ch != null &&
        !_seenChapters.contains(ch.section);
    setState(() {
      reply = null;
      if (open) chapterOpen = true;
    });
    if (open) {
      _seenChapters.add(ch.section);
      _speak(CoachLines.onbChapter(ch));
    }
  }

  void _closeChapter() {
    final ch = _chapter;
    setState(() => chapterOpen = false);
    if (ch != null && ch.breath) _speak(CoachLines.onbArrived());
  }

  void _onBreath(BreathPhase phase) {
    if (phase == BreathPhase.inhale) {
      _speak(CoachLines.onbBreath(CoachBreath.inhale));
    }
    if (phase == BreathPhase.exhale) {
      _speak(CoachLines.onbBreath(CoachBreath.exhale));
    }
  }

  /// A single answer was picked: show the coach's reply (if any), then move on.
  void _onPicked(OnbOption? option) {
    if (_advancing) return;
    _advancing = true;
    Haptics.light();
    final text = option?.reply;
    if (text == null || text.isEmpty) {
      _later(next, 420);
      return;
    }
    _later(() {
      if (!mounted) return;
      final started = DateTime.now();
      var done = false;
      void finish() {
        if (done || !mounted) return;
        done = true;
        _finishReply = null;
        setState(() => reply = null);
        next();
      }

      _finishReply = finish;
      final voiced = _speak(
        CoachLines.onbReply(option!),
        onDone: () {
          final spent = DateTime.now().difference(started).inMilliseconds;
          _later(finish, math.max(250, _replyMinMs - spent));
        },
      );
      setState(() => reply = (text: text, voiced: voiced));
      _later(finish, voiced ? _replyMaxMs : _replyMs);
    }, 300);
  }

  void _skipReply() {
    Voice.stop();
    _finishReply?.call();
  }

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
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    if (index < steps.length - 1) {
      setState(() {
        direction = 1;
        index++;
      });
      _onStep();
    } else {
      _finished = true;
      context.go('/plan-ready');
    }
  }

  void back() {
    FocusScope.of(context).unfocus();
    // the reply overlay owns the screen until it finishes
    if (reply != null) return;
    if (chapterOpen) {
      _closeChapter();
      return;
    }
    if (index == 0) {
      context.go('/welcome');
    } else {
      setState(() {
        direction = -1;
        index--;
      });
      _onStep();
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
        body: Stack(
          children: [
            const Positioned.fill(child: AmbientGlow()),
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, top + 10, 20, 0),
                  child: Row(
                    children: [
                      CircleBtn(
                        icon: LucideIcons.chevronLeft,
                        onTap: back,
                        label: 'Back',
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            for (var i = 0; i < _sections.length; i++) ...[
                              if (i > 0) const SizedBox(width: 6),
                              Expanded(
                                child: Bar(
                                  value: i < sectionIdx
                                      ? 1
                                      : (i > sectionIdx
                                            ? 0
                                            : (inSection + 1) /
                                                  sectionSteps.length),
                                  height: 5,
                                  gradient: G.jade,
                                  track: C.sandDeep.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SoundToggle(on: sound, onToggle: _toggleSound),
                    ],
                  ),
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
                        builder: (_, c) => Opacity(
                          opacity: anim.value,
                          child: Transform.translate(
                            offset: Offset(dx * (1 - anim.value), 0),
                            child: c,
                          ),
                        ),
                        child: child,
                      );
                    },
                    child: SingleChildScrollView(
                      key: ValueKey(step.id),
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Eyebrow(step.section, color: C.jade),
                          const SizedBox(height: 10),
                          Text(
                            step.title,
                            style:
                                step.type == 'name' &&
                                    MediaQuery.viewInsetsOf(context).bottom > 0
                                ? T.displayMd
                                : T.displayLg,
                          ),
                          if (step.subtitle != null &&
                              step.type != 'info' &&
                              step.type != 'insight') ...[
                            const SizedBox(height: 10),
                            Text(step.subtitle!, style: T.body.c(C.muted)),
                          ],
                          if (step.video != null) ...[
                            const SizedBox(height: 20),
                            StepFilm(film: step.video!),
                          ],
                          SizedBox(height: step.video != null ? 16 : 28),
                          _StepBody(
                            step: step,
                            onAdvance: next,
                            onPicked: _onPicked,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (showCta)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      12,
                      24,
                      bottomInset(context) + 16,
                    ),
                    child: EnsoButton(
                      label: step.type == 'name'
                          ? 'Create my plan'
                          : 'Continue',
                      onTap: valid ? next : null,
                    ),
                  ),
              ],
            ),
            if (reply != null)
              Positioned.fill(
                child: CoachReply(
                  key: ValueKey(reply!.text),
                  text: reply!.text,
                  voiced: reply!.voiced,
                  onSkip: _skipReply,
                ),
              ),
            if (chapterOpen && _chapter != null)
              Positioned.fill(
                child: ChapterCard(
                  key: ValueKey(_chapter!.section),
                  chapter: _chapter!,
                  number: _sections.indexOf(_chapter!.section) + 1,
                  total: _sections.length,
                  onDone: _closeChapter,
                  onBreath: _onBreath,
                  sound: sound,
                  onToggleSound: _toggleSound,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.step,
    required this.onAdvance,
    required this.onPicked,
  });
  final OnbStep step;
  final VoidCallback onAdvance;

  /// A single answer was picked: the screen shows the coach's reply (if any), then moves on.
  final ValueChanged<OnbOption?> onPicked;

  void _pick(VoidCallback apply, String id) {
    apply();
    onPicked(step.options.where((o) => o.id == id).firstOrNull);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.profile;
    switch (step.type) {
      case 'single':
        if (step.id == 'gender') {
          return _GenderCards(
            step: step,
            value: p.gender,
            onPick: (v) => _pick(() => app.setProfile((x) => x.gender = v), v),
          );
        }
        if (step.id == 'ageGroup') {
          return _AgeGrid(
            step: step,
            gender: p.gender,
            value: p.ageGroup,
            onPick: (v) =>
                _pick(() => app.setProfile((x) => x.ageGroup = v), v),
          );
        }
        return _SingleList(
          step: step,
          value: p.getString(step.id),
          onPick: (v) =>
              _pick(() => app.setProfile((x) => _setString(x, step.id, v)), v),
        );
      case 'multi':
        return _MultiGrid(
          step: step,
          value: p.getList(step.id),
          exclusive: step.id == 'limitations' ? 'none' : null,
          onChanged: (v) => app.setProfile((x) => _setList(x, step.id, v)),
        );
      case 'info':
        return _ProofCard(step: step);
      case 'insight':
        return _InsightCard(step: step, profile: p);
      case 'body':
        return _BodyGrid(
          step: step,
          gender: p.gender,
          value: p.bodyType,
          onPick: (v) => app.setProfile((x) => x.bodyType = v),
        );
      case 'zones':
        return _Zones(
          step: step,
          gender: p.gender,
          value: p.zones,
          onChanged: (v) => app.setProfile((x) => x.zones = v),
        );
      case 'height':
        return const _HeightStep();
      case 'weight':
        return const _WeightStep(target: false);
      case 'targetWeight':
        return const _WeightStep(target: true);
      case 'slider':
        return _StressScale(
          value: p.stress,
          onChanged: (v) => app.setProfile((x) => x.stress = v),
        );
      case 'time':
        return _TimeGrid(
          step: step,
          value: '${p.dailyMinutes}',
          onPick: (v) => _pick(
            () => app.setProfile((x) => x.dailyMinutes = int.parse(v)),
            v,
          ),
        );
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

BoxDecoration _optionDeco(bool on, {double radius = 24}) => BoxDecoration(
  color: on ? C.jadeSoft : C.ivory,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: on ? C.jade : Colors.transparent, width: 2),
  boxShadow: on ? null : S.soft,
);

class _SingleList extends StatelessWidget {
  const _SingleList({
    required this.step,
    required this.value,
    required this.onPick,
  });
  final OnbStep step;
  final String value;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                  child: Row(
                    children: [
                      if (o.image != null) ...[
                        AnimatedScale(
                          scale: value == o.id ? 1.05 : 1,
                          duration: const Duration(milliseconds: 300),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: EImage(
                                img(o.image!),
                                alignment: const Alignment(0, -0.4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ] else if (o.icon != null) ...[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: value == o.id ? C.jade : C.sand,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ContentIcon(
                            o.icon,
                            size: 22,
                            color: value == o.id ? C.ivory : C.jadeDeep,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              o.label,
                              style: T.label.copyWith(fontSize: 17),
                            ),
                            if (o.description != null) ...[
                              const SizedBox(height: 2),
                              Text(o.description!, style: T.caption.s(14)),
                            ],
                          ],
                        ),
                      ),
                      OptionCheck(value == o.id),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GenderCards extends StatelessWidget {
  const _GenderCards({
    required this.step,
    required this.value,
    required this.onPick,
  });
  final OnbStep step;
  final String value;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) {
    final photo = step.options.where((o) => o.image != null).toList();
    final other = step.options.where((o) => o.image == null).firstOrNull;
    return Column(
      children: [
        Row(
          children: [
            for (final (i, o) in photo.indexed) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: Reveal(
                  delay: 0.12 + 0.05 * i,
                  dy: 14,
                  child: Pressable(
                    onTap: () => onPick(o.id),
                    semanticLabel: o.label,
                    child: PhotoFrame(
                      selected: value == o.id,
                      radius: 30,
                      child: SizedBox(
                        height: 286,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AnimatedScale(
                              scale: value == o.id ? 1.04 : 1,
                              duration: const Duration(milliseconds: 700),
                              curve: kEase,
                              child: EImage(img(o.image!)),
                            ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0x00111A15),
                                    Color(0x00111A15),
                                    Color(0xB3111A15),
                                  ],
                                  stops: [0, 0.5, 1],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 10,
                              right: 10,
                              bottom: 10,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 44,
                                ),
                                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                                decoration: BoxDecoration(
                                  color: C.ivory.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        o.label,
                                        softWrap: true,
                                        style: T.label.copyWith(
                                          fontSize: 16,
                                          height: 1.2,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    OptionCheck(value == o.id),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (other != null) ...[
          const SizedBox(height: 16),
          Reveal(
            delay: 0.22,
            dy: 12,
            child: Pressable(
              onTap: () => onPick(other.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == other.id ? C.jadeSoft : C.ivory,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: value == other.id ? C.jade : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: value == other.id ? null : S.soft,
                ),
                child: Text(
                  other.label,
                  style: T.label.copyWith(
                    color: value == other.id
                        ? C.jadeDeep
                        : C.ink.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Reveal(
          delay: 0.27,
          dy: 10,
          child: Text(
            'Join members of every age, shape and fitness level.',
            textAlign: TextAlign.center,
            style: T.caption,
          ),
        ),
      ],
    );
  }
}

class _AgeGrid extends StatelessWidget {
  const _AgeGrid({
    required this.step,
    required this.gender,
    required this.value,
    required this.onPick,
  });
  final OnbStep step;
  final String gender;
  final String value;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.72,
      children: [
        for (final (i, o) in step.options.indexed)
          Reveal(
            delay: 0.12 + 0.05 * i,
            dy: 14,
            child: Pressable(
              onTap: () => onPick(o.id),
              semanticLabel: o.label,
              child: PhotoFrame(
                selected: value == o.id,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (o.image != null)
                      AnimatedScale(
                        scale: value == o.id ? 1.05 : 1,
                        duration: const Duration(milliseconds: 700),
                        curve: kEase,
                        child: EImage(img(onbImage(o.image!, gender))),
                      ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x00111A15),
                            Color(0x00111A15),
                            Color(0xD1111A15),
                          ],
                          stops: [0, 0.38, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: OptionCheck(value == o.id),
                    ),
                    Positioned(
                      left: 16,
                      right: 12,
                      bottom: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              o.label,
                              style: T.displayLg.copyWith(
                                fontSize: 28,
                                height: 1,
                                color: C.ivory,
                                letterSpacing: -0.9,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            o.description ?? '',
                            softWrap: true,
                            style: T.tiny.copyWith(
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                              color: C.ivory.withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MultiGrid extends StatelessWidget {
  const _MultiGrid({
    required this.step,
    required this.value,
    required this.onChanged,
    this.exclusive,
  });
  final OnbStep step;
  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  final String? exclusive;

  void _toggle(String id) {
    if (exclusive != null && id == exclusive) {
      onChanged(value.contains(id) ? [] : [id]);
      return;
    }
    final base = exclusive != null
        ? value.where((v) => v != exclusive).toList()
        : [...value];
    onChanged(
      base.contains(id) ? base.where((v) => v != id).toList() : [...base, id],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: value.contains(o.id) ? C.jade : C.sand,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ContentIcon(
                                  o.icon,
                                  size: 20,
                                  color: value.contains(o.id)
                                      ? C.ivory
                                      : C.jadeDeep,
                                ),
                              ),
                              const Spacer(),
                              OptionCheck(value.contains(o.id)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(o.label, style: T.label.copyWith(height: 1.2)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ProofCard extends StatelessWidget {
  const _ProofCard({required this.step});
  final OnbStep step;
  @override
  Widget build(BuildContext context) {
    final t = Content.i.testimonials.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Reveal(
          delay: 0.12,
          dy: 14,
          child: Container(
            height: 268,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: S.card,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                KenBurns(child: EImage(img(step.image ?? 'onb-proof'))),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00111A15),
                        Color(0x00111A15),
                        Color(0xD9111A15),
                      ],
                      stops: [0, 0.35, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.stat ?? '',
                        style: T.displayXl.copyWith(
                          fontSize: 52,
                          height: 1,
                          color: C.ivory,
                          letterSpacing: -2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        step.statLabel ?? '',
                        style: T.bodySm.copyWith(
                          color: C.ivory.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Reveal(
          delay: 0.17,
          dy: 12,
          child: Text(
            step.subtitle ?? '',
            style: T.body.copyWith(color: C.ink.withValues(alpha: 0.75)),
          ),
        ),
        const SizedBox(height: 20),
        Reveal(
          delay: 0.22,
          dy: 12,
          child: ECard(
            radius: 26,
            padding: const EdgeInsets.all(16),
            shadow: S.soft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Avatar(t.avatar ?? 'onb-age-f-50', size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.name,
                            style: T.label.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Stars(size: 13),
                        ],
                      ),
                    ),
                    const Icon(LucideIcons.quote, size: 24, color: C.sandDeep),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '“${t.text}”',
                  style: T.bodySm.copyWith(color: C.ink.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Reveal(
          delay: 0.27,
          dy: 12,
          child: Row(
            children: [
              for (final (i, s) in const [
                ('Balance', 'steadier'),
                ('10 min', 'a day'),
                ('0', 'equipment'),
              ].indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: C.ivory,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: S.soft,
                    ),
                    child: Column(
                      children: [
                        Text(s.$1, style: T.title.c(C.jadeDeep)),
                        const SizedBox(height: 2),
                        Text(
                          s.$2,
                          textAlign: TextAlign.center,
                          style: T.tiny.w(FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

const _zoneCopy = {
  'neck': 'Neck & shoulder release in every session',
  'back': 'Spine-friendly twists and gentle back mobility',
  'arms': 'Flowing arm work for tone and circulation',
  'core': 'Deep breathing that quietly strengthens your core',
  'hips': 'Hip openers to ease stiffness',
  'legs': 'Rooted stances for stronger legs and knees',
};

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.step, required this.profile});
  final OnbStep step;
  final Profile profile;
  @override
  Widget build(BuildContext context) {
    final bullets = <String>[
      ...profile.zones.take(2).map((z) => _zoneCopy[z]).whereType<String>(),
      profile.limitations.any((l) => l != 'none')
          ? 'Joint-safe options for the areas you flagged'
          : 'Low-impact flows that are kind to your joints',
      'Breath-led pacing that lowers stress as you move',
    ].take(3).toList();
    Widget legend(Color c, String l) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(l, style: T.tiny.copyWith(fontSize: 11)),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Reveal(
          delay: 0.12,
          dy: 14,
          child: ECard(
            padding: const EdgeInsets.all(20),
            shadow: S.card,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Balance & mobility', style: T.title)),
                    legend(C.jade, 'With TaiChi Flow'),
                    const SizedBox(width: 12),
                    legend(C.sandDeep, 'Without'),
                  ],
                ),
                const SizedBox(height: 16),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1800),
                  curve: kEase,
                  builder: (_, t, _) => AspectRatio(
                    aspectRatio: 2,
                    child: CustomPaint(painter: _InsightPainter(t)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final l in const ['Today', 'Week 2', 'Week 4'])
                      Text(l, style: T.tiny.copyWith(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Reveal(
          delay: 0.17,
          dy: 12,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: G.jade,
              borderRadius: BorderRadius.circular(26),
              boxShadow: S.glow,
            ),
            child: Row(
              children: [
                Text(
                  step.stat ?? '',
                  style: T.displayMd.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: C.ivory,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    step.statLabel ?? '',
                    style: T.caption.copyWith(
                      fontSize: 14,
                      height: 1.35,
                      color: C.ivory.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Reveal(
          delay: 0.22,
          dy: 12,
          child: Text(
            step.subtitle ?? '',
            style: T.body.copyWith(color: C.ink.withValues(alpha: 0.75)),
          ),
        ),
        const SizedBox(height: 16),
        for (final (i, b) in bullets.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Reveal(
              delay: 0.27 + 0.05 * i,
              dy: 12,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: C.ivory,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: S.soft,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: C.jadeSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.check,
                        size: 16,
                        color: C.jadeDeep,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(b, style: T.label.copyWith(height: 1.3)),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// "With TaiChi Flow" vs "Without" curves; mirrors the web insight chart (viewBox 300x150).
class _InsightPainter extends CustomPainter {
  _InsightPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 300, sy = size.height / 150;
    Offset o(double x, double y) => Offset(x * sx, y * sy);
    final grid = Paint()
      ..color = C.line
      ..strokeWidth = 1;
    for (final y in [30.0, 75.0, 120.0]) {
      for (double x = 0; x < 300; x += 8) {
        canvas.drawLine(o(x, y), o(x + 3, y), grid);
      }
    }
    final without = Path()
      ..moveTo(8 * sx, 112 * sy)
      ..cubicTo(70 * sx, 110 * sy, 120 * sx, 112 * sy, 170 * sx, 108 * sy)
      ..cubicTo(220 * sx, 104 * sy, 260 * sx, 104 * sy, 292 * sx, 102 * sy);
    final withFlow = Path()
      ..moveTo(8 * sx, 112 * sy)
      ..cubicTo(60 * sx, 108 * sy, 90 * sx, 92 * sy, 140 * sx, 70 * sy)
      ..cubicTo(190 * sx, 48 * sy, 230 * sx, 30 * sy, 292 * sx, 22 * sy);
    final p1 = (t / 0.8).clamp(0.0, 1.0);
    // dotted "without" line
    final dot = Paint()
      ..color = C.sandDeep
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final m in without.computeMetrics()) {
      for (double d = 0; d < m.length * p1; d += 9) {
        canvas.drawPath(
          m.extractPath(d, math.min(d + 2, m.length)),
          dot..style = PaintingStyle.stroke,
        );
      }
    }
    // area under the TaiChi Flow curve
    if (t > 0.5) {
      final area = Path.from(withFlow)
        ..lineTo(292 * sx, size.height)
        ..lineTo(8 * sx, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              C.jade.withValues(alpha: 0.28 * ((t - 0.5) / 0.5)),
              C.jade.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      );
    }
    final line = Paint()
      ..color = C.jade
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final m in withFlow.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * p1), line);
    }
    if (t > 0.85) {
      final k = ((t - 0.85) / 0.15).clamp(0.0, 1.0);
      canvas.drawCircle(
        o(292, 22),
        11 * k,
        Paint()..color = C.jade.withValues(alpha: 0.18),
      );
      canvas.drawCircle(o(292, 22), 6 * k, Paint()..color = C.jade);
      canvas.drawCircle(
        o(292, 22),
        6 * k,
        Paint()
          ..color = C.ivory
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _InsightPainter old) => old.t != t;
}

class _BodyGrid extends StatelessWidget {
  const _BodyGrid({
    required this.step,
    required this.gender,
    required this.value,
    required this.onPick,
  });
  final OnbStep step;
  final String gender;
  final String value;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.64,
      children: [
        for (final (i, o) in step.options.indexed)
          Reveal(
            delay: 0.12 + 0.05 * i,
            dy: 14,
            child: Pressable(
              onTap: () => onPick(o.id),
              semanticLabel: o.label,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: value == o.id ? C.jadeSoft : C.ivory,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: value == o.id ? C.jade : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: value == o.id ? null : S.soft,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(21),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: C.sand,
                              child: o.image == null
                                  ? null
                                  : EImage(
                                      img(onbImage(o.image!, gender)),
                                      alignment: const Alignment(0, -0.2),
                                    ),
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: OptionCheck(value == o.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
                      child: Text(
                        onbLabel(o.label, o.labelM, gender),
                        style: T.label.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Hotspot positions (fractions of the 2:3 body photo) — same as web.
const _hotspots = <String, List<(double, double)>>{
  'neck': [(0.5, 0.2)],
  'back': [(0.5, 0.31)],
  'arms': [(0.3, 0.38), (0.7, 0.38)],
  'core': [(0.5, 0.43)],
  'hips': [(0.4, 0.53), (0.6, 0.53)],
  'legs': [(0.43, 0.73), (0.57, 0.73)],
};

class _Zones extends StatelessWidget {
  const _Zones({
    required this.step,
    required this.gender,
    required this.value,
    required this.onChanged,
  });
  final OnbStep step;
  final String gender;
  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  void _toggle(String id) => onChanged(
    value.contains(id) ? value.where((v) => v != id).toList() : [...value, id],
  );
  @override
  Widget build(BuildContext context) {
    const h = 380.0;
    const photoW = h * 2 / 3;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Reveal(
          delay: 0.12,
          dy: 14,
          child: Container(
            height: h,
            width: (MediaQuery.sizeOf(context).width - 48) * 0.46,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: C.sand,
              borderRadius: BorderRadius.circular(28),
              boxShadow: S.soft,
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.hardEdge,
              children: [
                OverflowBox(
                  maxWidth: photoW,
                  minWidth: photoW,
                  child: SizedBox(
                    width: photoW,
                    height: h,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: EImage(
                            img(
                              onbImage(
                                step.image ?? 'onb-body-{g}-average',
                                gender,
                              ),
                            ),
                            alignment: Alignment.center,
                          ),
                        ),
                        for (final e in _hotspots.entries)
                          for (final (x, y) in e.value)
                            Positioned(
                              left: x * photoW - 22,
                              top: y * h - 22,
                              child: _Hotspot(
                                on: value.contains(e.key),
                                onTap: () => _toggle(e.key),
                                label: e.key,
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 64,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            C.sand.withValues(alpha: 0.8),
                            C.sand.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            children: [
              for (final (i, o) in step.options.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Reveal(
                    delay: 0.15 + 0.05 * i,
                    dy: 12,
                    child: Pressable(
                      onTap: () => _toggle(o.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        constraints: const BoxConstraints(minHeight: 52),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: value.contains(o.id) ? G.jade : null,
                          color: value.contains(o.id) ? null : C.ivory,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: value.contains(o.id) ? S.glow : S.soft,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                o.label,
                                style: T.label.copyWith(
                                  fontSize: 14,
                                  height: 1.2,
                                  color: value.contains(o.id) ? C.ivory : C.ink,
                                ),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: value.contains(o.id)
                                    ? C.ivory.withValues(alpha: 0.25)
                                    : Colors.transparent,
                                border: value.contains(o.id)
                                    ? null
                                    : Border.all(
                                        color: C.ink.withValues(alpha: 0.12),
                                        width: 2,
                                      ),
                              ),
                              child: value.contains(o.id)
                                  ? const Icon(
                                      LucideIcons.check,
                                      size: 12,
                                      color: C.ivory,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hotspot extends StatefulWidget {
  const _Hotspot({required this.on, required this.onTap, required this.label});
  final bool on;
  final VoidCallback onTap;
  final String label;
  @override
  State<_Hotspot> createState() => _HotspotState();
}

class _HotspotState extends State<_Hotspot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: widget.onTap,
      semanticLabel: widget.label,
      scale: 0.9,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.on)
              AnimatedBuilder(
                animation: _c,
                builder: (_, _) => Transform.scale(
                  scale: 0.6 + _c.value * 0.8,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: C.jade.withValues(alpha: 0.5 * (1 - _c.value)),
                    ),
                  ),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: widget.on ? 20 : 14,
              height: widget.on ? 20 : 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.on ? C.jade : C.ivory.withValues(alpha: 0.7),
                border: Border.all(color: C.ivory, width: 2.5),
                boxShadow: S.soft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: C.sand,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options)
              Pressable(
                onTap: () => onChanged(o.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == o.$1 ? C.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    o.$2,
                    style: T.label.copyWith(
                      fontSize: 14,
                      color: value == o.$1
                          ? C.ivory
                          : C.ink.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
          ],
        ),
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
      child: Column(
        children: [
          _UnitToggle(
            value: p.units,
            options: const [('metric', 'cm'), ('imperial', 'ft / in')],
            onChanged: (v) => app.setProfile((x) => x.units = v),
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                imperial ? '${fi.ft}′${fi.inch}″' : '${p.heightCm.round()}',
                style: T.displayXl.copyWith(fontSize: 72).tab,
              ),
              if (!imperial) ...[
                const SizedBox(width: 8),
                Text(
                  'cm',
                  style: T.title.copyWith(
                    fontSize: 20,
                    color: C.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),
          RulerPicker(
            key: ValueKey('h-${p.units}'),
            min: imperial ? 48 : 120,
            max: imperial ? 90 : 230,
            majorEvery: imperial ? 12 : 10,
            value: imperial ? inches : p.heightCm.round(),
            onChanged: (v) => app.setProfile(
              (x) => x.heightCm = imperial
                  ? (v * 2.54).roundToDouble()
                  : v.toDouble(),
            ),
          ),
        ],
      ),
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
      if (p.targetWeightKg > p.weightKg + 20 ||
          p.targetWeightKg < p.weightKg * 0.6 ||
          p.targetWeightKg == 66) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => app.setProfile(
            (x) => x.targetWeightKg = (p.weightKg * 0.93).roundToDouble(),
          ),
        );
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
    String fmt(double v) =>
        v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          _UnitToggle(
            value: p.units,
            options: const [('metric', 'kg'), ('imperial', 'lb')],
            onChanged: (v) => app.setProfile((x) => x.units = v),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$display', style: T.displayXl.copyWith(fontSize: 72).tab),
              const SizedBox(width: 8),
              Text(
                imperial ? 'lb' : 'kg',
                style: T.title.copyWith(
                  fontSize: 20,
                  color: C.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
              decoration: BoxDecoration(
                color: C.ivory,
                borderRadius: BorderRadius.circular(24),
                boxShadow: S.soft,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (diff > 0) ...[
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text:
                                'Lose ${imperial ? '${kgToLb(diff)} lb' : '${fmt(diff)} kg'} ',
                          ),
                          TextSpan(
                            text: '· $pct% of your weight',
                            style: T.title.c(C.muted),
                          ),
                        ],
                      ),
                      style: T.title,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pct <= 10
                          ? 'A realistic, healthy target. Gentle daily movement gets you there.'
                          : "An ambitious goal — we'll build up gradually and safely.",
                      style: T.caption.copyWith(fontSize: 14, height: 1.5),
                    ),
                  ] else ...[
                    Text('Maintain & tone', style: T.title),
                    const SizedBox(height: 6),
                    Text(
                      "We'll focus on strength, balance and flexibility while you hold your weight.",
                      style: T.caption.copyWith(fontSize: 14, height: 1.5),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Pill('BMI $currentBmi', C.sand, C.ink),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('→', style: TextStyle(color: C.muted)),
                      ),
                      _Pill('BMI $targetBmi', C.jadeSoft, C.jadeDeep),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
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
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(99),
    ),
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
      decoration: BoxDecoration(
        color: C.ivory,
        borderRadius: BorderRadius.circular(24),
        boxShadow: S.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Your BMI', style: T.title)),
              Text('$value', style: T.displayMd.tab),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              return SizedBox(
                height: 20,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(
                          colors: [C.sage, C.jade, C.gold, C.terracotta],
                          stops: [0, 0.35, 0.62, 1],
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutBack,
                      left: pos * c.maxWidth - 10,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: C.ink,
                          shape: BoxShape.circle,
                          border: Border.all(color: C.ivory, width: 3),
                          boxShadow: S.soft,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final l in const ['Under', 'Healthy', 'Over', 'Obese'])
                Text(
                  l,
                  style: T.tiny.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$cat. ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: C.ink,
                  ),
                ),
                TextSpan(text: copy[cat]),
              ],
            ),
            style: T.caption.s(14),
          ),
        ],
      ),
    );
  }
}

const _stressCopy = [
  'Wonderfully calm',
  'Mostly calm',
  'A little stressed',
  'Quite stressed',
  'Overwhelmed',
];
const _stressHelp = [
  "We'll keep your practice light and joyful.",
  'Regular flow will help you stay grounded.',
  'Breath-led qigong will help release tension.',
  "We'll add calming breathwork to every session.",
  "We'll start with soothing, slow sessions to help you reset.",
];

/// Seconds per breath of the orb: slow and easy when calm, quick when overwhelmed (web `stressBreath`).
const _stressBreath = [8.0, 6.5, 5.0, 3.6, 2.6];
const _stressIcon = ['smile', 'smile', 'meh', 'frown', 'cloud-sun'];
const _stressHalo = [
  C.jadeSoft,
  C.jadeSoft,
  C.goldSoft,
  C.terracottaSoft,
  C.terracottaSoft,
];
const _stressCore = [G.jade, G.jade, G.gold, G.ember, G.ember];

class _StressScale extends StatefulWidget {
  const _StressScale({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;
  @override
  State<_StressScale> createState() => _StressScaleState();
}

class _StressScaleState extends State<_StressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: _half(widget.value),
  )..repeat(reverse: true);

  static Duration _half(int v) =>
      Duration(milliseconds: (_stressBreath[v - 1] * 500).round());

  @override
  void didUpdateWidget(covariant _StressScale old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _breath.duration = _half(widget.value);
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final onChanged = widget.onChanged;
    final halo = _stressHalo[value - 1];
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          // the orb breathes faster and warms in colour as stress rises
          SizedBox(
            width: 144,
            height: 144,
            child: AnimatedBuilder(
              animation: _breath,
              builder: (_, child) {
                final t = Curves.easeInOut.transform(_breath.value);
                final s = 0.86 + 0.22 * t;
                final s2 =
                    0.86 +
                    0.22 *
                        Curves.easeInOut.transform(
                          (_breath.value + 0.15).clamp(0.0, 1.0),
                        );
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: s,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 700),
                        decoration: BoxDecoration(
                          color: halo,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: s2,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 700),
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: halo.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    child!,
                  ],
                );
              },
              child: TweenAnimationBuilder<double>(
                key: ValueKey(value),
                tween: Tween(begin: 0.7, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                builder: (_, s, child) =>
                    Transform.scale(scale: s, child: child),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: _stressCore[value - 1],
                    shape: BoxShape.circle,
                    boxShadow: S.glow,
                  ),
                  alignment: Alignment.center,
                  child: ContentIcon(
                    _stressIcon[value - 1],
                    size: 40,
                    color: C.ivory,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(_stressCopy[value - 1], style: T.displayMd),
          const SizedBox(height: 8),
          // two lines reserved so the buttons never jump between answers
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Text(
              _stressHelp[value - 1],
              textAlign: TextAlign.center,
              style: T.bodySm.c(C.muted),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              for (var v = 1; v <= 5; v++) ...[
                if (v > 1) const SizedBox(width: 8),
                Expanded(
                  child: Pressable(
                    onTap: () => onChanged(v),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: v == value ? C.ink : C.ivory,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: v == value ? null : S.soft,
                      ),
                      child: Text(
                        '$v',
                        style: T.title.copyWith(
                          color: v == value ? C.ivory : C.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Calm', style: T.tiny.w(FontWeight.w500)),
              Text('Overwhelmed', style: T.tiny.w(FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeGrid extends StatelessWidget {
  const _TimeGrid({
    required this.step,
    required this.value,
    required this.onPick,
  });
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (o.id == '10')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: value == o.id
                            ? C.ivory.withValues(alpha: 0.2)
                            : C.goldSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        'Popular',
                        style: T.tiny.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: value == o.id ? C.ivory : C.ink,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    o.label,
                    style: T.displayLg.copyWith(
                      color: value == o.id ? C.ivory : C.ink,
                    ),
                  ),
                  Text(
                    o.description ?? '',
                    style: T.caption.copyWith(
                      color: value == o.id
                          ? C.ivory.withValues(alpha: 0.8)
                          : C.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

const dayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

({String time, String ampm}) formatTime(int h, int m) => (
  time: '${h % 12 == 0 ? 12 : h % 12}:${m.toString().padLeft(2, '0')}',
  ampm: h >= 12 ? 'PM' : 'AM',
);

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

    const presets = [
      ('Morning', 7, 30),
      ('Midday', 12, 30),
      ('Evening', 19, 0),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: C.ivory,
            borderRadius: BorderRadius.circular(28),
            boxShadow: S.soft,
          ),
          child: Row(
            children: [
              CircleBtn(
                icon: LucideIcons.minus,
                tone: Tone.sand,
                size: 48,
                onTap: () => shift(-15),
                label: 'Earlier',
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(t.time, style: T.displayXl.copyWith(fontSize: 52).tab),
                    const SizedBox(width: 6),
                    Text(
                      t.ampm,
                      style: T.title.copyWith(
                        color: C.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              CircleBtn(
                icon: LucideIcons.plus,
                tone: Tone.sand,
                size: 48,
                onTap: () => shift(15),
                label: 'Later',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
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
                      color: r.hour == pr.$2 && r.minute == pr.$3
                          ? C.ink
                          : C.ivory,
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: r.hour == pr.$2 && r.minute == pr.$3
                          ? null
                          : S.soft,
                    ),
                    child: Text(
                      pr.$1,
                      style: T.label.copyWith(
                        fontSize: 14,
                        color: r.hour == pr.$2 && r.minute == pr.$3
                            ? C.ivory
                            : C.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Repeat on',
          style: T.caption.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        _DayPicker(
          days: r.days,
          onChanged: (d) => app.setReminders((x) => x.days = d),
          offColor: C.ivory,
        ),
        const SizedBox(height: 28),
        _NotificationPreview(
          name: '',
          minutes: app.profile.dailyMinutes,
          time: 'now',
        ),
        const SizedBox(height: 32),
        EnsoButton(
          label: 'Remind me daily',
          onTap: () async {
            app.setReminders((x) => x.enabled = true);
            onDone();
            await NotificationService.requestPermission();
            await NotificationService.schedule(
              app.reminders,
              name: app.profile.name,
              minutes: app.profile.dailyMinutes,
            );
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
      ],
    );
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({
    super.key,
    required this.days,
    required this.onChanged,
    required this.offColor,
  });
  final List<int> days;
  final ValueChanged<List<int>> onChanged;
  final Color offColor;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: Pressable(
            onTap: () => onChanged(
              days.contains(i)
                  ? days.where((x) => x != i).toList()
                  : ([...days, i]..sort()),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: days.contains(i) ? C.jade : offColor,
                shape: BoxShape.circle,
                boxShadow: days.contains(i) || offColor == C.sand
                    ? null
                    : S.soft,
              ),
              child: Text(
                dayLetters[i],
                style: T.label.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: days.contains(i)
                      ? C.ivory
                      : C.ink.withValues(alpha: 0.6),
                ),
              ),
            ),
          )))),
      ],
    );
  }
}

class DayPicker extends _DayPicker {
  const DayPicker({
    super.key,
    required super.days,
    required super.onChanged,
    super.offColor = C.sand,
  });
}

class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview({
    super.key,
    required this.name,
    required this.minutes,
    required this.time,
  });
  final String name;
  final int minutes;
  final String time;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.ink.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        boxShadow: S.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: C.jade,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(LucideIcons.bell, size: 12, color: C.ivory),
              ),
              const SizedBox(width: 8),
              Text(
                'TaiChi Flow · $time',
                style: T.tiny.copyWith(color: C.ivory.withValues(alpha: 0.6)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${name.isNotEmpty ? '$name, your' : 'Your'} $minutes-minute practice is ready 🌿',
            style: T.label.c(C.ivory),
          ),
          const SizedBox(height: 2),
          Text(
            'A few mindful minutes for balance and calm.',
            style: T.caption.c(C.ivory.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

class NotificationPreview extends _NotificationPreview {
  const NotificationPreview({
    super.key,
    required super.name,
    required super.minutes,
    required super.time,
  });
}

class _NameStep extends StatefulWidget {
  const _NameStep({required this.onSubmit});
  final VoidCallback onSubmit;
  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  late final TextEditingController _ctrl = TextEditingController(
    text: context.read<AppState>().profile.name,
  );
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _focus.requestFocus();
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 250),
          );
        }
      });
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
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final initial = app.profile.name.trim().isEmpty
        ? '✿'
        : app.profile.name.trim()[0].toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: keyboard ? 56 : 96,
            height: keyboard ? 56 : 96,
            decoration: BoxDecoration(
              gradient: G.jade,
              shape: BoxShape.circle,
              boxShadow: S.glow,
            ),
            alignment: Alignment.center,
            child: Text(initial, style: T.displayLg.c(C.ivory)),
          ),
          SizedBox(height: keyboard ? 16 : 32),
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: C.ivory,
              borderRadius: BorderRadius.circular(22),
              boxShadow: S.soft,
            ),
            alignment: Alignment.center,
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              maxLength: 24,
              textInputAction: TextInputAction.done,
              scrollPadding: const EdgeInsets.all(24),
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
        ],
      ),
    );
  }
}
