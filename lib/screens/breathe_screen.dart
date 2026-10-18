import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../logic/logic.dart';
import '../services/audio_service.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/breath_orb.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';

const _patterns = [
  (id: 'box', name: 'Box', desc: '4 · 4 · 4 · 4 — focus & calm', p: [4, 4, 4, 4]),
  (id: '478', name: '4-7-8', desc: 'Deep relaxation & sleep', p: [4, 7, 8, 0]),
  (id: 'calm', name: 'Calm', desc: '4 in · 6 out — reset stress', p: [4, 0, 6, 0]),
];
const _durations = [1, 3, 5];

class BreatheScreen extends StatefulWidget {
  const BreatheScreen({super.key});
  @override
  State<BreatheScreen> createState() => _BreatheScreenState();
}

class _BreatheScreenState extends State<BreatheScreen> {
  String pid = 'box';
  int mins = 3;
  bool running = false;
  int left = 0;
  Timer? _t;
  late BreathCycle cycle = _makeCycle();
  late final AppState app = context.read<AppState>();

  ({String id, String name, String desc, List<int> p}) get pattern => _patterns.firstWhere((x) => x.id == pid);

  BreathCycle _makeCycle() => BreathCycle(_patterns.firstWhere((x) => x.id == pid).p, onPhase: (ph) {
        Haptics.light();
        if (app.audio.voice) Voice.speak(ph == BreathPhase.inhale ? 'Breathe in' : (ph == BreathPhase.exhale ? 'Breathe out' : 'Hold'), 0.9);
      });

  @override
  void dispose() {
    _t?.cancel();
    cycle.dispose();
    Ambient.stop();
    Voice.stop();
    super.dispose();
  }

  void _select(String id) {
    if (running) return;
    setState(() {
      pid = id;
      cycle.dispose();
      cycle = _makeCycle();
    });
  }

  void _start() {
    cycle.dispose();
    cycle = _makeCycle();
    setState(() {
      left = mins * 60;
      running = true;
    });
    cycle.setRunning(true);
    Sfx.play('sfx-bell-start', 0.5);
    Ambient.play('ambient-bowls', 0.35);
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => left--);
      if (left <= 0) _complete();
    });
  }

  void _stop() {
    _t?.cancel();
    cycle.setRunning(false);
    setState(() => running = false);
    Ambient.stop();
    Voice.stop();
  }

  void _complete() {
    _stop();
    Sfx.play('sfx-bell-end', 0.6);
    final entry = HistoryEntry(
      id: '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(1 << 30).toRadixString(36)}',
      sessionId: 'breath:$pid',
      title: '${pattern.name} breathing',
      kind: 'meditation',
      image: 'med-mountains',
      completedAt: DateTime.now(),
      durationSec: mins * 60,
      kcal: 0,
    );
    app.completeSession(entry);
    context.pushReplacement('/complete?id=${entry.id}');
  }

  @override
  Widget build(BuildContext context) {
    return EnsoScaffold(
      background: C.forest,
      lightIcons: true,
      gradient: G.forest,
      body: Padding(
        padding: EdgeInsets.fromLTRB(24, topInset(context) + 10, 24, bottomInset(context) + 22),
        child: Column(children: [
          Row(children: [
            CircleBtn(icon: LucideIcons.x, tone: Tone.dark, label: 'Close', onTap: () => context.canPop() ? context.pop() : context.go('/meditate')),
            const Spacer(),
            if (running)
              Glass(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(formatClock(left), style: T.label.copyWith(fontWeight: FontWeight.w700, color: C.ivory).tab),
              ),
            const Spacer(),
            const SizedBox(width: 44),
          ]),
          const SizedBox(height: 16),
          Text('Breathe', style: T.displayLg.c(C.ivory)),
          const SizedBox(height: 4),
          Text(pattern.desc, style: T.bodySm.c(C.ivory.withValues(alpha: 0.65))),
          Expanded(child: Center(child: BreathOrb(cycle: cycle, running: running, size: 290))),
          if (!running) ...[
            Row(children: [
              for (final (i, x) in _patterns.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Pressable(
                    onTap: () => _select(x.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: pid == x.id ? C.ivory : C.ivory.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(x.name, style: T.label.copyWith(fontWeight: FontWeight.w700, color: pid == x.id ? C.ink : C.ivory)),
                    ),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 8),
            Row(children: [
              for (final (i, d) in _durations.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Pressable(
                    onTap: () => setState(() => mins = d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: mins == d ? C.jade : C.ivory.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(48)),
                      child: Text('$d min', style: T.label.copyWith(fontSize: 14, color: mins == d ? C.ivory : C.ivory.withValues(alpha: 0.8))),
                    ),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 20),
            EnsoButton(label: 'Begin', variant: BtnVariant.ivory, onTap: _start),
          ] else
            EnsoButton(label: 'Stop', variant: BtnVariant.glass, onTap: _stop),
        ]),
      ),
    );
  }
}
