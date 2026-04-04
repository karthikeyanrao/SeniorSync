import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Schedule a DAILY medication reminder.
  /// Uses inexact mode — no special permission needed, fires within ~1 min of scheduled time.
  Future<void> scheduleMedicationReminder({
    required int id,
    required String medName,
    required String dosage,
    required TimeOfDay timeOfDay,
  }) async {
    await init();
    await _plugin.cancel(id);

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      '💊 Medication Time!',
      'Time to take $medName — $dosage',
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'med_reminders',
          'Medication Reminders',
          channelDescription: 'Daily medication reminders',
          importance: Importance.max,
          priority: Priority.high,
          color: const Color(0xFF2196F3),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      // exactAllowWhileIdle bypasses Android Doze to ensure it rings on time
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily
    );
  }

  /// Schedule routine reminders — daily or specific weekdays.
  Future<void> scheduleRoutineReminder({
    required int id,
    required String routineTitle,
    required TimeOfDay timeOfDay,
    required List<String> days,
  }) async {
    await init();
    await _plugin.cancel(id);

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    if (days.isEmpty || days.contains('All') || days.length == 7) {
      // Daily repeat
      await _plugin.zonedSchedule(
        id,
        '📋 Routine Reminder',
        'Time for your routine: $routineTitle',
        tz.TZDateTime.from(scheduledDate, tz.local),
        _routineNotifDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } else {
      // Per-weekday repeat
      final dayMap = {'Sun': 7, 'Mon': 1, 'Tue': 2, 'Wed': 3, 'Thu': 4, 'Fri': 5, 'Sat': 6};
      int subId = id;
      for (final day in days) {
        final targetWeekday = dayMap[day];
        if (targetWeekday == null) continue;

        DateTime nextDay = scheduledDate;
        while (nextDay.weekday != targetWeekday) {
          nextDay = nextDay.add(const Duration(days: 1));
        }

        await _plugin.zonedSchedule(
          subId++,
          '📋 Routine Reminder',
          'Time for your routine: $routineTitle',
          tz.TZDateTime.from(nextDay, tz.local),
          _routineNotifDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  NotificationDetails _routineNotifDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'routine_reminders',
        'Routine Reminders',
        channelDescription: 'Daily routine task reminders',
        importance: Importance.high,
        priority: Priority.high,
        color: const Color(0xFF4CAF50),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Cancel a specific scheduled notification
  Future<void> cancelNotification(int id) async {
    await init();
    await _plugin.cancel(id);
  }

  /// Show an IMMEDIATE notification — used for local SOS alerts on the caregiver device.
  Future<void> showImmediate({
    required int id,
    required String title,
    required String body,
    Color color = const Color(0xFFF44336),
  }) async {
    await init();
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'sos_alerts',
          'SOS & Emergency Alerts',
          channelDescription: 'Emergency and critical push alerts',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          color: color,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
