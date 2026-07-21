import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

/// Notification IDs
/// 10-15 : Weekly attendance reminder (Mon=10, Tue=11, Wed=12, Thu=13, Fri=14, Sat=15)
/// 20-25 : Weekly homework reminder (same pattern)
/// 100+  : Real-time notice alerts

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // ── Init ────────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) return; // No local notifications on web

    tz.initializeTimeZones();
    // Set to India Standard Time
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    } catch (_) {}

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    // Request Android 13+ permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  // ── Notification details ────────────────────────────────────────────────────

  static const _attendanceChannel = AndroidNotificationChannel(
    'nemps_attendance',
    'Attendance Reminders',
    description: 'Daily attendance marking reminder',
    importance: Importance.high,
  );

  static const _homeworkChannel = AndroidNotificationChannel(
    'nemps_homework',
    'Homework Reminders',
    description: 'Daily homework submission reminder',
    importance: Importance.high,
  );

  static const _noticeChannel = AndroidNotificationChannel(
    'nemps_notices',
    'School Notices',
    description: 'Notice alerts from admin',
    importance: Importance.max,
  );

  static NotificationDetails _details(AndroidNotificationChannel channel) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  // ── Schedule daily reminders (Mon–Sat only) ─────────────────────────────────

  /// Schedule attendance reminder at 9:00 AM Mon–Sat.
  /// Sunday (weekday 7) is skipped by scheduling only days 1–6.
  static Future<void> scheduleDailyAttendanceReminder() async {
    if (kIsWeb) return;
    await init();

    // Cancel existing first
    for (int id = 10; id <= 15; id++) {
      await _plugin.cancel(id);
    }

    // Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6 in Dart's DateTime
    for (int day = 1; day <= 6; day++) {
      final scheduledTime = _nextWeekday(day, 9, 0);
      await _plugin.zonedSchedule(
        10 + (day - 1),
        '📋 Attendance Mark Karein',
        'Aaj ki class attendance abhi tak nahi bhari. Jaldi mark karein!',
        scheduledTime,
        _details(_attendanceChannel),
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  /// Schedule homework reminder at 12:00 PM Mon–Sat.
  static Future<void> scheduleDailyHomeworkReminder() async {
    if (kIsWeb) return;
    await init();

    for (int id = 20; id <= 25; id++) {
      await _plugin.cancel(id);
    }

    for (int day = 1; day <= 6; day++) {
      final scheduledTime = _nextWeekday(day, 12, 0);
      await _plugin.zonedSchedule(
        20 + (day - 1),
        '📚 Homework Update Karein',
        'Students ka homework status update karna baaki hai.',
        scheduledTime,
        _details(_homeworkChannel),
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  /// Cancel today's attendance + homework reminders (call when holiday marked).
  static Future<void> cancelTodayReminders() async {
    if (kIsWeb) return;
    await init();
    final today = DateTime.now().weekday; // 1=Mon...6=Sat
    if (today >= 1 && today <= 6) {
      await _plugin.cancel(10 + (today - 1)); // attendance
      await _plugin.cancel(20 + (today - 1)); // homework
    }
  }

  /// Re-schedule after a cancel so next week's occurrences still fire.
  static Future<void> rescheduleAfterHoliday() async {
    if (kIsWeb) return;
    await scheduleDailyAttendanceReminder();
    await scheduleDailyHomeworkReminder();
  }

  // ── Real-time notice notification ────────────────────────────────────────────

  static int _noticeCounter = 100;

  static Future<void> showNotice(String title, String body) async {
    if (kIsWeb) return;
    await init();
    await _plugin.show(
      _noticeCounter++,
      '📢 Notice: $title',
      body,
      _details(_noticeChannel),
    );
  }

  // ── Helper ──────────────────────────────────────────────────────────────────

  /// Returns the next occurrence of [weekday] (1=Mon…6=Sat) at [hour]:[minute].
  static tz.TZDateTime _nextWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Advance until we hit the right weekday
    while (scheduled.weekday != weekday ||
        scheduled.isBefore(now.add(const Duration(seconds: 5)))) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
