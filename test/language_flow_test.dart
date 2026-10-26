import 'dart:convert';
import 'dart:io';
import 'package:enso/data/content.dart';
import 'package:enso/router.dart';
import 'package:enso/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('new users choose a saved language before welcome and the quiz', (tester) async {
    Content.loadFromJson(jsonDecode(File('assets/data/content.json').readAsStringSync()) as Map<String, dynamic>);
    SharedPreferences.setMockInitialValues({});
    final app = await AppState.load();
    final router = buildRouter(app);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: app,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/language');
    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();
    expect(app.language, 'es');
    await app.flush();
    expect((await AppState.load()).language, 'es');
    await tester.tap(find.text('Continue'));
    expect(router.routeInformationProvider.value.uri.path, '/welcome');
    router.pop();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/language');
    expect(app.language, 'es');
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });
}