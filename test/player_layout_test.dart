// The guided lesson player must build and lay out on small phones with large system text in every
// language, through every screen a person meets: the tutor's welcome, the calm check-in, a
// "watch first" demo, the practice, the closing check-in, the congratulations and the results.
import 'dart:convert';
import 'dart:io';

import 'package:enso/data/content.dart';
import 'package:enso/i18n/i18n.dart';
import 'package:enso/logic/logic.dart';
import 'package:enso/screens/complete_screen.dart';
import 'package:enso/screens/player_screen.dart';
import 'package:enso/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFonts() async {
  final families = {
    'PlusJakartaSans': ['400', '500', '600', '700', '800'].map((w) => 'assets/fonts/PlusJakartaSans-$w.ttf'),
    'InstrumentSerif': ['assets/fonts/InstrumentSerif-Regular.ttf', 'assets/fonts/InstrumentSerif-Italic.ttf'],
  };
  for (final e in families.entries) {
    final loader = FontLoader(e.key);
    for (final f in e.value) {
      loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
    }
    await loader.load();
  }
}

Map<String, dynamic> _content(String lang) => jsonDecode(
      File(lang == 'en' ? 'assets/data/content.json' : 'assets/data/i18n/content.$lang.json').readAsStringSync(),
    ) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await _loadFonts();
    await initializeDateFormatting();
  });

  const journey = 'plan:tai-chi-journey-30:1';
  final runs = [
    ('en', const Size(320, 568)),
    ('en', const Size(360, 640)),
    ('de', const Size(320, 568)),
    ('fr', const Size(320, 568)),
    ('ja', const Size(320, 568)),
  ];

  for (final (lang, size) in runs) {
    testWidgets('guided Day 1 lays out at ${size.width.toInt()}x${size.height.toInt()}, 130% text, $lang', (tester) async {
      Content.loadFromJson(_content(lang), lang);
      SharedPreferences.setMockInitialValues({
        'enso-state-v1': jsonEncode({
          'language': lang,
          'onboarded': true,
          'ratedApp': true,
          'activePlanId': 'tai-chi-journey-30',
          'planProgress': {'tai-chi-journey-30': {'startedAt': '2026-10-20T08:00:00.000Z', 'completedDays': <int>[]}},
          // no audio in tests: the captions and cues move on by reading time
          'audio': {'voice': false, 'music': false, 'musicTrack': 'music-bamboo', 'musicVolume': 0.5, 'voiceRate': 0.95, 'beeps': false, 'haptics': false},
        }),
      });
      final app = await AppState.load();
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final problems = <String>[];
      final prev = FlutterError.onError;
      FlutterError.onError = (d) {
        final msg = d.exceptionAsString();
        // native players/plugins are absent in tests; every layout or build error counts
        if (msg.contains('MissingPluginException') || msg.contains('PlatformException')) return;
        final at = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(d.toString())?.group(0) ?? '?';
        problems.add('${msg.split('\n').first} @ $at');
      };
      final router = GoRouter(
        initialLocation: '/player',
        routes: [
          GoRoute(path: '/', builder: (c, s) => const SizedBox.shrink()),
          GoRoute(path: '/player', builder: (c, s) => const PlayerScreen(sessionId: journey)),
          GoRoute(path: '/complete', builder: (c, s) => CompleteScreen(entryId: s.uri.queryParameters['id'] ?? '')),
        ],
      );
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: app,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ));
      Future<void> settle([int frames = 8]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
      }

      final seen = <String>[];
      final steps = Content.i.plan('tai-chi-journey-30')!.days.first.items.length;
      try {
        Future<void> tapLabel(String label, String phase) async {
          await settle();
          final f = find.bySemanticsLabel(label);
          expect(f, findsWidgets, reason: '$phase: "$label" not on screen');
          seen.add(phase);
          await tester.tap(f.first, warnIfMissed: false);
          await settle();
        }

        // the tutor's welcome with today's skills
        await settle(10);
        expect(find.text(tr('player.todayYoullLearn')), findsOneWidget);
        await tapLabel(tr('player.imReady'), 'intro');
        // calm check-in before
        expect(find.text(tr('player.calmQuestionBefore')), findsOneWidget);
        await tester.tap(find.text('6'));
        await tapLabel(tr('player.calmStart'), 'checkBefore');
        // every step: watch first, then practice
        for (var k = 0; k < steps; k++) {
          expect(find.text(tr('player.skipDemo')), findsOneWidget, reason: 'step ${k + 1} opens with its demo');
          await tapLabel(tr('player.skipDemo'), 'watch ${k + 1}');
          await tapLabel(tr('player.next'), 'work ${k + 1}');
        }
        // calm check-in after, then the tutor's congratulations
        expect(find.text(tr('player.calmQuestionAfter')), findsOneWidget);
        await tester.tap(find.text('8'));
        await tapLabel(tr('player.calmSeeResults'), 'checkAfter');
        await tapLabel(tr('common.continue'), 'outro');
        // the results screen with the calm change and today's unlocks
        await settle(12);
        expect(find.text(tr('complete.yourCalm').toUpperCase()), findsOneWidget);
      } finally {
        FlutterError.onError = prev;
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
      expect(seen.length, 2 + steps * 2 + 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 30));
    });
  }

  // demo-first courses and short sessions: every step still opens with its demo and reaches the results
  final others = <String>[];
  {
    Content.loadFromJson(_content('en'), 'en');
    final c = Content.i;
    others.add('quick:${c.quickSessions.first.id}');
    for (final p in c.plans.where((p) => p.id != 'tai-chi-journey-30').take(3)) {
      others.add('plan:${p.id}:1');
    }
  }
  for (final lang in ['en', 'de']) {
    for (final id in others) {
      testWidgets('$id plays through at 320x568, 130% text, $lang', (tester) async {
        Content.loadFromJson(_content(lang), lang);
        SharedPreferences.setMockInitialValues({
          'enso-state-v1': jsonEncode({
            'language': lang,
            'onboarded': true,
            'ratedApp': true,
            'premium': {'active': true, 'plan': 'yearly', 'since': '2026-10-20T08:00:00.000Z'},
            'audio': {'voice': false, 'music': false, 'musicTrack': 'music-bamboo', 'musicVolume': 0.5, 'voiceRate': 0.95, 'beeps': false, 'haptics': false},
          }),
        });
        final app = await AppState.load();
        tester.view.physicalSize = const Size(320, 568) * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final problems = <String>[];
        final prev = FlutterError.onError;
        FlutterError.onError = (d) {
          final msg = d.exceptionAsString();
          if (msg.contains('MissingPluginException') || msg.contains('PlatformException')) return;
          final at = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(d.toString())?.group(0) ?? '?';
          problems.add('${msg.split('\n').first} @ $at');
        };
        final router = GoRouter(
          initialLocation: '/player',
          routes: [
            GoRoute(path: '/', builder: (c, s) => const SizedBox.shrink()),
            GoRoute(path: '/player', builder: (c, s) => PlayerScreen(sessionId: id)),
            GoRoute(path: '/complete', builder: (c, s) => CompleteScreen(entryId: s.uri.queryParameters['id'] ?? '')),
          ],
        );
        await tester.pumpWidget(ChangeNotifierProvider.value(
          value: app,
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ));
        var demos = 0, practices = 0;
        try {
          for (var guard = 0; guard < 200 && find.byType(CompleteScreen).evaluate().isEmpty; guard++) {
            for (var i = 0; i < 6; i++) {
              await tester.pump(const Duration(milliseconds: 150));
            }
            Finder by(String key) => find.bySemanticsLabel(tr(key));
            if (by('player.skipDemo').evaluate().isNotEmpty) {
              demos++;
              await tester.tap(by('player.skipDemo').first, warnIfMissed: false);
            } else if (by('player.next').evaluate().isNotEmpty) {
              practices++;
              await tester.tap(by('player.next').first, warnIfMissed: false);
            } else if (by('player.imReady').evaluate().isNotEmpty) {
              await tester.tap(by('player.imReady').first, warnIfMissed: false);
            } else if (by('common.continue').evaluate().isNotEmpty) {
              await tester.tap(by('common.continue').first, warnIfMissed: false);
            }
          }
          for (var i = 0; i < 12; i++) {
            await tester.pump(const Duration(milliseconds: 150));
          }
        } finally {
          FlutterError.onError = prev;
        }
        final session = resolveSession(id)!;
        final moving = session.items.where((it) => !Content.i.exercise(it.e)!.isAffirmation).length;
        expect(problems, isEmpty, reason: problems.join('\n'));
        expect(find.byType(CompleteScreen), findsOneWidget, reason: 'reached the results');
        expect(demos, moving, reason: 'every movement opens with its demo');
        expect(practices, greaterThanOrEqualTo(moving));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 30));
      });
    }
  }
}
