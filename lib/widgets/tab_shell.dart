import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/audio_service.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';

/// Floating glass tab bar (web `TabBar`) hosting the 5 tab branches.
class TabShell extends StatelessWidget {
  const TabShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const tabs = [
    (label: 'Today', icon: LucideIcons.house),
    (label: 'Plans', icon: LucideIcons.layoutGrid),
    (label: 'Meditate', icon: LucideIcons.flower2),
    (label: 'History', icon: LucideIcons.chartColumn),
    (label: 'Profile', icon: LucideIcons.userRound),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: C.cream,
      extendBody: true,
      body: Stack(children: [
        Positioned.fill(child: shell),
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
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: C.ivory.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: C.ivory.withValues(alpha: 0.7)),
                      boxShadow: S.card,
                    ),
                    child: LayoutBuilder(builder: (context, c) {
                      final w = c.maxWidth / tabs.length;
                      return Stack(children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutBack,
                          left: w * shell.currentIndex,
                          top: 7,
                          width: w,
                          height: 56,
                          child: Container(decoration: BoxDecoration(color: C.jadeSoft, borderRadius: BorderRadius.circular(22))),
                        ),
                        Row(children: [
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
                                    shell.goBranch(i, initialLocation: i == shell.currentIndex);
                                  },
                                  child: SizedBox(
                                    height: 70,
                                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Icon(tabs[i].icon, size: 22, color: shell.currentIndex == i ? C.jadeDeep : C.muted),
                                      const SizedBox(height: 4),
                                      Text(
                                        tabs[i].label,
                                        style: T.tiny.copyWith(fontSize: 11, color: shell.currentIndex == i ? C.jadeDeep : C.muted, letterSpacing: -0.05),
                                      ),
                                    ]),
                                  ),
                                ),
                              ),
                            ),
                        ]),
                      ]);
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Tab screens reserve space for the floating bar.
double tabBarSpace(BuildContext context) => MediaQuery.paddingOf(context).bottom + 120;
