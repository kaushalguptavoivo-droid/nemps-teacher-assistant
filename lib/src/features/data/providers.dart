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

/// Current logged-in user's role fetched from profiles table.
final currentUserRoleProvider = FutureProvider<UserRole>(
    (ref) => ref.watch(repoProvider).getCurrentUserRole());

/// Absent students for a given class + date.
final absentStudentsProvider =
    FutureProvider.family<List<Student>, (String, DateTime)>(
        (ref, params) {
  final (classId, date) = params;
  return ref.watch(repoProvider).getAbsentStudents(classId, date);
});

/// Present students for a given class + date.
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
  return ref
      .watch(repoProvider)
      .getDailyAttendanceCount(classId, date);
});

final homeworkStatusProvider =
    FutureProvider.family<List<HomeworkStatusRecord>, String>(
        (ref, homeworkId) {
  return ref.watch(repoProvider).getHomeworkStatus(homeworkId);
});

/// Students (with their pending subjects) who haven't completed today's
/// homework. Used for the single combined WhatsApp reminder.
final todayPendingByStudentProvider =
    FutureProvider.family<List<PendingHomeworkSummary>, String>(
        (ref, classId) =>
            ref.watch(repoProvider).getTodayPendingByStudent(classId));

/// Completion counts for a single homework: completed / pending / total.
final homeworkCompletionProvider =
    FutureProvider.family<Map<String, int>, (String, String)>((ref, params) {
  final (classId, homeworkId) = params;
  return ref.watch(repoProvider).getHomeworkCompletionCount(classId, homeworkId);
});

// ── Admin providers ──────────────────────────────────────────────────────────

/// Admin: all classes (not filtered by teacher).
final allClassesProvider = FutureProvider<List<ClassRoom>>(
    (ref) => ref.watch(repoProvider).getAllClasses());

/// Admin: all teacher profiles.
final allTeachersProvider = FutureProvider<List<TeacherProfile>>(
    (ref) => ref.watch(repoProvider).getAllTeachers());

/// Admin: classes assigned to a specific teacher.
final teacherAssignedClassesProvider =
    FutureProvider.family<List<ClassRoom>, String>(
        (ref, teacherId) =>
            ref.watch(repoProvider).getTeacherAssignedClasses(teacherId));

/// Admin: all active students across all classes.
final allStudentsProvider = FutureProvider<List<Student>>(
    (ref) => ref.watch(repoProvider).getAllStudents());
