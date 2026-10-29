import 'dart:convert';
import 'dart:io';

import 'package:enso/data/content.dart';
import 'package:enso/data/models.dart';
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

  test('journey Day 1 downloads its 11 films and 65 coach clips, tutor welcome first, no duplicates', () {
    final day = Content.i.plan('tai-chi-journey-30')!.days.first;
    final paths = sessionMediaPaths(day.items, Content.i.exercise, Content.i.voice, intro: day.intro, outro: day.outro);
    final films = paths.where((p) => p.startsWith('video/')).toList();
    expect(paths.length, 76);
    expect(films.length, 11);
    expect(paths.first, 'video/lf-tutor-welcome.mp4');
    expect(films.last, 'video/lf-tutor-congrats.mp4');
    expect(films, contains('video/mv-standing-parting-the-wild-horses-mane.mp4'));
    expect(films, isNot(contains('video/lf-qi-rub.mp4')));
    expect(films, isNot(contains('video/lf-link-open-horse.mp4')));
    expect(paths.toSet().length, paths.length);
  });

  test("a step with its own lesson film never downloads the movement's usual film too", () {
    final first = Content.i.plan('tai-chi-journey-30')!.days.first.items.first;
    final own = SessionItem(first.e, first.s, first.p, first.g, first.t, first.lv, first.w, first.wl, first.go, first.c, 'lf-tutor-welcome');
    final paths = sessionMediaPaths([own], Content.i.exercise, Content.i.voice);
    expect(paths.where((p) => p.startsWith('video/')).toList(), ['video/lf-tutor-welcome.mp4']);
  });

  test('Evening Wind-Down downloads each narration clip once, then its music', () {
    final m = Content.i.meditation('evening-wind-down')!;
    final paths = meditationMediaPaths(m, Content.i.voice);
    expect(paths.length, {for (final l in m.script) voiceKey(l.text)}.length + 1);
    expect(paths.toSet().length, paths.length);
    expect(paths.last, 'audio/${m.music}.mp3');
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

  test('a re-made film gets a new fingerprint, so old bundled or saved copies are not reused', () {
    const revs = {'mv-x': 'abc123'};
    expect(filmRev(revs, 'video/mv-x.mp4'), 'abc123');
    expect(filmRev(revs, 'voice/k.m4a'), isNull);
    expect(filmRev({'voice:k': 'v9'}, 'voice/k.m4a'), 'v9');
    expect(sameMedia('abc123', 'abc123'), isTrue);
    expect(sameMedia('abc123', 'old999'), isFalse);
    expect(sameMedia('abc123', null), isFalse);
    expect(sameMedia(null, null), isTrue);
    expect(mediaUrl('video/mv-x.mp4', 'abc123'), '$kMediaBase/video/mv-x.mp4?v=abc123');
    expect(mediaUrl('voice/k.m4a'), '$kMediaBase/voice/k.m4a');
    expect(Content.i.mediaRev['mv-standing-brush-knee-and-twist-step'], hasLength(10));
  });
}
