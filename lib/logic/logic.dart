// Pure business rules — 1:1 mirror of src/lib/logic.ts. Any change must be applied to both.
import 'dart:math' as math;

import '../data/content.dart';
import '../data/models.dart';
import '../i18n/i18n.dart';

const restBetweenSec = 10;

/// Tai Chi Foundations: the course every standing newcomer starts with.
/// The flagship 30-Day Tai Chi Journey: Today's main lesson and every standing newcomer's default plan.
const journeyId = 'tai-chi-journey-30';
const defaultPlanId = journeyId;
const baseWeightKg = 70.0;

class Profile {
  String name,
      gender,
      ageGroup,
      bodyType,
      activity,
      flexibilityCheck,
      balanceCheck,
      units,
      style;
  List<String> goals, zones, limitations;
  double heightCm, weightKg, targetWeightKg;
  int stress, dailyMinutes;

  Profile({
    this.name = '',
    this.gender = '',
    this.ageGroup = '',
    this.bodyType = '',
    this.activity = '',
    this.flexibilityCheck = '',
    this.balanceCheck = '',
    this.units = 'metric',
    this.style = '',
    List<String>? goals,
    List<String>? zones,
    List<String>? limitations,
    this.heightCm = 168,
    this.weightKg = 72,
    this.targetWeightKg = 66,
    this.stress = 3,
    this.dailyMinutes = 10,
  }) : goals = goals ?? [],
       zones = zones ?? [],
       limitations = limitations ?? [];

  bool get imperial => units == 'imperial';

  Map<String, dynamic> toJson() => {
    'name': name,
    'gender': gender,
    'ageGroup': ageGroup,
    'goals': goals,
    'bodyType': bodyType,
    'zones': zones,
    'activity': activity,
    'flexibilityCheck': flexibilityCheck,
    'balanceCheck': balanceCheck,
    'limitations': limitations,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'targetWeightKg': targetWeightKg,
    'units': units,
    'style': style,
    'stress': stress,
    'dailyMinutes': dailyMinutes,
  };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    name: j['name'] ?? '',
    gender: j['gender'] ?? '',
    ageGroup: j['ageGroup'] ?? '',
    goals: (j['goals'] as List? ?? []).cast<String>().toList(),
    bodyType: j['bodyType'] ?? '',
    zones: (j['zones'] as List? ?? []).cast<String>().toList(),
    activity: j['activity'] ?? '',
    flexibilityCheck: j['flexibilityCheck'] ?? '',
    balanceCheck: j['balanceCheck'] ?? '',
    limitations: (j['limitations'] as List? ?? []).cast<String>().toList(),
    heightCm: (j['heightCm'] as num? ?? 168).toDouble(),
    weightKg: (j['weightKg'] as num? ?? 72).toDouble(),
    targetWeightKg: (j['targetWeightKg'] as num? ?? 66).toDouble(),
    units: j['units'] ?? 'metric',
    style: j['style'] ?? '',
    stress: (j['stress'] as num? ?? 3).toInt(),
    dailyMinutes: (j['dailyMinutes'] as num? ?? 10).toInt(),
  );

  Profile copy() => Profile.fromJson(toJson());

  String getString(String field) => (toJson()[field] ?? '').toString();
  List<String> getList(String field) =>
      (toJson()[field] as List? ?? []).cast<String>();
}

class HistoryEntry {
  final String id, sessionId, title, kind, image;
  final String? planId;
  final int? day;
  final DateTime completedAt;
  final int durationSec, kcal;
  int? feeling;

  HistoryEntry({
    required this.id,
    required this.sessionId,
    required this.title,
    required this.kind,
    required this.image,
    this.planId,
    this.day,
    required this.completedAt,
    required this.durationSec,
    required this.kcal,
    this.feeling,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'title': title,
    'kind': kind,
    'image': image,
    if (planId != null) 'planId': planId,
    if (day != null) 'day': day,
    'completedAt': completedAt.toIso8601String(),
    'durationSec': durationSec,
    'kcal': kcal,
    if (feeling != null) 'feeling': feeling,
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
    id: j['id'],
    sessionId: j['sessionId'],
    title: j['title'],
    kind: j['kind'],
    image: j['image'],
    planId: j['planId'],
    day: (j['day'] as num?)?.toInt(),
    completedAt: DateTime.parse(j['completedAt']).toLocal(),
    durationSec: (j['durationSec'] as num).toInt(),
    kcal: (j['kcal'] as num).toInt(),
    feeling: (j['feeling'] as num?)?.toInt(),
  );
}

class Session {
  final String id, kind, title, subtitle, image;
  final List<SessionItem> items;
  final int restSec, baseKcal;
  final String? planId;
  final int? day;
  const Session({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.items,
    required this.restSec,
    required this.baseKcal,
    this.planId,
    this.day,
  });
}

// ------------------------------------------------------------ dates

String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime addDays(DateTime d, int n) =>
    DateTime(d.year, d.month, d.day + n, d.hour, d.minute);
int dayOfYear(DateTime d) =>
    DateTime(d.year, d.month, d.day).difference(DateTime(d.year, 1, 1)).inDays +
    1;

// ------------------------------------------------------------ language

/// Languages the app ships in; English is the source language.
const supportedLanguages = ['en', 'es', 'pt', 'de', 'fr', 'it', 'ja'];

/// Each language's own name, shown in the language picker.
const languageNames = {
  'en': 'English',
  'es': 'Español',
  'pt': 'Português',
  'de': 'Deutsch',
  'fr': 'Français',
  'it': 'Italiano',
  'ja': '日本語',
};

/// The app language: the person's saved choice, else the first device language we ship, else English.
String resolveLanguage(String? saved, List<String> deviceLocales) {
  if (saved != null && supportedLanguages.contains(saved)) return saved;
  for (final l in deviceLocales) {
    final primary = l.toLowerCase().split(RegExp('[-_]')).first;
    if (supportedLanguages.contains(primary)) return primary;
  }
  return 'en';
}

/// Device-voice locales for the coach fallback, most preferred first (prefix match on the
/// voice's locale). English stays US/UK only; other languages prefer the accent of the clips.
List<String> fallbackVoiceLocales(String lang) => const {
  'en': ['en-us', 'en-gb'],
  'es': ['es-mx', 'es-us', 'es-419', 'es-es', 'es'],
  'pt': ['pt-br', 'pt'],
  'de': ['de-de', 'de'],
  'fr': ['fr-fr', 'fr'],
  'it': ['it-it', 'it'],
  'ja': ['ja-jp', 'ja'],
}[lang] ?? const ['en-us', 'en-gb'];

/// Rank of a device voice locale for [lang] (lower is better), or null when it must not be used.
int? fallbackVoiceRank(String lang, String locale) {
  final l = locale.toLowerCase().replaceAll('_', '-');
  final prefs = fallbackVoiceLocales(lang);
  for (var i = 0; i < prefs.length; i++) {
    if (l == prefs[i] || l.startsWith('${prefs[i]}-')) return i;
  }
  return null;
}

String greeting(int hour) {
  if (hour < 5) return tr('greet.evening');
  if (hour < 12) return tr('greet.morning');
  if (hour < 17) return tr('greet.afternoon');
  return tr('greet.evening');
}

/// Rating prompt: once per calendar day after a completed session, until the person has rated (4–5 stars sent to the store, or private feedback sent).
bool shouldAskRating(bool rated, String? lastAskedDay, String todayKey) =>
    !rated && lastAskedDay != todayKey;

/// 4–5 stars go to the store review; 1–3 stars open private feedback instead.
bool ratingGoesToStore(int stars) => stars >= 4;

/// Meditate tab's featured card: a free pick for people without Plus, so the first thing they see plays.
String featuredMeditationId(int hour, bool premium) {
  if (hour >= 17) return premium ? 'moonlit-lake' : 'evening-wind-down';
  return 'morning-clarity';
}

/// Free quick session featured on Today for people without Plus: morning wake-up, evening unwind, desk reset in between.
String freePickQuickId(int hour) {
  if (hour >= 5 && hour < 12) return 'morning-energy-boost';
  if (hour >= 17 || hour < 5) return 'evening-relax-stretch';
  return 'desk-break-routine';
}

/// Keep the journey on Today while the personal plan is locked, including after the free days.
/// An accessible personal plan still leads; selecting the hero never changes saved progress.
String todayPlanId(
  String activePlanId, {
  required bool activeLocked,
}) {
  return activeLocked ? journeyId : activePlanId;
}

/// After finishing a plan day: the next day when it exists and is locked for this person (the finish
/// screen previews it with a Plus offer), else null.
int? lockedNextDay(Plan plan, int finishedDay, bool premium) {
  final next = finishedDay + 1;
  return next <= plan.days.length && isDayLocked(plan, next, premium)
      ? next
      : null;
}

// ------------------------------------------------------------ body

double bmi(double heightCm, double weightKg) {
  final m = heightCm / 100;
  if (m <= 0) return 0;
  return (weightKg / (m * m) * 10).round() / 10;
}

String bmiCategory(double v) {
  if (v < 18.5) return 'Underweight';
  if (v < 25) return 'Healthy';
  if (v < 30) return 'Overweight';
  return 'Obese';
}

int kgToLb(double kg) => (kg * 2.20462).round();
double lbToKg(num lb) => (lb / 2.20462 * 10).round() / 10;
({int ft, int inch}) cmToFtIn(double cm) {
  final total = (cm / 2.54).round();
  return (ft: total ~/ 12, inch: total % 12);
}

int ftInToCm(int ft, int inch) => ((ft * 12 + inch) * 2.54).round();

String _trim(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
String formatWeight(double kg, String units) => units == 'imperial'
    ? '${kgToLb(kg)} lb'
    : '${_trim((kg * 10).round() / 10)} kg';
String formatHeight(double cm, String units) {
  if (units == 'imperial') {
    final r = cmToFtIn(cm);
    return '${r.ft}′${r.inch}″';
  }
  return '${cm.round()} cm';
}

int predictWeeks(double currentKg, double targetKg) {
  final diff = (currentKg - targetKg).abs();
  return math.min(26, math.max(4, (diff / 0.5).ceil()));
}

DateTime predictTargetDate(double currentKg, double targetKg, DateTime from) =>
    addDays(from, predictWeeks(currentKg, targetKg) * 7);

List<double> predictionCurve(
  double currentKg,
  double targetKg, [
  int points = 6,
]) {
  return List.generate(points, (i) {
    final t = i / (points - 1);
    final eased = 1 - math.pow(1 - t, 2.2).toDouble();
    return ((currentKg + (targetKg - currentKg) * eased) * 10).round() / 10;
  });
}

// ------------------------------------------------------------ personalization

String recommendPlanId({
  required List<String> goals,
  required String style,
  required List<String> limitations,
  required String ageGroup,
}) {
  final g = goals.toSet();
  final seated = limitations.contains('mobility') || style == 'chair';
  if (seated) {
    return g.contains('weight') ? 'chair-yoga-weight-loss' : 'seated-tai-chi';
  }
  if (g.contains('weight')) return 'weight-loss-walking';
  if (style == 'walking') return 'tai-chi-walking-30';
  if (style == 'qigong') return 'standing-qigong-14';
  return defaultPlanId;
}

/// Which 60-day daily practice suits this person: seated for limited mobility or chair lovers.
String dailyPlanId({
  required List<String> limitations,
  required String style,
}) => limitations.contains('mobility') || style == 'chair'
    ? 'seated-tai-chi'
    : 'standing-tai-chi';

String recommendFor(Profile p) => recommendPlanId(
  goals: p.goals,
  style: p.style,
  limitations: p.limitations,
  ageGroup: p.ageGroup,
);

// ------------------------------------------------------------ sessions

int totalSeconds(List<SessionItem> items, [int restSec = restBetweenSec]) {
  final work = items.fold<int>(0, (s, it) => s + it.s);
  return work + restSec * math.max(0, items.length - 1);
}

int kcalForWeight(int baseKcal, double weightKg) =>
    math.max(1, (baseKcal * weightKg / baseWeightKg).round());

int itemsKcal(List<SessionItem> items) => items
    .fold<double>(
      0,
      (s, it) => s + (Content.i.exercise(it.e)?.kcalPerMin ?? 3) * (it.s / 60),
    )
    .round();

String planSessionId(String planId, int day) => 'plan:$planId:$day';

Session? resolveSession(String id) {
  final parts = id.split(':');
  final kind = parts[0];
  final a = parts.length > 1 ? parts[1] : null;
  final b = parts.length > 2 ? parts[2] : null;
  final c = Content.i;
  if (kind == 'quick' && a != null) {
    final q = c.quick(a);
    if (q == null) return null;
    return Session(
      id: id,
      kind: 'quick',
      title: q.title,
      subtitle: q.subtitle,
      image: q.image,
      items: q.items,
      restSec: restBetweenSec,
      baseKcal: q.kcal,
    );
  }
  if (kind == 'plan' && a != null && b != null) {
    final plan = c.plan(a);
    final dayNum = int.tryParse(b);
    final day = plan?.days.where((d) => d.day == dayNum).firstOrNull;
    if (plan == null || day == null) return null;
    return Session(
      id: id,
      kind: 'plan',
      title: plan.isSingleSession
          ? plan.title
          : tr('common.dayTitle', {'day': day.day, 'title': day.title}),
      subtitle: plan.isSingleSession ? trTag(plan.group) : plan.title,
      image: plan.image,
      items: day.items,
      restSec: restBetweenSec,
      baseKcal: day.kcal,
      planId: plan.id,
      day: day.day,
    );
  }
  if (kind == 'cat' && a != null) {
    final cat = c.category(a);
    if (cat == null) return null;
    return Session(
      id: id,
      kind: 'category',
      title: cat.name,
      subtitle: cat.tagline,
      image: cat.image,
      items: cat.items,
      restSec: restBetweenSec,
      baseKcal: cat.kcal,
    );
  }
  if (kind == 'ex' && a != null) {
    final ex = c.exercise(a);
    if (ex == null) return null;
    final items = [SessionItem(ex.id, ex.durationSec * 2)];
    return Session(
      id: id,
      kind: 'exercise',
      title: ex.name,
      subtitle: tr('session.singlePractice'),
      image: ex.image,
      items: items,
      restSec: 0,
      baseKcal: itemsKcal(items),
    );
  }
  return null;
}

int nextPlanDay(int totalDays, List<int> completed) {
  final done = completed.toSet();
  for (var d = 1; d <= totalDays; d++) {
    if (!done.contains(d)) return d;
  }
  return totalDays;
}

/// Free programs are fully open; premium programs open their first `freeDays` days.
bool isDayLocked(Plan plan, int day, bool premium) =>
    !premium && plan.premium && day > plan.freeDays;

/// A program that cannot be started at all without TaiChi Flow Plus.
bool isPlanLocked(Plan plan, bool premium) => isDayLocked(plan, 1, premium);

bool isMeditationLocked(String id, bool premium) {
  final m = Content.i.meditation(id);
  return m != null && m.premium && !premium;
}

/// Player-entry guard: direct routes obey the same day gate as program screens.
bool isSessionLocked(String sessionId, bool premium) {
  final parts = sessionId.split(':');
  if (parts.length != 3 || parts[0] != 'plan') return false;
  final plan = Content.i.plan(parts[1]);
  final day = int.tryParse(parts[2]);
  return plan != null && day != null && isDayLocked(plan, day, premium);
}

// ------------------------------------------------------------ progress

List<String> uniqueDays(List<HistoryEntry> history) =>
    (history.map((h) => dateKey(h.completedAt)).toSet().toList()..sort());

int currentStreak(List<HistoryEntry> history, DateTime today) {
  final days = uniqueDays(history).toSet();
  var cursor = today;
  if (!days.contains(dateKey(cursor))) {
    cursor = addDays(today, -1);
    if (!days.contains(dateKey(cursor))) return 0;
  }
  var streak = 0;
  while (days.contains(dateKey(cursor))) {
    streak++;
    cursor = addDays(cursor, -1);
  }
  return streak;
}

int bestStreak(List<HistoryEntry> history) {
  final days = uniqueDays(history);
  var best = 0, run = 0;
  DateTime? prev;
  for (final key in days) {
    final p = key.split('-').map(int.parse).toList();
    final date = DateTime(p[0], p[1], p[2]);
    if (prev != null && dateKey(addDays(prev, 1)) == key) {
      run++;
    } else {
      run = 1;
    }
    best = math.max(best, run);
    prev = date;
  }
  return best;
}

class Stats {
  final int sessions,
      workouts,
      meditations,
      minutes,
      kcal,
      streak,
      best,
      plansCompleted,
      earlyBird,
      nightOwl;
  const Stats({
    required this.sessions,
    required this.workouts,
    required this.meditations,
    required this.minutes,
    required this.kcal,
    required this.streak,
    required this.best,
    required this.plansCompleted,
    required this.earlyBird,
    required this.nightOwl,
  });
}

Stats computeStats(
  List<HistoryEntry> history,
  DateTime today,
  int plansCompleted,
) {
  final workouts = history.where((h) => h.kind == 'workout').toList();
  return Stats(
    sessions: history.length,
    workouts: workouts.length,
    meditations: history.length - workouts.length,
    minutes: (history.fold<int>(0, (s, h) => s + h.durationSec) / 60).round(),
    kcal: workouts.fold<int>(0, (s, h) => s + h.kcal),
    streak: currentStreak(history, today),
    best: bestStreak(history),
    plansCompleted: plansCompleted,
    earlyBird: history.where((h) => h.completedAt.hour < 8).length,
    nightOwl: history.where((h) => h.completedAt.hour >= 21).length,
  );
}

int achievementValue(Achievement a, Stats s) {
  switch (a.metric) {
    case 'sessions':
      return s.sessions;
    case 'streak':
      return math.max(s.streak, s.best);
    case 'minutes':
      return s.minutes;
    case 'meditations':
      return s.meditations;
    case 'kcal':
      return s.kcal;
    case 'plansCompleted':
      return s.plansCompleted;
    case 'earlyBird':
      return s.earlyBird;
    case 'nightOwl':
      return s.nightOwl;
    default:
      return 0;
  }
}

List<String> unlockedAchievements(Stats s) => Content.i.achievements
    .where((a) => achievementValue(a, s) >= a.threshold)
    .map((a) => a.id)
    .toList();

class DayMinutes {
  final String key, label;
  final int minutes;
  const DayMinutes(this.key, this.label, this.minutes);
}

/// Weekday initials (Sunday first) in the app language.
List<String> get weekLetters => trList('common.weekdayLetters');

List<DayMinutes> weekMinutes(List<HistoryEntry> history, DateTime today) {
  final letters = weekLetters;
  return List.generate(7, (idx) {
    final i = 6 - idx;
    final d = addDays(today, -i);
    final key = dateKey(d);
    final secs = history
        .where((h) => dateKey(h.completedAt) == key)
        .fold<int>(0, (s, h) => s + h.durationSec);
    return DayMinutes(key, letters[d.weekday % 7], (secs / 60).round());
  });
}

// ------------------------------------------------------------ formatting

String formatMinutes(int sec) =>
    tr('common.minShort', {'n': math.max(1, (sec / 60).round())});

String formatClock(num sec) {
  final s = math.max(0, sec.ceil());
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

T dailyPick<T>(List<T> list, DateTime date, [int salt = 0]) =>
    list[(dayOfYear(date) + salt) % list.length];

// ------------------------------------------------------------ onboarding imagery

/// Gender variant used by onboarding photos: men see "m" imagery, everyone else "f".
String genderVariant(String gender) => gender == 'male' ? 'm' : 'f';

/// Resolves an onboarding image template (`onb-age-{g}-18`) for the person's gender.
String onbImage(String template, String gender) =>
    template.replaceAll('{g}', genderVariant(gender));

/// Option label, using the male wording when one exists and the person identifies as male.
String onbLabel(String label, String? labelM, String gender) =>
    gender == 'male' && labelM != null ? labelM : label;

// ------------------------------------------------------------ ads privacy

/// Version of the privacy notice shown in the consent sheet. Bump it when the
/// notice wording, shared data or recipients change so people are asked again.
const privacyNoticeVersion = 1;

/// Countries where ad measurement needs an explicit opt-in first
/// (EU + EEA, United Kingdom and Switzerland).
const consentCountries = {
  'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'DE', 'GR', 'HU',
  'IE', 'IT', 'LV', 'LT', 'LU', 'MT', 'NL', 'PL', 'PT', 'RO', 'SK', 'SI', 'ES',
  'SE', 'IS', 'LI', 'NO', 'GB', 'CH',
};

/// Consent regions — and unknown regions, to be safe — get the opt-in sheet.
bool isConsentRegion(String? country) {
  final c = country?.trim().toUpperCase() ?? '';
  return c.isEmpty || c.length != 2 || consentCountries.contains(c);
}

/// May app activity (installs, onboarding finished, purchases) be shared with
/// Meta for ad measurement? An explicit choice always wins; without one, consent
/// regions stay off and everyone else is on until they opt out in Profile.
/// A choice made on an older notice version counts as no choice.
bool adsMeasurementAllowed(String choice, int noticeVersion, String? country) {
  final decided = noticeVersion == privacyNoticeVersion;
  if (decided && choice == 'denied') return false;
  if (decided && choice == 'granted') return true;
  return !isConsentRegion(country);
}

/// Should the opt-in sheet be shown? Only in consent regions, and only until
/// the person has answered the current notice.
bool needsPrivacyChoice(String choice, int noticeVersion, String? country) =>
    isConsentRegion(country) &&
    (noticeVersion != privacyNoticeVersion || choice == 'unset');

// ------------------------------------------------------------ paywall offer

/// Which paywall variant to show. During onboarding the requested variant is
/// shown (regular → exit / gift); afterwards the app always repeats the last
/// offer the person saw in onboarding, so the in-app price never differs.
String paywallVariant(String from, String requested, String? savedOffer) {
  if (from == 'onboarding') return requested;
  return savedOffer ?? 'standard';
}

/// The "what's holding you back?" question is asked once ever, only when the
/// regular paywall is closed.
bool shouldAskExitSurvey(String variant, bool alreadyAsked) =>
    (variant == 'standard' || variant == 'regular') && !alreadyAsked;

/// Offer reveal only; neither answer grants access or starts a trial.
String? paywallSurveyOffer(String? reason) => switch (reason) {
  'price' => 'exit',
  'later' || 'unsure' => 'regular',
  _ => null,
};
