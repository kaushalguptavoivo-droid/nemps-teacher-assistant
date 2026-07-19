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
