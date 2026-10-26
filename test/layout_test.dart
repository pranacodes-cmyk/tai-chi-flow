// Every screen must build and lay out without errors on small phones with large system text.
import 'dart:convert';
import 'dart:io';

import 'package:enso/data/content.dart';
import 'package:enso/router.dart';
import 'package:enso/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await _loadFonts();
    await initializeDateFormatting();
  });
  Map<String, dynamic> contentFor(String lang) => jsonDecode(
        File(lang == 'en' ? 'assets/data/content.json' : 'assets/data/i18n/content.$lang.json').readAsStringSync(),
      ) as Map<String, dynamic>;
  Content.loadFromJson(contentFor('en'));
  final c = Content.i;
  // the journey after its two free days: Today and the course page show their locked, Plus-offer state
  const starter = 'tai-chi-journey-30';
  final premium = c.plans.firstWhere((p) => p.premium).id;
  final quick = c.quickSessions.first.id;
  final routes = [
    '/language', '/welcome', '/', '/courses', '/courses?view=classes', '/meditate', '/profile', '/history', '/achievements',
    '/movements', '/reminders', '/settings', '/edit-profile', '/plan/$starter', '/plan/$premium',
    '/category/${c.categories.first.id}', '/exercise/${c.exercises.first.id}', '/guide/${c.guides.first.id}',
    '/legal/privacy', '/paywall?from=onboarding&offer=regular', '/paywall?offer=gift', '/paywall?offer=exit',
    '/session/quick:$quick', '/plan-ready',
  ];
  // English at both widths; every other language (longer German/French words, Japanese glyphs)
  // at the tightest width.
  final runs = [
    for (final w in [320.0, 360.0]) ('en', Size(w, 640)),
    for (final lang in ['de', 'fr', 'es', 'pt', 'it', 'ja']) (lang, const Size(320, 640)),
  ];

  for (final (lang, size) in runs) {
    for (final route in routes) {
      testWidgets('no overflow at ${size.width.toInt()}px, 130% text, $lang: $route', (tester) async {
        Content.loadFromJson(contentFor(lang), lang);
        SharedPreferences.setMockInitialValues({
          'enso-state-v1': jsonEncode({
            'language': lang,
            'onboarded': route != '/language' && route != '/welcome',
            'activePlanId': starter,
            'planProgress': {starter: {'startedAt': '2026-10-20T08:00:00.000Z', 'completedDays': [1, 2]}},
          }),
        });
        final app = await AppState.load();
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final overflows = <String>[];
        final prev = FlutterError.onError;
        FlutterError.onError = (d) {
          final msg = d.exceptionAsString();
          // native players/plugins are absent in tests; every layout or build error counts
          if (msg.contains('MissingPluginException') || msg.contains('PlatformException')) return;
          final at = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(d.toString())?.group(0) ?? '?';
          overflows.add('${msg.split('\n').first} @ $at');
        };
        final router = buildRouter(app);
        await tester.pumpWidget(ChangeNotifierProvider.value(
          value: app,
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
          ),
        ));
        router.go(route);
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        FlutterError.onError = prev;
        expect(overflows, isEmpty, reason: overflows.join('\n'));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 5));
      });
    }
  }
}
