import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../logic/logic.dart';

/// App state — mirrors src/lib/store.ts (same keys, same defaults, same actions).
class AudioSettings {
  bool voice, music, beeps, haptics;
  String musicTrack;
  double musicVolume, voiceRate;
  AudioSettings({
    this.voice = true,
    this.music = true,
    this.musicTrack = 'music-bamboo',
    this.musicVolume = 0.5,
    this.voiceRate = 0.95,
    this.beeps = true,
    this.haptics = true,
  });
  Map<String, dynamic> toJson() => {
    'voice': voice,
    'music': music,
    'musicTrack': musicTrack,
    'musicVolume': musicVolume,
    'voiceRate': voiceRate,
    'beeps': beeps,
    'haptics': haptics,
  };
  factory AudioSettings.fromJson(Map<String, dynamic> j) => AudioSettings(
    voice: j['voice'] ?? true,
    music: j['music'] ?? true,
    musicTrack: j['musicTrack'] ?? 'music-bamboo',
    musicVolume: (j['musicVolume'] as num? ?? 0.5).toDouble(),
    voiceRate: (j['voiceRate'] as num? ?? 0.95).toDouble(),
    beeps: j['beeps'] ?? true,
    haptics: j['haptics'] ?? true,
  );
}

class Reminders {
  bool enabled;
  int hour, minute;
  List<int> days; // 0 = Sunday
  Reminders({
    this.enabled = true,
    this.hour = 8,
    this.minute = 0,
    List<int>? days,
  }) : days = days ?? [0, 1, 2, 3, 4, 5, 6];
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'hour': hour,
    'minute': minute,
    'days': days,
  };
  factory Reminders.fromJson(Map<String, dynamic> j) => Reminders(
    enabled: j['enabled'] ?? true,
    hour: (j['hour'] as num? ?? 8).toInt(),
    minute: (j['minute'] as num? ?? 0).toInt(),
    days: (j['days'] as List? ?? [0, 1, 2, 3, 4, 5, 6])
        .map((e) => (e as num).toInt())
        .toList(),
  );
}

class PlanProgress {
  final DateTime startedAt;
  final List<int> completedDays;
  PlanProgress(this.startedAt, this.completedDays);
  Map<String, dynamic> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'completedDays': completedDays,
  };
  factory PlanProgress.fromJson(Map<String, dynamic> j) => PlanProgress(
    DateTime.parse(j['startedAt']),
    (j['completedDays'] as List).map((e) => (e as num).toInt()).toList(),
  );
}

class Premium {
  final bool active;
  final String? plan;
  final DateTime? since;
  const Premium({this.active = false, this.plan, this.since});
  Map<String, dynamic> toJson() => {
    'active': active,
    'plan': plan,
    'since': since?.toIso8601String(),
  };
  factory Premium.fromJson(Map<String, dynamic> j) => Premium(
    active: j['active'] ?? false,
    plan: j['plan'],
    since: j['since'] == null ? null : DateTime.parse(j['since']),
  );
}

/// Ad-measurement choice with its evidence: which notice version was answered,
/// when, and the region the device reported at that moment.
class PrivacyChoice {
  final String ads; // unset | granted | denied
  final int version;
  final DateTime? decidedAt;
  final String? country;
  const PrivacyChoice({
    this.ads = 'unset',
    this.version = 0,
    this.decidedAt,
    this.country,
  });
  Map<String, dynamic> toJson() => {
    'ads': ads,
    'version': version,
    'decidedAt': decidedAt?.toIso8601String(),
    'country': country,
  };
  factory PrivacyChoice.fromJson(Map<String, dynamic> j) => PrivacyChoice(
    ads: j['ads'] is String ? j['ads'] : 'unset',
    version: (j['version'] as num?)?.toInt() ?? 0,
    decidedAt: j['decidedAt'] == null
        ? null
        : DateTime.tryParse(j['decidedAt'].toString()),
    country: j['country'] as String?,
  );
}

class WeightPoint {
  final DateTime date;
  final double kg;
  WeightPoint(this.date, this.kg);
  Map<String, dynamic> toJson() => {'date': date.toIso8601String(), 'kg': kg};
  factory WeightPoint.fromJson(Map<String, dynamic> j) =>
      WeightPoint(DateTime.parse(j['date']), (j['kg'] as num).toDouble());
}

const offerMinutes = 15;
const _storageKey = 'enso-state-v1';

class AppState extends ChangeNotifier {
  AppState._(this._prefs);
  final SharedPreferences? _prefs;

  bool onboarded = false;
  Profile profile = Profile();
  String activePlanId = defaultPlanId;
  Map<String, PlanProgress> planProgress = {};
  List<HistoryEntry> history = [];
  Premium premium = const Premium();
  DateTime? offerExpiresAt;
  /// Last paywall offer seen during onboarding; the app repeats it afterwards.
  String? paywallOffer;
  bool exitSurveyAsked = false;
  bool ratedApp = false;
  String? ratePromptDay;
  Reminders reminders = Reminders();
  AudioSettings audio = AudioSettings();
  Map<String, String> challenges = {};
  List<String> favorites = [];
  List<WeightPoint> weightLog = [];
  List<String> downloads = [];
  PrivacyChoice privacy = const PrivacyChoice();

  Timer? _saveTimer;

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = AppState._(prefs);
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        s._fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('TaiChi Flow: could not restore state ($e) — starting fresh');
      }
    }
    return s;
  }

  /// In-memory instance for tests.
  @visibleForTesting
  factory AppState.memory() => AppState._(null);

  Map<String, dynamic> toJson() => {
    'onboarded': onboarded,
    'profile': profile.toJson(),
    'activePlanId': activePlanId,
    'planProgress': planProgress.map((k, v) => MapEntry(k, v.toJson())),
    'history': history.map((h) => h.toJson()).toList(),
    'premium': premium.toJson(),
    'offerExpiresAt': offerExpiresAt?.toIso8601String(),
    'paywallOffer': paywallOffer,
    'exitSurveyAsked': exitSurveyAsked,
    'ratedApp': ratedApp,
    'ratePromptDay': ratePromptDay,
    'reminders': reminders.toJson(),
    'audio': audio.toJson(),
    'challenges': challenges,
    'favorites': favorites,
    'weightLog': weightLog.map((w) => w.toJson()).toList(),
    'downloads': downloads,
    'privacy': privacy.toJson(),
  };

  void _fromJson(Map<String, dynamic> j) {
    onboarded = j['onboarded'] ?? false;
    profile = Profile.fromJson(
      (j['profile'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    activePlanId = j['activePlanId'] ?? defaultPlanId;
    // plans from older content versions fall back to the person's recommended plan
    if (Content.i.plan(activePlanId) == null) {
      activePlanId = recommendFor(profile);
    }
    planProgress = ((j['planProgress'] as Map?) ?? {}).map(
      (k, v) => MapEntry(
        k as String,
        PlanProgress.fromJson((v as Map).cast<String, dynamic>()),
      ),
    );
    history = ((j['history'] as List?) ?? [])
        .map((e) => HistoryEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    premium = Premium.fromJson(
      (j['premium'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    offerExpiresAt = j['offerExpiresAt'] == null
        ? null
        : DateTime.parse(j['offerExpiresAt']);
    paywallOffer = j['paywallOffer'] as String?;
    exitSurveyAsked = j['exitSurveyAsked'] == true;
    ratedApp = j['ratedApp'] == true;
    ratePromptDay = j['ratePromptDay'] as String?;
    reminders = Reminders.fromJson(
      (j['reminders'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    audio = AudioSettings.fromJson(
      (j['audio'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    challenges = ((j['challenges'] as Map?) ?? {}).map(
      (k, v) => MapEntry(k as String, v as String),
    );
    favorites = ((j['favorites'] as List?) ?? []).cast<String>().toList();
    weightLog = ((j['weightLog'] as List?) ?? [])
        .map((e) => WeightPoint.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    downloads = ((j['downloads'] as List?) ?? []).cast<String>().toList();
    privacy = PrivacyChoice.fromJson(
      (j['privacy'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }

  void _commit() {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), () {
      _prefs?.setString(_storageKey, jsonEncode(toJson()));
    });
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    await _prefs?.setString(_storageKey, jsonEncode(toJson()));
  }

  // ------------------------------------------------------------ derived

  Plan get activePlan =>
      Content.i.plan(activePlanId) ?? Content.i.plan(defaultPlanId)!;
  List<int> get activeCompleted =>
      planProgress[activePlanId]?.completedDays ?? const [];

  int get plansCompleted => planProgress.entries.where((e) {
    final p = Content.i.plan(e.key);
    return p != null && e.value.completedDays.length >= p.days.length;
  }).length;

  Stats get stats => computeStats(history, DateTime.now(), plansCompleted);
  List<String> get unlocked => unlockedAchievements(stats);

  // ------------------------------------------------------------ actions

  void setProfile(void Function(Profile p) patch) {
    patch(profile);
    _commit();
  }

  void replaceProfile(Profile p) {
    profile = p;
    _commit();
  }

  void completeOnboarding(String planId) {
    onboarded = true;
    activePlanId = planId;
    planProgress.putIfAbsent(planId, () => PlanProgress(DateTime.now(), []));
    if (weightLog.isEmpty) {
      weightLog = [WeightPoint(DateTime.now(), profile.weightKg)];
    }
    _commit();
  }

  void startPlan(String planId) {
    activePlanId = planId;
    planProgress.putIfAbsent(planId, () => PlanProgress(DateTime.now(), []));
    _commit();
  }

  void restartPlan(String planId) {
    activePlanId = planId;
    planProgress[planId] = PlanProgress(DateTime.now(), []);
    _commit();
  }

  void completeSession(HistoryEntry entry) {
    if (entry.planId != null && entry.day != null) {
      final current =
          planProgress[entry.planId!] ?? PlanProgress(entry.completedAt, []);
      if (!current.completedDays.contains(entry.day)) {
        planProgress[entry.planId!] = PlanProgress(
          current.startedAt,
          [...current.completedDays, entry.day!]..sort(),
        );
      }
    }
    history = [...history, entry];
    _commit();
  }

  void rateEntry(String id, int feeling) {
    for (final h in history) {
      if (h.id == id) h.feeling = feeling;
    }
    _commit();
  }

  void setPremium(String plan) {
    premium = Premium(active: true, plan: plan, since: DateTime.now());
    _commit();
  }

  void cancelPremium() {
    premium = const Premium();
    _commit();
  }

  void setPaywallOffer(String offer) {
    paywallOffer = offer;
    _commit();
  }

  void markExitSurveyAsked() {
    exitSurveyAsked = true;
    _commit();
  }

  void markRatePrompted(String day) {
    ratePromptDay = day;
    _commit();
  }

  void setRatedApp() {
    ratedApp = true;
    _commit();
  }

  DateTime ensureOffer() {
    final existing = offerExpiresAt;
    if (existing != null && existing.isAfter(DateTime.now())) return existing;
    final next = DateTime.now().add(const Duration(minutes: offerMinutes));
    offerExpiresAt = next;
    _commit();
    return next;
  }

  void setReminders(void Function(Reminders r) patch) {
    patch(reminders);
    _commit();
  }

  void setAudio(void Function(AudioSettings a) patch) {
    patch(audio);
    _commit();
  }

  void setChallenge(String key, String status) {
    challenges = {...challenges, key: status};
    _commit();
  }

  void toggleFavorite(String id) {
    favorites = favorites.contains(id)
        ? favorites.where((f) => f != id).toList()
        : [...favorites, id];
    _commit();
  }

  void logWeight(double kg) {
    weightLog = [...weightLog, WeightPoint(DateTime.now(), kg)];
    profile.weightKg = kg;
    _commit();
  }

  /// Records the person's ad-measurement answer for the current notice version.
  void setAdsChoice(String choice, String? country) {
    privacy = PrivacyChoice(
      ads: choice,
      version: privacyNoticeVersion,
      decidedAt: DateTime.now(),
      country: country,
    );
    _commit();
  }

  void toggleDownload(String id) {
    downloads = downloads.contains(id)
        ? downloads.where((d) => d != id).toList()
        : [...downloads, id];
    _commit();
  }

  void reset() {
    onboarded = false;
    profile = Profile();
    activePlanId = defaultPlanId;
    planProgress = {};
    history = [];
    premium = const Premium();
    offerExpiresAt = null;
    paywallOffer = null;
    exitSurveyAsked = false;
    ratedApp = false;
    ratePromptDay = null;
    reminders = Reminders();
    audio = AudioSettings();
    challenges = {};
    favorites = [];
    weightLog = [];
    downloads = [];
    // The privacy answer is a consent record, not practice data, so a reset keeps it.
    _commit();
  }
}
