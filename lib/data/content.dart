import 'dart:convert';

import 'package:flutter/painting.dart' show Alignment;
import 'package:flutter/services.dart' show rootBundle;

import '../i18n/i18n.dart';
import '../services/content_updates.dart';
import 'models.dart';

/// The shared content in the app language: `content.json` (English) or `i18n/content.<lang>.json`,
/// loaded at startup and again when the language changes.
class Content {
  Content._(Map<String, dynamic> j, this.lang)
    : ui = ((j['ui'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k as String, v as String),
      ),
      exercises = (j['exercises'] as List)
          .map((e) => Exercise.fromJson(e))
          .toList(),
      categories = (j['categories'] as List)
          .map((e) => Category.fromJson(e))
          .toList(),
      quickSessions = (j['quickSessions'] as List)
          .map((e) => QuickSession.fromJson(e))
          .toList(),
      planGroups = (j['planGroups'] as List).cast<String>(),
      plans = (j['plans'] as List).map((e) => Plan.fromJson(e)).toList(),
      challengeIds = (j['challengeIds'] as List? ?? const []).cast<String>(),
      dailyPlanIds = (j['dailyPlanIds'] as List? ?? const []).cast<String>(),
      meditationCategories = (j['meditationCategories'] as List).cast<String>(),
      meditations = (j['meditations'] as List)
          .map((e) => Meditation.fromJson(e))
          .toList(),
      soundscapes = (j['soundscapes'] as List)
          .map((e) => Soundscape.fromJson(e))
          .toList(),
      achievements = (j['achievements'] as List)
          .map((e) => Achievement.fromJson(e))
          .toList(),
      dailyChallenges = (j['dailyChallenges'] as List)
          .map((e) => DailyChallenge.fromJson(e))
          .toList(),
      quotes = (j['quotes'] as List).map((e) => Quote.fromJson(e)).toList(),
      affirmations = (j['affirmations'] as List).cast<String>(),
      testimonials = (j['testimonials'] as List)
          .map((e) => Testimonial.fromJson(e))
          .toList(),
      onboarding = (j['onboarding'] as List)
          .map((e) => OnbStep.fromJson(e))
          .toList(),
      onboardingChapters = (j['onboardingChapters'] as List? ?? const [])
          .map((e) => OnbChapter.fromJson(e as Map<String, dynamic>))
          .toList(),
      guides = (j['guides'] as List? ?? const [])
          .map((e) => Guide.fromJson(e as Map<String, dynamic>))
          .toList(),
      tips = (j['tips'] as List? ?? const [])
          .map((e) => Tip.fromJson(e as Map<String, dynamic>))
          .toList(),
      voice = {...(j['voice'] as List? ?? const []).cast<String>()},
      legal = Legal.fromJson(
        (j['legal'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      imageFocus = {
        for (final e in ((j['imageFocus'] as Map?) ?? const {}).entries)
          e.key as String: ((e.value as List)[0] as num).toDouble() * 2 - 1,
      },
      _focusY = {
        for (final e in ((j['imageFocus'] as Map?) ?? const {}).entries)
          e.key as String: ((e.value as List)[1] as num).toDouble() * 2 - 1,
      } {
    setI18n(lang, ui);
    for (final e in exercises) {
      _ex[e.id] = e;
    }
    for (final p in plans) {
      _plans[p.id] = p;
    }
    for (final c in categories) {
      _cats[c.id] = c;
    }
    for (final q in quickSessions) {
      _quick[q.id] = q;
    }
    for (final m in meditations) {
      _meds[m.id] = m;
    }
    for (final a in achievements) {
      _ach[a.id] = a;
    }
  }

  static late Content i;
  static bool loaded = false;

  /// Bundled content file for a language code.
  static String assetFor(String lang) => lang == 'en'
      ? 'assets/data/content.json'
      : 'assets/data/i18n/content.$lang.json';

  /// Revision of the content bundled in this build (newer published updates replace it).
  static int bundledRev = 0;

  /// Revision actually in use (bundled, or a downloaded update).
  static int rev = 0;

  /// Loads the bundled content, then a saved newer published update when one is valid; a broken
  /// update falls back to the bundled content so the app always opens.
  static Future<void> load([String lang = 'en']) async {
    final raw = await rootBundle.loadString(assetFor(lang));
    final bundled = jsonDecode(raw) as Map<String, dynamic>;
    bundledRev = (bundled['contentRev'] as num?)?.toInt() ?? 0;
    final remote = await ContentUpdates.saved(lang, bundledRev);
    if (remote != null) {
      try {
        i = Content._(remote, lang);
        rev = (remote['contentRev'] as num).toInt();
        loaded = true;
        return;
      } catch (_) {}
    }
    i = Content._(bundled, lang);
    rev = bundledRev;
    loaded = true;
  }

  /// For tests: build from an already-decoded map.
  static void loadFromJson(Map<String, dynamic> j, [String lang = 'en']) {
    i = Content._(j, lang);
    loaded = true;
  }

  /// Language of the loaded content ("en", "de", "ja"…).
  final String lang;

  /// UI strings (key → message) in this language, read through `tr()`.
  final Map<String, String> ui;

  final List<Exercise> exercises;
  final List<Category> categories;
  final List<QuickSession> quickSessions;
  final List<String> planGroups;
  final List<Plan> plans;

  /// The 19 plan challenges (3 free quick sessions + premium programs).
  final List<String> challengeIds;

  /// The 60-day daily practices shown on Today (seated / standing).
  final List<String> dailyPlanIds;
  final List<String> meditationCategories;
  final List<Meditation> meditations;
  final List<Soundscape> soundscapes;
  final List<Achievement> achievements;
  final List<DailyChallenge> dailyChallenges;
  final List<Quote> quotes;
  final List<String> affirmations;
  final List<Testimonial> testimonials;
  final List<OnbStep> onboarding;
  final List<OnbChapter> onboardingChapters;

  /// The host who introduces the quiz and voices its replies (chapter 1's `host`).
  OnbHost? get onboardingHost =>
      onboardingChapters.map((c) => c.host).whereType<OnbHost>().firstOrNull;
  final List<Guide> guides;
  final List<Tip> tips;
  final Set<String> voice;

  /// Privacy policy + terms of use (also published as the store-listing pages).
  final Legal legal;

  /// Focal point x per image key, already mapped to Alignment space (-1..1).
  final Map<String, double> imageFocus;
  final Map<String, double> _focusY;

  /// Alignment that keeps faces and heads in frame whenever an image is cropped.
  Alignment focusOf(String key) =>
      Alignment(imageFocus[key] ?? 0, _focusY[key] ?? -0.5);

  final _ex = <String, Exercise>{};
  final _plans = <String, Plan>{};
  final _cats = <String, Category>{};
  final _quick = <String, QuickSession>{};
  final _meds = <String, Meditation>{};
  final _ach = <String, Achievement>{};

  Exercise? exercise(String id) => _ex[id];
  Plan? plan(String id) => _plans[id];
  Category? category(String id) => _cats[id];
  QuickSession? quick(String id) => _quick[id];
  Meditation? meditation(String id) => _meds[id];
  Achievement? achievement(String id) => _ach[id];
  OnbStep? step(String id) => onboarding.where((s) => s.id == id).firstOrNull;
  OnbChapter? chapter(String section) =>
      onboardingChapters.where((c) => c.section == section).firstOrNull;
  Guide? guide(String id) => guides.where((g) => g.id == id).firstOrNull;
}

/// Image key from an asset path (inverse of [img]).
String imgKey(String asset) =>
    asset.split('/').last.replaceAll(RegExp(r'\.(jpg|png)$'), '');

/// Bundled image asset by key. Saved history can name imagery that has since been retired
/// from the bundle, so unknown keys fall back to the Today hero (same as web `img`).
String img(String key) {
  if (key.endsWith('.png')) return 'assets/images/$key';
  if (key.startsWith('logo')) return 'assets/images/$key.png';
  final known = !Content.loaded || Content.i.imageFocus.containsKey(key);
  return 'assets/images/${known ? key : 'hero-today'}.jpg';
}

/// Online copy of an image key, used when a published content update names imagery this build
/// does not bundle (publish-content.py uploads every content image).
String imgUrl(String key) =>
    '${ContentUpdates.base.replaceFirst(RegExp(r'/content$'), '')}/v1/images/$key.jpg';
}

String audioAsset(String key) => 'audio/$key.mp3';
String voiceAsset(String key) => 'voice/$key.m4a';

/// Bundled film asset by key (web `filmUrl`).
String filmAsset(String key) => 'assets/video/$key.mp4';


class LegalSection {
  final String heading;
  final List<String> paragraphs;
  const LegalSection(this.heading, this.paragraphs);
  factory LegalSection.fromJson(Map<String, dynamic> j) => LegalSection(
    j['h'] as String? ?? '',
    (j['p'] as List? ?? const []).cast<String>(),
  );
}

class LegalDoc {
  final String title, intro;
  final List<LegalSection> sections;
  const LegalDoc(this.title, this.intro, this.sections);
  factory LegalDoc.fromJson(Map<String, dynamic> j) => LegalDoc(
    j['title'] as String? ?? '',
    j['intro'] as String? ?? '',
    [
      for (final s in j['sections'] as List? ?? const [])
        LegalSection.fromJson((s as Map).cast<String, dynamic>()),
    ],
  );
}

class Legal {
  final String updated, contact, site;
  final LegalDoc privacy, terms;
  const Legal(this.updated, this.contact, this.site, this.privacy, this.terms);
  factory Legal.fromJson(Map<String, dynamic> j) => Legal(
    j['updated'] as String? ?? '',
    j['contact'] as String? ?? '',
    j['site'] as String? ?? '',
    LegalDoc.fromJson((j['privacy'] as Map?)?.cast<String, dynamic>() ?? const {}),
    LegalDoc.fromJson((j['terms'] as Map?)?.cast<String, dynamic>() ?? const {}),
  );
}
