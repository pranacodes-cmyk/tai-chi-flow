import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../logic/logic.dart';
import '../services/audio_service.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
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
  Exercise? get nextEx => index + 1 < items.length ? Content.i.exercise(items[index + 1].e) : null;
  String get affirmation => Content.i.affirmations[(index * 7 + widget.sessionId.length) % Content.i.affirmations.length];

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
      if (mounted) _say("Let's begin. First, ${Content.i.exercise(items[0].e)!.name}.");
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

  void _say(String text) {
    if (app.audio.voice) Voice.speak(text, app.audio.voiceRate);
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
    if (app.audio.beeps && (crossed(3) || crossed(2) || crossed(1))) Sfx.play('sfx-tick', 0.5);
    if (phase == _Phase.work) {
      final ex = current;
      final len = items[index].s;
      if (!ex.isAffirmation && ex.steps.length > 1) {
        // walk through the real instructions, one step per equal slice of the movement
        final k = ((len - next) / (len / ex.steps.length)).floor().clamp(0, ex.steps.length - 1);
        if (k != stepIdx) {
          stepIdx = k;
          _say(ex.steps[k]);
        }
      } else if (!spokeHalf && len >= 40 && next <= len / 2) {
        spokeHalf = true;
        _say(ex.isAffirmation ? 'Once more. ${ex.cue.replaceFirst('Repeat after me: ', '')}' : affirmation);
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
      if (mounted) _say(ex.isAffirmation ? 'Spoken affirmation. ${ex.cue}' : '${ex.name}. ${ex.steps.isNotEmpty ? ex.steps.first : ex.cue}');
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
      _say('Rest. Up next, ${Content.i.exercise(items[index + 1].e)!.name}.');
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
    _say('Session complete. Beautifully done.');
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
      kcal: math.max(1, (kcalForWeight(s.baseKcal, app.profile.weightKg) * ratio).round()),
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
    final pctDone = ((index + (phase == _Phase.work ? _progress : 0)) / items.length * 100).round();
    final leave = await showEnsoSheet<bool>(context, dark: true, builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        child: Column(children: [
          Text('Leave this session?', style: T.displayMd.c(C.ivory)),
          const SizedBox(height: 8),
          Text("You're $pctDone% through. Progress for this session won't be saved.", textAlign: TextAlign.center, style: T.bodySm.c(C.ivory.withValues(alpha: 0.65))),
          const SizedBox(height: 24),
          EnsoButton(label: 'Keep practicing', variant: BtnVariant.ivory, onTap: () => Navigator.pop(ctx, false)),
          const SizedBox(height: 8),
          Pressable(
            onTap: () => Navigator.pop(ctx, true),
            child: SizedBox(height: 48, child: Center(child: Text('End session', style: T.label.c(C.terracotta)))),
          ),
        ]),
      );
    });
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
    showEnsoSheet<void>(context, dark: true, builder: (ctx) => _SoundSheet(onChange: _syncMusic));
  }

  double get _phaseTotal => phase == _Phase.ready ? _readySec : (phase == _Phase.rest ? session!.restSec.toDouble() : items[index].s.toDouble());
  double get _progress => (1 - math.max(0, remaining) / _phaseTotal).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    if (session == null) return const NotFoundView();
    final shown = phase == _Phase.rest && nextEx != null ? nextEx! : current;
    final top = topInset(context);
    final bottom = bottomInset(context);
    final size = MediaQuery.sizeOf(context);
    final mediaH = math.min(size.width - 40, size.height * 0.4);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: EnsoScaffold(
        background: C.forest,
        lightIcons: true,
        body: Stack(fit: StackFit.expand, children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Opacity(opacity: 0.3, child: Transform.scale(scale: 1.25, child: EImage(img(shown.image)))),
          ),
          Opacity(opacity: 0.9, child: Container(decoration: const BoxDecoration(gradient: G.forest))),
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 8, 20, bottom + 18),
            child: Column(children: [
              Row(children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Container(
                        height: 3,
                        color: C.ivory.withValues(alpha: 0.15),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: i < index ? 1 : (i == index ? (phase == _Phase.work ? _progress : (phase == _Phase.rest ? 1 : 0)) : 0),
                          child: Container(color: C.ivory),
                        ),
                      ),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 12),
              Row(children: [
                CircleBtn(icon: LucideIcons.x, tone: Tone.dark, onTap: _exit, label: 'Close'),
                Expanded(
                  child: Column(children: [
                    Text(
                      (phase == _Phase.rest ? 'Rest' : (phase == _Phase.ready ? 'Get ready' : session!.subtitle)).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.tiny.copyWith(letterSpacing: 1.4, color: C.ivory.withValues(alpha: 0.6)),
                    ),
                    Text('${index + 1} / ${items.length}', style: T.label.copyWith(fontWeight: FontWeight.w700, color: C.ivory).tab),
                  ]),
                ),
                CircleBtn(icon: LucideIcons.slidersHorizontal, tone: Tone.dark, iconSize: 18, onTap: _settings, label: 'Audio settings'),
              ]),
              const SizedBox(height: 16),
              Container(
                height: mediaH,
                width: double.infinity,
                decoration: BoxDecoration(color: C.forest2, borderRadius: BorderRadius.circular(34), boxShadow: S.float),
                clipBehavior: Clip.antiAlias,
                child: Stack(fit: StackFit.expand, children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: shown.video != null
                        ? _VideoLoop(key: ValueKey('v-${shown.id}'), url: shown.video!, playing: running, fallback: img(shown.image))
                        : KenBurns(key: ValueKey(shown.id), running: running, child: EImage(img(shown.image))),
                  ),
                  if (shown.isAffirmation && phase == _Phase.work)
                    Container(
                      color: C.forest.withValues(alpha: 0.55),
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      alignment: Alignment.center,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Eyebrow('Repeat after me', color: C.ivory.withValues(alpha: 0.7)),
                        const SizedBox(height: 14),
                        Text(shown.description, textAlign: TextAlign.center, style: T.serifAccent.copyWith(fontSize: 26, height: 1.25, color: C.ivory)),
                      ]),
                    ),
                  if (phase == _Phase.work && !current.isAffirmation) Positioned(left: 16, right: 16, bottom: 16, child: _BreathPill(running: running, label: current.breath)),
                  if (phase == _Phase.rest)
                    Container(
                      color: C.forest.withValues(alpha: 0.55),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Eyebrow('Up next', color: C.ivory.withValues(alpha: 0.75)),
                        const SizedBox(height: 8),
                        Text('${math.max(0, remaining.ceil())}', style: T.displayXl.c(C.ivory).tab),
                        const SizedBox(height: 16),
                        Pressable(
                          onTap: _skipNext,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: C.ivory.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(99)),
                            child: Text('Skip rest', style: T.caption.copyWith(fontWeight: FontWeight.w600, color: C.ivory)),
                          ),
                        ),
                      ]),
                    ),
                  if (phase == _Phase.ready)
                    Container(
                      color: C.forest.withValues(alpha: 0.6),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          transitionBuilder: (c, a) => ScaleTransition(scale: Tween(begin: 1.6, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: c)),
                          child: Text('${math.max(1, remaining.ceil())}', key: ValueKey(remaining.ceil()), style: T.displayXl.copyWith(fontSize: 72, color: C.ivory).tab),
                        ),
                        const SizedBox(height: 8),
                        Text('Find your space, soften your knees', style: T.label.c(C.ivory.withValues(alpha: 0.8))),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: Column(key: ValueKey('${shown.id}-$phase-$stepIdx'), children: [
                  Text(shown.name, textAlign: TextAlign.center, style: T.displayMd.c(C.ivory)),
                  if (phase == _Phase.work && !shown.isAffirmation && shown.steps.length > 1) ...[
                    const SizedBox(height: 4),
                    Text('STEP ${stepIdx + 1} OF ${shown.steps.length}', style: T.tiny.copyWith(letterSpacing: 1.3, color: C.sage)),
                  ],
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Text(
                      phase == _Phase.rest
                          ? 'Shake out gently and breathe.'
                          : shown.isAffirmation
                              ? 'Breathe in calm, and speak the words softly on the exhale.'
                              : _guidance(shown),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: T.bodySm.copyWith(color: C.ivory.withValues(alpha: 0.72), height: 1.5),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Text(formatClock(remaining), style: T.displayXl.copyWith(fontSize: 56, height: 1, letterSpacing: -2.2, color: C.ivory).tab),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircleBtn(icon: Icons.skip_previous_rounded, tone: Tone.dark, size: 56, iconSize: 26, onTap: _skipPrev, label: 'Previous'),
                const SizedBox(width: 28),
                Ring(
                  value: _progress,
                  size: 96,
                  stroke: 4,
                  track: C.ivory.withValues(alpha: 0.15),
                  bar: C.ivory,
                  child: Pressable(
                    onTap: _togglePlay,
                    semanticLabel: running ? 'Pause' : 'Play',
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(color: C.ivory, shape: BoxShape.circle, boxShadow: S.float),
                      child: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 40, color: C.ink),
                    ),
                  ),
                ),
                const SizedBox(width: 28),
                CircleBtn(icon: Icons.skip_next_rounded, tone: Tone.dark, size: 56, iconSize: 26, onTap: _skipNext, label: 'Next'),
              ]),
              const Spacer(),
              if (nextEx != null && phase != _Phase.rest)
                Glass(
                  radius: 22,
                  padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
                  child: Row(children: [
                    RoundedImage(img(nextEx!.image), size: 48, radius: 14),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('UP NEXT', style: T.tiny.copyWith(fontSize: 11, letterSpacing: 1.3, color: C.ivory.withValues(alpha: 0.55))),
                        Text(nextEx!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.label.c(C.ivory)),
                      ]),
                    ),
                    Text(formatClock(items[index + 1].s), style: T.caption.copyWith(fontWeight: FontWeight.w700, color: C.ivory.withValues(alpha: 0.75)).tab),
                  ]),
                )
              else
                Glass(
                  radius: 22,
                  padding: const EdgeInsets.all(16),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (phase != _Phase.rest) ...[const Icon(LucideIcons.check, size: 16, color: C.ivory), const SizedBox(width: 8)],
                    Text(phase == _Phase.rest ? "Breathe. You're doing beautifully." : 'Final movement', style: T.label.copyWith(fontSize: 14, color: C.ivory.withValues(alpha: 0.8))),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _BreathPill extends StatefulWidget {
  const _BreathPill({required this.running, required this.label});
  final bool running;
  final String label;
  @override
  State<_BreathPill> createState() => _BreathPillState();
}

class _BreathPillState extends State<_BreathPill> {
  bool inhale = true;
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _BreathPill old) {
    super.didUpdateWidget(old);
    if (old.running != widget.running) _sync();
  }

  void _sync() {
    _t?.cancel();
    if (widget.running) _t = Timer.periodic(const Duration(seconds: 4), (_) => setState(() => inhale = !inhale));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        SizedBox(
          width: 32,
          height: 32,
          child: Stack(alignment: Alignment.center, children: [
            AnimatedScale(
              scale: inhale ? 1 : 0.45,
              duration: const Duration(seconds: 4),
              curve: Curves.easeInOut,
              child: Container(decoration: BoxDecoration(color: C.sage.withValues(alpha: 0.6), shape: BoxShape.circle)),
            ),
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: C.ivory, shape: BoxShape.circle)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(inhale ? 'Inhale slowly' : 'Exhale gently', style: T.caption.copyWith(fontWeight: FontWeight.w700, color: C.ivory)),
            Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: C.ivory.withValues(alpha: 0.65))),
          ]),
        ),
      ]),
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
    Widget toggle(IconData icon, String label, bool on, VoidCallback onTap) => Expanded(
          child: Pressable(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: on ? C.jade : C.ivory.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Row(children: [Icon(icon, size: 20, color: C.ivory), const SizedBox(width: 12), Text(label, style: T.label.c(C.ivory))]),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(left: 4), child: Text('Sound', style: T.title.c(C.ivory))),
        const SizedBox(height: 16),
        Row(children: [
          toggle(a.voice ? LucideIcons.mic : LucideIcons.micOff, 'Voice ${a.voice ? 'on' : 'off'}', a.voice, () => app.setAudio((x) => x.voice = !x.voice)),
          const SizedBox(width: 12),
          toggle(LucideIcons.music2, 'Music ${a.music ? 'on' : 'off'}', a.music, () {
            app.setAudio((x) => x.music = !x.music);
            onChange();
          }),
        ]),
        const SizedBox(height: 20),
        Padding(padding: const EdgeInsets.only(left: 4), child: Text('Soundscape', style: T.caption.copyWith(fontWeight: FontWeight.w600, color: C.ivory.withValues(alpha: 0.6)))),
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
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: a.musicTrack == s.id ? C.ivory : Colors.transparent, width: 2)),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(fit: StackFit.expand, children: [
                    EImage(img(s.image)),
                    Container(color: C.ink.withValues(alpha: 0.45)),
                    Positioned(left: 10, right: 8, bottom: 8, child: Text(s.name, style: T.tiny.copyWith(fontWeight: FontWeight.w700, color: C.ivory, height: 1.1))),
                  ]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Padding(padding: const EdgeInsets.only(left: 4), child: Text('Music volume', style: T.caption.copyWith(fontWeight: FontWeight.w600, color: C.ivory.withValues(alpha: 0.6)))),
        Slider(
          value: a.musicVolume,
          onChanged: (v) {
            app.setAudio((x) => x.musicVolume = v);
            Ambient.setVolume(v * 0.6);
          },
          inactiveColor: C.ivory.withValues(alpha: 0.15),
        ),
      ]),
    );
  }
}

/// Muted looping exercise video (used when licensed media is attached to an exercise).
class _VideoLoop extends StatefulWidget {
  const _VideoLoop({super.key, required this.url, required this.playing, required this.fallback});
  final String url, fallback;
  final bool playing;
  @override
  State<_VideoLoop> createState() => _VideoLoopState();
}

class _VideoLoopState extends State<_VideoLoop> {
  late final VideoPlayerController _c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _ready = false, _failed = false;

  @override
  void initState() {
    super.initState();
    _c.setLooping(true);
    _c.setVolume(0);
    _c.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      if (widget.playing) _c.play();
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void didUpdateWidget(covariant _VideoLoop old) {
    super.didUpdateWidget(old);
    if (!_ready) return;
    widget.playing ? _c.play() : _c.pause();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _failed) return EImage(widget.fallback);
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(width: _c.value.size.width, height: _c.value.size.height, child: VideoPlayer(_c)),
    );
  }
}
