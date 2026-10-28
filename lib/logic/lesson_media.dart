import '../data/models.dart';
import '../i18n/i18n.dart';
import 'coach.dart';

/// Lesson media that lives on the R2 media server (Mirrors src/lib/lesson-media.ts).
/// Paths are relative to the versioned media root: `video/<film>.mp4`, `voice/<key>.m4a`.
/// Onboarding, UI and breathing media stay bundled; callers drop paths already in the app.
const String kMediaBase =
    'https://pub-6b6ccbaa2b5946dd851b43b1f1219507.r2.dev/v1';

String filmPath(String film) => 'video/$film.mp4';
String voicePath(String key) => 'voice/$key.m4a';

/// Every film and coach clip a session player can use, in play order, without duplicates.
/// [available] is the set of voice keys that have a pre-rendered clip.
/// The tutor's welcome comes first and the congratulations last (web `sessionMediaPaths`).
List<String> sessionMediaPaths(
  List<SessionItem> items,
  Exercise? Function(String id) exercise,
  Set<String> available, {
  LessonTutor? intro,
  LessonTutor? outro,
}) {
  final out = <String>[];
  void add(String p) {
    if (!out.contains(p)) out.add(p);
  }

  void say(Iterable<String> lines) {
    for (final l in lines) {
      final k = voiceKey(l);
      if (available.contains(k)) add(voicePath(k));
    }
  }

  void tutor(LessonTutor? t) {
    if (t == null) return;
    add(filmPath(t.film));
    say(t.lines);
  }

  tutor(intro);
  for (final (i, item) in items.indexed) {
    final ex = exercise(item.e);
    if (ex == null) continue;
    // a lesson film replaces the movement's own film for the whole step
    if (item.f != null) {
      add(filmPath(item.f!));
    } else if (ex.demo != null && ex.video == null) {
      add(filmPath(ex.demo!));
    }
    if (i == 0) say(CoachLines.begin(ex));
    if (item.w != null) {
      if (item.w! > 0) say(CoachLines.watch(ex, item));
      say(CoachLines.go(ex, item));
    } else {
      say(CoachLines.start(ex, item));
    }
    if (item.c.isNotEmpty) {
      say(item.c.map((c) => c.l));
    } else {
      say(CoachLines.instructions(ex, item));
    }
    if (item.u != null) say(CoachLines.unlock(item.u!));
    if (ex.isAffirmation) say(CoachLines.halfway(ex, ''));
    if (i > 0) say([tr('coach.name', {'name': ex.name})]);
  }
  tutor(outro);
  return out;
}

/// Narration clips of a meditation.
List<String> meditationMediaPaths(Meditation m, Set<String> available) => [
  for (final k in {for (final l in m.script) voiceKey(l.text)})
    if (available.contains(k)) voicePath(k),
];

/// Share of a download that is complete, as a whole percent (0 when nothing is needed is 100).
int downloadPercent(int done, int total) =>
    total <= 0 ? 100 : ((done / total) * 100).floor().clamp(0, 100);
