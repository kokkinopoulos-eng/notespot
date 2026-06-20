import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz_data.initializeTimeZones();
    try {
      final localName = DateTime.now().timeZoneName;
      // Best-effort: default to Europe/Athens for Greek users if mapping unknown
      tz.setLocalLocation(tz.getLocation('Europe/Athens'));
    } catch (_) {}
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    await _ensurePermissions();
  }

  Future<void> _ensurePermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleReminder(
      int noteId, String title, DateTime when) async {
    final tzWhen = tz.TZDateTime.from(when, tz.local);
    await _plugin.zonedSchedule(
      noteId,
      'SpotNote AI',
      title,
      tzWhen,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'notespot_reminders',
          'Υπενθυμίσεις',
          channelDescription: 'Υπενθυμίσεις σημειώσεων NoteSpot',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Wrapper that never throws, falls back to inexact if exact alarm denied
  Future<bool> trySchedule(int noteId, String title, DateTime when) async {
    try {
      await scheduleReminder(noteId, title, when);
      return true;
    } catch (_) {
      try {
        final tzWhen = tz.TZDateTime.from(when, tz.local);
        await _plugin.zonedSchedule(
          noteId,
          'SpotNote AI',
          title,
          tzWhen,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'notespot_reminders',
              'Υπενθυμίσεις',
              channelDescription: 'Υπενθυμίσεις σημειώσεων NoteSpot',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<void> cancelReminder(int noteId) async {
    await _plugin.cancel(noteId);
  }
}
