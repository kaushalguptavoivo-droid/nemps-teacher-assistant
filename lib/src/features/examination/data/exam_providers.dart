// Examination Module — Riverpod Providers
// All providers for the Examination Module.
// Follows the same patterns as lib/src/features/data/providers.dart.
// Existing providers are NOT modified.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exam_models.dart';
import 'exam_repository.dart';

// ── Repository Provider ───────────────────────────────────────────────────────

final examRepoProvider = Provider<ExamRepository>(
  (_) => ExamRepository(Supabase.instance.client),
);

// ── Academic Sessions ─────────────────────────────────────────────────────────

// Resilience helper: immediate snapshot + real-time overlay.
// If Supabase Realtime subscription fails, stream ends silently after snapshot.
Stream<T> _resilient<T>(
  Future<T> Function() fetch,
  Stream<T> Function() rt,
) async* {
  try {
    yield await fetch();
  } catch (_) {}
  try {
    await for (final v in rt()) {
      yield v;
    }
  } catch (_) {}
}

/// All academic sessions — updated in real-time with fallback initial fetch.
final academicSessionsProvider = StreamProvider<List<AcademicSession>>((ref) {
  final client = Supabase.instance.client;
  final repo = ref.read(examRepoProvider);
  return _resilient(
    () => repo.getSessions(),
    () => client
        .from('academic_sessions')
        .stream(primaryKey: ['id'])
        .order('label', ascending: false)
        .map((rows) => rows
            .map<AcademicSession>((r) => AcademicSession.fromMap(r))
            .toList()),
  );
});

/// The currently active session (null if none).
final activeSessionProvider = FutureProvider<AcademicSession?>((ref) async {
  return ref.read(examRepoProvider).getActiveSession();
});

/// Convenience: just the active session's label (e.g. "2026-27").
final activeYearProvider = Provider<AsyncValue<String?>>((ref) {
  return ref.watch(activeSessionProvider).whenData((s) => s?.label);
});

// ── Exam Configs ──────────────────────────────────────────────────────────────

/// All exam configs for the active academic year.
final examConfigsProvider =
    FutureProvider.family<List<ExamConfig>, String>((ref, academicYear) async {
  return ref.read(examRepoProvider).getExamConfigs(academicYear);
});

/// Exam config for a specific class+year. Returns null if not yet configured.
final examConfigProvider = FutureProvider.family<ExamConfig?, ({String classId, String year})>(
  (ref, args) async {
    return ref.read(examRepoProvider).getExamConfig(args.classId, args.year);
  },
);

// ── Exam Terms ────────────────────────────────────────────────────────────────

/// Terms for a specific exam config.
final examTermsProvider =
    FutureProvider.family<List<ExamTerm>, String>((ref, examConfigId) async {
  return ref.read(examRepoProvider).getTerms(examConfigId);
});

// ── Class Subjects ────────────────────────────────────────────────────────────

/// Active subjects for a class in a given year.
final classSubjectsProvider = FutureProvider.family<List<ClassSubject>,
    ({String classId, String year})>((ref, args) async {
  return ref.read(examRepoProvider).getSubjects(args.classId, args.year);
});

// ── Exam Marks ────────────────────────────────────────────────────────────────

/// All marks for a class in a given term (used in marks-entry spreadsheet).
final termMarksProvider = FutureProvider.family<List<ExamMark>,
    ({String classId, String termId})>((ref, args) async {
  return ref.read(examRepoProvider).getMarksForTerm(args.classId, args.termId);
});

/// All marks for a single student in a class (used for result/report card).
final studentMarksProvider = FutureProvider.family<List<ExamMark>,
    ({String studentId, String classId})>((ref, args) async {
  return ref
      .read(examRepoProvider)
      .getMarksForStudent(args.studentId, args.classId);
});

// ── Grade Configs ─────────────────────────────────────────────────────────────

/// Grade table for a given academic year (used in result engine and UI).
final gradeConfigsProvider =
    FutureProvider.family<List<GradeConfig>, String>((ref, academicYear) async {
  return ref.read(examRepoProvider).getGradeConfigs(academicYear);
});

// ── Report Templates ──────────────────────────────────────────────────────────

/// All report templates for a year.
final reportTemplatesProvider =
    FutureProvider.family<List<ReportTemplate>, String>((ref, academicYear) async {
  return ref.read(examRepoProvider).getReportTemplates(academicYear);
});

/// Default report template for a year (used in PDF engine).
final defaultTemplateProvider =
    FutureProvider.family<ReportTemplate?, String>((ref, academicYear) async {
  return ref.read(examRepoProvider).getDefaultTemplate(academicYear);
});

// ── Student Remarks ───────────────────────────────────────────────────────────

/// All remarks for students in a given term.
final termRemarksProvider =
    FutureProvider.family<List<StudentRemark>, String>((ref, termId) async {
  return ref.read(examRepoProvider).getRemarksForTerm(termId);
});

// ── Result Engine ─────────────────────────────────────────────────────────────

/// Full computed result for all students in a class.
/// Never reads stored totals — always computed dynamically.
final classResultsProvider = FutureProvider.family<
    List<StudentResult>,
    ({
      String classId,
      String academicYear,
      ExamConfig config,
      List<ExamTerm> terms,
      List<ClassSubject> subjects,
      List<GradeConfig> gradeConfigs,
      List<Map<String, dynamic>> students,
    })>((ref, args) async {
  return ref.read(examRepoProvider).calculateResults(
        classId: args.classId,
        academicYear: args.academicYear,
        config: args.config,
        terms: args.terms,
        subjects: args.subjects,
        gradeConfigs: args.gradeConfigs,
        students: args.students,
      );
});

// ── Analytics ─────────────────────────────────────────────────────────────────

/// All exam configs for a year, joined with their class name.
final examConfigsWithClassProvider = FutureProvider.family<
    List<ExamConfigWithClass>, String>((ref, academicYear) async {
  return ref.read(examRepoProvider).getExamConfigsWithClassNames(academicYear);
});

/// Per-class analytics summary using stable primitive-only family key.
///
/// Fixes the infinite-rebuild loop in the old _ResultsAggregator: it called
/// classResultsProvider with ExamConfig / List<ExamTerm> / etc. as family keys.
/// Those model classes have no == override, so every rebuild created a brand-new
/// key → brand-new provider instance → loading state → rebuild again → loop.
///
/// This provider does all loading internally and only needs two plain strings
/// (classId + academicYear) as its key — always equal across rebuilds.
final classAnalyticsSummaryProvider = FutureProvider.autoDispose.family<
    ClassAnalyticsSummary?,
    ({String classId, String className, String academicYear})>(
  (ref, args) async {
    final repo = ref.read(examRepoProvider);
    final client = Supabase.instance.client;

    final config = await repo.getExamConfig(args.classId, args.academicYear);
    if (config == null) return null;

    // Load all deps in parallel
    final futures = await Future.wait([
      repo.getTerms(config.id),
      repo.getSubjects(args.classId, args.academicYear),
      repo.getGradeConfigs(args.academicYear),
      client
          .from('students')
          .select('id, full_name, roll_no')
          .eq('class_id', args.classId)
          .eq('active', true)
          .order('roll_no'),
    ]);

    final allTerms = futures[0] as List<ExamTerm>;
    final terms = allTerms.where((t) => t.includeInFinalResult).toList();
    final subjects = futures[1] as List<ClassSubject>;
    final grades = futures[2] as List<GradeConfig>;
    final rawStudents = futures[3] as List<dynamic>;

    if (subjects.isEmpty || rawStudents.isEmpty) return null;

    final studentMaps = rawStudents
        .map((r) => {
              'id': r['id'] as String,
              'full_name': r['full_name'] as String,
              'roll_no': r['roll_no'] as String,
            })
        .toList();

    final studentResults = await repo.calculateResults(
      classId: args.classId,
      academicYear: args.academicYear,
      config: config,
      terms: terms,
      subjects: subjects,
      gradeConfigs: grades,
      students: studentMaps,
    );

    if (studentResults.isEmpty) return null;

    return ClassAnalyticsSummary.fromResults(
      classId: args.classId,
      className: args.className,
      results: studentResults,
    );
  },
);

// ── Promotion Records ─────────────────────────────────────────────────────────

/// Promotion records for a class in a given academic year.
/// Invalidated after generate or override operations.
final promotionRecordsProvider = FutureProvider.family<List<PromotionRecord>,
    ({String classId, String year})>((ref, args) async {
  return ref
      .read(examRepoProvider)
      .getPromotionRecords(args.classId, args.year);
});

// ── Marks Entry State ─────────────────────────────────────────────────────────

/// Holds in-progress (unsaved) marks keyed by "subjectId_termId_studentId".
/// Cleared on bulk save or navigation.
class MarksEntryNotifier
    extends StateNotifier<Map<String, ExamMark>> {
  MarksEntryNotifier() : super({});

  void setMark(ExamMark mark) {
    final key = '${mark.subjectId}_${mark.termId}_${mark.studentId}';
    state = {...state, key: mark};
  }

  void clear() => state = {};

  List<ExamMark> get pendingMarks => state.values.toList();
}

final marksEntryProvider =
    StateNotifierProvider<MarksEntryNotifier, Map<String, ExamMark>>(
  (_) => MarksEntryNotifier(),
);
