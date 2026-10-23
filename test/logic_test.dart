// Mirrors src/lib/logic.test.ts — the same rules must hold on Android and web.
import 'dart:convert';
import 'dart:io';

import 'package:enso/data/content.dart';
import 'package:enso/data/models.dart';
import 'package:enso/logic/coach.dart';
import 'package:enso/logic/logic.dart';
import 'package:enso/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

HistoryEntry entry(DateTime d) => HistoryEntry(
  id: d.toIso8601String(),
  sessionId: 'quick:desk-break-routine',
  title: 'Desk',
  kind: 'workout',
  image: 'quick-desk',
  completedAt: d,
  durationSec: 300,
  kcal: 10,
);

void main() {
  late Map<String, dynamic> json;
  setUpAll(() {
    json = jsonDecode(
      File('assets/data/content.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    Content.loadFromJson(json);
  });

  group('shared content', () {
    final webFile = File('../src/data/content.json');
    test(
      'Android ships the same content as the web app',
      () {
        final web = webFile.readAsStringSync();
        expect(jsonEncode(jsonDecode(web)), jsonEncode(json));
      },
      skip: webFile.existsSync()
          ? false
          : 'web project not present in this checkout',
    );
    test(
      'ships exactly the curated movements that programs and classes use',
      () {
        final c = Content.i;
        final used = {
          for (final p in c.plans)
            for (final d in p.days)
              for (final it in d.items) it.e,
          for (final q in c.quickSessions)
            for (final it in q.items) it.e,
          for (final cat in c.categories)
            for (final it in cat.items) it.e,
        };
        final browsable = {for (final cat in c.categories) ...cat.exerciseIds};
        final shipped = {for (final e in c.exercises) e.id};
        expect(
          shipped
              .where((id) => !used.contains(id) && !browsable.contains(id))
              .toList(),
          isEmpty,
        );
        expect(used.where((id) => !shipped.contains(id)).toList(), isEmpty);
        for (final cat in c.categories) {
          expect(cat.exerciseIds.every(shipped.contains), isTrue);
        }
      },
    );
    test('free offer: 3 quick sessions + the 7-day starter + 4 meditations, everything else fully paid', () {
      final c = Content.i;
      final starter = c.plans.firstWhere((p) => p.id == 'tai-chi-starter-7');
      expect(starter.days.length, 7);
      for (final p in c.plans) {
        final quick = c.quickSessions.any((q) => q.id == p.id) || p.id == 'tai-chi-starter-7';
        if (quick) {
          expect([p.premium, p.freeDays], [false, p.days.length]);
        } else {
          expect([p.premium, p.freeDays], [true, 0]);
        }
      }
      expect(c.meditations.where((m) => !m.premium).length, 4);
    });
    test(
      'every extracted challenge still listed ships, exactly 3 of them free',
      () {
        for (final id in Content.i.challengeIds) {
          expect(Content.i.plan(id), isNotNull, reason: id);
        }
        final free = Content.i.challengeIds
            .where((id) => !Content.i.plan(id)!.premium)
            .toList();
        expect(free, [
          'morning-energy-boost',
          'evening-relax-stretch',
          'desk-break-routine',
        ]);
      },
    );
    test('quick sessions run exactly 10, 7 and 5 minutes including rests', () {
      final secs = {
        for (final q in Content.i.quickSessions) q.id: totalSeconds(q.items),
      };
      expect(secs, {
        'morning-energy-boost': 600,
        'evening-relax-stretch': 420,
        'desk-break-routine': 300,
      });
    });
    test('every program day references a real exercise', () {
      final missing = [
        for (final p in Content.i.plans)
          for (final d in p.days)
            for (final it in d.items)
              if (Content.i.exercise(it.e) == null) '${p.id}:${d.day}:${it.e}',
      ];
      expect(missing, isEmpty);
    });
    test('no two single-session routines are the same class', () {
      final seqs = [
        for (final p in Content.i.plans)
          if (p.days.length == 1)
            p.days.first.items.map((it) => it.e).join(','),
      ];
      expect(seqs.toSet().length, seqs.length);
    });
    test('multi-day programs never repeat one class for a whole week', () {
      for (final p in Content.i.plans.where((x) => x.days.length >= 7)) {
        for (var start = 0; start + 7 <= p.days.length; start++) {
          final week = {
            for (final d in p.days.sublist(start, start + 7))
              d.items.map((it) => it.e).join(','),
          };
          expect(
            week.length,
            greaterThanOrEqualTo(4),
            reason: '${p.id} days ${start + 1}-${start + 7}',
          );
        }
      }
    });
    test('the daily Tai Chi practices run 28 days', () {
      expect(Content.i.dailyPlanIds, ['seated-tai-chi', 'standing-tai-chi']);
      for (final id in Content.i.dailyPlanIds) {
        expect(Content.i.plan(id)!.days.length, 28);
      }
    });
    test('the catalogue ships 12 courses and 20 single sessions, every one on a shelf', () {
      final c = Content.i;
      final courses = c.plans.where((p) => p.days.length > 1).toList();
      final sessions = c.plans.where((p) => p.days.length == 1).toList();
      expect(courses.length, 12);
      expect(sessions.length, 20);
      for (final p in courses) {
        expect(c.planGroups, contains(p.group));
      }
      for (final p in sessions) {
        expect([...c.planGroups, 'Quick & free'], contains(p.group));
      }
    });
    test('Seated Tai Chi teaches 14 forms and graduates with all 14 in one flow', () {
      final days = Content.i.plan('seated-tai-chi')!.days;
      final taught = days
          .expand((d) => d.items.where((it) => it.p == 'New today').map((it) => it.e))
          .toSet()
        ..remove('guided-deep-breathing-seated-tai-chi');
      expect(taught.length, 14);
      expect(days[27].items.where((it) => it.p == 'Flow').map((it) => it.e).toSet().length, 14);
    });
    test(
      'Shibashi 18 teaches a new form every day and ends with all 18 forms',
      () {
        final days = Content.i.plan('shibashi-flow-18')!.days;
        expect(days.length, 18);
        final finale = days[17].items
            .where((it) => it.p == 'Flow')
            .map((it) => it.e);
        expect(finale.toSet().length, 18);
        for (final d in days.take(17)) {
          expect(d.items.any((it) => it.p == 'New today'), isTrue);
        }
      },
    );
    test('Eight Brocades ends with the complete set, the bow both ways', () {
      final days = Content.i.plan('standing-qigong-14')!.days;
      expect(days.length, 14);
      expect(
        days[13].items
            .where((it) => it.p == 'Flow')
            .map((it) => it.e)
            .toSet()
            .length,
        9,
      );
    });
    test(
      '28-Day Wall Pilates uses 34 movements and never repeats one inside a workout',
      () {
        final days = Content.i.plan('wall-pilates-28')!.days;
        expect(days.length, 28);
        expect(
          days.expand((d) => d.items.map((it) => it.e)).toSet().length,
          34,
        );
        for (final d in days) {
          final work = d.items
              .where((it) => it.p == 'Workout')
              .map((it) => it.e)
              .toList();
          expect(work.toSet().length, work.length, reason: 'day ${d.day}');
        }
      },
    );
    test('no third-party hosted media ships with the app', () {
      expect(jsonEncode(json).contains('firebasestorage'), isFalse);
    });
  });

  group('body metrics', () {
    test('computes BMI to one decimal', () => expect(bmi(170, 70), 24.2));
    test('classifies BMI bands', () {
      expect(bmiCategory(18.4), 'Underweight');
      expect(bmiCategory(24.9), 'Healthy');
      expect(bmiCategory(25), 'Overweight');
      expect(bmiCategory(30), 'Obese');
    });
    test('predicts 0.5 kg per week, at least 4 and at most 26 weeks', () {
      expect(predictWeeks(80, 75), 10);
      expect(predictWeeks(70, 69), 4);
      expect(predictWeeks(120, 70), 26);
    });
  });

  group('personal plan', () {
    String rec({
      List<String> goals = const [],
      String style = '',
      List<String> limitations = const [],
      String ageGroup = '30-39',
    }) => recommendPlanId(
      goals: goals,
      style: style,
      limitations: limitations,
      ageGroup: ageGroup,
    );
    test(
      'puts limited mobility on seated Tai Chi',
      () => expect(rec(limitations: ['mobility']), 'seated-tai-chi'),
    );
    test(
      'weight goal gets the 30-day weight loss walking',
      () => expect(rec(goals: ['weight', 'balance']), 'weight-loss-walking'),
    );
    test(
      'balance for 50+ starts Tai Chi Foundations',
      () =>
          expect(rec(goals: ['balance'], ageGroup: '50+'), 'tai-chi-beginner'),
    );
    test('qigong preference stays standing without mobility restriction', () {
      expect(rec(style: 'qigong'), 'standing-qigong-14');
      expect(rec(style: 'qigong', limitations: ['mobility']), 'seated-tai-chi');
    });
    test('standing newcomers start with Tai Chi Foundations', () {
      expect(rec(), 'tai-chi-beginner');
      expect(rec(style: 'tai-chi', goals: ['stress']), 'tai-chi-beginner');
    });
    test('daily practice is seated for limited mobility', () {
      expect(
        dailyPlanId(limitations: ['mobility'], style: ''),
        'seated-tai-chi',
      );
      expect(
        dailyPlanId(limitations: [], style: 'tai-chi'),
        'standing-tai-chi',
      );
    });
  });

  group('sessions & premium', () {
    test('free programs are open on every day', () {
      final desk = Content.i.plan('desk-break-routine')!;
      expect(isDayLocked(desk, 1, false), false);
    });
    test(
      'paid courses are fully locked from day 1 without TaiChi Flow Plus',
      () {
        final plan = Content.i.plan('wall-pilates-28')!;
        expect(isDayLocked(plan, 1, false), true);
        expect(isDayLocked(plan, 4, false), true);
        expect(isDayLocked(plan, 4, true), false);
      },
    );
    test('one meditation per everyday need is free', () {
      expect(Content.i.meditations.where((m) => !m.premium).map((m) => m.id).toList(), ['evening-wind-down', 'ocean-calm', 'box-breathing', 'morning-clarity']);
    });
    test('the player route cannot bypass a locked premium day', () {
      expect(isSessionLocked('plan:wall-pilates-28:1', false), true);
      expect(isSessionLocked('plan:wall-pilates-28:4', false), true);
      expect(isSessionLocked('plan:wall-pilates-28:4', true), false);
      expect(isSessionLocked('quick:desk-break-routine', false), false);
    });
    test('audited course equipment matches its actual practice', () {
      expect(Content.i.plan('desk-break-routine')!.equipment, 'none');
      for (final id in [
        'chair-strength',
        'gentle-flexibility-flow',
        'neck-shoulder-mobility',
        'chair-qigong-flow',
        'seated-tai-chi',
        'chair-yoga-weight-loss',
      ]) {
        expect(Content.i.plan(id)!.equipment, 'chair');
      }
      for (final id in [
        'wall-pilates-28',
        'wall-express',
        'wall-core-glutes',
      ]) {
        expect(Content.i.plan(id)!.equipment, 'wall');
      }
    });
    test('Tai Chi Foundations promises 21 days and schedules exactly 21', () {
      final taiChi = Content.i.plan('tai-chi-beginner')!;
      expect(taiChi.days.length, 21);
      expect(taiChi.subtitle, contains('21 days'));
    });
    test('Tai Chi Foundations ends with all 22 postures of the 24-form, first form first, closing last', () {
      const warmAndSettle = {
        'full-body-breathing-qigong',
        'twisting-waist-and-pushing-palms-shibashi',
        'guided-deep-breathing-standing',
      };
      final forms = Content.i
          .plan('tai-chi-beginner')!
          .days[20]
          .items
          .map((it) => it.e)
          .where((e) => !warmAndSettle.contains(e))
          .toList();
      expect(forms.toSet().length, 22);
      expect(forms.first, 'commencement-opening-form-standing');
      expect(forms.last, 'closing-form-standing');
    });
    test('every Tai Chi Foundations lesson is a different class', () {
      final days = Content.i
          .plan('tai-chi-beginner')!
          .days
          .map((d) => d.items.map((it) => it.e).join(','))
          .toSet();
      expect(days.length, 21);
    });
    test('Tai Chi Foundations lessons open with a warm-up, end settling, and label every movement', () {
      final taiChi = Content.i.plan('tai-chi-beginner')!;
      for (final d in taiChi.days) {
        expect(d.items.every((it) => it.p != null), true);
        expect(d.items.first.p, 'Warm-up');
        expect(d.items.last.p, 'Settle');
      }
      expect(
        taiChi.days[2].items
            .where((it) => it.p == 'New today')
            .map((it) => it.e)
            .toList(),
        ['white-crane-spreads-wings-standing'],
      );
    });
    test('premium single workouts are locked without TaiChi Flow Plus', () {
      final walk = Content.i.plan('cardio-boost-walk')!;
      expect(isPlanLocked(walk, false), true);
      expect(isPlanLocked(walk, true), false);
    });
    test(
      'adds 10s rest between exercises',
      () => expect(
        totalSeconds(const [SessionItem('a', 60), SessionItem('b', 60)]),
        130,
      ),
    );
    test(
      'scales calories by body weight against a 70 kg baseline',
      () => expect(kcalForWeight(35, 84), 42),
    );
    test('resolves plan day sessions', () {
      final s = resolveSession('plan:standing-tai-chi:2');
      expect(s?.day, 2);
      expect(s!.items.length, greaterThan(3));
      expect(s.title, startsWith('Day 2 · '));
    });
    test(
      'next plan day is the first not yet completed',
      () => expect(nextPlanDay(28, [1, 2, 4]), 3),
    );
  });

  group('streaks', () {
    final today = DateTime(2026, 10, 17, 12);
    test('counts consecutive days ending today', () {
      expect(
        currentStreak([
          entry(DateTime(2026, 10, 15, 9)),
          entry(DateTime(2026, 10, 16, 9)),
          entry(DateTime(2026, 10, 17, 9)),
        ], today),
        3,
      );
    });
    test('keeps the streak alive until the end of today', () {
      expect(
        currentStreak([
          entry(DateTime(2026, 10, 15, 9)),
          entry(DateTime(2026, 10, 16, 9)),
        ], today),
        2,
      );
    });
    test(
      'breaks after a missed day',
      () => expect(currentStreak([entry(DateTime(2026, 10, 14, 9))], today), 0),
    );
    test('finds the best streak', () {
      expect(
        bestStreak(
          [1, 2, 3, 5, 6].map((d) => entry(DateTime(2026, 10, d, 9))).toList(),
        ),
        3,
      );
    });
  });

  group('app state', () {
    test('completing a plan day records progress once', () {
      final s = AppState.memory();
      s.completeOnboarding('standing-tai-chi');
      final e = HistoryEntry(
        id: 'x',
        sessionId: 'plan:standing-tai-chi:1',
        title: 'Day 1',
        kind: 'workout',
        image: 'prog-standing-taichi',
        completedAt: DateTime.now(),
        durationSec: 600,
        kcal: 30,
        planId: 'standing-tai-chi',
        day: 1,
      );
      s.completeSession(e);
      s.completeSession(e);
      expect(s.planProgress['standing-tai-chi']!.completedDays, [1]);
      expect(s.history.length, 2);
    });
    test('state survives a JSON round trip', () {
      final s = AppState.memory();
      s.setProfile((p) => p.name = 'Mohit');
      s.setPremium('yearly');
      final restored =
          jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
      expect(restored['profile']['name'], 'Mohit');
      expect(restored['premium']['plan'], 'yearly');
    });
  });

  group('onboarding opening', () {
    test('opens straight with the breath chapter, no welcome host film', () {
      expect(Content.i.onboardingHost, isNull);
      expect(Content.i.onboardingChapters.any((c) => c.host != null), isFalse);
      expect(Content.i.onboardingChapters.first.breath, isTrue);
    });
    test('his breath cues have natural-voice clips', () {
      for (final p in [CoachBreath.inhale, CoachBreath.exhale]) {
        for (final l in CoachLines.onbBreath(p)) {
          expect(Content.i.voice.contains(voiceKey(l)), isTrue, reason: l);
        }
      }
    });
  });

  group('onboarding imagery', () {
    test('men see male photos, everyone else the female set', () {
      expect(genderVariant('male'), 'm');
      expect(genderVariant('female'), 'f');
      expect(genderVariant('other'), 'f');
    });
    test('resolves gender templates for age and body photos', () {
      expect(onbImage('onb-age-{g}-50', 'male'), 'onb-age-m-50');
      expect(onbImage('onb-body-{g}-plus', 'female'), 'onb-body-f-plus');
      expect(onbImage('onb-proof', 'male'), 'onb-proof');
    });
    test('uses male wording only when provided', () {
      expect(onbLabel('Curvy', 'Stocky', 'male'), 'Stocky');
      expect(onbLabel('Curvy', 'Stocky', 'female'), 'Curvy');
      expect(onbLabel('Slim', null, 'male'), 'Slim');
    });
    test('every templated onboarding photo exists for both genders', () {
      final keys = Content.i.onboarding
          .expand(
            (s) => [s.image ?? '', ...s.options.map((o) => o.image ?? '')],
          )
          .where((k) => k.isNotEmpty);
      for (final k in keys) {
        for (final g in ['male', 'female']) {
          expect(
            Content.i.imageFocus.containsKey(onbImage(k, g)),
            isTrue,
            reason: onbImage(k, g),
          );
        }
      }
    });
  });

  group('demo films', () {
    test('every movement has its own bundled demo film', () {
      final moves = Content.i.exercises.where((e) => !e.isAffirmation).toList();
      expect(moves.every((e) => e.demo != null), isTrue);
      for (final d in moves.map((e) => e.demo!).toSet()) {
        expect(File('assets/video/$d.mp4').existsSync(), isTrue, reason: d);
      }
    });
  });

  group('coach voice', () {
    test('hashes lines identically across clients', () {
      expect(voiceKey('Breathe in'), 'v1c9247bd');
      expect(voiceKey('Session complete. Beautifully done.'), 'vd714375a');
      expect(voiceKey('Tai Chi · 太極 — calm'), 'vf69244b6');
    });
    test('every line the players speak has a natural-voice clip or recorded provider refusal', () {
      final blockedFile =
          [
            File('../scripts/content/voice-blocked.json'),
            File('test/voice-blocked.json'),
          ].firstWhere(
            (f) => f.existsSync(),
            orElse: () => File('test/voice-blocked.json'),
          );
      final blocked = blockedFile.existsSync()
          ? (jsonDecode(blockedFile.readAsStringSync()) as Map).keys.toSet()
          : <dynamic>{};
      final missing = <String>[];
      void check(List<String> lines) {
        for (final line in lines) {
          final k = voiceKey(line);
          if (!Content.i.voice.contains(k) && !blocked.contains(k)) {
            missing.add(line);
          }
        }
      }

      final first = Content.i.exercises.first;
      check(CoachLines.begin(first));
      check(CoachLines.rest(first));
      check(CoachLines.finish());
      check(CoachLines.preview());
      for (final p in CoachBreath.values) {
        check(CoachLines.breath(p));
      }
      for (final e in Content.i.exercises) {
        check(CoachLines.start(e));
        for (var k = 0; k < e.steps.length; k++) {
          check(CoachLines.step(e, k));
        }
        if (e.isAffirmation) check(CoachLines.halfway(e, ''));
      }
      check(Content.i.affirmations);
      for (final m in Content.i.meditations) {
        check([for (final l in m.script) l.text]);
      }
      for (final g in Content.i.guides) {
        check(CoachLines.guide(g));
      }
      expect(missing, isEmpty);
      for (final k in Content.i.voice) {
        expect(File('assets/voice/$k.m4a').existsSync(), isTrue, reason: k);
      }
    });
    test('every movement has 3 to 5 spoken steps and a coach tip', () {
      expect(
        Content.i.exercises.where(
          (e) =>
              !e.isAffirmation &&
              (e.steps.length < 3 || e.steps.length > 5 || e.tip == null),
        ),
        isEmpty,
      );
    });
  });

  group('ads privacy', () {
    test('EU, EEA, UK, Switzerland and unknown regions need an opt-in', () {
      expect(isConsentRegion('DE'), isTrue);
      expect(isConsentRegion('gb'), isTrue);
      expect(isConsentRegion('CH'), isTrue);
      expect(isConsentRegion('NO'), isTrue);
      expect(isConsentRegion(null), isTrue);
      expect(isConsentRegion(''), isTrue);
      expect(isConsentRegion('US'), isFalse);
      expect(isConsentRegion('IN'), isFalse);
    });
    test('without an answer, sharing is off in consent regions and on elsewhere', () {
      expect(adsMeasurementAllowed('unset', 0, 'FR'), isFalse);
      expect(adsMeasurementAllowed('unset', 0, null), isFalse);
      expect(adsMeasurementAllowed('unset', 0, 'US'), isTrue);
    });
    test('an explicit answer to the current notice always wins', () {
      expect(adsMeasurementAllowed('granted', privacyNoticeVersion, 'DE'), isTrue);
      expect(adsMeasurementAllowed('denied', privacyNoticeVersion, 'US'), isFalse);
    });
    test('an answer to an older notice counts as no answer', () {
      expect(adsMeasurementAllowed('granted', privacyNoticeVersion - 1, 'DE'), isFalse);
      expect(needsPrivacyChoice('granted', privacyNoticeVersion - 1, 'DE'), isTrue);
    });
    test('the opt-in sheet shows only in consent regions until answered', () {
      expect(needsPrivacyChoice('unset', 0, 'IT'), isTrue);
      expect(needsPrivacyChoice('denied', privacyNoticeVersion, 'IT'), isFalse);
      expect(needsPrivacyChoice('unset', 0, 'IN'), isFalse);
    });
    test('the privacy answer survives saving and a data reset', () {
      final s = AppState.memory()..setAdsChoice('granted', 'DE');
      final restored = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
      expect((restored['privacy'] as Map)['ads'], 'granted');
      expect((restored['privacy'] as Map)['version'], privacyNoticeVersion);
      s.reset();
      expect(s.privacy.ads, 'granted');
    });
  });

  group('paywall offer', () {
    test('onboarding shows the requested variant', () {
      expect(paywallVariant('onboarding', 'exit', null), 'exit');
    });
    test('in the app the last onboarding offer is repeated', () {
      expect(paywallVariant('plan', 'regular', 'exit'), 'exit');
      expect(paywallVariant('home', 'regular', 'gift'), 'gift');
      expect(paywallVariant('home', 'regular', null), 'regular');
    });
    test('exit survey is asked only once, only on the regular paywall', () {
      expect(shouldAskExitSurvey('regular', false), isTrue);
      expect(shouldAskExitSurvey('regular', true), isFalse);
      expect(shouldAskExitSurvey('exit', false), isFalse);
    });
    test('saved offer and survey flag survive a save', () {
      final s = AppState.memory()
        ..setPaywallOffer('exit')
        ..markExitSurveyAsked();
      final j = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
      expect(j['paywallOffer'], 'exit');
      expect(j['exitSurveyAsked'], true);
    });
  });

  group('today free lead', () {
    test('features a free session by time of day', () {
      expect(freePickQuickId(7), 'morning-energy-boost');
      expect(freePickQuickId(14), 'desk-break-routine');
      expect(freePickQuickId(21), 'evening-relax-stretch');
      expect(freePickQuickId(2), 'evening-relax-stretch');
    });
    test('features the next unfinished starter day, then hands back to quick sessions', () {
      expect(freeStarterDay(7, []), 1);
      expect(freeStarterDay(7, [1, 2]), 3);
      expect(freeStarterDay(7, [1, 3]), 2);
      expect(freeStarterDay(7, [1, 2, 3, 4, 5, 6, 7]), null);
      final s = Content.i.plan(freeStarterId)!;
      expect([s.premium, s.freeDays, s.days.length], [false, 7, 7]);
    });
    test('leads with free only when the personal plan is locked', () {
      expect(homeLeadsWithFree(true), true);
      expect(homeLeadsWithFree(false), false);
    });
  });

  group('rating prompt', () {
    test('asks once per day after a session until rated', () {
      expect(shouldAskRating(false, null, '2026-10-23'), true);
      expect(shouldAskRating(false, '2026-10-23', '2026-10-23'), false);
      expect(shouldAskRating(false, '2026-10-22', '2026-10-23'), true);
      expect(shouldAskRating(true, '2026-10-22', '2026-10-23'), false);
    });
    test('sends 4-5 stars to the store, 1-3 to feedback', () {
      expect(ratingGoesToStore(5), true);
      expect(ratingGoesToStore(4), true);
      expect(ratingGoesToStore(3), false);
    });
  });

  test('featured meditation is free for people without Plus', () {
    expect(featuredMeditationId(20, false), 'evening-wind-down');
    expect(featuredMeditationId(20, true), 'moonlit-lake');
    expect(featuredMeditationId(8, false), 'morning-clarity');
  });
}
