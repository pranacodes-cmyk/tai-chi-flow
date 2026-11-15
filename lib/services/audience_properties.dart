/// Explicit allowlist; health-related categories require separate permission.
Map<String, Object> audienceProperties(Map<String, dynamic> answers, {bool quizConsent = false}) {
  final result = <String, Object>{};
  const choices = {
    'ageGroup': ['18-29', '30-39', '40-49', '50+'],
    'gender': ['female', 'male', 'other'],
    'style': ['tai-chi', 'qigong', 'walking', 'chair', 'mix'],
  };
  const keys = {'ageGroup': 'audience_age_group', 'gender': 'audience_gender', 'style': 'audience_style'};
  for (final entry in choices.entries) {
    final value = answers[entry.key];
    final key = keys[entry.key];
    if (key != null && value is String && entry.value.contains(value)) result[key] = value;
  }
  final minutes = answers['dailyMinutes'];
  if (minutes is int && const [5, 10, 15, 20].contains(minutes)) result['audience_daily_minutes'] = minutes;
  if (!quizConsent) return result;
  const singles = {
    'activity': ['sedentary', 'light', 'moderate', 'very'],
    'balanceCheck': ['30+', '10-30', '<10', 'unsure'],
    'flexibilityCheck': ['easily', 'almost', 'no'],
    'bodyType': ['slim', 'average', 'curvy', 'plus'],
  };
  const singleKeys = {'activity': 'audience_activity', 'balanceCheck': 'audience_balance_check', 'flexibilityCheck': 'audience_flexibility_check', 'bodyType': 'audience_body_type'};
  for (final entry in singles.entries) {
    final value = answers[entry.key];
    final key = singleKeys[entry.key];
    if (key != null && value is String && entry.value.contains(value)) result[key] = value;
  }
  const multi = {
    'goals': ['balance', 'flexibility', 'stress', 'bones', 'aging', 'weight', 'energy', 'core', 'sleep', 'wellbeing'],
    'limitations': ['knees', 'back', 'hips', 'mobility', 'none'],
    'zones': ['neck', 'back', 'arms', 'core', 'hips', 'legs'],
  };
  for (final entry in multi.entries) {
    final value = answers[entry.key];
    if (value is! List || value.isEmpty || value.any((v) => v is! String || !entry.value.contains(v))) continue;
    result['audience_${entry.key}'] = value.cast<String>().toSet().toList();
  }
  final stress = answers['stress'];
  if (stress is int && stress >= 1 && stress <= 5) result['audience_stress'] = stress;
  return result;
}
