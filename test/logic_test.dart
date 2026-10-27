// Mirrors src/lib/logic.test.ts — the same rules must hold on Android and web.
import 'dart:convert';
import 'dart:io';

import 'package:enso/data/content.dart';
import 'package:enso/data/models.dart';
import 'package:enso/i18n/i18n.dart';
import 'package:enso/logic/coach.dart';
import 'package:enso/logic/logic.dart';
import 'package:enso/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Yang 24-form in its true order (left/right and repeated forms are separate films).
const yang24 = [
  'commencement-opening-form-standing',
  'parting-the-wild-horses-mane-standing',
  'white-crane-spreads-wings-standing',
  'brush-knee-and-twist-step-standing',
  'play-the-lute-standing',
  'repulse-the-monkey-standing',
  'grasp-the-birds-tail-standing',
  'grasp-the-birds-tail-right-standing',
  'single-whip-standing',
  'wave-hands-like-clouds-standing',
  'single-whip-from-cloud-hands-standing',
  'high-pat-on-horse-standing',
  'kick-with-the-right-heel-standing',
  'strike-the-ears-with-both-fists-standing',
  'kick-with-the-left-heel-standing',
  'snake-creeps-down-and-golden-rooster-left-standing',
  'snake-creeps-down-and-golden-rooster-right-standing',
  'fair-lady-works-the-shuttles-standing',
  'needle-at-sea-bottom-standing',
  'fan-through-back-standing',
  'deflect-parry-and-punch-standing',
  'withdraw-and-push-standing',
  'cross-hands-standing',
  'closing-form-standing',
];

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
    test('free offer: 3 quick sessions + journey Days 1–2 + 4 meditations, everything else fully paid', () {
      final c = Content.i;
      for (final p in c.plans) {
        final quick = c.quickSessions.any((q) => q.id == p.id);
        if (quick) {
          expect([p.premium, p.freeDays], [false, p.days.length]);
        } else if (p.id == journeyId) {
          expect([p.premium, p.freeDays, p.days.length], [true, 2, 30]);
        } else {
          expect([p.premium, p.freeDays], [true, 0], reason: p.id);
        }
      }
      expect(c.meditations.where((m) => !m.premium).length, 4);
    });
    test('the 30-day journey teaches all 24 forms in their true order and day 30 flows through all of them', () {
      final days = Content.i.plan(journeyId)!.days;
      expect(
        days
            .expand((d) => d.items.where((it) => it.p == 'New today'))
            .map((it) => it.e)
            .toList(),
        yang24,
      );
      expect(
        days[29].items.where((it) => it.p == 'Flow').map((it) => it.e).toList(),
        yang24,
      );
      expect(days[0].items.first.e, 'squat-swing-standing');
    });
    test('no movement plays twice inside one journey lesson, and frail-looking warm-ups never appear', () {
      final days = Content.i.plan(journeyId)!.days;
      const frail = [
        'full-body-shaking-qigong',
        'knock-thighs-qigong',
        'knock-back-qigong',
        'hip-circles-qigong',
        'wise-owl-gazes-backward-qigong',
        'full-body-breathing-qigong',
      ];
      for (var i = 0; i < days.length; i++) {
        final ids = days[i].items.map((it) => it.e).toList();
        expect(ids.toSet().length, ids.length, reason: 'day ${i + 1}');
        expect(ids.where(frail.contains).toList(), isEmpty, reason: 'day ${i + 1}');
      }
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
    test('Daily Tai Chi never plays the same movement twice in one day', () {
      final days = Content.i.plan('standing-tai-chi')?.days ?? [];
      expect(days.length, 28);
      for (final d in days) {
        final ids = d.items.map((it) => it.e).toList();
        expect(ids.toSet().length, ids.length, reason: 'day ${d.day}');
      }
    });
    test('Daily Tai Chi day 1 has Opening and Wild Horse once, day 16 Single Whip once', () {
      final p = Content.i.plan('standing-tai-chi');
      expect(p, isNotNull);
      if (p == null) return;
      expect(
        p.days[0].items
            .where((it) => it.e == 'commencement-opening-form-standing')
            .length,
        1,
      );
      expect(
        p.days[0].items
            .where((it) => it.e == 'parting-the-wild-horses-mane-standing')
            .length,
        1,
      );
      expect(
        p.days[15].items.where((it) => it.e == 'single-whip-standing').length,
        1,
      );
      expect(
        p.days
            .map(
              (d) => d.items
                  .firstWhere((it) => it.p == 'Skill' || it.p == 'Flow')
                  .g,
            )
            .toSet()
            .length,
        28,
      );
    });
    test('lesson cue precedes normal instructions and older items keep existing guidance', () {
      final ex = Content.i.exercise('commencement-opening-form-standing');
      expect(ex, isNotNull);
      if (ex == null) return;
      const item = SessionItem(
        'commencement-opening-form-standing',
        60,
        'Flow',
        'Keep both feet grounded.',
      );
      expect(CoachLines.start(ex, item).last, 'Keep both feet grounded.');
      expect(CoachLines.step(ex, 1, item), [ex.steps.first]);
      expect(CoachLines.start(ex).last, ex.steps.first);
      expect(SessionItem.fromJson({'e': ex.id, 's': 60}).g, isNull);
    });
    test(
      'Seated Tai Chi teaches 14 forms and graduates with all 14 in one flow',
      () {
        final days = Content.i.plan('seated-tai-chi')!.days;
        final taught =
            days
                .expand(
                  (d) => d.items
                      .where((it) => it.p == 'New today')
                      .map((it) => it.e),
                )
                .toSet()
              ..remove('guided-deep-breathing-seated-tai-chi');
        expect(taught.length, 14);
        expect(
          days[27].items
              .where((it) => it.p == 'Flow')
              .map((it) => it.e)
              .toSet()
              .length,
          14,
        );
      },
    );
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
    test('Shibashi linked lessons contain the first seven and thirteen forms once in finale order', () {
      final plan = Content.i.plan('shibashi-flow-18');
      expect(plan, isNotNull);
      if (plan == null) return;
      final forms = plan.days[17].items.where((it) => it.p == 'Flow').map((it) => it.e).toList();
      for (final pair in [[5, 7], [11, 13]]) {
        expect(plan.days[pair[0]].items.where((it) => forms.contains(it.e)).map((it) => it.e).toList(), forms.take(pair[1]).toList());
      }
    });
    test('28-Day Wall Pilates uses 34 movements and never repeats one inside a workout', () {
      final days = Content.i.plan('wall-pilates-28')!.days;
      expect(days.length, 28);
      expect(days.expand((d) => d.items.map((it) => it.e)).toSet().length, 34);
      for (final d in days) {
        final work = d.items
            .where((it) => it.p == 'Workout')
            .map((it) => it.e)
            .toList();
        expect(work.toSet().length, work.length, reason: 'day ${d.day}');
      }
    });
    test('teaching courses play each movement once per flow; a form taught today returns once with its own guidance', () {
      const ids = ['tai-chi-beginner', 'seated-tai-chi', 'tai-chi-walking-30', 'shibashi-flow-18', 'standing-qigong-14'];
      for (final id in ids) {
        final plan = Content.i.plan(id);
        expect(plan, isNotNull);
        if (plan == null) continue;
        for (final d in plan.days) {
          final flow = d.items.where((it) => it.p == 'Flow').map((it) => it.e).toList();
          expect(flow.toSet().length, flow.length, reason: '$id day ${d.day}');
          // An explicitly labelled "Round 2" is a deliberate conditioning pass, not a repeat.
          final taught = d.items.where((it) => it.p != 'Round 2').toList();
          for (final e in taught.map((it) => it.e).toSet()) {
            final group = taught.where((it) => it.e == e).toList();
            if (group.length > 1) {
              expect(group.length, 2, reason: '$id day ${d.day}');
              expect(group.every((it) => (it.g ?? '').isNotEmpty), isTrue);
              expect(group.map((it) => it.g).toSet().length, 2);
            }
          }
          final first = d.items.firstWhere((it) => it.p != 'Warm-up');
          expect((first.g ?? '').isNotEmpty, isTrue, reason: '$id day ${d.day}');
        }
      }
    });
    test('chair blocks do not overlap within the first workout pass', () {
      final plan = Content.i.plan('chair-yoga-weight-loss');
      expect(plan, isNotNull);
      if (plan == null) return;
      for (final d in plan.days) {
        final work = d.items.where((it) => it.p == 'Workout').map((it) => it.e).toList();
        expect(work.toSet().length, work.length, reason: 'day ${d.day}');
      }
      expect(plan.days[2].items.where((it) => it.e == 'seated-knee-to-elbow-crunches-seated').length, 1);
      expect(plan.days[4].items.where((it) => it.e == 'seated-row-upper-back-squeeze-chair-yoga').length, 1);
    });
    test('retained conditioning rounds are explicitly coached', () {
      for (final p in Content.i.plans.where((p) => p.days.length > 1)) {
        for (final d in p.days) {
          for (var i = 0; i < d.items.length; i++) {
            final it = d.items[i];
            if (it.p == 'Round 2' && (i == 0 || d.items[i - 1].p != 'Round 2')) {
              expect((it.g ?? '').isNotEmpty, isTrue, reason: '${p.id} day ${d.day}');
            }
          }
        }
      }
      final brocades = Content.i.plan('standing-qigong-14');
      expect(brocades?.days[12].items.where((it) => it.p == 'Round 2').length, 0);
      expect(brocades?.days[12].items.where((it) => it.p == 'Flow').map((it) => it.s).toList(), List.filled(9, 70));
    });
    for (final id in ['shibashi-flow-18', 'standing-qigong-14']) {
      test('$id never repeats a movement or its film in the same lesson', () {
        final plan = Content.i.plan(id);
        expect(plan, isNotNull);
        if (plan == null) return;
        for (final day in plan.days) {
          final ids = day.items.map((it) => it.e).toList();
          expect(ids.toSet().length, ids.length, reason: '$id day ${day.day}');
          final films = ids.map((e) => Content.i.exercise(e)?.demo).whereType<String>().toList();
          expect(films.length, ids.length);
          expect(films.toSet().length, films.length, reason: '$id day ${day.day} films');
        }
      });
    }
    test('all lesson guidance has a bundled natural voice clip', () {
      final clips = Content.i.voice.toSet();
      for (final p in Content.i.plans) {
        for (final d in p.days) {
          for (final it in d.items.where((it) => (it.g ?? '').isNotEmpty)) {
            expect(clips.contains(voiceKey(it.g ?? '')), isTrue, reason: '${p.id} day ${d.day}');
          }
        }
      }
    });
    test('course warm-ups do not duplicate teaching work or settling', () {
      for (final p in Content.i.plans.where((p) => p.days.length > 1)) {
        for (final d in p.days) {
          final main = d.items.where((it) => it.p != 'Warm-up' && it.p != 'Round 2').map((it) => it.e).toSet();
          for (final it in d.items.where((it) => it.p == 'Warm-up')) {
            expect(main.contains(it.e), isFalse, reason: '${p.id} day ${d.day}: ${it.e}');
          }
        }
      }
    });
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
      'balance for 50+ starts the 30-day Tai Chi journey',
      () => expect(
        rec(goals: ['balance'], ageGroup: '50+'),
        'tai-chi-journey-30',
      ),
    );
    test('qigong preference stays standing without mobility restriction', () {
      expect(rec(style: 'qigong'), 'standing-qigong-14');
      expect(rec(style: 'qigong', limitations: ['mobility']), 'seated-tai-chi');
    });
    test('standing newcomers start with the 30-day Tai Chi journey', () {
      expect(rec(), 'tai-chi-journey-30');
      expect(rec(style: 'tai-chi', goals: ['stress']), 'tai-chi-journey-30');
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
      expect(
        Content.i.meditations
            .where((m) => !m.premium)
            .map((m) => m.id)
            .toList(),
        ['evening-wind-down', 'ocean-calm', 'box-breathing', 'morning-clarity'],
      );
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
    test('Tai Chi Foundations ends with all 24 forms flowed once each, first form first, closing last', () {
      final forms = Content.i
          .plan('tai-chi-beginner')!
          .days[20]
          .items
          .where((it) => it.p == 'Flow')
          .map((it) => it.e)
          .toList();
      expect(forms.length, 24);
      expect(forms.toSet().length, 24);
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
    test('every movement has its own demo film, bundled or on the lesson media server', () {
      final remote = ((jsonDecode(File('test/lesson-media.json').readAsStringSync()) as Map)['video'] as List).toSet();
      final moves = Content.i.exercises.where((e) => !e.isAffirmation).toList();
      expect(moves.every((e) => e.demo != null), isTrue);
      for (final d in moves.map((e) => e.demo!).toSet()) {
        expect(File('assets/video/$d.mp4').existsSync() || remote.contains(d), isTrue, reason: d);
      }
    });
    test('the paywall film and its poster are bundled, with no browser-only WebM', () {
      expect(File('assets/video/paywall-mountain.mp4').existsSync(), isTrue);
      expect(File('assets/images/paywall-mountain.jpg').existsSync(), isTrue);
      expect(Directory('assets/video').listSync().where((f) => f.path.endsWith('.webm')), isEmpty);
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
      final remote = ((jsonDecode(File('test/lesson-media.json').readAsStringSync()) as Map)['voice'] as List).toSet();
      for (final k in Content.i.voice) {
        expect(File('assets/voice/$k.m4a').existsSync() || remote.contains(k), isTrue, reason: k);
      }
      // onboarding and breathing never wait on a download
      for (final l in [...CoachLines.breath(CoachBreath.inhale), ...CoachLines.breath(CoachBreath.exhale), ...CoachLines.onbArrived()]) {
        expect(File('assets/voice/${voiceKey(l)}.m4a').existsSync(), isTrue, reason: l);
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
    test(
      'without an answer, sharing is off in consent regions and on elsewhere',
      () {
        expect(adsMeasurementAllowed('unset', 0, 'FR'), isFalse);
        expect(adsMeasurementAllowed('unset', 0, null), isFalse);
        expect(adsMeasurementAllowed('unset', 0, 'US'), isTrue);
      },
    );
    test('an explicit answer to the current notice always wins', () {
      expect(
        adsMeasurementAllowed('granted', privacyNoticeVersion, 'DE'),
        isTrue,
      );
      expect(
        adsMeasurementAllowed('denied', privacyNoticeVersion, 'US'),
        isFalse,
      );
    });
    test('an answer to an older notice counts as no answer', () {
      expect(
        adsMeasurementAllowed('granted', privacyNoticeVersion - 1, 'DE'),
        isFalse,
      );
      expect(
        needsPrivacyChoice('granted', privacyNoticeVersion - 1, 'DE'),
        isTrue,
      );
    });
    test('the opt-in sheet shows only in consent regions until answered', () {
      expect(needsPrivacyChoice('unset', 0, 'IT'), isTrue);
      expect(needsPrivacyChoice('denied', privacyNoticeVersion, 'IT'), isFalse);
      expect(needsPrivacyChoice('unset', 0, 'IN'), isFalse);
    });
    test('the privacy answer survives saving and a data reset', () {
      final s = AppState.memory()..setAdsChoice('granted', 'DE');
      final restored =
          jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
      expect((restored['privacy'] as Map)['ads'], 'granted');
      expect((restored['privacy'] as Map)['version'], privacyNoticeVersion);
      s.reset();
      expect(s.privacy.ads, 'granted');
    });
  });

  group('paywall offer', () {
    test('checking first reveals the regular trial offer without a purchase', () {
      expect(paywallSurveyOffer('later'), 'regular');
      expect(paywallSurveyOffer('unsure'), 'regular');
    });
    test('try first without trial eligibility reveals the lower offer instead of nothing', () {
      expect(paywallSurveyOffer('later', trialAvailable: false), 'exit');
      expect(paywallSurveyOffer('unsure', trialAvailable: false), 'exit');
    });
    test('price high reveals the lower exit offer', () {
      expect(paywallSurveyOffer('price'), 'exit');
    });
    test('dismissing the survey selects no offer', () {
      expect(paywallSurveyOffer(null), isNull);
    });
    test('onboarding shows the requested variant', () {
      expect(paywallVariant('onboarding', 'exit', null), 'exit');
    });
    test('in the app the last onboarding offer is repeated', () {
      expect(paywallVariant('plan', 'regular', 'exit'), 'exit');
      expect(paywallVariant('home', 'regular', 'gift'), 'gift');
      expect(paywallVariant('home', 'standard', null), 'standard');
      expect(paywallVariant('home', 'standard', 'regular'), 'regular');
    });
    test('exit survey is asked only once, only on the regular paywall', () {
      expect(shouldAskExitSurvey('standard', false), isTrue);
      expect(shouldAskExitSurvey('standard', true), isFalse);
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
    test('new people start on the 30-day journey', () {
      expect(defaultPlanId, journeyId);
      expect(Content.i.plan(defaultPlanId), isNotNull);
    });
    test('Today preserves an accessible personal plan and otherwise shows the journey', () {
      String pick(bool locked) => todayPlanId(
        'standing-qigong-14',
        activeLocked: locked,
      );
      expect(pick(false), 'standing-qigong-14');
      expect(pick(true), journeyId);
    });
    test('after free Days 1 and 2 Today keeps journey progress and locked Day 3, not Chair Yoga', () {
      final selected = todayPlanId('chair-yoga-weight-loss', activeLocked: true);
      expect(selected, journeyId);
      final plan = Content.i.plan(selected);
      expect(plan, isNotNull);
      if (plan == null) return;
      final completed = [1, 2];
      final next = nextPlanDay(plan.days.length, completed);
      expect(completed.length, 2);
      expect(plan.days.length, 30);
      expect(next, 3);
      expect(isDayLocked(plan, next, false), true);
    });
    test('finishing Day 2 previews the locked Day 3; Day 1, Plus members and the last day get no preview', () {
      final journey = Content.i.plan(journeyId)!;
      expect(lockedNextDay(journey, 2, false), 3);
      expect(lockedNextDay(journey, 1, false), null);
      expect(lockedNextDay(journey, 2, true), null);
      expect(lockedNextDay(journey, 30, false), null);
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

  // Mirrors src/lib/i18n.test.ts.
  group('languages', () {
    test('fills placeholders and keeps unknown ones visible', () {
      expect(formatMessage('Hi {name}, {n} min', {'name': 'Mohit', 'n': 12}), 'Hi Mohit, 12 min');
      expect(formatMessage('Hi {name}', {}), 'Hi {name}');
    });
    test("picks plural forms by each language's rules", () {
      const days = '{n, plural, one {# day} other {# days}}';
      expect(formatMessage(days, {'n': 1}, 'en'), '1 day');
      expect(formatMessage(days, {'n': 2}, 'en'), '2 days');
      expect(formatMessage(days, {'n': 0}, 'en'), '0 days');
      expect(formatMessage('{n, plural, one {# jour} other {# jours}}', {'n': 0}, 'fr'), '0 jour');
      expect(formatMessage('{n, plural, one {# dia} other {# dias}}', {'n': 1}, 'pt'), '1 dia');
      expect(formatMessage('{n, plural, other {#日}}', {'n': 1}, 'ja'), '1日');
      expect(formatMessage('{n, plural, =0 {none} one {# Tag} other {# Tage}}', {'n': 0}, 'de'), 'none');
      expect(pluralCategory('de', 1), 'one');
      expect(pluralCategory('it', 1.5), 'other');
      expect(pluralCategory('ja', 1), 'other');
    });
    test('agrees day counts in number on the real screens (1 day, 2 days)', () {
      Map<String, dynamic> bundle(String lang) =>
          jsonDecode(File('assets/data/i18n/content.$lang.json').readAsStringSync()) as Map<String, dynamic>;
      Content.loadFromJson(bundle('fr'), 'fr');
      expect(tr('home.streakDayStreak', {'n': 1}), 'Série de 1 jour');
      expect(tr('home.streakDayStreak', {'n': 2}), 'Série de 2 jours');
      expect(tr('home.doneOfTotalDays', {'done': 1, 'total': 30}), '1 jour sur 30');
      Content.loadFromJson(bundle('de'), 'de');
      expect(tr('home.streakDayStreak', {'n': 1}), '1 Tag in Folge');
      Content.loadFromJson(json);
      expect(tr('home.streakDayStreak', {'n': 1}), '1-day streak');
      expect(tr('home.doneOfTotalDays', {'done': 1, 'total': 30}), '1 of 30 days');
    });
    test('finds the arguments a message uses, inside plural and select branches too', () {
      expect(messageArgs('{price}/{period, select, month {month} other {year}} for {name}'), ['name', 'period', 'price']);
      expect(messageArgs('{n, plural, one {# day with {who}} other {# days}}'), ['n', 'who']);
    });
    test('handles selects with nested placeholders', () {
      const m = '{hasName, select, yes {{name}, your plan} other {Your plan}}';
      expect(formatMessage(m, {'hasName': 'yes', 'name': 'Mo'}), 'Mo, your plan');
      expect(formatMessage(m, {'hasName': 'no'}), 'Your plan');
    });
    test('looks keys up in the active language and splits lists and link templates', () {
      setI18n('de', {'a.b': 'Hallo {name}', 'a.list': 'S, M, D', 'a.legal': 'Mit {terms} und {privacy}.'});
      expect(tr('a.b', {'name': 'Ana'}), 'Hallo Ana');
      expect(tr('missing.key'), 'missing.key');
      expect(trList('a.list'), ['S', 'M', 'D']);
      expect(trParts('a.legal').map((p) => p.name ?? p.text).toList(), ['Mit ', 'terms', ' und ', 'privacy', '.']);
      Content.loadFromJson(json);
    });
    test('ships English plus every translated language, each loading in its own language', () {
      expect(supportedLanguages, ['en', 'es', 'pt', 'de', 'fr', 'it', 'ja']);
      for (final lang in supportedLanguages.skip(1)) {
        final file = File('assets/data/i18n/content.$lang.json');
        Content.loadFromJson(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>, lang);
        expect(appLang, lang);
        expect(Content.i.plans.map((p) => p.id), [for (final p in json['plans'] as List) p['id']]);
        final web = File('../src/data/i18n/content.$lang.json');
        if (web.existsSync()) expect(file.readAsStringSync(), web.readAsStringSync());
      }
      Content.loadFromJson(json);
      expect(appLang, 'en');
    });
    test('uses the saved choice, else the first device language we ship, else English', () {
      expect(resolveLanguage('ja', ['de-DE']), 'ja');
      expect(resolveLanguage(null, ['hi-IN', 'de-AT', 'en-US']), 'de');
      expect(resolveLanguage(null, ['pt-PT']), 'pt');
      expect(resolveLanguage(null, ['es_419']), 'es');
      expect(resolveLanguage('xx', ['fr-CA']), 'fr');
      expect(resolveLanguage(null, ['hi-IN', 'zh-CN']), 'en');
    });
    test('falls back to a device voice in the app language, English only in US or UK accents', () {
      expect(fallbackVoiceRank('en', 'en-US'), 0);
      expect(fallbackVoiceRank('en', 'en_GB'), 1);
      expect(fallbackVoiceRank('en', 'en-IN'), isNull);
      expect(fallbackVoiceRank('es', 'es-MX'), 0);
      expect(fallbackVoiceRank('es', 'es-ES'), 3);
      expect(fallbackVoiceRank('pt', 'pt-BR'), 0);
      expect(fallbackVoiceRank('pt', 'pt-PT'), 1);
      expect(fallbackVoiceRank('ja', 'ja-JP'), 0);
      expect(fallbackVoiceRank('ja', 'en-US'), isNull);
      expect(fallbackVoiceRank('de', 'de'), 1);
    });
  });
}
