import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'models.dart';

/// Loaded once at startup from the shared content.json.
class Content {
  Content._(Map<String, dynamic> j)
      : exercises = (j['exercises'] as List).map((e) => Exercise.fromJson(e)).toList(),
        categories = (j['categories'] as List).map((e) => Category.fromJson(e)).toList(),
        quickSessions = (j['quickSessions'] as List).map((e) => QuickSession.fromJson(e)).toList(),
        planGroups = (j['planGroups'] as List).cast<String>(),
        plans = (j['plans'] as List).map((e) => Plan.fromJson(e)).toList(),
        challengeIds = (j['challengeIds'] as List? ?? const []).cast<String>(),
        dailyPlanIds = (j['dailyPlanIds'] as List? ?? const []).cast<String>(),
        meditationCategories = (j['meditationCategories'] as List).cast<String>(),
        meditations = (j['meditations'] as List).map((e) => Meditation.fromJson(e)).toList(),
        soundscapes = (j['soundscapes'] as List).map((e) => Soundscape.fromJson(e)).toList(),
        achievements = (j['achievements'] as List).map((e) => Achievement.fromJson(e)).toList(),
        dailyChallenges = (j['dailyChallenges'] as List).map((e) => DailyChallenge.fromJson(e)).toList(),
        quotes = (j['quotes'] as List).map((e) => Quote.fromJson(e)).toList(),
        affirmations = (j['affirmations'] as List).cast<String>(),
        testimonials = (j['testimonials'] as List).map((e) => Testimonial.fromJson(e)).toList(),
        onboarding = (j['onboarding'] as List).map((e) => OnbStep.fromJson(e)).toList() {
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

  static Future<void> load() async {
    final raw = await rootBundle.loadString('assets/data/content.json');
    i = Content._(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// For tests: build from an already-decoded map.
  static void loadFromJson(Map<String, dynamic> j) => i = Content._(j);

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
}

String img(String key) => key.endsWith('.png') ? 'assets/images/$key' : (key.startsWith('logo') ? 'assets/images/$key.png' : 'assets/images/$key.jpg');
String audioAsset(String key) => 'audio/$key.mp3';
