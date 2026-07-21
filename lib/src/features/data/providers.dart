import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/models.dart';
import 'school_repository.dart';

final repoProvider =
    Provider((_) => SchoolRepository(Supabase.instance.client));

final classesProvider = FutureProvider<List<ClassRoom>>(
    (ref) => ref.watch(repoProvider).myClasses());

final studentsProvider =
    FutureProvider.family<List<Student>, String>(
        (ref, classId) => ref.watch(repoProvider).students(classId));

final homeworkProvider =
    FutureProvider.family<List<Homework>, String>(
        (ref, classId) =>
            ref.watch(repoProvider).getHomeworkForClass(classId));

final noticesProvider =
    FutureProvider.family<List<Notice>, String>(
        (ref, classId) =>
            ref.watch(repoProvider).getNotices(classId));

final themeProvider =
    StateProvider<ThemeMode>((_) => ThemeMode.system);

final currentUserRoleProvider = FutureProvider<UserRole>(
    (ref) => ref.watch(repoProvider).getCurrentUserRole());

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
        (ref, homeworkId) {
  return ref.watch(repoProvider).getHomeworkStatus(homeworkId);
});

/// Whether today's attendance is done for a given class.
final attendanceDoneTodayProvider =
    FutureProvider.family<bool, String>((ref, classId) {
  return ref.watch(repoProvider).isAttendanceDoneToday(classId);
});

/// Homework assigned for a specific date (for combined send).
final homeworkForDateProvider =
    FutureProvider.family<List<Homework>, (String, DateTime)>(
        (ref, params) {
  final (classId, date) = params;
  return ref.watch(repoProvider).getHomeworkForDate(classId, date);
});

/// WhatsApp group link for a class.
final whatsappGroupLinkProvider =
    FutureProvider.family<String?, String>((ref, classId) {
  return ref.watch(repoProvider).getWhatsAppGroupLink(classId);
});

/// WhatsApp sent students for attendance notification.
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

// ── Admin providers ──────────────────────────────────────────────────────────

final allClassesProvider = FutureProvider<List<ClassRoom>>(
    (ref) => ref.watch(repoProvider).getAllClasses());

final allTeachersProvider = FutureProvider<List<TeacherProfile>>(
    (ref) => ref.watch(repoProvider).getAllTeachers());

final teacherAssignedClassesProvider =
    FutureProvider.family<List<ClassRoom>, String>(
        (ref, teacherId) =>
            ref.watch(repoProvider).getTeacherAssignedClasses(teacherId));

final allStudentsProvider = FutureProvider<List<Student>>(
    (ref) => ref.watch(repoProvider).getAllStudents());
