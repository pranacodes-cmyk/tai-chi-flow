import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../i18n/i18n.dart';
import '../logic/coach.dart';
import '../logic/lesson_media.dart';
import '../services/audio_service.dart';
import '../services/media_store.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'breath_orb.dart';
import 'scaffold.dart';
import 'preparation_breath.dart';
import 'ui.dart';

/// Gate in front of a lesson or meditation player (web `LessonPrepare`): when the lesson's
/// films/voice are already on the phone (or bundled) the player opens immediately; otherwise the
/// coach breathes with the person (bundled breath cues) while the files download with real
/// progress, then the player opens. Failures offer retry; closing cancels.
class LessonPrepare extends StatefulWidget {
  const LessonPrepare({super.key, required this.paths, required this.child});
  final List<String> paths;
  final Widget child;
  @override
  State<LessonPrepare> createState() => _LessonPrepareState();
}

class _LessonPrepareState extends State<LessonPrepare> {
  late List<String> _missing = MediaStore.missing(widget.paths);
  late final AppState app = context.read<AppState>();
  int _done = 0;
  bool _failed = false, _cancelled = false;
  BreathCycle? _cycle;

  bool get _ready => _missing.isEmpty;

  @override
  void initState() {
    super.initState();
    if (_ready) return;
    _cycle = BreathCycle(
      const [4, 1, 5, 1],
      onPhase: (ph) {
        if (!app.audio.voice || _ready || _failed) return;
        if (ph == BreathPhase.inhale) Voice.say(CoachLines.breath(CoachBreath.inhale));
        if (ph == BreathPhase.exhale) Voice.say(CoachLines.breath(CoachBreath.exhale));
      },
    )..setRunning(true);
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted && app.audio.voice && !_ready) {
        Voice.say(CoachLines.breath(CoachBreath.inhale));
      }
    });
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _failed = false;
      _done = 0;
    });
    try {
      await MediaStore.download(
        _missing,
        onProgress: (d, _) {
          if (mounted) setState(() => _done = d);
        },
        cancelled: () => _cancelled || !mounted,
      );
      if (!mounted || _cancelled) return;
      Voice.stop();
      _cycle?.setRunning(false);
      setState(() => _missing = MediaStore.missing(widget.paths));
      if (!_ready) setState(() => _failed = true);
    } catch (_) {
      if (!mounted) return;
      Voice.stop();
      setState(() {
        _failed = true;
        _missing = MediaStore.missing(widget.paths);
      });
    }
  }

  void _close() {
    _cancelled = true;
    Voice.stop();
    context.canPop() ? context.pop() : context.go('/');
  }

  @override
  void dispose() {
    _cancelled = true;
    _cycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    final pct = downloadPercent(_done, _missing.length);
    return EnsoScaffold(
      background: C.ivory,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final cycle = _cycle;
            return SingleChildScrollView(child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Padding(
              padding: EdgeInsets.fromLTRB(24, 10, 24, bottomInset(context) + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    CircleBtn(icon: LucideIcons.chevronLeft, label: tr('prepare.cancel'), onTap: _close),
                    Expanded(child: Text('TaiChi Flow', textAlign: TextAlign.center, style: T.title.copyWith(letterSpacing: 0))),
                    const SizedBox(width: 44),
                  ]),
                  SizedBox(height: math.max(24, box.maxHeight * 0.05)),
                  Text(
                    tr(_failed ? 'prepare.failedTitle' : 'prepare.title'),
                    textAlign: TextAlign.center,
                    style: T.displayMd.copyWith(letterSpacing: 0),
                  ),
                  const SizedBox(height: 10),
                  Text(tr(_failed ? 'prepare.failedBody' : 'prepare.subtitle'), textAlign: TextAlign.center, style: T.bodySm.c(C.muted)),
                  SizedBox(height: math.max(20, box.maxHeight * 0.045)),
                  if (_failed) ...[
                    SizedBox(height: math.min(180, box.maxHeight * 0.28), child: const Center(child: Icon(LucideIcons.wifiOff, size: 44, color: C.jade))),
                  ] else if (cycle != null) ...[
                    ListenableBuilder(listenable: cycle, builder: (_, _) => Column(children: [
                      PreparationBreath(expanded: cycle.phase == BreathPhase.inhale || cycle.phase == BreathPhase.hold, duration: cycle.duration),
                      const SizedBox(height: 20),
                      Text(cycle.label, textAlign: TextAlign.center, style: T.serifAccent.copyWith(fontSize: 30, color: C.jadeDeep, letterSpacing: 0)),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(cycle.duration, (i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: i < cycle.left ? C.jade : C.jadeSoft)),
                      ))),
                    ])),
                  ],
                  SizedBox(height: math.max(28, box.maxHeight * 0.07)),
                  if (_failed)
                    EnsoButton(
                      label: tr('prepare.retry'),
                      icon: LucideIcons.rotateCw,
                      onTap: _run,
                    )
                  else ...[
                    Bar(
                      value: pct / 100,
                      height: 6,
                      track: C.jadeSoft,
                      color: C.jade,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      tr('prepare.progress', {'pct': '$pct'}),
                      style: T.label.c(C.jadeDeep).tab,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr('prepare.offlineNote'),
                      textAlign: TextAlign.center,
                      style: T.caption.c(C.muted),
                    ),
                  ],
                  const SizedBox(height: 16),
                  EnsoButton(label: tr('prepare.cancel'), variant: BtnVariant.ghost, size: BtnSize.md, onTap: _close),
                ],
              ),
            )));
          },
        ),
      ),
    );
  }
}
