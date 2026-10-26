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

  test('journey Day 1 downloads its 10 films and 60 coach clips, warm-up film first, no duplicates', () {
    final day = Content.i.plan('tai-chi-journey-30')!.days.first;
    final paths = sessionMediaPaths(day.items, Content.i.exercise, Content.i.voice);
    expect(paths.length, 70);
    expect(paths.where((p) => p.startsWith('video/')).length, 10);
    expect(paths.first, 'video/mv-standing-squat-swing.mp4');
    expect(paths.toSet().length, paths.length);
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
