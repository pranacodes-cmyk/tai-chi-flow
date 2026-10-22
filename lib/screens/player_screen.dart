import 'dart:async';
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
import '../widgets/demo_film.dart';
import '../widgets/scaffold.dart';
import '../widgets/sheet.dart';
import '../widgets/ui.dart';
import 'plan_detail_screen.dart';

enum _Phase { ready, work, rest }

const _readySec = 3.0;

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.sessionId});
  final String sessionId;
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Session? session = resolveSession(widget.sessionId);
  late final AppState app = context.read<AppState>();
  _Phase phase = _Phase.ready;
  int index = 0;
  double remaining = _readySec;
  bool running = true;
  double elapsed = 0, work = 0;
  bool spokeHalf = false, finished = false;
  int stepIdx = 0;
  Timer? _tick;
  DateTime _last = DateTime.now();

  List<SessionItem> get items => session!.items;
  Exercise get current => Content.i.exercise(items[index].e)!;
  Exercise? get nextEx =>
      index + 1 < items.length ? Content.i.exercise(items[index + 1].e) : null;
  String get affirmation =>
      Content.i.affirmations[(index * 7 + widget.sessionId.length) %
          Content.i.affirmations.length];

  /// The line shown (and spoken) right now: the active instruction step, or the affirmation itself.
  String _guidance(Exercise e) {
    if (e.isAffirmation) return e.description;
    if (e.steps.isEmpty) return e.cue;
    return e.steps[stepIdx.clamp(0, e.steps.length - 1)];
  }

  @override
  void initState() {
    super.initState();
    if (session == null) return;
    WakelockPlus.enable();
    Sfx.play('sfx-bell-start', 0.6);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _say(CoachLines.begin(Content.i.exercise(items[0].e)!));
    });
    _syncMusic();
    _start();
  }

  @override
  void dispose() {
    _tick?.cancel();
    Voice.stop();
    Ambient.stop();
    WakelockPlus.disable();
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

  void _onTick() {
    if (!running || finished) return;
    final now = DateTime.now();
    final dt = now.difference(_last).inMicroseconds / 1e6;
    _last = now;
    final prev = remaining;
    final next = prev - dt;
    if (phase != _Phase.ready) elapsed += dt;
    if (phase == _Phase.work) work += dt;
    bool crossed(double n) => prev > n && next <= n;
    if (app.audio.beeps && (crossed(3) || crossed(2) || crossed(1))) {
      Sfx.play('sfx-tick', 0.5);
    }
    if (phase == _Phase.work) {
      final ex = current;
      final len = items[index].s;
      if (!ex.isAffirmation && ex.steps.length > 1) {
        // walk through the real instructions, one step per equal slice of the movement
        final k = ((len - next) / (len / ex.steps.length)).floor().clamp(
          0,
          ex.steps.length - 1,
        );
        if (k != stepIdx) {
          stepIdx = k;
          _say(CoachLines.step(ex, k), interrupt: false);
        }
      } else if (!spokeHalf && len >= 40 && next <= len / 2) {
        spokeHalf = true;
        _say(CoachLines.halfway(ex, affirmation), interrupt: false);
      }
    }
    setState(() => remaining = next);
    if (next <= 0) {
      switch (phase) {
        case _Phase.ready:
          _startWork(0);
        case _Phase.work:
          _advance();
        case _Phase.rest:
          _startWork(index + 1);
      }
    }
  }

  void _startWork(int i) {
    final ex = Content.i.exercise(items[i].e)!;
    setState(() {
      index = i;
      phase = _Phase.work;
      remaining = items[i].s.toDouble();
      spokeHalf = false;
      stepIdx = 0;
    });
    Sfx.play('sfx-chime', 0.45);
    Haptics.medium();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _say(CoachLines.start(ex));
    });
  }

  void _advance() {
    if (index >= items.length - 1) {
      _finish();
      return;
    }
    if (session!.restSec > 0) {
      setState(() {
        phase = _Phase.rest;
        remaining = session!.restSec.toDouble();
      });
      Sfx.play('sfx-chime', 0.35);
      _say(CoachLines.rest(Content.i.exercise(items[index + 1].e)!));
    } else {
      _startWork(index + 1);
    }
  }

  void _finish() {
    if (finished) return;
    finished = true;
    _tick?.cancel();
    setState(() => running = false);
    Sfx.play('sfx-bell-end', 0.7);
    _say(CoachLines.finish());
    final s = session!;
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
      if (!running) Voice.stop();
    });
    _last = DateTime.now();
    _syncMusic();
  }

  void _skipNext() {
    if (index >= items.length - 1) {
      _finish();
      return;
    }
    _startWork(index + 1);
    if (!running) _togglePlay();
  }

  void _skipPrev() {
    final spent = items[index].s - remaining;
    if (phase == _Phase.work && spent > 3) {
      _startWork(index);
    } else {
      _startWork(math.max(0, index - 1));
    }
    if (!running) _togglePlay();
  }

  Future<void> _exit() async {
    final wasRunning = running;
    if (wasRunning) _togglePlay();
    final pctDone =
        ((index + (phase == _Phase.work ? _progress : 0)) / items.length * 100)
            .round();
    final leave = await showEnsoSheet<bool>(
      context,
      dark: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Column(
            children: [
              Text('Leave this session?', style: T.displayMd.c(C.ivory)),
              const SizedBox(height: 8),
              Text(
                "You're $pctDone% through. Progress for this session won't be saved.",
                textAlign: TextAlign.center,
                style: T.bodySm.c(C.ivory.withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 24),
              EnsoButton(
                label: 'Keep practicing',
                variant: BtnVariant.ivory,
                onTap: () => Navigator.pop(ctx, false),
              ),
              const SizedBox(height: 8),
              Pressable(
                onTap: () => Navigator.pop(ctx, true),
                child: SizedBox(
                  height: 48,
                  child: Center(
                    child: Text('End session', style: T.label.c(C.terracotta)),
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

  double get _phaseTotal => phase == _Phase.ready
      ? _readySec
      : (phase == _Phase.rest
            ? session!.restSec.toDouble()
            : items[index].s.toDouble());
  double get _progress =>
      (1 - math.max(0, remaining) / _phaseTotal).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    if (session == null) return const NotFoundView();
    final shown = phase == _Phase.rest && nextEx != null ? nextEx! : current;
    final shownPhase =
        items[phase == _Phase.rest && nextEx != null ? index + 1 : index].p;
    final top = topInset(context);
    final bottom = bottomInset(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: EnsoScaffold(
        background: C.forest,
        lightIcons: true,
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, top + 4, 16, 8),
              child: Row(
                children: [
                  CircleBtn(
                    icon: LucideIcons.x,
                    tone: Tone.dark,
                    onTap: _exit,
                    label: 'Close',
                  ),
                  Expanded(
                    child: Text(
                      phase == _Phase.rest
                          ? 'Rest · next movement'
                          : phase == _Phase.ready
                          ? 'Get ready'
                          : '${index + 1} / ${items.length}',
                      textAlign: TextAlign.center,
                      style: T.caption.c(C.ivory.withValues(alpha: 0.7)),
                    ),
                  ),
                  CircleBtn(
                    icon: LucideIcons.slidersHorizontal,
                    tone: Tone.dark,
                    onTap: _settings,
                    label: 'Audio settings',
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
                    key: ValueKey(shown.id),
                    exercise: shown,
                    contain: true,
                    playing: running,
                    alignment: Alignment.center,
                  ),
                  if (phase != _Phase.work)
                    ColoredBox(
                      color: C.forest.withValues(alpha: 0.4),
                      child: Center(
                        child: Text(
                          '${math.max(1, remaining.ceil())}',
                          style: T.displayXl
                              .copyWith(fontSize: 64, color: C.ivory)
                              .tab,
                        ),
                      ),
                    ),
                  if (shown.isAffirmation && phase == _Phase.work)
                    Container(
                      color: C.forest.withValues(alpha: 0.6),
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: Text(
                        shown.description,
                        textAlign: TextAlign.center,
                        style: T.serifAccent.copyWith(
                          fontSize: 26,
                          color: C.ivory,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, bottom + 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (shownPhase != null) ...[
                    Eyebrow(shownPhase, color: C.sage),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    shown.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: T.title.copyWith(fontSize: 24, color: C.ivory),
                  ),
                  Container(
                    constraints: const BoxConstraints(minHeight: 72),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    child: Center(
                      child: Text(
                        phase == _Phase.rest
                            ? 'Breathe and prepare for the next movement.'
                            : _guidance(shown),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: T.bodySm.copyWith(
                          color: C.ivory.withValues(alpha: 0.65),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    formatClock(remaining),
                    style: T.displayMd
                        .copyWith(fontSize: 32, color: C.ivory)
                        .tab,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CircleBtn(
                        icon: Icons.skip_previous_rounded,
                        tone: Tone.dark,
                        size: 48,
                        iconSize: 26,
                        onTap: _skipPrev,
                        label: 'Previous',
                      ),
                      Pressable(
                        onTap: _togglePlay,
                        semanticLabel: running ? 'Pause' : 'Play',
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: C.ivory,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            running
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 34,
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
                        label: 'Next',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value:
                          (index +
                              (phase == _Phase.work
                                  ? _progress
                                  : phase == _Phase.rest
                                  ? 1
                                  : 0)) /
                          items.length,
                      minHeight: 2,
                      backgroundColor: C.ivory.withValues(alpha: 0.15),
                      color: C.sage,
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
            child: Text('Sound', style: T.title.c(C.ivory)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              toggle(
                a.voice ? LucideIcons.mic : LucideIcons.micOff,
                'Voice ${a.voice ? 'on' : 'off'}',
                a.voice,
                () => app.setAudio((x) => x.voice = !x.voice),
              ),
              const SizedBox(width: 12),
              toggle(
                LucideIcons.music2,
                'Music ${a.music ? 'on' : 'off'}',
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
              'Soundscape',
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
              for (final s in Content.i.soundscapes)
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
                        color: a.musicTrack == s.id
                            ? C.ivory
                            : Colors.transparent,
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
              'Music volume',
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
