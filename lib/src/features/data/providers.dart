import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/models.dart';
import '../../core/services/notification_service.dart';
import 'school_repository.dart';

final repoProvider =
    Provider((_) => SchoolRepository(Supabase.instance.client));

// ── Real-time StreamProviders ─────────────────────────────────────────────────

/// Teacher's assigned classes — updates instantly when admin adds/removes a class.
final classesProvider = StreamProvider<List<ClassRoom>>((ref) {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id ?? '';

  return client
      .from('teacher_classes')
      .stream(primaryKey: ['teacher_id', 'class_id'])
      .eq('teacher_id', uid)
      .asyncMap((_) => ref.read(repoProvider).myClasses());
});

/// Students in a class — updates instantly when admin adds/moves/removes a student.
final studentsProvider =
    StreamProvider.family<List<Student>, String>((ref, classId) {
  final client = Supabase.instance.client;

  return client
      .from('students')
      .stream(primaryKey: ['id'])
      .eq('class_id', classId)
      .order('roll_no')
      .map((rows) => rows
          .where((r) => r['active'] == true)
          .map((r) => Student.fromMap(r))
          .toList());
});

/// Homework for a class — updates when any teacher adds new homework.
final homeworkProvider =
    StreamProvider.family<List<Homework>, String>((ref, classId) {
  final client = Supabase.instance.client;

  return client
      .from('homework')
      .stream(primaryKey: ['id'])
      .eq('class_id', classId)
      .order('assigned_date', ascending: false)
      .map((rows) => rows.take(30).map((r) => Homework.fromMap(r)).toList());
});

/// Notices for a class — updates when admin sends a new notice.
/// Also triggers a push notification for new notices.
final noticesProvider =
    StreamProvider.family<List<Notice>, String>((ref, classId) {
  final client = Supabase.instance.client;

  String? lastNoticeId;

  return client
      .from('notices')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) {
        final filtered = rows
            .where((r) =>
                r['audience_class_id'] == classId ||
                r['audience_class_id'] == null)
            .take(20)
            .map((r) => Notice.fromMap(r))
            .toList();

        // Show push notification for the newest notice if it's new
        if (filtered.isNotEmpty) {
          final newest = filtered.first;
          if (lastNoticeId != null && lastNoticeId != newest.id) {
            // A new notice arrived — push a notification
            NotificationService.showNotice(newest.title, newest.body);
          }
          lastNoticeId = newest.id;
        } else {
          lastNoticeId = null;
        }

        return filtered;
      });
});

/// Global notices stream (no class filter) — used on dashboard for teachers.
final allNoticesProvider = StreamProvider<List<Notice>>((ref) {
  final client = Supabase.instance.client;
  String? lastNoticeId;

  return client
      .from('notices')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) {
        final notices = rows.take(10).map((r) => Notice.fromMap(r)).toList();

        // Show push notification for new notices
        if (notices.isNotEmpty) {
          final newest = notices.first;
          if (lastNoticeId != null && lastNoticeId != newest.id) {
            NotificationService.showNotice(newest.title, newest.body);
          }
          lastNoticeId = newest.id;
        } else {
          lastNoticeId = null;
        }
        return notices;
      });
});

// ── Theme ─────────────────────────────────────────────────────────────────────

final themeProvider = StateProvider<ThemeMode>((_) => ThemeMode.system);

// ── Role (one-time fetch, changes rarely) ────────────────────────────────────

final currentUserRoleProvider = FutureProvider<UserRole>(
    (ref) => ref.watch(repoProvider).getCurrentUserRole());

// ── Attendance — REAL-TIME StreamProviders ────────────────────────────────────

/// Real-time stream of all attendance rows for [classId] (all dates).
final _rawAttendanceStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, classId) {
  return Supabase.instance.client
      .from('attendance')
      .stream(primaryKey: ['id'])
      .eq('class_id', classId);
});

/// Whether today's attendance has been started for [classId].
final attendanceDoneTodayProvider =
    StreamProvider.family<bool, String>((ref, classId) {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  return ref
      .watch(_rawAttendanceStreamProvider(classId).stream)
      .map((rows) => rows.any((r) => r['date'] == today));
});

/// Live present/absent/holiday count for [classId] on [date].
final dailyAttendanceCountProvider =
    StreamProvider.family<Map<String, int>, (String, DateTime)>((ref, params) {
  final (classId, date) = params;
  final dateStr = date.toIso8601String().substring(0, 10);
  return ref
      .watch(_rawAttendanceStreamProvider(classId).stream)
      .map((rows) {
    int present = 0, absent = 0, holiday = 0;
    for (final r in rows) {
      if (r['date'] != dateStr) continue;
      if (r['status'] == 'present') present++;
      else if (r['status'] == 'absent') absent++;
      else if (r['status'] == 'holiday') holiday++;
    }
    return {'present': present, 'absent': absent, 'holiday': holiday};
  });
});

/// Absent students for [classId] on [date].
final absentStudentsProvider =
    FutureProvider.family<List<Student>, (String, DateTime)>((ref, params) {
  final (classId, date) = params;
  return ref.watch(repoProvider).getAbsentStudents(classId, date);
});

final presentStudentsProvider =
    FutureProvider.family<List<Student>, (String, DateTime)>((ref, params) {
  final (classId, date) = params;
  return ref.watch(repoProvider).getPresentStudents(classId, date);
});

// ── Homework status — REAL-TIME ───────────────────────────────────────────────

final homeworkStatusStreamProvider =
    StreamProvider.family<Map<String, String>, String>((ref, homeworkId) {
  return Supabase.instance.client
      .from('homework_status')
      .stream(primaryKey: ['id'])
      .eq('homework_id', homeworkId)
      .map((rows) => {
            for (final r in rows)
              r['student_id'] as String: r['status'] as String,
          });
});

final homeworkStatusProvider =
    FutureProvider.family<List<HomeworkStatusRecord>, String>(
        (ref, homeworkId) =>
            ref.watch(repoProvider).getHomeworkStatus(homeworkId));

final attendanceDoneTodayFutureProvider =
    FutureProvider.family<bool, String>((ref, classId) =>
        ref.watch(repoProvider).isAttendanceDoneToday(classId));

final homeworkForDateProvider =
    FutureProvider.family<List<Homework>, (String, DateTime)>((ref, params) {
  final (classId, date) = params;
  return ref.watch(repoProvider).getHomeworkForDate(classId, date);
});

final whatsappGroupLinkProvider =
    FutureProvider.family<String?, String>((ref, classId) =>
        ref.watch(repoProvider).getWhatsAppGroupLink(classId));

final whatsappSentStudentsProvider =
    FutureProvider.family<Set<String>, (String, DateTime, String)>(
        (ref, params) {
  final (classId, date, type) = params;
  return ref.watch(repoProvider).getWhatsAppSentStudents(
        classId: classId,
        date: date,
        type: type,
      );
});

// ── Admin providers ───────────────────────────────────────────────────────────

final allClassesProvider = StreamProvider<List<ClassRoom>>((ref) {
  final client = Supabase.instance.client;
  return client
      .from('classes')
      .stream(primaryKey: ['id'])
      .order('name')
      .map((rows) => rows.map((r) => ClassRoom.fromMap(r)).toList());
});

final allTeachersProvider = StreamProvider<List<TeacherProfile>>((ref) {
  final client = Supabase.instance.client;
  return client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .order('full_name')
      .map((rows) => rows.map((r) => TeacherProfile.fromMap(r)).toList());
});

final teacherAssignedClassesProvider =
    FutureProvider.family<List<ClassRoom>, String>(
        (ref, teacherId) =>
            ref.watch(repoProvider).getTeacherAssignedClasses(teacherId));

final allStudentsProvider = StreamProvider<List<Student>>((ref) {
  final client = Supabase.instance.client;
  return client
      .from('students')
      .stream(primaryKey: ['id'])
      .order('full_name')
      .map((rows) => rows
          .where((r) => r['active'] == true)
          .map((r) => Student.fromMap(r))
          .toList());
});
