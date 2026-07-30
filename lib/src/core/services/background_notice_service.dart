// Background Notice Check Service
//
// Problem this fixes: NotificationService.showNotice() (in
// notification_service.dart) is only ever called from inside a Supabase
// realtime stream listener (see features/data/providers.dart). That stream
// is only alive while the app process is running — if the user fully
// closes/kills the app, no code is listening anymore, so a new notice
// posted by the admin never triggers an alert.
//
// Fix: WorkManager runs a small background task periodically (Android
// enforces a 15-minute minimum interval for periodic tasks — this is an
// OS-level limit, not something an app can shorten). Each run does a
// lightweight REST call to Supabase (no need to boot the full Supabase SDK
// in a background isolate), compares the newest notice id against the last
// one we've already alerted for (kept in SharedPreferences, which persists
// across app restarts), and fires a local notification if it's new.
//
// Honest limitation: WorkManager periodic tasks run at most every ~15 min
// (Android platform limit) and some phone brands (Xiaomi/Vivo/Oppo/Realme
// and similar) aggressively kill background tasks unless the user manually
// disables battery optimization / enables "autostart" for the app. This is
// the most robust option achievable without standing up Firebase Cloud
// Messaging (which needs a Firebase project + server-side push credentials
// that only the school/dev can set up — a separate, bigger task). Attendance
// and homework reminders don't have this limitation: they use exact
// AlarmManager scheduling (see scheduleDailyAttendanceReminder /
// scheduleDailyHomeworkReminder in notification_service.dart), which
// reliably fires at the scheduled time even with the app fully closed.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../config/app_config.dart';
import 'notification_service.dart';

const String noticeCheckTaskName = 'nemps_notice_check';
const String _lastNoticeIdKey = 'nemps_last_alerted_notice_id';

class BackgroundNoticeService {
  BackgroundNoticeService._();

  /// Call once at app startup (main.dart). Registers a periodic background
  /// task that keeps checking for new notices even after the app is closed.
  static Future<void> init() async {
    if (kIsWeb) return; // WorkManager is Android/iOS only.
    try {
      await Workmanager().initialize(callbackDispatcher);
      await Workmanager().registerPeriodicTask(
        noticeCheckTaskName,
        noticeCheckTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (_) {
      // Best-effort: if WorkManager isn't supported on this platform/build,
      // the app should keep working normally without background alerts.
    }
  }

  /// Records the id of the notice the foreground stream listener just
  /// alerted for, so the background task doesn't re-alert for the same one
  /// the moment the app is reopened.
  static Future<void> markAlerted(String noticeId) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastNoticeIdKey, noticeId);
    } catch (_) {}
  }
}

/// Entry point WorkManager calls in a separate background isolate. Must stay
/// a top-level function (not a class method) and keep this exact signature.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != noticeCheckTaskName) return true;
    try {
      await _checkForNewNotice();
    } catch (_) {
      // Swallow errors — a failed background check should not crash the
      // task runner or affect the next scheduled run.
    }
    return true;
  });
}

Future<void> _checkForNewNotice() async {
  final uri = Uri.parse(
    '${AppConfig.supabaseUrl}/rest/v1/notices'
    '?select=id,title,body,created_at'
    '&order=created_at.desc&limit=1',
  );

  final response = await http.get(uri, headers: {
    'apikey': AppConfig.supabaseAnonKey,
    'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
  }).timeout(const Duration(seconds: 20));

  if (response.statusCode != 200) return;

  final rows = jsonDecode(response.body) as List;
  if (rows.isEmpty) return;

  final newest = rows.first as Map<String, dynamic>;
  final newestId = newest['id'] as String;

  final prefs = await SharedPreferences.getInstance();
  final lastId = prefs.getString(_lastNoticeIdKey);

  if (lastId != null && lastId == newestId) return; // already alerted

  if (lastId != null) {
    // Only alert if this is genuinely a notice we haven't seen before —
    // on the very first run (lastId == null) we just record it silently so
    // installing the app doesn't immediately fire an alert for old notices.
    await NotificationService.showNotice(
      (newest['title'] as String?) ?? 'Notice',
      (newest['body'] as String?) ?? '',
    );
  }
  await prefs.setString(_lastNoticeIdKey, newestId);
}
