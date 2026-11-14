import 'package:flutter_test/flutter_test.dart';
import 'package:enso/services/analytics_service.dart';

void main() {
  test('Android replay masks private content and excludes native payments', () {
    final config = AnalyticsService.replayConfig('existing-install-id', true);
    expect(config.sessionReplay, isTrue);
    expect(config.sessionReplayConfig.maskAllTexts, isTrue);
    expect(config.sessionReplayConfig.maskAllImages, isTrue);
    expect(config.sessionReplayConfig.maskCustomPaint, isTrue);
    expect(config.sessionReplayConfig.maskAllPlatformViews, isTrue);
    expect(config.sessionReplayConfig.captureNativeScreens, isFalse);
  });
  test('Opt-out disables SDK collection and identity stays historical', () {
    final config = AnalyticsService.replayConfig('existing-install-id', false);
    expect(config.optOut, isTrue);
    expect(config.bootstrap?.distinctId, 'existing-install-id');
    expect(config.captureApplicationLifecycleEvents, isFalse);
  });
  test('Health answers and personal screens are excluded, paywall and Today allowed', () {
    for (final path in ['/onboarding', '/plan-ready', '/profile', '/edit-profile', '/history', '/complete', '/achievements', '/reminders', '/settings', '']) {
      expect(AnalyticsService.replaySafeScreen(path), isFalse, reason: path);
    }
    expect(AnalyticsService.replaySafeScreen('/paywall'), isTrue);
    expect(AnalyticsService.replaySafeScreen('/'), isTrue);
  });
}