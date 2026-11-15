import 'package:flutter_test/flutter_test.dart';
import 'package:enso/services/audience_properties.dart';

void main() {
  test('exports four validated audience categories', () {
    expect(audienceProperties({'ageGroup': '50+', 'gender': 'female', 'style': 'walking', 'dailyMinutes': 10}), {
      'audience_age_group': '50+', 'audience_gender': 'female',
      'audience_style': 'walking', 'audience_daily_minutes': 10,
    });
  });
  test('private and health answers never leave the allowlist', () {
    expect(audienceProperties({'name': 'Private', 'goals': ['weight'], 'bodyType': 'plus', 'zones': ['back'], 'activity': 'sedentary', 'flexibilityCheck': 'no', 'balanceCheck': '<10', 'limitations': ['knees'], 'heightCm': 168, 'weightKg': 72, 'targetWeightKg': 66, 'stress': 5, 'reminder': '08:00'}), isEmpty);
  });
  test('eight extra quiz categories require explicit permission', () {
    final answers = {'goals': ['balance', 'weight'], 'limitations': ['knees'], 'activity': 'sedentary', 'balanceCheck': '<10', 'flexibilityCheck': 'no', 'bodyType': 'plus', 'zones': ['back'], 'stress': 5};
    expect(audienceProperties(answers), isEmpty);
    expect(audienceProperties(answers, quizConsent: true), {'audience_goals': ['balance', 'weight'], 'audience_limitations': ['knees'], 'audience_activity': 'sedentary', 'audience_balance_check': '<10', 'audience_flexibility_check': 'no', 'audience_body_type': 'plus', 'audience_zones': ['back'], 'audience_stress': 5});
  });
  test('private measurements and invalid categories remain excluded with permission', () {
    expect(audienceProperties({'name': 'Private', 'heightCm': 168, 'weightKg': 72, 'targetWeightKg': 66, 'goals': ['free text'], 'limitations': ['knees', 'private'], 'zones': ['unknown'], 'stress': 6}, quizConsent: true), isEmpty);
  });
  test('rejects arbitrary strings and invalid time values', () {
    expect(audienceProperties({'ageGroup': '82', 'gender': 'private text', 'style': 'private text', 'dailyMinutes': 99}), isEmpty);
    expect(audienceProperties({}), isEmpty);
  });
}