import 'dart:convert';

import '../data/models.dart';
import '../i18n/i18n.dart';

/// Every line the coach speaks, built in one place so both clients say exactly the same words.
/// Natural-voice clips are pre-rendered per line and looked up by [voiceKey], so wording
/// changes need `bun scripts/render-voice.ts` + `bun scripts/generate-content.ts`.
/// Mirrors src/lib/coach.ts (tests assert identical keys).

/// Collapse whitespace so cosmetic spacing never changes a clip key.
String normalizeLine(String text) =>
    text.trim().replaceAll(RegExp(r'\s+'), ' ');

/// FNV-1a (32-bit) over the UTF-8 bytes of the normalised line → "v" + 8 hex chars.
String voiceKey(String text) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(normalizeLine(text))) {
    h ^= b;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return 'v${h.toRadixString(16).padLeft(8, '0')}';
}

enum CoachBreath { inhale, exhale, hold }

/// Strip the localized "Repeat after me:" lead-in from an affirmation cue.
String _affirmationWords(String cue) {
  final lead = tr('coach.repeatAfterMe');
  return cue.startsWith(lead) ? cue.substring(lead.length).trim() : cue;
}

class CoachLines {
  CoachLines._();

  static List<String> begin(Exercise first) => [
    tr('coach.begin'),
    tr('coach.name', {'name': first.name}),
  ];

  static List<String> instructions(Exercise ex, [SessionItem? item]) => [
    if (item?.g case final String cue when cue.trim().isNotEmpty) cue,
    ...ex.steps,
  ];

  static List<String> start(Exercise ex, [SessionItem? item]) =>
      ex.isAffirmation
      ? [tr('coach.spokenAffirmation'), ex.cue]
      : [
          tr('coach.name', {'name': ex.name}),
          instructions(ex, item).firstOrNull ?? ex.cue,
        ];

  static List<String> step(Exercise ex, int k, [SessionItem? item]) {
    final lines = instructions(ex, item);
    return [k >= 0 && k < lines.length ? lines[k] : ex.cue];
  }

  static List<String> halfway(Exercise ex, String affirmation) =>
      ex.isAffirmation
      ? [tr('coach.onceMore'), _affirmationWords(ex.cue)]
      : [affirmation];

  static List<String> rest(Exercise next) => [
    tr('coach.rest'),
    tr('coach.name', {'name': next.name}),
  ];

  static List<String> finish() => [tr('coach.finish')];

  static List<String> breath(CoachBreath phase) => [
    phase == CoachBreath.inhale
        ? tr('coach.breatheIn')
        : (phase == CoachBreath.exhale
              ? tr('coach.breatheOut')
              : tr('coach.hold')),
  ];

  /// Onboarding: the coach's reply to a picked answer.
  static List<String> onbReply(OnbOption o) =>
      (o.reply ?? '').isEmpty ? const [] : [o.reply!];

  /// Onboarding: spoken when a chapter card opens (the breath chapter uses breath cues).
  static List<String> onbChapter(OnbChapter c) =>
      c.breath ? const [] : [c.line];

  /// Onboarding: the coach's cues during the opening breath.
  static List<String> onbBreath(CoachBreath phase) => [
    phase == CoachBreath.inhale
        ? tr('coach.onbBreatheIn')
        : tr('coach.onbBreatheOut'),
  ];

  /// Onboarding: after the opening breath.
  static List<String> onbArrived() => [tr('coach.onbArrived')];

  static List<String> guide(Guide g) => [
    tr('coach.guideIntro', {'title': g.title, 'intro': g.intro}),
    for (final s in g.sections)
      tr('coach.guideSection', {
        'heading': s.heading.replaceFirst(RegExp(r'^\d+ · '), ''),
        'body': s.body,
      }),
    tr('coach.remember', {
      'list': g.takeaways.join(tr('coach.listSeparator')),
    }),
  ];

  static List<String> preview() => [tr('coach.preview')];
}
