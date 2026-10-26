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
    Future.delayed(const Duration(milliseconds: 400), () {
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
      background: C.forest,
      lightIcons: true,
      gradient: G.forest,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final orb = math.min(260.0, math.min(box.maxWidth - 64, box.maxHeight * 0.42));
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 10, 24, bottomInset(context) + 20),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CircleBtn(
                      icon: LucideIcons.x,
                      tone: Tone.dark,
                      label: tr('prepare.cancel'),
                      onTap: _close,
                    ),
                  ),
                  const Spacer(),
                  if (_failed) ...[
                    Icon(LucideIcons.wifiOff, size: 44, color: C.ivory.withValues(alpha: 0.85)),
                    const SizedBox(height: 18),
                    Text(
                      tr('prepare.failedTitle'),
                      textAlign: TextAlign.center,
                      style: T.displayMd.c(C.ivory),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('prepare.failedBody'),
                      textAlign: TextAlign.center,
                      style: T.bodySm.c(C.ivory.withValues(alpha: 0.7)),
                    ),
                  ] else ...[
                    BreathOrb(cycle: _cycle!, running: true, size: orb),
                    const SizedBox(height: 22),
                    Text(
                      tr('prepare.title'),
                      textAlign: TextAlign.center,
                      style: T.displayMd.c(C.ivory),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr('prepare.subtitle'),
                      textAlign: TextAlign.center,
                      style: T.bodySm.c(C.ivory.withValues(alpha: 0.7)),
                    ),
                  ],
                  const Spacer(),
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
                      track: C.ivory.withValues(alpha: 0.15),
                      color: C.ivory,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      tr('prepare.progress', {'pct': '$pct'}),
                      style: T.label.c(C.ivory.withValues(alpha: 0.85)).tab,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr('prepare.offlineNote'),
                      textAlign: TextAlign.center,
                      style: T.caption.c(C.ivory.withValues(alpha: 0.55)),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
