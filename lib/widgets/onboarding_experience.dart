import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../services/audio_service.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'demo_film.dart';
import 'ui.dart';
import 'voice_bars.dart';

/// The cinematic layer of the onboarding quiz: the host's spoken intro, chapter cards with looping
/// films, the opening guided breath, the coach's spoken replies and film heroes above some questions.
/// Mirrors src/components/enso/OnboardingExperience.tsx.

/// The onboarding host (chapter 1's `host` in content): his name and portrait sit on every
/// spoken reply (web `COACH_NAME` / `coachUrl`).
String get coachName => Content.i.onboardingHost?.name ?? 'Your coach';
String get coachAvatar => img(Content.i.onboardingHost?.avatar ?? 'logo-taichi');

/// Seconds of the opening breath (web `BREATH_IN` / `BREATH_OUT`).
const breathIn = 4;
const breathOut = 5;

enum BreathPhase { inhale, exhale, done }

const _breathLabel = {
  BreathPhase.inhale: 'Breathe in…',
  BreathPhase.exhale: '…and slowly out',
  BreathPhase.done: 'Beautiful.',
};

/// Muted looping film that fades in over its poster (the film's matching pose photo) once it can
/// play; the poster stays when the film can't play (web `LoopFilm`).
class LoopFilm extends StatefulWidget {
  const LoopFilm({
    super.key,
    required this.film,
    this.alignment = Alignment.center,
  });
  final String film;
  final Alignment alignment;
  @override
  State<LoopFilm> createState() => _LoopFilmState();
}

class _LoopFilmState extends State<LoopFilm> {
  VideoPlayerController? _c;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  void _open() {
    final c = VideoPlayerController.asset(
      filmAsset(widget.film),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _c = c;
    c.setLooping(true);
    c.setVolume(0);
    c
        .initialize()
        .then((_) {
          // a newer film may have replaced (and disposed) this controller meanwhile
          if (!mounted || !identical(_c, c)) return;
          setState(() => _ready = true);
          c.play();
        })
        .catchError((Object _) {
          // the poster stays visible
        });
  }

  @override
  void didUpdateWidget(covariant LoopFilm old) {
    super.didUpdateWidget(old);
    if (old.film != widget.film) {
      _c?.dispose();
      _ready = false;
      _open();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          img(widget.film),
          fit: BoxFit.cover,
          alignment: widget.alignment,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        if (c != null)
          AnimatedOpacity(
            opacity: _ready ? 1 : 0,
            duration: const Duration(milliseconds: 700),
            child: _ready
                ? ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      alignment: widget.alignment,
                      child: SizedBox.fromSize(
                        size: filmBox(c, square: true),
                        child: VideoPlayer(c),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------ host film

/// The host's spoken introduction: plays once with his own voice (muted when sound is off),
/// shows timed subtitles and reports when it ends; the poster stays if the film can't play
/// (web `HostFilm`).
class HostFilm extends StatefulWidget {
  const HostFilm({
    super.key,
    required this.host,
    required this.sound,
    required this.onEnded,
  });
  final OnbHost host;
  final bool sound;
  final VoidCallback onEnded;
  @override
  State<HostFilm> createState() => _HostFilmState();
}

class _HostFilmState extends State<HostFilm> {
  VideoPlayerController? _c;
  bool _ready = false;
  bool _ended = false;
  String _caption = '';
  Timer? _guard;

  @override
  void initState() {
    super.initState();
    final c = VideoPlayerController.asset(
      filmAsset(widget.host.video),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _c = c;
    c.addListener(_tick);
    c
        .initialize()
        .then((_) {
          if (!mounted) return;
          c.setVolume(widget.sound ? 1 : 0);
          setState(() => _ready = true);
          Voice.stop();
          Ambient.duck(true);
          c.play();
          // never strand the card if the platform misses the end of playback
          _guard = Timer(
            c.value.duration + const Duration(seconds: 2),
            _end,
          );
        })
        .catchError((Object _) => _end());
  }

  void _tick() {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    final pos = c.value.position;
    final caption = widget.host.captionAt(pos.inMilliseconds / 1000);
    if (caption != _caption && mounted) setState(() => _caption = caption);
    final dur = c.value.duration;
    if (dur > Duration.zero &&
        pos >= dur - const Duration(milliseconds: 120) &&
        !c.value.isPlaying) {
      _end();
    }
  }

  void _end() {
    if (_ended || !mounted) return;
    _ended = true;
    _guard?.cancel();
    Ambient.duck(false);
    widget.onEnded();
  }

  @override
  void didUpdateWidget(covariant HostFilm old) {
    super.didUpdateWidget(old);
    if (old.sound != widget.sound && _ready) {
      _c?.setVolume(widget.sound ? 1 : 0);
    }
  }

  @override
  void dispose() {
    _guard?.cancel();
    _c?.removeListener(_tick);
    _c?.dispose();
    if (!_ended) Ambient.duck(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          img(widget.host.video),
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.4),
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        if (c != null)
          AnimatedOpacity(
            opacity: _ready ? 1 : 0,
            duration: const Duration(milliseconds: 500),
            child: _ready
                ? ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.4),
                      child: SizedBox.fromSize(
                        size: filmBox(c, square: true),
                        child: VideoPlayer(c),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 200,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  C.ink.withValues(alpha: 0.45),
                  C.ink.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: Semantics(
            liveRegion: true,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: kEase,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.2),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: _caption.isEmpty
                  ? const SizedBox(key: ValueKey(''), height: 1)
                  : Text(
                      _caption,
                      key: ValueKey(_caption),
                      textAlign: TextAlign.center,
                      style: T.title.s(19).c(C.ivory).copyWith(
                        height: 1.35,
                        shadows: [
                          Shadow(
                            color: C.ink.withValues(alpha: 0.5),
                            blurRadius: 12,
                          ),
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

// ------------------------------------------------------------ chapter card

class ChapterCard extends StatefulWidget {
  const ChapterCard({
    super.key,
    required this.chapter,
    required this.number,
    required this.total,
    required this.onDone,
    this.onBreath,
    this.sound = true,
    this.onToggleSound,
  });
  final OnbChapter chapter;
  final int number;
  final int total;
  final VoidCallback onDone;

  /// Called as the opening breath moves through its phases (the screen speaks the cue).
  final ValueChanged<BreathPhase>? onBreath;

  /// Whether music and voice are on; the host film follows it.
  final bool sound;
  final VoidCallback? onToggleSound;
  @override
  State<ChapterCard> createState() => _ChapterCardState();
}

class _ChapterCardState extends State<ChapterCard> {
  late bool intro = widget.chapter.host != null;
  late BreathPhase phase = widget.chapter.breath
      ? BreathPhase.inhale
      : BreathPhase.done;
  final _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    if (!intro) _startBreath();
  }

  /// The host finished (or was skipped): the instructor's film and the guided breath take over.
  void _endIntro() {
    if (!intro || !mounted) return;
    setState(() => intro = false);
    _startBreath();
  }

  void _startBreath() {
    if (!widget.chapter.breath) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onBreath?.call(BreathPhase.inhale);
    });
    _timers.add(
      Timer(const Duration(seconds: breathIn), () {
        if (!mounted) return;
        setState(() => phase = BreathPhase.exhale);
        widget.onBreath?.call(BreathPhase.exhale);
      }),
    );
    _timers.add(
      Timer(const Duration(seconds: breathIn + breathOut), () {
        if (!mounted) return;
        setState(() => phase = BreathPhase.done);
        widget.onBreath?.call(BreathPhase.done);
      }),
    );
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ch = widget.chapter;
    final host = ch.host;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final cta = intro
        ? 'Skip intro'
        : ch.breath
        ? (phase == BreathPhase.done ? "Let's begin" : 'Skip & begin')
        : (widget.number == widget.total ? 'Almost there' : 'Continue');
    final title = intro && host != null ? host.title : ch.title;
    final line = intro && host != null ? host.line : ch.line;
    return Semantics(
      label: 'Chapter ${widget.number}: $title',
      child: ColoredBox(
        color: C.cream,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, top + 12, 16, 0),
                child: _CardEntrance(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 260),
                    decoration: BoxDecoration(
                      color: C.studio,
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: S.card,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 700),
                          switchInCurve: kEase,
                          child: intro && host != null
                              ? HostFilm(
                                  key: const ValueKey('host'),
                                  host: host,
                                  sound: widget.sound,
                                  onEnded: _endIntro,
                                )
                              : Stack(
                                  key: const ValueKey('film'),
                                  fit: StackFit.expand,
                                  children: [
                                    LoopFilm(
                                      film: ch.video,
                                      alignment: const Alignment(0, -0.2),
                                    ),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      height: 180,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [
                                              C.ink.withValues(alpha: 0.25),
                                              C.ink.withValues(alpha: 0),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (ch.breath) _BreathHalo(phase: phase),
                                  ],
                                ),
                        ),
                        Positioned(
                          left: 16,
                          top: 16,
                          child: Glass(
                            dark: false,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Text(
                              intro && host != null
                                  ? '${host.name} · Your coach'
                                  : 'Chapter ${widget.number} of ${widget.total}',
                              style: T.caption.w(FontWeight.w600).c(C.ink),
                            ),
                          ),
                        ),
                        if (intro && widget.onToggleSound != null)
                          Positioned(
                            right: 12,
                            top: 12,
                            child: Semantics(
                              button: true,
                              label: widget.sound
                                  ? 'Mute sound'
                                  : 'Turn on sound',
                              child: GestureDetector(
                                onTap: widget.onToggleSound,
                                child: Glass(
                                  dark: false,
                                  radius: 22,
                                  padding: const EdgeInsets.all(13),
                                  child: Icon(
                                    widget.sound
                                        ? LucideIcons.volume2
                                        : LucideIcons.volumeX,
                                    size: 18,
                                    color: widget.sound ? C.jadeDeep : C.muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Reveal(
                    delay: 0.25,
                    dy: 8,
                    child: Text(
                      '${widget.number.toString().padLeft(2, '0')} · ${ch.section}',
                      style: T.serifAccent.s(21.6).c(C.jade),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    switchInCurve: kEase,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topLeft,
                      children: [...previous, ?current],
                    ),
                    child: Column(
                      key: ValueKey(title),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Reveal(
                          delay: 0.32,
                          dy: 10,
                          child: Text(title, style: T.displayLg),
                        ),
                        const SizedBox(height: 8),
                        Reveal(
                          delay: 0.4,
                          dy: 10,
                          child: Text(line, style: T.body.c(C.muted)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      for (var i = 0; i < widget.total; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(
                              begin: i < widget.number - 1 ? 1 : 0,
                              end: i < widget.number ? 1 : 0,
                            ),
                            duration: const Duration(milliseconds: 1400),
                            curve: const Interval(0.35, 1, curve: kEase),
                            builder: (_, v, _) => Bar(
                              value: v,
                              height: 5,
                              gradient: G.jade,
                              track: C.sandDeep.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, bottom + 20),
              child: intro
                  ? EnsoButton(
                      label: cta,
                      variant: BtnVariant.secondary,
                      onTap: _endIntro,
                    )
                  : EnsoButton(label: cta, onTap: widget.onDone),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardEntrance extends StatelessWidget {
  const _CardEntrance({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 800),
    curve: kEase,
    builder: (_, v, c) => Opacity(
      opacity: v,
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - v)),
        child: Transform.scale(scale: 0.96 + 0.04 * v, child: c),
      ),
    ),
    child: child,
  );
}

/// A soft halo that grows on the inhale and settles on the exhale, around the instructor.
class _BreathHalo extends StatelessWidget {
  const _BreathHalo({required this.phase});
  final BreathPhase phase;
  @override
  Widget build(BuildContext context) {
    final scale = switch (phase) {
      BreathPhase.inhale => 1.0,
      BreathPhase.exhale => 0.68,
      BreathPhase.done => 0.82,
    };
    final ms = switch (phase) {
      BreathPhase.inhale => breathIn * 1000,
      BreathPhase.exhale => breathOut * 1000,
      BreathPhase.done => 1200,
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: LayoutBuilder(
            builder: (_, box) {
              final d = (box.maxWidth * 0.78).clamp(0.0, 300.0);
              return Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.68, end: scale),
                  duration: Duration(milliseconds: ms),
                  curve: Curves.easeInOut,
                  builder: (_, s, _) => Transform.scale(
                    scale: s,
                    // CSS box-shadow is clipped inside the element; Flutter's
                    // BoxShadow is not, which washed the photo white. Paint
                    // only the ring + an outside glow to match the web.
                    child: CustomPaint(
                      size: Size(d, d),
                      painter: _GlowRingPainter(C.ivory),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 20,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              switchInCurve: kEase,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.25),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: Glass(
                key: ValueKey(phase),
                dark: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  _breathLabel[phase]!,
                  style: T.label.s(16).c(C.jadeDeep),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ coach reply

class CoachReply extends StatefulWidget {
  const CoachReply({
    super.key,
    required this.text,
    required this.voiced,
    required this.onSkip,
  });
  final String text;
  final bool voiced;
  final VoidCallback onSkip;
  @override
  State<CoachReply> createState() => _CoachReplyState();
}

class _CoachReplyState extends State<CoachReply> {
  bool typed = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 420), () {
      if (mounted) setState(() => typed = true);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: '$coachName: ${widget.text}',
      child: ColoredBox(
        color: C.cream,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onSkip,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              32,
              safe.top + 32,
              32,
              safe.bottom + 28,
            ),
            child: Column(
              children: [
                const Spacer(),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: reduced ? 1 : 0.9, end: 1),
                  duration: Duration(milliseconds: reduced ? 0 : 650),
                  curve: kEase,
                  builder: (_, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: Container(
                    width: 128,
                    height: 128,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: C.jadeSoft, width: 2),
                    ),
                    child: ClipOval(
                      child: Image.asset(coachAvatar, fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(coachName, style: T.label.c(C.jade)),
                    if (widget.voiced) ...[
                      const SizedBox(width: 8),
                      const VoiceBars(color: C.jade, size: 18),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                AnimatedOpacity(
                  opacity: typed ? 1 : 0,
                  duration: Duration(milliseconds: reduced ? 0 : 450),
                  child: Text(
                    widget.text,
                    textAlign: TextAlign.center,
                    style: T.displayMd.copyWith(
                      fontSize: 26,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 80,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(
                      milliseconds: widget.voiced ? 8000 : 4000,
                    ),
                    builder: (_, v, _) => Bar(
                      value: v,
                      height: 3,
                      track: C.jadeSoft,
                      color: C.jade,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                EnsoButton(
                  label: 'Continue',
                  variant: BtnVariant.ghost,
                  size: BtnSize.md,
                  onTap: widget.onSkip,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 24,
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Builder(
              builder: (_) {
                final t = ((_c.value - i * 0.16) % 1 + 1) % 1;
                final k = t < 0.5 ? t * 2 : (1 - t) * 2;
                return Transform.translate(
                  offset: Offset(0, -2 * k),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: C.jade.withValues(alpha: 0.3 + 0.7 * k),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    ),
  );
}

// ------------------------------------------------------------ film hero above a question

class StepFilm extends StatelessWidget {
  const StepFilm({super.key, required this.film});
  final String film;
  @override
  Widget build(BuildContext context) {
    return Reveal(
      delay: 0.1,
      dy: 12,
      child: Container(
        height: 188,
        decoration: BoxDecoration(
          color: C.studio,
          borderRadius: BorderRadius.circular(28),
          boxShadow: S.soft,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LoopFilm(film: film),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: _EdgeFade(toRight: true),
                    ),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: _EdgeFade(toRight: false),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Glass(
                dark: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.play, size: 12, color: C.ink),
                    const SizedBox(width: 6),
                    Text(
                      'Like this',
                      style: T.caption.w(FontWeight.w600).c(C.ink),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.toRight});
  final bool toRight;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 48,
    height: double.infinity,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: toRight ? Alignment.centerLeft : Alignment.centerRight,
          end: toRight ? Alignment.centerRight : Alignment.centerLeft,
          colors: [C.studio, C.studio.withValues(alpha: 0)],
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------ sound

class SoundToggle extends StatelessWidget {
  const SoundToggle({super.key, required this.on, required this.onToggle});
  final bool on;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) => CircleBtn(
    icon: on ? LucideIcons.volume2 : LucideIcons.volumeX,
    iconColor: on ? C.jadeDeep : C.muted,
    iconSize: 18,
    onTap: onToggle,
    label: on ? 'Mute music and voice' : 'Turn on music and voice',
  );
}

class _GlowRingPainter extends CustomPainter {
  _GlowRingPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final circle = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    canvas.save();
    // Clip out the inside so the glow only spreads outward (CSS behaviour).
    canvas.clipPath(Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromCircle(center: c, radius: r + 80))
      ..addPath(circle, Offset.zero));
    canvas.drawCircle(
      c,
      r - 6,
      Paint()
        ..color = color.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );
    canvas.restore();
    canvas.drawCircle(
      c,
      r - 1.25,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = color.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_GlowRingPainter old) => old.color != color;
}
