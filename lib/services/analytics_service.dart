import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/app_state.dart';
import 'tracking_service.dart';

/// Product analytics (PostHog). Mirrors src/lib/analytics.ts.
///
/// Sends funnel events (screens, onboarding steps, paywall, survey, checkout,
/// purchases, lessons, ratings) with a random install ID. Gated by the same
/// privacy choice as ad measurement, so consent regions stay silent until the
/// person opts in. Never sends onboarding answers, health details, name or email.
class AnalyticsService {
  AnalyticsService._();

  /// Public project token (publishable by design).
  static const _token = 'phc_rwxgjM5jYDfd2jdGhZzLqfTPezKvPZRN3dx4UnvaHjEL';
  static const _host = 'https://us.i.posthog.com';
  static const _idKey = 'enso-analytics-id';

  static AppState? _app;
  static String? _id;
  static String _session = '';
  static DateTime _lastActive = DateTime.now();
  static String _version = '';
  static final List<Map<String, dynamic>> _queue = [];
  static Timer? _timer;
  static bool _wasOnboarded = false, _wasPremium = false;
  static int _history = 0;
  static String? _language;
  static String _screen = '';

  static bool get _native => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  static bool get _allowed => _native && TrackingService.allowed;

  static Future<void> init(AppState app) async {
    _app = app;
    _wasOnboarded = app.onboarded;
    _wasPremium = app.premium.active;
    _history = app.history.length;
    _language = app.language;
    _newSession();
    try {
      final p = await SharedPreferences.getInstance();
      _id = p.getString(_idKey);
      if (_id == null) {
        _id = _uuid();
        await p.setString(_idKey, _id!);
      }
      _version = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      _id ??= _uuid();
    }
    app.addListener(_onState);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => flush());
    capture('app_opened', {'first_open': app.history.isEmpty && !app.onboarded});
    identify();
  }

  static void _onState() {
    final a = _app;
    if (a == null) return;
    if (!_wasOnboarded && a.onboarded) capture('onboarding_completed');
    _wasOnboarded = a.onboarded;
    if (a.history.length > _history && a.history.isNotEmpty) {
      final e = a.history.last;
      capture('session_completed', {
        'session_id': e.sessionId,
        'kind': e.kind,
        'plan_id': e.planId,
        'day': e.day,
        'duration_sec': e.durationSec,
        'total_sessions': a.history.length,
        'first_session': a.history.length == 1,
      });
    }
    _history = a.history.length;
    if (!_wasPremium && a.premium.active) {
      capture('plus_activated', {'plan': a.premium.plan});
    }
    if (_wasPremium != a.premium.active || _language != a.language) identify();
    _wasPremium = a.premium.active;
    _language = a.language;
  }

  /// Person properties used to segment funnels (no personal data).
  static void identify() {
    final a = _app;
    if (a == null) return;
    capture(r'$set', {
      r'$set': {
        'language': a.language ?? 'auto',
        'plus': a.premium.active,
        'plus_plan': a.premium.plan,
        'onboarded': a.onboarded,
        'sessions_total': a.history.length,
        'paywall_offer': a.paywallOffer,
      },
    });
  }

  static void screen(String path) {
    if (path == _screen) return;
    _screen = path;
    capture(r'$screen', {r'$screen_name': path});
  }

  static void capture(String event, [Map<String, Object?> props = const {}]) {
    if (!_allowed || _id == null) return;
    final now = DateTime.now();
    if (now.difference(_lastActive).inMinutes >= 30) _newSession();
    _lastActive = now;
    final a = _app;
    _queue.add({
      'event': event,
      'distinct_id': _id,
      'timestamp': now.toUtc().toIso8601String(),
      'properties': {
        ...props,
        r'$session_id': _session,
        r'$os': Platform.isIOS ? 'iOS' : 'Android',
        r'$app_version': _version,
        r'$lib': 'taichi-flow-flutter',
        r'$screen_name': _screen,
        'language': a?.language ?? 'auto',
        'plus': a?.premium.active ?? false,
        'platform': Platform.isIOS ? 'ios' : 'android',
      },
    });
    if (_queue.length > 200) _queue.removeRange(0, _queue.length - 200);
    if (_queue.length >= 20 || event == 'purchase_completed') flush();
  }

  /// Send queued events; kept for retry if offline.
  static Future<void> flush() async {
    if (_queue.isEmpty) return;
    if (!_allowed) {
      _queue.clear();
      return;
    }
    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();
    try {
      final res = await http
          .post(Uri.parse('$_host/batch/'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'api_key': _token, 'batch': batch}))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode >= 500) _queue.insertAll(0, batch);
    } catch (_) {
      if (_queue.length + batch.length <= 200) _queue.insertAll(0, batch);
    }
  }

  static void paused() => unawaited(flush());

  static void _newSession() => _session = _uuid();

  static String _uuid() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
