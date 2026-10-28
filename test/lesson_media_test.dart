import 'dart:convert';
import 'dart:io';

import 'package:enso/data/content.dart';
import 'package:enso/logic/coach.dart';
import 'package:enso/logic/lesson_media.dart';
import 'package:flutter_test/flutter_test.dart';

// Mirrors src/lib/lesson-media.test.ts
void main() {
  setUpAll(() {
    Content.loadFromJson(
      jsonDecode(File('assets/data/content.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  });

  test('journey Day 1 downloads its 12 films and 77 coach clips, tutor welcome first, no duplicates', () {
    final day = Content.i.plan('tai-chi-journey-30')!.days.first;
    final paths = sessionMediaPaths(day.items, Content.i.exercise, Content.i.voice, intro: day.intro, outro: day.outro);
    final films = paths.where((p) => p.startsWith('video/')).toList();
    expect(paths.length, 89);
    expect(films.length, 12);
    expect(paths.first, 'video/lf-tutor-welcome.mp4');
    expect(films.last, 'video/lf-tutor-congrats.mp4');
    expect(films, contains('video/lf-qi-rub.mp4'));
    expect(films, isNot(contains('video/lf-link-open-horse.mp4')));
    expect(paths.toSet().length, paths.length);
  });

  test("a step with its own lesson film never downloads the movement's usual film too", () {
    final day = Content.i.plan('tai-chi-journey-30')!.days.first;
    final qi = day.items.firstWhere((i) => i.f == 'lf-qi-rub');
    final paths = sessionMediaPaths([qi], Content.i.exercise, Content.i.voice);
    expect(paths.where((p) => p.startsWith('video/')).toList(), ['video/lf-qi-rub.mp4']);
  });

  test('Evening Wind-Down downloads its 13 narration clips', () {
    final m = Content.i.meditation('evening-wind-down')!;
    expect(meditationMediaPaths(m, Content.i.voice).length, 13);
  });

  test('the breathing cues spoken while a lesson downloads stay inside the app', () {
    final remote = ((jsonDecode(File('test/lesson-media.json').readAsStringSync()) as Map)['voice'] as List).toSet();
    for (final l in [...CoachLines.breath(CoachBreath.inhale), ...CoachLines.breath(CoachBreath.exhale)]) {
      expect(remote.contains(voiceKey(l)), isFalse, reason: l);
      expect(File('assets/voice/${voiceKey(l)}.m4a').existsSync(), isTrue, reason: l);
    }
  });

  test('progress is a whole percent and an empty download is complete', () {
    expect(downloadPercent(0, 70), 0);
    expect(downloadPercent(35, 70), 50);
    expect(downloadPercent(69, 70), 98);
    expect(downloadPercent(0, 0), 100);
  });
}
