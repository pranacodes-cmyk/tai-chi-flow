import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/content.dart';
import '../services/audio_service.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';

/// Floating glass tab bar (web `TabBar`) hosting the 4 tab branches.
class TabShell extends StatelessWidget {
  const TabShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const tabs = [
    (label: 'Today', icon: LucideIcons.house),
    (label: 'Courses', icon: LucideIcons.bookOpen),
    (label: 'Meditate', icon: LucideIcons.flower2),
    (label: 'Profile', icon: LucideIcons.userRound),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: C.cream,
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(child: shell),
          // soft fade so scrolling content dissolves before it reaches the bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottom + 120,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      C.cream,
                      C.cream.withValues(alpha: 0.85),
                      C.cream.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottom + 90,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: const NowPlayingPill(),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottom + 10,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                    child: Container(
                      height: 70,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: C.ivory.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: C.ivory.withValues(alpha: 0.7),
                        ),
                        boxShadow: S.card,
                      ),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final w = c.maxWidth / tabs.length;
                          return Stack(
                            children: [
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 420),
                                curve: Curves.easeOutBack,
                                left: w * shell.currentIndex,
                                top: 7,
                                width: w,
                                height: 56,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: C.jadeSoft,
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  for (var i = 0; i < tabs.length; i++)
                                    Expanded(
                                      child: Semantics(
                                        button: true,
                                        selected: shell.currentIndex == i,
                                        label: tabs[i].label,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {
                                            Haptics.select();
                                            shell.goBranch(
                                              i,
                                              initialLocation:
                                                  i == shell.currentIndex,
                                            );
                                          },
                                          child: SizedBox(
                                            height: 70,
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  tabs[i].icon,
                                                  size: 22,
                                                  color: shell.currentIndex == i
                                                      ? C.jadeDeep
                                                      : C.muted,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  tabs[i].label,
                                                  style: T.tiny.copyWith(
                                                    fontSize: 11,
                                                    color:
                                                        shell.currentIndex == i
                                                        ? C.jadeDeep
                                                        : C.muted,
                                                    letterSpacing: -0.05,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab screens reserve space for the floating bar.
double tabBarSpace(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom + 120;

/// Floating "now playing" pill for soundscapes that keep playing across tabs (web `NowPlaying`).
class NowPlayingPill extends StatelessWidget {
  const NowPlayingPill({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Ambient.state,
      builder: (context, st, _) {
        final scape = Content.i.soundscapes
            .where((s) => s.id == st.key)
            .firstOrNull;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.4),
                end: Offset.zero,
              ).animate(a),
              child: c,
            ),
          ),
          child: scape == null
              ? const SizedBox.shrink(key: ValueKey('none'))
              : ClipRRect(
                  key: const ValueKey('pill'),
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
                      decoration: BoxDecoration(
                        color: C.forest.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: S.float,
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.asset(
                                    img(scape.image),
                                    fit: BoxFit.cover,
                                  ),
                                  if (st.playing)
                                    Container(
                                      color: C.ink.withValues(alpha: 0.35),
                                      alignment: Alignment.bottomCenter,
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: const _Bars(),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  scape.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: T.label.copyWith(
                                    fontSize: 14,
                                    color: C.ivory,
                                  ),
                                ),
                                Text(
                                  st.playing
                                      ? 'Soundscape · playing'
                                      : 'Soundscape · paused',
                                  style: T.tiny.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: C.ivory.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: st.playing
                                ? 'Pause soundscape'
                                : 'Play soundscape',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                Haptics.select();
                                st.playing
                                    ? Ambient.pause()
                                    : Ambient.play(scape.id, 0.55);
                              },
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Center(
                                  child: Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: C.ivory,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  st.playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 22,
                                  color: C.ink,
                                ),
                              ),
                                ),
                              ),
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'Stop soundscape',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                Haptics.select();
                                Ambient.stop();
                              },
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Icon(
                                  LucideIcons.x,
                                  size: 16,
                                  color: C.ivory.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _Bars extends StatefulWidget {
  const _Bars();
  @override
  State<_Bars> createState() => _BarsState();
}

class _BarsState extends State<_Bars> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Container(
              width: 3,
              height:
                  5 +
                  9 *
                      (0.5 +
                          0.5 * math.sin((_c.value + i * 0.18) * 2 * math.pi)),
              decoration: BoxDecoration(
                color: C.ivory,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
