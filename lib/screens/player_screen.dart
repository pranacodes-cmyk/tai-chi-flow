import 'dart:async';
import '../services/analytics_service.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../logic/coach.dart';
import '../logic/logic.dart';
import '../services/audio_service.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/confetti.dart';
import '../widgets/demo_film.dart';
import '../widgets/scaffold.dart';
import '../widgets/sheet.dart';
import '../widgets/ui.dart';
import 'plan_detail_screen.dart';
import '../i18n/i18n.dart';

/// The lesson player (web `player.$sessionId.tsx`). Phases come from `firstPlayerStep` /
/// `nextPlayerStep` in logic: guided lessons open with the tutor's welcome and a calm check-in,
/// show a "watch first" demo before each practice, celebrate learned forms and skills, and close
/// with a second check-in and the tutor's congratulations; legacy lessons rest between movements.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.sessionId});
  final String sessionId;
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  // Minimised or screen locked: pause the practice (music, voice, film, timer);
  // the person resumes with play when they come back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (running) _togglePlay();
    }
  }

  late final Session? session = resolveSession(widget.sessionId);
  late final AppState app = context.read<AppState>();
  late PlayerStep step = firstPlayerStep(session!);
  double remaining = 0;
  bool running = true;
  double elapsed = 0, work = 0;
  bool spokeHalf = false, finished = false;
  int stepIdx = 0, cuesSpoken = 0;
  String? cueText;
  int? calmBefore, calmAfter, calmPick;
  int caption = 0;
  bool captionsDone = false;
  Timer? _tick, _captionTimer;
  DateTime _last = DateTime.now();

  /// Bumped on every phase change so delayed callbacks of an earlier phase do nothing.
  int _gen = 0;

  List<SessionItem> get items => session!.items;
  int get index => step.index;
  SessionItem get item => items[index];
  Exercise get current => Content.i.exercise(item.e)!;
  String get affirmation =>
      Content.i.affirmations[(index * 7 + widget.sessionId.length) %
          Content.i.affirmations.length];
  bool get _timed => step.seconds > 0;
  LessonTutor? get _tutor => step.phase == PlayerPhase.intro
      ? session!.intro
      : step.phase == PlayerPhase.outro
      ? session!.outro
      : null;

  /// The line shown right now: the latest timed cue, the active instruction step, or the affirmation.
  String _guidance(Exercise e) {
    if (e.isAffirmation) return e.description;
    switch (step.phase) {
      case PlayerPhase.rest:
        return tr('player.restGuidance');
      case PlayerPhase.watch:
        return (item.wl ?? '').trim().isNotEmpty ? item.wl! : e.cue;
      default:
        break;
    }
    if (item.c.isNotEmpty) return cueText ?? CoachLines.go(e, item).last;
    final lines = CoachLines.instructions(e, item);
    if (lines.isEmpty) return e.cue;
    return lines[stepIdx.clamp(0, lines.length - 1)];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (session == null) return;
    voiceVariant = session!.voice; // a course with its own coach (Master Wei) speaks in his voice
    WakelockPlus.enable();
    AnalyticsService.capture('lesson_started', {'session_id': widget.sessionId, 'items': items.length});
    Sfx.play('sfx-bell-start', 0.6);
    _syncMusic();
    _start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _enter(step, first: true);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _captionTimer?.cancel();
    // A finished session hands over to the completion screen while the
    // closing line is still playing; stopping here would cut it mid-word.
    if (!finished) Voice.stop();
    voiceVariant = null;
    Ambient.stop();
    WakelockPlus.disable();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _say(List<String> lines, {bool interrupt = true}) {
    if (app.audio.voice) {
      Voice.say(lines, interrupt: interrupt, rate: app.audio.voiceRate);
    }
  }

  void _syncMusic() {
    if (app.audio.music && running) {
      Ambient.play(app.audio.musicTrack, app.audio.musicVolume * 0.6);
    } else {
      Ambient.pause();
    }
  }

  void _start() {
    _tick?.cancel();
    _last = DateTime.now();
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) => _onTick());
  }

  // ------------------------------------------------------------ phases

  void _enter(PlayerStep next, {bool first = false}) {
    if (finished) return;
    if (next.phase == PlayerPhase.done) {
      _finish();
      return;
    }
    final gen = ++_gen;
    _captionTimer?.cancel();
    setState(() {
      step = next;
      remaining = next.seconds.toDouble();
      spokeHalf = false;
      stepIdx = 0;
      cuesSpoken = 0;
      cueText = null;
      caption = 0;
      captionsDone = false;
      calmPick = next.phase == PlayerPhase.checkAfter ? null : calmPick;
    });
    final ex = current;
    final delay = Duration(milliseconds: first ? 700 : 350);
    void later(List<String> lines) => Future.delayed(delay, () {
      if (mounted && gen == _gen) _say(lines);
    });
    switch (next.phase) {
      case PlayerPhase.intro:
      case PlayerPhase.outro:
        if (!first) Sfx.play('sfx-chime', 0.35);
        Future.delayed(delay, () {
          if (mounted && gen == _gen) _speakCaption(gen);
        });
      case PlayerPhase.checkBefore:
        later(CoachLines.checkIn(false));
      case PlayerPhase.checkAfter:
        Sfx.play('sfx-chime', 0.35);
        later(CoachLines.checkIn(true));
      case PlayerPhase.ready:
        later(CoachLines.begin(ex));
      case PlayerPhase.watch:
        Sfx.play('sfx-chime', 0.35);
        // the first demo of a lesson without a welcome opens with "Let's begin"
        later(index == 0 && session!.intro == null && (item.wl ?? '').isEmpty
            ? CoachLines.begin(ex)
            : CoachLines.watch(ex, item, announcesTurn(session!.items, next.index)));
      case PlayerPhase.work:
        Sfx.play('sfx-chime', 0.45);
        Haptics.medium();
        later(item.w != null
            ? CoachLines.go(ex, item, announcesTurn(session!.items, next.index))
            : CoachLines.start(ex, item));
      case PlayerPhase.rest:
        Sfx.play('sfx-chime', 0.35);
        _say(CoachLines.rest(ex));
      case PlayerPhase.unlock:
        Sfx.play('sfx-bell-end', 0.3);
        Haptics.medium();
        later(CoachLines.unlock(item.u!));
      case PlayerPhase.done:
        break;
    }
  }

  void _advance() => _enter(nextPlayerStep(session!, step));

  /// Tutor captions: each line is spoken in turn and the caption follows the voice; with the voice
  /// off (or if a line never reports back) the captions move on by reading time.
  void _speakCaption(int gen) {
    final t = _tutor;
    if (t == null || gen != _gen || !mounted) return;
    if (caption >= t.lines.length) {
      setState(() => captionsDone = true);
      return;
    }
    final line = t.lines[caption];
    var fired = false;
    void next() {
      if (fired || !mounted || gen != _gen || !running) return;
      fired = true;
      _captionTimer?.cancel();
      setState(() => caption++);
      _speakCaption(gen);
    }

    _captionTimer?.cancel();
    if (app.audio.voice) {
      Voice.say(
        [line],
        rate: app.audio.voiceRate,
        onDone: () => Future.delayed(const Duration(milliseconds: 380), next),
      );
      _captionTimer = Timer(Duration(milliseconds: line.length * 95 + 4000), next);
    } else {
      _captionTimer = Timer(Duration(milliseconds: line.length * 60 + 1500), next);
    }
  }

  void _onTick() {
    final now = DateTime.now();
    final dt = now.difference(_last).inMicroseconds / 1e6;
    _last = now;
    if (!running || finished || !_timed) return;
    final prev = remaining;
    final next = prev - dt;
    final phase = step.phase;
    if (phase == PlayerPhase.watch ||
        phase == PlayerPhase.work ||
        phase == PlayerPhase.rest ||
        phase == PlayerPhase.unlock) {
      elapsed += dt;
    }
    if (phase == PlayerPhase.work) work += dt;
    bool crossed(double n) => prev > n && next <= n;
    if (app.audio.beeps &&
        (phase == PlayerPhase.work || phase == PlayerPhase.rest || phase == PlayerPhase.ready) &&
        (crossed(3) || crossed(2) || crossed(1))) {
      Sfx.play('sfx-tick', 0.5);
    }
    if (phase == PlayerPhase.work) {
      final ex = current;
      final len = item.s;
      final spent = len - next;
      if (item.c.isNotEmpty) {
        final due = dueCues(item, spent, cuesSpoken);
        if (due.isNotEmpty) {
          cuesSpoken += due.length;
          cueText = due.last.l;
          _say(CoachLines.cue(due.last), interrupt: false);
        }
      } else {
        final lines = CoachLines.instructions(ex, item);
        if (!ex.isAffirmation && lines.length > 1) {
          // walk through the real instructions, one step per equal slice of the movement
          final k = (spent / (len / lines.length)).floor().clamp(0, lines.length - 1);
          if (k != stepIdx) {
            stepIdx = k;
            _say(CoachLines.step(ex, k, item), interrupt: false);
          }
        } else if (!spokeHalf && len >= 40 && next <= len / 2) {
          spokeHalf = true;
          _say(CoachLines.halfway(ex, affirmation), interrupt: false);
        }
      }
    }
    setState(() => remaining = next);
    if (next <= 0) _advance();
  }

  void _finish() {
    if (finished) return;
    finished = true;
    _tick?.cancel();
    _captionTimer?.cancel();
    setState(() => running = false);
    final s = session!;
    // Soft bell first, then the closing line once the strike has faded, so the ring never sits on
    // top of "Session complete"; the tutor's congratulations already closed a guided lesson.
    final speak = app.audio.voice && s.outro == null;
    final rate = app.audio.voiceRate;
    if (s.outro == null) {
      Sfx.play('sfx-bell-end', 0.35);
      Voice.stop();
    }
    Future.delayed(const Duration(milliseconds: 900), () {
      if (speak) Voice.say(CoachLines.finish(), rate: rate);
    });
    final totalWork = items.fold<int>(0, (a, it) => a + it.s);
    final ratio = math.min(1.0, work / math.max(1, totalWork));
    final entry = HistoryEntry(
      id: '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(1 << 30).toRadixString(36)}',
      sessionId: s.id,
      title: s.title,
      kind: 'workout',
      image: s.image,
      completedAt: DateTime.now(),
      durationSec: math.max(30, elapsed.round()),
      kcal: math.max(
        1,
        (kcalForWeight(s.baseKcal, app.profile.weightKg) * ratio).round(),
      ),
      planId: s.planId,
      day: s.day,
      calmBefore: calmBefore,
      calmAfter: calmAfter,
    );
    app.completeSession(entry);
    Ambient.stop();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) context.pushReplacement('/complete?id=${entry.id}');
    });
  }

  void _togglePlay() {
    Haptics.light();
    setState(() {
      running = !running;
      if (!running) {
        Voice.stop();
        _captionTimer?.cancel();
      }
    });
    _last = DateTime.now();
    _syncMusic();
    // resumed during the tutor's film: pick the captions up where they stopped
    if (running && _tutor != null && !captionsDone) _speakCaption(_gen);
  }

  void _skipNext() {
    if (!running) _togglePlay();
    _enter(skipPlayerStep(session!, step));
  }

  void _skipPrev() {
    final spent = item.s - remaining;
    if (step.phase == PlayerPhase.work && spent > 3) {
      _enter(stepEntry(session!, index));
    } else {
      _enter(stepEntry(session!, math.max(0, index - 1)));
    }
    if (!running) _togglePlay();
  }

  bool get _afterPractice =>
      step.phase == PlayerPhase.checkAfter || step.phase == PlayerPhase.outro;

  Future<void> _exit() async {
    // the practice is already done: closing now just saves it
    if (_afterPractice) {
      _finish();
      return;
    }
    final wasRunning = running;
    if (wasRunning) _togglePlay();
    final pctDone = (_sessionProgress * 100).round();
    final leave = await showEnsoSheet<bool>(
      context,
      dark: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Column(
            children: [
              Text(tr('player.leaveSessionTitle'), style: T.displayMd.c(C.ivory)),
              const SizedBox(height: 8),
              Text(
                tr('player.leaveSessionBody', {'pct': pctDone}),
                textAlign: TextAlign.center,
                style: T.bodySm.c(C.ivory.withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 24),
              EnsoButton(
                label: tr('player.keepPracticing'),
                variant: BtnVariant.ivory,
                onTap: () => Navigator.pop(ctx, false),
              ),
              const SizedBox(height: 8),
              Pressable(
                onTap: () => Navigator.pop(ctx, true),
                child: SizedBox(
                  height: 48,
                  child: Center(
                    child: Text(tr('player.endSession'), style: T.label.c(C.terracotta)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    if (leave == true) {
      Voice.stop();
      Ambient.stop();
      context.go('/');
    } else if (wasRunning && !running) {
      _togglePlay();
    }
  }

  void _settings() {
    showEnsoSheet<void>(
      context,
      dark: true,
      builder: (ctx) => _SoundSheet(onChange: _syncMusic),
    );
  }

  double get _progress =>
      _timed ? (1 - math.max(0, remaining) / step.seconds).clamp(0.0, 1.0) : 0;

  /// Share of the lesson done: steps before this one, plus this practice's progress.
  double get _sessionProgress {
    final n = items.length;
    final done = switch (step.phase) {
      PlayerPhase.intro || PlayerPhase.checkBefore => 0.0,
      PlayerPhase.checkAfter || PlayerPhase.outro || PlayerPhase.done => n.toDouble(),
      PlayerPhase.work => index + _progress,
      PlayerPhase.unlock => index + 1.0,
      _ => index.toDouble(),
    };
    return (done / n).clamp(0.0, 1.0);
  }

  void _pickCalm(int n) {
    Haptics.select();
    setState(() => calmPick = n);
  }

  void _confirmCalm({bool skip = false}) {
    if (step.phase == PlayerPhase.checkBefore) {
      calmBefore = skip ? null : calmPick;
    } else {
      calmAfter = skip ? null : calmPick;
    }
    Voice.stop();
    _advance();
  }

  @override
  Widget build(BuildContext context) {
    if (session == null) return const NotFoundView();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: EnsoScaffold(
        background: C.forest,
        lightIcons: true,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          child: KeyedSubtree(
            key: ValueKey(switch (step.phase) {
              PlayerPhase.intro => 'intro',
              PlayerPhase.outro => 'outro',
              PlayerPhase.checkBefore || PlayerPhase.checkAfter => 'check-${step.phase.name}',
              _ => 'practice',
            }),
            child: switch (step.phase) {
              PlayerPhase.intro || PlayerPhase.outro => _tutorView(context),
              PlayerPhase.checkBefore || PlayerPhase.checkAfter => _checkInView(context),
              _ => _practiceView(context),
            },
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ tutor film

  Widget _tutorView(BuildContext context) {
    final t = _tutor!;
    final intro = step.phase == PlayerPhase.intro;
    final day = session!.day ?? 1;
    final skills = intro ? newSkillItems(items) : const <SessionItem>[];
    final minutes = math.max(1, (totalSeconds(items, session!.restSec) / 60).round());
    final line = t.lines.isEmpty ? '' : t.lines[math.min(caption, t.lines.length - 1)];
    return Stack(
      fit: StackFit.expand,
      children: [
        DemoFilm.lesson(film: t.film, playing: running, alignment: const Alignment(0, -0.35)),
        const DecoratedBox(decoration: BoxDecoration(gradient: G.tutor)),
        Positioned(
          left: 16,
          right: 16,
          top: topInset(context) + 4,
          child: Row(
            children: [
              CircleBtn(icon: LucideIcons.x, tone: Tone.dark, onTap: _exit, label: tr('common.close')),
              const Spacer(),
              CircleBtn(
                icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                tone: Tone.dark,
                onTap: _togglePlay,
                label: running ? tr('common.pause') : tr('common.play'),
              ),
              const SizedBox(width: 8),
              CircleBtn(
                icon: LucideIcons.slidersHorizontal,
                tone: Tone.dark,
                onTap: _settings,
                label: tr('player.audioSettings'),
              ),
            ],
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: bottomInset(context) + 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(
                tr(intro ? 'player.welcomeEyebrow' : 'player.completeEyebrow', {'day': day}),
                color: C.sage,
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 96),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    line,
                    key: ValueKey(caption),
                    style: T.serifAccent.copyWith(fontSize: 28, height: 1.2, color: C.ivory),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var k = 0; k < t.lines.length; k++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 6),
                      width: k == caption ? 22 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: C.ivory.withValues(alpha: k <= caption ? 0.9 : 0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
              if (skills.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(tr('player.todayYoullLearn'), style: T.caption.c(C.ivory.withValues(alpha: 0.7))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in skills)
                      Glass(
                        radius: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Text(
                          s.t ?? Content.i.exercise(s.e)?.name ?? '',
                          style: T.label.s(14).c(C.ivory),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  tr('player.minutesWatchFirst', {'minutes': minutes}),
                  style: T.caption.c(C.ivory.withValues(alpha: 0.6)),
                ),
              ],
              const SizedBox(height: 20),
              EnsoButton(
                label: intro ? tr('player.imReady') : tr('common.continue'),
                variant: BtnVariant.ivory,
                onTap: () {
                  Voice.stop();
                  _advance();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ calm check-in

  Widget _checkInView(BuildContext context) {
    final after = step.phase == PlayerPhase.checkAfter;
    final pick = calmPick;
    return Container(
      decoration: const BoxDecoration(gradient: G.forest),
      padding: EdgeInsets.fromLTRB(24, topInset(context) + 4, 24, bottomInset(context) + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleBtn(icon: LucideIcons.x, tone: Tone.dark, onTap: _exit, label: tr('common.close')),
              const Spacer(),
            ],
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Eyebrow(tr(after ? 'player.checkInAgain' : 'player.checkInEyebrow'), color: C.sage),
                    const SizedBox(height: 12),
                    Text(
                      tr(after ? 'player.calmQuestionAfter' : 'player.calmQuestionBefore'),
                      textAlign: TextAlign.center,
                      style: T.displayMd.c(C.ivory),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('player.calmScale'),
                      textAlign: TextAlign.center,
                      style: T.caption.c(C.ivory.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 28),
                    Semantics(
                      label: tr('player.calmLabel'),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 12,
                        children: [
                          for (var n = 1; n <= 10; n++)
                            Pressable(
                              onTap: () => _pickCalm(n),
                              semanticLabel: '$n',
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                width: 52,
                                height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: pick == n ? C.ivory : C.ivory.withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: pick == n ? C.ivory : C.ivory.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Text(
                                  '$n',
                                  style: T.title.s(18).c(pick == n ? C.ink : C.ivory).tab,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 34,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          pick == null ? '' : tr(calmWordKey(pick)),
                          key: ValueKey(pick),
                          style: T.serifAccent.copyWith(fontSize: 24, color: C.sage),
                        ),
                      ),
                    ),
                    if (after && calmBefore != null) ...[
                      const SizedBox(height: 8),
                      Glass(
                        radius: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        child: Text(
                          tr('player.calmBeforeChip', {'n': calmBefore!}),
                          style: T.caption.c(C.ivory.withValues(alpha: 0.8)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          EnsoButton(
            label: tr(after ? 'player.calmSeeResults' : 'player.calmStart'),
            variant: BtnVariant.ivory,
            onTap: pick == null ? null : _confirmCalm,
          ),
          Pressable(
            onTap: () => _confirmCalm(skip: true),
            child: SizedBox(
              height: 48,
              child: Center(
                child: Text(tr('common.skip'), style: T.label.c(C.ivory.withValues(alpha: 0.7))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ practice

  Widget _practiceView(BuildContext context) {
    final phase = step.phase;
    final ex = current;
    final it = item;
    final top = topInset(context);
    final bottom = bottomInset(context);
    final counting = phase == PlayerPhase.ready || phase == PlayerPhase.rest;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, top + 4, 16, 8),
          child: Row(
            children: [
              CircleBtn(icon: LucideIcons.x, tone: Tone.dark, onTap: _exit, label: tr('common.close')),
              Expanded(
                child: Text(
                  switch (phase) {
                    PlayerPhase.rest => tr('player.restNextMovement'),
                    PlayerPhase.ready => tr('player.getReady'),
                    _ => tr('player.stepOfTotal', {'current': index + 1, 'total': items.length}),
                  },
                  textAlign: TextAlign.center,
                  style: T.caption.c(C.ivory.withValues(alpha: 0.7)),
                ),
              ),
              CircleBtn(
                icon: LucideIcons.slidersHorizontal,
                tone: Tone.dark,
                onTap: _settings,
                label: tr('player.audioSettings'),
              ),
            ],
          ),
        ),
        // The film takes every pixel the compact coaching block below doesn't need.
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              DemoFilm(
                key: ValueKey(it.f ?? ex.id),
                exercise: ex,
                film: it.f,
                contain: true,
                playing: running,
                alignment: Alignment.center,
              ),
              if (counting)
                ColoredBox(
                  color: C.forest.withValues(alpha: 0.4),
                  child: Center(
                    child: Text(
                      '${math.max(1, remaining.ceil())}',
                      style: T.displayXl.copyWith(fontSize: 64, color: C.ivory).tab,
                    ),
                  ),
                ),
              if (phase == PlayerPhase.watch) ...[
                Positioned(
                  left: 14,
                  top: 12,
                  child: Glass(
                    radius: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.eye, size: 15, color: C.ivory),
                        const SizedBox(width: 6),
                        Text(tr('player.watchFirst').toUpperCase(), style: T.eyebrow.c(C.ivory)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 8,
                  child: CircleBtn(
                    icon: Icons.skip_next_rounded,
                    tone: Tone.dark,
                    label: tr('player.skipDemo'),
                    size: 36,
                    iconSize: 18,
                    onTap: _skipNext,
                  ),
                ),

              ],
              if (phase == PlayerPhase.work && !ex.isAffirmation)
                Positioned(
                  key: ValueKey('turn-$index'),
                  left: 14,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: C.jade, borderRadius: BorderRadius.circular(40)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _PulseDot(),
                        const SizedBox(width: 6),
                        Text(
                          tr('coach.yourTurn').replaceAll(RegExp(r'[.。!！]$'), '').toUpperCase(),
                          style: T.eyebrow.c(C.ivory),
                        ),
                      ],
                    ),
                  ),
                ),
              if (it.lv != null && (phase == PlayerPhase.watch || phase == PlayerPhase.work))
                Positioned(
                  right: 14,
                  top: 12,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.45),
                    child: Glass(
                      radius: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Text(
                        tr('player.level', {'n': it.lv!.n, 'label': it.lv!.l}),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.tiny.copyWith(color: C.ivory, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              if (ex.isAffirmation && phase == PlayerPhase.work)
                Container(
                  color: C.forest.withValues(alpha: 0.6),
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Text(
                    ex.description,
                    textAlign: TextAlign.center,
                    style: T.serifAccent.copyWith(fontSize: 26, color: C.ivory),
                  ),
                ),
              if (phase == PlayerPhase.unlock && it.u != null) _UnlockCard(unlock: it.u!, onContinue: _advance),
            ],
          ),
        ),
        // Compact coaching block (Oct 29: ~40 px slimmer, so the film gains 10-15% on short phones).
        Padding(
          padding: EdgeInsets.fromLTRB(24, 10, 24, bottom + 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Always reserve the phase line so every course's film is the same height.
              Eyebrow(it.p ?? '\u00a0', color: C.sage),
              const SizedBox(height: 4),
              Text(
                it.t ?? ex.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: T.title.copyWith(fontSize: 22, color: C.ivory),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 72),
                padding: const EdgeInsets.symmetric(vertical: 4),
                alignment: Alignment.center,
                child: Text(
                  _guidance(ex),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: T.bodySm.copyWith(color: C.ivory.withValues(alpha: 0.65), height: 1.5),
                ),
              ),
              Text(
                formatClock(remaining),
                style: T.displayMd.copyWith(fontSize: 28, color: C.ivory).tab,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CircleBtn(
                    icon: Icons.skip_previous_rounded,
                    tone: Tone.dark,
                    size: 48,
                    iconSize: 26,
                    onTap: _skipPrev,
                    label: tr('player.previous'),
                  ),
                  Pressable(
                    onTap: _togglePlay,
                    semanticLabel: running ? tr('common.pause') : tr('common.play'),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(color: C.ivory, shape: BoxShape.circle),
                      child: Icon(
                        running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 30,
                        color: C.ink,
                      ),
                    ),
                  ),
                  CircleBtn(
                    icon: Icons.skip_next_rounded,
                    tone: Tone.dark,
                    size: 48,
                    iconSize: 26,
                    onTap: _skipNext,
                    label: tr('player.next'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: _sessionProgress,
                  minHeight: 2,
                  backgroundColor: C.ivory.withValues(alpha: 0.15),
                  color: C.sage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The celebration after a step (web `UnlockCard`): a learned form with its place in the 24,
/// a skill, or a linked sequence.
/// Softly pulsing ivory dot of the "Your turn" badge (web `animate-pulse`).
class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    final dot = Container(width: 8, height: 8, decoration: const BoxDecoration(color: C.ivory, shape: BoxShape.circle));
    if (still) return dot;
    return FadeTransition(opacity: Tween(begin: 0.45, end: 1.0).animate(_c), child: dot);
  }
}

class _UnlockCard extends StatelessWidget {
  const _UnlockCard({required this.unlock, required this.onContinue});
  final StepUnlock unlock;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final form = unlock.k == 'form' && unlock.n != null;
    final icon = switch (unlock.k) {
      'form' => LucideIcons.award,
      'sequence' => LucideIcons.link,
      _ => LucideIcons.sparkles,
    };
    final label = switch (unlock.k) {
      'form' => tr('player.unlockForm'),
      'sequence' => tr('player.unlockSequence'),
      _ => tr('player.unlockSkill'),
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: C.forest.withValues(alpha: 0.62)),
        const Positioned(left: 0, right: 0, top: 0, height: 320, child: Confetti(height: 320)),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 1),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 360),
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                decoration: BoxDecoration(
                  color: C.ivory,
                  borderRadius: BorderRadius.circular(R.lg),
                  boxShadow: S.float,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(gradient: G.gold, shape: BoxShape.circle),
                      child: Icon(icon, size: 26, color: C.ink),
                    ),
                    const SizedBox(height: 12),
                    Eyebrow(label, color: C.jade),
                    const SizedBox(height: 6),
                    Text(
                      unlock.t,
                      textAlign: TextAlign.center,
                      style: T.displayMd.c(C.ink),
                    ),
                    if (form) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          for (var k = 1; k <= 24; k++)
                            Expanded(
                              child: Container(
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: k <= unlock.n! ? C.jade : C.sand,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('player.formsOf24', {'n': unlock.n!}),
                        style: T.caption.copyWith(fontWeight: FontWeight.w600, color: C.jadeDeep),
                      ),
                    ],
                    const SizedBox(height: 16),
                    EnsoButton(label: tr('common.continue'), size: BtnSize.md, onTap: onContinue),
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

class _SoundSheet extends StatelessWidget {
  const _SoundSheet({required this.onChange});
  final VoidCallback onChange;
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final a = app.audio;
    Widget toggle(IconData icon, String label, bool on, VoidCallback onTap) =>
        Expanded(
          child: Pressable(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: on ? C.jade : C.ivory.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: C.ivory),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label, style: T.label.c(C.ivory))),
                ],
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(tr('player.sound'), style: T.title.c(C.ivory)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              toggle(
                a.voice ? LucideIcons.mic : LucideIcons.micOff,
                a.voice ? tr('player.voiceOn') : tr('player.voiceOff'),
                a.voice,
                () => app.setAudio((x) => x.voice = !x.voice),
              ),
              const SizedBox(width: 12),
              toggle(
                LucideIcons.music2,
                a.music ? tr('player.musicOn') : tr('player.musicOff'),
                a.music,
                () {
                  app.setAudio((x) => x.music = !x.music);
                  onChange();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              tr('player.soundscape'),
              style: T.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: C.ivory.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.35,
            children: [
              for (final s in Content.i.sounds)
                Pressable(
                  onTap: () {
                    app.setAudio((x) {
                      x.musicTrack = s.id;
                      x.music = true;
                    });
                    onChange();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: a.musicTrack == s.id ? C.ivory : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          EImage(img(s.image)),
                          Container(color: C.ink.withValues(alpha: 0.45)),
                          Positioned(
                            left: 10,
                            right: 8,
                            bottom: 8,
                            child: Text(
                              s.name,
                              style: T.tiny.copyWith(
                                fontWeight: FontWeight.w700,
                                color: C.ivory,
                                height: 1.1,
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
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              tr('player.musicVolume'),
              style: T.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: C.ivory.withValues(alpha: 0.6),
              ),
            ),
          ),
          Slider(
            value: a.musicVolume,
            onChanged: (v) {
              app.setAudio((x) => x.musicVolume = v);
              Ambient.setVolume(v * 0.6);
            },
            inactiveColor: C.ivory.withValues(alpha: 0.15),
          ),
        ],
      ),
    );
  }
}
