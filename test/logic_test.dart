// Mirrors src/lib/logic.test.ts — the same rules must hold on Android and web.
import 'dart:convert';
import 'dart:io';

import 'package:enso/data/content.dart';
import 'package:enso/data/models.dart';
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
    json = jsonDecode(File('assets/data/content.json').readAsStringSync()) as Map<String, dynamic>;
    Content.loadFromJson(json);
  });

  group('shared content', () {
    final webFile = File('../src/data/content.json');
    test('Android ships the same content as the web app', () {
      final web = webFile.readAsStringSync();
      expect(jsonEncode(jsonDecode(web)), jsonEncode(json));
    }, skip: webFile.existsSync() ? false : 'web project not present in this checkout');
    test('imports every extracted exercise', () {
      expect(Content.i.exercises.length, greaterThanOrEqualTo(319));
    });
    test('has the 19 real plan challenges, exactly 3 of them free', () {
      expect(Content.i.challengeIds.length, 19);
      final free = Content.i.challengeIds.where((id) => !Content.i.plan(id)!.premium).toList();
      expect(free, ['morning-energy-boost', 'evening-relax-stretch', 'desk-break-routine']);
    });
    test('quick sessions run exactly 10, 7 and 5 minutes including rests', () {
      final secs = {for (final q in Content.i.quickSessions) q.id: totalSeconds(q.items)};
      expect(secs, {'morning-energy-boost': 600, 'evening-relax-stretch': 420, 'desk-break-routine': 300});
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
    test('the daily Tai Chi practices run 60 days', () {
      expect(Content.i.dailyPlanIds, ['seated-tai-chi', 'standing-tai-chi']);
      for (final id in Content.i.dailyPlanIds) {
        expect(Content.i.plan(id)!.days.length, 60);
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
    String rec({List<String> goals = const [], String style = '', List<String> limitations = const [], String ageGroup = '30-39'}) =>
        recommendPlanId(goals: goals, style: style, limitations: limitations, ageGroup: ageGroup);
    test('puts limited mobility on seated Tai Chi', () => expect(rec(limitations: ['mobility']), 'seated-tai-chi'));
    test('weight goal gets the 30-day weight loss walking', () => expect(rec(goals: ['weight', 'balance']), 'weight-loss-walking'));
    test('balance for 50+ gets Tai Chi for Beginners', () => expect(rec(goals: ['balance'], ageGroup: '50+'), 'tai-chi-beginner'));
    test('defaults to the standing Tai Chi daily practice', () => expect(rec(), 'standing-tai-chi'));
    test('daily practice is seated for limited mobility', () {
      expect(dailyPlanId(limitations: ['mobility'], style: ''), 'seated-tai-chi');
      expect(dailyPlanId(limitations: [], style: 'tai-chi'), 'standing-tai-chi');
    });
  });

  group('sessions & premium', () {
    test('free programs are open on every day', () {
      final desk = Content.i.plan('desk-break-routine')!;
      expect(isDayLocked(desk, 1, false), false);
    });
    test('premium challenges open their first 3 days, day 4 needs Enso Plus', () {
      final plan = Content.i.plan('chair-yoga-30')!;
      expect(isDayLocked(plan, 3, false), false);
      expect(isDayLocked(plan, 4, false), true);
      expect(isDayLocked(plan, 4, true), false);
    });
    test('premium single workouts are locked without Enso Plus', () {
      final walk = Content.i.plan('cardio-boost-walk')!;
      expect(isPlanLocked(walk, false), true);
      expect(isPlanLocked(walk, true), false);
    });
    test('adds 10s rest between exercises', () => expect(totalSeconds(const [SessionItem('a', 60), SessionItem('b', 60)]), 130));
    test('scales calories by body weight against a 70 kg baseline', () => expect(kcalForWeight(35, 84), 42));
    test('resolves plan day sessions', () {
      final s = resolveSession('plan:standing-tai-chi:2');
      expect(s?.day, 2);
      expect(s!.items.length, greaterThan(3));
      expect(s.title, startsWith('Day 2 · '));
    });
    test('next plan day is the first not yet completed', () => expect(nextPlanDay(28, [1, 2, 4]), 3));
  });

  group('streaks', () {
    final today = DateTime(2026, 10, 17, 12);
    test('counts consecutive days ending today', () {
      expect(currentStreak([entry(DateTime(2026, 10, 15, 9)), entry(DateTime(2026, 10, 16, 9)), entry(DateTime(2026, 10, 17, 9))], today), 3);
    });
    test('keeps the streak alive until the end of today', () {
      expect(currentStreak([entry(DateTime(2026, 10, 15, 9)), entry(DateTime(2026, 10, 16, 9))], today), 2);
    });
    test('breaks after a missed day', () => expect(currentStreak([entry(DateTime(2026, 10, 14, 9))], today), 0));
    test('finds the best streak', () {
      expect(bestStreak([1, 2, 3, 5, 6].map((d) => entry(DateTime(2026, 10, d, 9))).toList()), 3);
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
      final restored = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
      expect(restored['profile']['name'], 'Mohit');
      expect(restored['premium']['plan'], 'yearly');
    });
  });
}
