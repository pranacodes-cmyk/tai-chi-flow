import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../logic/logic.dart';
import '../logic/coach.dart';
import '../services/audio_service.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/breath_orb.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';
import '../i18n/i18n.dart';

List<({String id, String name, String desc, List<int> p})> get _patterns => [
  (
    id: 'box',
    name: tr('breathe.patternBoxName'),
    desc: tr('breathe.patternBoxDesc'),
    p: [4, 4, 4, 4],
  ),
  (id: '478', name: tr('breathe.pattern478Name'), desc: tr('breathe.pattern478Desc'), p: [4, 7, 8, 0]),
  (
    id: 'calm',
    name: tr('breathe.patternCalmName'),
    desc: tr('breathe.patternCalmDesc'),
    p: [4, 0, 6, 0],
  ),
];
const _durations = [1, 3, 5];

class BreatheScreen extends StatefulWidget {
  const BreatheScreen({super.key});
  @override
  State<BreatheScreen> createState() => _BreatheScreenState();
}

enum _Stage { setup, intro, breathing, closing }

class _BreatheScreenState extends State<BreatheScreen> with WidgetsBindingObserver {
  String pid = 'box';
  int mins = 3;
  _Stage stage = _Stage.setup;

  /// Seconds into the breathing part, and how many whole cycles it runs.
  int sec = 0, cycles = 0;
  Timer? _t, _safety;
  late BreathCycle cycle = BreathCycle(pattern.p);
  late final AppState app = context.read<AppState>();

  /// Calm music only (no bells or singing bowls): the composed breathing track, Zen Garden offline.
  static const _music = 'zen-breath';

  ({String id, String name, String desc, List<int> p}) get pattern =>
      _patterns.firstWhere((x) => x.id == pid);

  int get _cycleLen => pattern.p.fold<int>(0, (a, b) => a + b);
  bool get active => stage != _Stage.setup;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  // Minimised or screen locked: stop the session (the person starts again when back).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused || state == AppLifecycleState.hidden) && active) _stop();
  }

  @override
  void dispose() {
    _t?.cancel();
    _safety?.cancel();
    cycle.dispose();
    Ambient.stop();
    Voice.stop();
    WakelockPlus.disable();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _select(String id) {
    if (active) return;
    setState(() {
      pid = id;
      cycle.dispose();
      cycle = BreathCycle(pattern.p);
    });
  }

  /// Begin: a short spoken explanation (what, how, posture), then the first breath in.
  void _start() {
    setState(() {
      stage = _Stage.intro;
      sec = 0;
      cycles = breathingCycles(pattern.p, mins);
    });
    cycle.show(0, pattern.p[0]);
    WakelockPlus.enable();
    Ambient.play(_music, app.audio.musicVolume * 0.6);
    if (app.audio.voice) {
      Voice.say(CoachLines.breathIntro(pid), onDone: _beginBreathing);
      _safety = Timer(const Duration(seconds: 40), _beginBreathing); // never wait forever on audio
    } else {
      _safety = Timer(const Duration(seconds: 6), _beginBreathing);
    }
  }

  void _skipIntro() {
    Voice.stop();
    _beginBreathing();
  }

  void _beginBreathing() {
    if (!mounted || stage != _Stage.intro) return;
    _safety?.cancel();
    setState(() {
      stage = _Stage.breathing;
      sec = 0;
    });
    _show(0);
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (sec + 1 >= cycles * _cycleLen) {
        _finish();
        return;
      }
      setState(() => sec++);
      _show(sec);
    });
  }

  /// Orb + spoken cue for second [s]: the first second of every phase says it, starting with "Breathe in".
  void _show(int s) {
    final at = breathAt(pattern.p, s);
    cycle.show(at.phase, at.left);
    if (!at.start) return;
    Haptics.light();
    if (app.audio.voice) {
      Voice.say(CoachLines.breath(const [CoachBreath.inhale, CoachBreath.hold, CoachBreath.exhale, CoachBreath.hold][at.phase]));
    }
  }

  void _finish() {
    _t?.cancel();
    setState(() => stage = _Stage.closing);
    if (app.audio.voice) {
      Voice.say(CoachLines.breathClose(), onDone: _complete);
      _safety = Timer(const Duration(seconds: 12), _complete);
    } else {
      _safety = Timer(const Duration(seconds: 3), _complete);
    }
  }

  void _stop() {
    _t?.cancel();
    _safety?.cancel();
    setState(() => stage = _Stage.setup);
    Ambient.stop();
    Voice.stop();
    WakelockPlus.disable();
  }

  void _complete() {
    if (!mounted || stage != _Stage.closing) return;
    final seconds = cycles * _cycleLen;
    _stop();
    final entry = HistoryEntry(
      id: '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(1 << 30).toRadixString(36)}',
      sessionId: 'breath:$pid',
      title: tr('breathe.sessionTitle', {'name': pattern.name}),
      kind: 'meditation',
      image: 'med-mountains',
      completedAt: DateTime.now(),
      durationSec: seconds,
      kcal: 0,
    );
    app.completeSession(entry);
    context.pushReplacement('/complete?id=${entry.id}');
  }

  String get _subtitle => switch (stage) {
    _Stage.intro => '${tr('coach.breathIntro${pid == 'box' ? 'Box' : (pid == '478' ? '478' : 'Calm')}')} ${tr('coach.breathPosture')}',
    _Stage.closing => tr('coach.breathClose'),
    _ => pattern.desc,
  };

  @override
  Widget build(BuildContext context) {
    return EnsoScaffold(
      background: C.forest,
      lightIcons: true,
      gradient: G.forest,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 680;
            final orbSize = math.min(
              290.0,
              compact
                  ? constraints.maxHeight * 0.34
                  : constraints.maxWidth - 48,
            );
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                24,
                10,
                24,
                bottomInset(context) + 22,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - bottomInset(context) - 32,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleBtn(
                          icon: LucideIcons.x,
                          tone: Tone.dark,
                          label: tr('common.close'),
                          onTap: () => context.canPop()
                              ? context.pop()
                              : context.go('/meditate'),
                        ),
                        const Spacer(),
                        if (active)
                          Glass(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Text(
                              formatClock(math.max(0, cycles * _cycleLen - sec)),
                              style: T.label
                                  .copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: C.ivory,
                                  )
                                  .tab,
                            ),
                          ),
                        const Spacer(),
                        const SizedBox(width: 44),
                      ],
                    ),
                    SizedBox(height: compact ? 8 : 16),
                    Text(tr('breathe.title'), style: T.displayLg.c(C.ivory)),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        _subtitle,
                        key: ValueKey(_subtitle),
                        textAlign: TextAlign.center,
                        style: T.bodySm.c(C.ivory.withValues(alpha: 0.65)),
                      ),
                    ),
                    SizedBox(
                      height: compact
                          ? orbSize + 20
                          : math.max(orbSize + 36, constraints.maxHeight - 374),
                      child: Center(
                        child: BreathOrb(
                          cycle: cycle,
                          running: stage == _Stage.breathing,
                          size: orbSize,
                          idleLabel: switch (stage) {
                            _Stage.intro => tr('breathOrb.getReady'),
                            _Stage.closing => tr('breathOrb.breatheNaturally'),
                            _ => null,
                          },
                        ),
                      ),
                    ),
                    if (!active) ...[
                      Row(
                        children: [
                          for (final (i, x) in _patterns.indexed) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: Pressable(
                                onTap: () => _select(x.id),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  constraints: const BoxConstraints(
                                    minHeight: 58,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 12,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: pid == x.id
                                        ? C.ivory
                                        : C.ivory.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    x.name,
                                    textAlign: TextAlign.center,
                                    style: T.label.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: pid == x.id ? C.ink : C.ivory,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (final (i, d) in _durations.indexed) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: Pressable(
                                onTap: () => setState(() => mins = d),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  constraints: const BoxConstraints(
                                    minHeight: 48,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: mins == d
                                        ? C.jade
                                        : C.ivory.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(48),
                                  ),
                                  child: Text(
                                    tr('common.minShort', {'n': d}),
                                    style: T.label.copyWith(
                                      fontSize: 14,
                                      color: mins == d
                                          ? C.ivory
                                          : C.ivory.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),
                      EnsoButton(
                        label: tr('breathe.begin'),
                        variant: BtnVariant.ivory,
                        onTap: _start,
                      ),
                    ] else ...[
                      if (stage == _Stage.intro) ...[
                        Pressable(
                          onTap: _skipIntro,
                          semanticLabel: tr('breathe.skipIntro'),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              tr('breathe.skipIntro'),
                              style: T.label.copyWith(fontWeight: FontWeight.w700, color: C.ivory.withValues(alpha: 0.85)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      EnsoButton(
                        label: tr('breathe.stop'),
                        variant: BtnVariant.glass,
                        onTap: _stop,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
