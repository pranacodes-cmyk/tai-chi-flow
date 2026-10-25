import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../state/app_state.dart';
import '../i18n/i18n.dart';

/// Daily practice reminders via Android local notifications.
class NotificationService {
  NotificationService._();
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  // a getter so the channel text follows the current app language
  static AndroidNotificationDetails get _channel => AndroidNotificationDetails(
    'enso_daily',
    tr('notify.channelName'),
    channelDescription: tr('notify.channelDescription'),
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
    color: Color(0xFF3F7A5C),
  );

  static Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('TaiChi Flow tz: $e');
    }
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('TaiChi Flow notifications init: $e');
    }
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  static Future<bool> requestPermission() async {
    await init();
    final granted = await _android?.requestNotificationsPermission();
    return granted ?? true;
  }

  /// Re-schedules one weekly notification per selected weekday.
  static Future<void> schedule(
    Reminders r, {
    required String name,
    required int minutes,
  }) async {
    await init();
    if (!_ready) return;
    for (var d = 0; d < 7; d++) {
      await _plugin.cancel(id: 100 + d);
    }
    if (!r.enabled) return;
    final body = tr('notify.body', {
      'hasName': name.isNotEmpty ? 'yes' : 'other',
      'name': name,
      'minutes': minutes,
    });
    final now = tz.TZDateTime.now(tz.local);
    for (final weekday in r.days) {
      // weekday: 0 = Sunday … 6 = Saturday; Dart: 1 = Monday … 7 = Sunday
      final dartWeekday = weekday == 0 ? 7 : weekday;
      var when = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        r.hour,
        r.minute,
      );
      while (when.weekday != dartWeekday || !when.isAfter(now)) {
        when = when.add(const Duration(days: 1));
      }
      try {
        await _plugin.zonedSchedule(
          id: 100 + weekday,
          title: tr('notify.title'),
          body: body,
          scheduledDate: when,
          notificationDetails: NotificationDetails(android: _channel),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      } catch (e) {
        debugPrint('TaiChi Flow schedule: $e');
      }
    }
  }

  static Future<void> showTest({
    required String name,
    required int minutes,
  }) async {
    await init();
    await requestPermission();
    await _plugin.show(
      id: 1,
      title: tr('notify.title'),
      body: tr('notify.body', {
        'hasName': name.isNotEmpty ? 'yes' : 'other',
        'name': name,
        'minutes': minutes,
      }),
      notificationDetails: NotificationDetails(android: _channel),
    );
  }
}
