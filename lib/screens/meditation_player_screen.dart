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
import '../widgets/breath_orb.dart';
import '../widgets/scaffold.dart';
import '../widgets/sheet.dart';
import '../widgets/toast.dart';
import '../widgets/ui.dart';
import 'plan_detail_screen.dart';

const _sleepOptions = [0, 5, 10, 15, 30];

class MeditationPlayerScreen extends StatefulWidget {
  const MeditationPlayerScreen({super.key, required this.meditationId});
  final String meditationId;
  @override
  State<MeditationPlayerScreen> createState() => _MeditationPlayerScreenState();
}

class _MeditationPlayerScreenState extends State<MeditationPlayerScreen> {
  late final Meditation? m = Content.i.meditation(widget.meditationId);
  late final AppState app = context.read<AppState>();
  int elapsed = 0;
  bool running = false, downloading = false, done = false;
  int? sleepAt;
  final spoken = <int>{};
  Timer? _t;
  BreathCycle? cycle;

  int get total => m!.minutes * 60;

  @override
  void initState() {
    super.initState();
    if (m?.breath != null) {
      cycle = BreathCycle(
        m!.breath!,
        onPhase: (p) {
          Haptics.light();
          if (app.audio.voice && elapsed < 60) {
            Voice.say(
              CoachLines.breath(
                p == BreathPhase.inhale
                    ? CoachBreath.inhale
                    : (p == BreathPhase.exhale
                          ? CoachBreath.exhale
                          : CoachBreath.hold),
              ),
            );
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    cycle?.dispose();
    Voice.stop();
    Ambient.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  String _save(int seconds) {
    final entry = HistoryEntry(
      id: '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(1 << 30).toRadixString(36)}',
      sessionId: 'med:${m!.id}',
      title: m!.title,
      kind: 'meditation',
      image: m!.image,
      completedAt: DateTime.now(),
      durationSec: seconds,
      kcal: 0,
    );
    app.completeSession(entry);
    return entry.id;
  }

  void _setRunning(bool v) {
    setState(() => running = v);
    cycle?.setRunning(v);
    _t?.cancel();
    if (v) {
      WakelockPlus.enable();
      Ambient.play(m!.track, app.audio.musicVolume * 0.8);
      _t = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else {
      WakelockPlus.disable();
      Ambient.pause();
      Voice.stop();
    }
  }

  void _tick() {
    setState(() => elapsed = math.min(total, elapsed + 1));
    final due = m!.script
        .where(
          (l) => l.t <= elapsed && !spoken.contains(l.t) && elapsed - l.t < 3,
        )
        .firstOrNull;
    if (due != null && m!.breath == null) {
      spoken.add(due.t);
      if (app.audio.voice) Voice.say([due.text]);
    }
    if (sleepAt != null && elapsed >= sleepAt!) {
      sleepAt = null;
      _setRunning(false);
      Toast.show('Sleep timer ended', description: 'Sweet dreams.');
    }
    if (elapsed >= total && !done) {
      done = true;
      _setRunning(false);
      Sfx.play('sfx-bell-end', 0.6);
      final id = _save(total);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) context.pushReplacement('/complete?id=$id');
      });
    }
  }

  bool get locked => isMeditationLocked(m!.id, app.premium.active);

  void _toggle() {
    if (locked) {
      context.push('/paywall?from=meditation');
      return;
    }
    if (!running && elapsed == 0) Sfx.play('sfx-bell-start', 0.5);
    _setRunning(!running);
  }

  void _seek(int d) {
    setState(() => elapsed = (elapsed + d).clamp(0, total - 1));
    spoken.clear();
  }

  Future<void> _close() async {
    if (elapsed >= 60 && !done) {
      final wasRunning = running;
      _setRunning(false);
      final choice = await showEnsoSheet<String>(
        context,
        dark: true,
        builder: (ctx) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: Column(
              children: [
                Text('End meditation?', style: T.displayMd.c(C.ivory)),
                const SizedBox(height: 8),
                Text(
                  "You've been still for ${(elapsed / 60).round()} minutes. Save them to your history?",
                  textAlign: TextAlign.center,
                  style: T.bodySm.c(C.ivory.withValues(alpha: 0.65)),
                ),
                const SizedBox(height: 24),
                EnsoButton(
                  label: 'Save & finish',
                  variant: BtnVariant.ivory,
                  onTap: () => Navigator.pop(ctx, 'save'),
                ),
                const SizedBox(height: 8),
                Pressable(
                  onTap: () => Navigator.pop(ctx, 'keep'),
                  child: SizedBox(
                    height: 48,
                    child: Center(
                      child: Text(
                        'Keep listening',
                        style: T.label.c(C.ivory.withValues(alpha: 0.8)),
                      ),
                    ),
                  ),
                ),
                Pressable(
                  onTap: () => Navigator.pop(ctx, 'discard'),
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: Text(
                        'Discard',
                        style: T.label.copyWith(
                          fontSize: 14,
                          color: C.terracotta,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
      if (!mounted) return;
      if (choice == 'save') {
        done = true;
        final id = _save(elapsed);
        context.pushReplacement('/complete?id=$id');
      } else if (choice == 'discard') {
        _leave();
      } else if (wasRunning) {
        // "Keep listening" or a dismissed sheet carries on where it paused
        _setRunning(true);
      }
    } else {
      _leave();
    }
  }

  void _leave() => context.canPop() ? context.pop() : context.go('/meditate');

  void _download() {
    if (locked) {
      context.push('/paywall?from=meditation');
      return;
    }
    if (app.downloads.contains(m!.id)) {
      app.toggleDownload(m!.id);
      Toast.show('Removed from downloads');
      return;
    }
    setState(() => downloading = true);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => downloading = false);
      app.toggleDownload(m!.id);
      Toast.show(
        'Available offline',
        description: '${m!.title} is saved to your device.',
        tone: 'success',
      );
    });
  }

  void _sleep() {
    showEnsoSheet<void>(
      context,
      dark: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('Sleep timer', style: T.title.c(C.ivory)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final (i, min) in _sleepOptions.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Pressable(
                        onTap: () {
                          setState(
                            () => sleepAt = min == 0
                                ? null
                                : math.min(total, elapsed + min * 60),
                          );
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: min == 0 && sleepAt == null
                                ? C.jade
                                : C.ivory.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            min == 0 ? 'Off' : '${min}m',
                            style: T.label.copyWith(
                              fontWeight: FontWeight.w700,
                              color: C.ivory,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (m == null) return const NotFoundView();
    final watch = context.watch<AppState>();
    final downloaded = watch.downloads.contains(m!.id);
    final fav = watch.favorites.contains('med:${m!.id}');
    final line =
        m!.script.reversed.where((l) => l.t <= elapsed).firstOrNull?.text ??
        m!.subtitle;
    final top = topInset(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: EnsoScaffold(
        background: C.forest,
        lightIcons: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedOpacity(
              opacity: running ? 0.45 : 0.6,
              duration: const Duration(seconds: 2),
              child: Transform.scale(scale: 1.1, child: EImage(img(m!.image))),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF111A15).withValues(alpha: 0.5),
                    const Color(0xFF111A15).withValues(alpha: 0.35),
                    const Color(0xFF0E1612).withValues(alpha: 0.95),
                  ],
                  stops: const [0, 0.4, 1],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                top + 10,
                24,
                bottomInset(context) + 22,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleBtn(
                        icon: LucideIcons.chevronDown,
                        tone: Tone.dark,
                        onTap: _close,
                        label: 'Close',
                      ),
                      const Spacer(),
                      CircleBtn(
                        icon: fav ? Icons.favorite_rounded : LucideIcons.heart,
                        iconColor: fav ? C.terracotta : C.ivory,
                        tone: Tone.dark,
                        label: 'Favorite',
                        onTap: () => app.toggleFavorite('med:${m!.id}'),
                      ),
                      const SizedBox(width: 8),
                      downloading
                          ? Glass(
                              radius: 44,
                              child: const SizedBox(
                                width: 44,
                                height: 44,
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: C.ivory,
                                  ),
                                ),
                              ),
                            )
                          : CircleBtn(
                              icon: downloaded
                                  ? LucideIcons.download
                                  : LucideIcons.cloudDownload,
                              iconColor: downloaded ? C.sage : C.ivory,
                              tone: Tone.dark,
                              label: 'Download',
                              onTap: _download,
                            ),
                      if (m!.category == 'Sleep') ...[
                        const SizedBox(width: 8),
                        CircleBtn(
                          icon: LucideIcons.timer,
                          iconColor: sleepAt != null ? C.sage : C.ivory,
                          tone: Tone.dark,
                          label: 'Sleep timer',
                          onTap: _sleep,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  Eyebrow(
                    '${m!.category} · ${m!.minutes} min',
                    color: C.ivory.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    m!.title,
                    textAlign: TextAlign.center,
                    style: T.displayLg.c(C.ivory),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (cycle != null)
                          BreathOrb(cycle: cycle!, running: running, size: 270)
                        else
                          CalmOrb(running: running, size: 270),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 64,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 800),
                            child: ConstrainedBox(
                              key: ValueKey(
                                running || elapsed > 0 ? line : m!.subtitle,
                              ),
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: Text(
                                running || elapsed > 0 ? line : m!.subtitle,
                                textAlign: TextAlign.center,
                                style: T.serifAccent.copyWith(
                                  fontSize: 21.6,
                                  height: 1.3,
                                  color: C.ivory.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Bar(
                    value: elapsed / total,
                    track: C.ivory.withValues(alpha: 0.15),
                    color: C.ivory,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        formatClock(elapsed),
                        style: T.tiny
                            .copyWith(color: C.ivory.withValues(alpha: 0.6))
                            .tab,
                      ),
                      const Spacer(),
                      Text(
                        '-${formatClock(total - elapsed)}',
                        style: T.tiny
                            .copyWith(color: C.ivory.withValues(alpha: 0.6))
                            .tab,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SeekBtn(back: true, onTap: () => _seek(-15)),
                      const SizedBox(width: 40),
                      Pressable(
                        onTap: _toggle,
                        semanticLabel: running ? 'Pause' : 'Play',
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: C.ivory,
                            shape: BoxShape.circle,
                            boxShadow: S.float,
                          ),
                          child: Icon(
                            locked
                                ? LucideIcons.crown
                                : (running
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded),
                            size: locked ? 32 : 42,
                            color: C.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                      _SeekBtn(back: false, onTap: () => _seek(15)),
                    ],
                  ),
                  if (locked) ...[
                    const SizedBox(height: 24),
                    EnsoButton(
                      label: 'Unlock with TaiChi Flow Plus',
                      variant: BtnVariant.gold,
                      onTap: () => context.push('/paywall?from=meditation'),
                    ),
                  ],
                  if (sleepAt != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Sleep timer · stops at ${formatClock(sleepAt!)}',
                      style: T.caption.c(C.ivory.withValues(alpha: 0.6)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeekBtn extends StatelessWidget {
  const _SeekBtn({required this.back, required this.onTap});
  final bool back;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: back ? 'Back 15 seconds' : 'Forward 15 seconds',
    child: SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            back ? LucideIcons.rotateCcw : LucideIcons.rotateCw,
            size: 28,
            color: C.ivory.withValues(alpha: 0.85),
          ),
          Text(
            '15',
            style: T.tiny.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: C.ivory.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    ),
  );
}
