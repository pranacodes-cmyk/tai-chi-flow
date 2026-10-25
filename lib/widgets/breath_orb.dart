import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';
import '../i18n/i18n.dart';

enum BreathPhase { inhale, hold, exhale, rest }

String _phaseLabel(BreathPhase phase) => switch (phase) {
  BreathPhase.inhale => tr('breathOrb.breatheIn'),
  BreathPhase.hold => tr('breathOrb.hold'),
  BreathPhase.exhale => tr('breathOrb.breatheOut'),
  BreathPhase.rest => tr('breathOrb.rest'),
};

/// Drives an [inhale, hold, exhale, hold] cycle once per second (web useBreathCycle).
class BreathCycle extends ChangeNotifier {
  BreathCycle(this.pattern, {this.onPhase}) : left = pattern[0];
  final List<int> pattern;
  final void Function(BreathPhase)? onPhase;
  BreathPhase phase = BreathPhase.inhale;
  int left;
  Timer? _t;

  String get label => _phaseLabel(phase);
  int get duration => pattern[phase.index];

  void setRunning(bool running) {
    _t?.cancel();
    if (!running) return;
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (left > 1) {
        left--;
        notifyListeners();
        return;
      }
      var i = phase.index;
      for (var k = 0; k < 4; k++) {
        i = (i + 1) % 4;
        if (pattern[i] > 0) break;
      }
      phase = BreathPhase.values[i];
      left = pattern[i];
      onPhase?.call(phase);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }
}

class BreathOrb extends StatelessWidget {
  const BreathOrb({
    super.key,
    required this.cycle,
    required this.running,
    this.size = 260,
  });
  final BreathCycle cycle;
  final bool running;
  final double size;
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cycle,
      builder: (_, _) {
        final expanded =
            cycle.phase == BreathPhase.inhale ||
            cycle.phase == BreathPhase.hold;
        final scale = running ? (expanded ? 1.0 : 0.62) : 0.8;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final (i, r) in [1.0, 0.82, 0.64].indexed)
                _PulseRing(size: size * r, period: 6 + i, running: running),
              AnimatedScale(
                scale: scale,
                duration: Duration(
                  milliseconds: running
                      ? math.max(600, cycle.duration * 1000)
                      : 800,
                ),
                curve: Curves.easeInOut,
                child: Container(
                  width: size * 0.62,
                  height: size * 0.62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.3, -0.4),
                      colors: [
                        Color(0xFFBBDBC0),
                        Color(0xFF558F6E),
                        Color(0xFF26523E),
                      ],
                      stops: [0, 0.55, 1],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8FC29E).withValues(alpha: 0.6),
                        blurRadius: 80,
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    running ? cycle.label : tr('breathOrb.paused'),
                    style: T.title.c(C.ivory),
                  ),
                  if (running)
                    Text(
                      '${cycle.left}',
                      style: T.displayXl
                          .copyWith(fontSize: 36, color: C.ivory, height: 1)
                          .tab,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PulseRing extends StatefulWidget {
  const _PulseRing({
    required this.size,
    required this.period,
    required this.running,
  });
  final double size;
  final int period;
  final bool running;
  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.period),
  );
  @override
  void initState() {
    super.initState();
    if (widget.running) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulseRing old) {
    super.didUpdateWidget(old);
    if (widget.running && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.running) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.scale(
          scale: 1 + 0.04 * t,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: C.ivory.withValues(alpha: 0.15 * (0.5 + 0.4 * t) / 0.7),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Soft looping orb for non-breath meditations (web CalmOrb).
class CalmOrb extends StatefulWidget {
  const CalmOrb({super.key, required this.running, this.size = 260});
  final bool running;
  final double size;
  @override
  State<CalmOrb> createState() => _CalmOrbState();
}

class _CalmOrbState extends State<CalmOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );
  @override
  void initState() {
    super.initState();
    if (widget.running) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant CalmOrb old) {
    super.didUpdateWidget(old);
    if (widget.running && !_c.isAnimating) _c.repeat();
    if (!widget.running) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        double wave(double offset) =>
            0.5 - 0.5 * math.cos(2 * math.pi * ((_c.value + offset) % 1));
        return SizedBox(
          width: s,
          height: s,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final (i, r) in [1.0, 0.8, 0.6].indexed)
                Transform.scale(
                  scale: widget.running ? 0.92 + 0.14 * wave(i * 0.08) : 0.95,
                  child: Container(
                    width: s * r,
                    height: s * r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: C.ivory.withValues(alpha: 0.06),
                    ),
                  ),
                ),
              Transform.scale(
                scale: widget.running ? 0.88 + 0.17 * wave(0) : 0.9,
                child: Container(
                  width: s * 0.5,
                  height: s * 0.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.3, -0.4),
                      colors: [
                        Color(0xFFEADDC1),
                        Color(0xFF6A9C7F),
                        Color(0xFF284B3A),
                      ],
                      stops: [0, 0.6, 1],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFA6CBAF).withValues(alpha: 0.6),
                        blurRadius: 90,
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
