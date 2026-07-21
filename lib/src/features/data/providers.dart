import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/models.dart';
import 'school_repository.dart';

final repoProvider =
    Provider((_) => SchoolRepository(Supabase.instance.client));

// ── Real-time StreamProviders ─────────────────────────────────────────────────
// These use Supabase's Postgres Changes listener — any INSERT/UPDATE/DELETE
// on the table is pushed to the app immediately without polling.

/// Teacher's assigned classes — updates instantly when admin adds/removes a class.
final classesProvider = StreamProvider<List<ClassRoom>>((ref) {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id ?? '';

  // Stream the join table; on every change re-fetch the full class list.
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
final noticesProvider =
    StreamProvider.family<List<Notice>, String>((ref, classId) {
  final client = Supabase.instance.client;

  return client
      .from('notices')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) => rows
          .where((r) =>
              r['audience_class_id'] == classId ||
              r['audience_class_id'] == null)
          .take(20)
          .map((r) => Notice.fromMap(r))
          .toList());
});

// ── Theme ─────────────────────────────────────────────────────────────────────

final themeProvider = StateProvider<ThemeMode>((_) => ThemeMode.system);

// ── Role (one-time fetch, changes rarely) ────────────────────────────────────

final currentUserRoleProvider = FutureProvider<UserRole>(
    (ref) => ref.watch(repoProvider).getCurrentUserRole());

// ── Attendance (FutureProvider — date-specific, not continuous stream) ───────

final absentStudentsProvider =
    FutureProvider.family<List<Student>, (String, DateTime)>(
        (ref, params) {
  final (classId, date) = params;
  return ref.watch(repoProvider).getAbsentStudents(classId, date);
});

final presentStudentsProvider =
    FutureProvider.family<List<Student>, (String, DateTime)>(
        (ref, params) {
  final (classId, date) = params;
  return ref.watch(repoProvider).getPresentStudents(classId, date);
});

final dailyAttendanceCountProvider =
    FutureProvider.family<Map<String, int>, (String, DateTime)>(
        (ref, params) {
  final (classId, date) = params;
  return ref.watch(repoProvider).getDailyAttendanceCount(classId, date);
});

final homeworkStatusProvider =
    FutureProvider.family<List<HomeworkStatusRecord>, String>(
        (ref, homeworkId) =>
            ref.watch(repoProvider).getHomeworkStatus(homeworkId));

/// Whether today's attendance is done for a given class.
final attendanceDoneTodayProvider =
    FutureProvider.family<bool, String>((ref, classId) =>
        ref.watch(repoProvider).isAttendanceDoneToday(classId));

/// Homework assigned for a specific date (for combined send).
final homeworkForDateProvider =
    FutureProvider.family<List<Homework>, (String, DateTime)>(
        (ref, params) {
  final (classId, date) = params;
  return ref.watch(repoProvider).getHomeworkForDate(classId, date);
});

/// WhatsApp group link for a class.
final whatsappGroupLinkProvider =
    FutureProvider.family<String?, String>((ref, classId) =>
        ref.watch(repoProvider).getWhatsAppGroupLink(classId));

/// WhatsApp sent students for a given date+type.
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

/// All classes — real-time so admin additions reflect instantly everywhere.
final allClassesProvider = StreamProvider<List<ClassRoom>>((ref) {
  final client = Supabase.instance.client;
  return client
      .from('classes')
      .stream(primaryKey: ['id'])
      .order('name')
      .map((rows) => rows.map((r) => ClassRoom.fromMap(r)).toList());
});

/// All teachers — real-time.
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

/// All students (admin view) — real-time.
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
