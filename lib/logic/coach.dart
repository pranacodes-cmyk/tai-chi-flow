import 'dart:convert';

import '../data/models.dart';

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

class CoachLines {
  CoachLines._();

  static List<String> begin(Exercise first) => [
    "Let's begin. First up:",
    '${first.name}.',
  ];

  static List<String> instructions(Exercise ex, [SessionItem? item]) => [
    if (item?.g case final String cue when cue.trim().isNotEmpty) cue,
    ...ex.steps,
  ];

  static List<String> start(Exercise ex, [SessionItem? item]) =>
      ex.isAffirmation
      ? ['Spoken affirmation.', ex.cue]
      : ['${ex.name}.', instructions(ex, item).firstOrNull ?? ex.cue];

  static List<String> step(Exercise ex, int k, [SessionItem? item]) {
    final lines = instructions(ex, item);
    return [k >= 0 && k < lines.length ? lines[k] : ex.cue];
  }

  static List<String> halfway(Exercise ex, String affirmation) =>
      ex.isAffirmation
      ? ['Once more.', ex.cue.replaceFirst('Repeat after me: ', '')]
      : [affirmation];

  static List<String> rest(Exercise next) => [
    'Rest. Up next:',
    '${next.name}.',
  ];

  static List<String> finish() => ['Session complete. Beautifully done.'];

  static List<String> breath(CoachBreath phase) => [
    phase == CoachBreath.inhale
        ? 'Breathe in'
        : (phase == CoachBreath.exhale ? 'Breathe out' : 'Hold'),
  ];

  /// Onboarding: the coach's reply to a picked answer.
  static List<String> onbReply(OnbOption o) =>
      (o.reply ?? '').isEmpty ? const [] : [o.reply!];

  /// Onboarding: spoken when a chapter card opens (the breath chapter uses breath cues).
  static List<String> onbChapter(OnbChapter c) =>
      c.breath ? const [] : [c.line];

  /// Onboarding: the host's cues during the opening breath (his own voice, not the workout coach's).
  static List<String> onbBreath(CoachBreath phase) => [
    phase == CoachBreath.inhale
        ? 'Breathe in slowly, through your nose.'
        : 'And gently, let it all go.',
  ];

  /// Onboarding: after the opening breath.
  static List<String> onbArrived() => [
    'Beautiful. Now, tell me a little about you.',
  ];

  static List<String> guide(Guide g) => [
    '${g.title}. ${g.intro}',
    for (final s in g.sections)
      '${s.heading.replaceFirst(RegExp(r'^\d+ · '), '')}. ${s.body}',
    'Remember: ${g.takeaways.join('. ')}.',
  ];

  static List<String> preview() => [
    'Let your arms float up as if resting on water, then sink as you soften your knees.',
  ];
}
