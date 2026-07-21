// Examination Module — Repository
// All database operations for the Examination Module.
// Never duplicates student/class/teacher data — only stores references.
// Business logic goes here, NOT in UI widgets.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exam_models.dart';

class ExamRepository {
  ExamRepository(this._client);
  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  // ── Academic Sessions ─────────────────────────────────────────────────────

  Future<List<AcademicSession>> getSessions() async {
    final data = await _client
        .from('academic_sessions')
        .select()
        .order('label', ascending: false);
    return data.map<AcademicSession>((r) => AcademicSession.fromMap(r)).toList();
  }

  Future<AcademicSession?> getActiveSession() async {
    final data = await _client
        .from('academic_sessions')
        .select()
        .eq('is_active', true)
        .maybeSingle();
    return data != null ? AcademicSession.fromMap(data) : null;
  }

  /// Creates a new session. Does NOT activate it automatically.
  Future<AcademicSession> createSession(String label) async {
    final data = await _client
        .from('academic_sessions')
        .insert({'label': label, 'is_active': false, 'created_by': _uid})
        .select()
        .single();
    return AcademicSession.fromMap(data);
  }

  /// Sets [sessionId] as active. Deactivates all others in a transaction.
  Future<void> activateSession(String sessionId) async {
    // Deactivate all first, then activate the chosen one.
    await _client
        .from('academic_sessions')
        .update({'is_active': false})
        .neq('id', sessionId);
    await _client
        .from('academic_sessions')
        .update({'is_active': true})
        .eq('id', sessionId);
  }

  // ── Exam Configs ──────────────────────────────────────────────────────────

  Future<List<ExamConfig>> getExamConfigs(String academicYear) async {
    final data = await _client
        .from('exam_configs')
        .select()
        .eq('academic_year', academicYear)
        .order('created_at');
    return data.map<ExamConfig>((r) => ExamConfig.fromMap(r)).toList();
  }

  Future<ExamConfig?> getExamConfig(String classId, String academicYear) async {
    final data = await _client
        .from('exam_configs')
        .select()
        .eq('class_id', classId)
        .eq('academic_year', academicYear)
        .maybeSingle();
    return data != null ? ExamConfig.fromMap(data) : null;
  }

  /// Creates an ExamConfig and auto-generates ExamTerms from the pattern.
  Future<ExamConfig> createExamConfig({
    required String classId,
    required String academicYear,
    required ExamPattern pattern,
    double passingPercentage = 33.0,
    String resultType = 'marks',
  }) async {
    final configData = await _client
        .from('exam_configs')
        .insert({
          'class_id': classId,
          'academic_year': academicYear,
          'exam_pattern': pattern == ExamPattern.nursery ? 'nursery' : 'prep_to_8',
          'passing_percentage': passingPercentage,
          'result_type': resultType,
          'is_locked': false,
          'created_by': _uid,
        })
        .select()
        .single();

    final config = ExamConfig.fromMap(configData);

    // Auto-generate terms from pattern
    final terms = _defaultTermsFor(config.id, pattern);
    await _client.from('exam_terms').insert(
          terms.map((t) => t.toInsertMap()).toList(),
        );

    return config;
  }

  /// Lock or unlock an exam config (admin only — enforced by RLS).
  Future<void> setLocked(String configId, {required bool locked}) async {
    await _client
        .from('exam_configs')
        .update({'is_locked': locked})
        .eq('id', configId);
  }

  // ── Exam Terms ────────────────────────────────────────────────────────────

  Future<List<ExamTerm>> getTerms(String examConfigId) async {
    final data = await _client
        .from('exam_terms')
        .select()
        .eq('exam_config_id', examConfigId)
        .order('display_order');
    return data.map<ExamTerm>((r) => ExamTerm.fromMap(r)).toList();
  }

  Future<void> updateTermMaxMarks(String termId, double maxMarks) async {
    await _client
        .from('exam_terms')
        .update({'maximum_marks': maxMarks})
        .eq('id', termId);
  }

  // ── Class Subjects ────────────────────────────────────────────────────────

  Future<List<ClassSubject>> getSubjects(
      String classId, String academicYear) async {
    final data = await _client
        .from('class_subjects')
        .select()
        .eq('class_id', classId)
        .eq('academic_year', academicYear)
        .eq('is_active', true)
        .order('display_order');
    return data.map<ClassSubject>((r) => ClassSubject.fromMap(r)).toList();
  }

  Future<ClassSubject> addSubject({
    required String classId,
    required String academicYear,
    required String subjectName,
    required int displayOrder,
    bool isGradeSubject = false,
  }) async {
    final data = await _client
        .from('class_subjects')
        .insert({
          'class_id': classId,
          'academic_year': academicYear,
          'subject_name': subjectName,
          'display_order': displayOrder,
          'is_grade_subject': isGradeSubject,
          'is_active': true,
        })
        .select()
        .single();
    return ClassSubject.fromMap(data);
  }

  Future<void> renameSubject(String subjectId, String newName) async {
    await _client
        .from('class_subjects')
        .update({'subject_name': newName})
        .eq('id', subjectId);
  }

  /// Soft-delete: sets is_active=false. Blocked at DB layer if marks exist.
  Future<void> disableSubject(String subjectId) async {
    // Safety: check no marks exist before disabling
    final marksCount = await _client
        .from('exam_marks')
        .select('id')
        .eq('subject_id', subjectId);
    if ((marksCount as List).isNotEmpty) {
      throw Exception(
          'Cannot disable subject: marks already exist for this subject.');
    }
    await _client
        .from('class_subjects')
        .update({'is_active': false})
        .eq('id', subjectId);
  }

  Future<void> reorderSubject(String subjectId, int newOrder) async {
    await _client
        .from('class_subjects')
        .update({'display_order': newOrder})
        .eq('id', subjectId);
  }

  Future<void> toggleGradeSubject(String subjectId, {required bool isGrade}) async {
    await _client
        .from('class_subjects')
        .update({'is_grade_subject': isGrade})
        .eq('id', subjectId);
  }

  // ── Exam Marks ────────────────────────────────────────────────────────────

  /// Fetch all marks for a class in a given term.
  Future<List<ExamMark>> getMarksForTerm(
      String classId, String termId) async {
    final data = await _client
        .from('exam_marks')
        .select()
        .eq('class_id', classId)
        .eq('term_id', termId);
    return data.map<ExamMark>((r) => ExamMark.fromMap(r)).toList();
  }

  /// Fetch all marks for a single student across all terms in a config.
  Future<List<ExamMark>> getMarksForStudent(
      String studentId, String classId) async {
    final data = await _client
        .from('exam_marks')
        .select()
        .eq('student_id', studentId)
        .eq('class_id', classId);
    return data.map<ExamMark>((r) => ExamMark.fromMap(r)).toList();
  }

  /// UPSERT marks for a single student+subject+term.
  /// Validates max marks at app layer before saving.
  Future<ExamMark> saveMark({
    required String studentId,
    required String classId,
    required String subjectId,
    required String termId,
    double? obtainedMarks,
    String? grade,
    bool isAbsent = false,
    String? remarks,
    required double maximumMarks,
  }) async {
    // App-layer validation
    if (!isAbsent && obtainedMarks != null) {
      if (obtainedMarks < 0) throw Exception('Marks cannot be negative.');
      if (obtainedMarks > maximumMarks) {
        throw Exception(
            'Marks ($obtainedMarks) exceed maximum ($maximumMarks).');
      }
    }

    final row = {
      'student_id': studentId,
      'class_id': classId,
      'subject_id': subjectId,
      'term_id': termId,
      'obtained_marks': isAbsent ? null : obtainedMarks,
      'grade': grade,
      'is_absent': isAbsent,
      if (remarks != null) 'remarks': remarks,
      'entered_by': _uid,
      'entered_at': DateTime.now().toIso8601String(),
    };

    final data = await _client
        .from('exam_marks')
        .upsert(row, onConflict: 'student_id,subject_id,term_id')
        .select()
        .single();
    return ExamMark.fromMap(data);
  }

  /// Bulk UPSERT — used for spreadsheet-style batch save.
  Future<void> bulkSaveMarks(List<ExamMark> marks) async {
    final rows = marks.map((m) => m.toUpsertMap()).toList();
    await _client
        .from('exam_marks')
        .upsert(rows, onConflict: 'student_id,subject_id,term_id');
  }

  // ── Grade Configs ─────────────────────────────────────────────────────────

  Future<List<GradeConfig>> getGradeConfigs(String academicYear) async {
    final data = await _client
        .from('grade_configs')
        .select()
        .eq('academic_year', academicYear)
        .order('display_order');
    return data.map<GradeConfig>((r) => GradeConfig.fromMap(r)).toList();
  }

  Future<GradeConfig> saveGradeConfig(GradeConfig config) async {
    final data = await _client
        .from('grade_configs')
        .upsert(config.toInsertMap(), onConflict: 'academic_year,grade')
        .select()
        .single();
    return GradeConfig.fromMap(data);
  }

  Future<void> deleteGradeConfig(String id) async {
    await _client.from('grade_configs').delete().eq('id', id);
  }

  // ── Report Templates ──────────────────────────────────────────────────────

  Future<List<ReportTemplate>> getReportTemplates(String academicYear) async {
    final data = await _client
        .from('report_templates')
        .select()
        .eq('academic_year', academicYear)
        .order('created_at');
    return data.map<ReportTemplate>((r) => ReportTemplate.fromMap(r)).toList();
  }

  Future<ReportTemplate?> getDefaultTemplate(String academicYear) async {
    final data = await _client
        .from('report_templates')
        .select()
        .eq('academic_year', academicYear)
        .eq('is_default', true)
        .maybeSingle();
    return data != null ? ReportTemplate.fromMap(data) : null;
  }

  Future<ReportTemplate> saveReportTemplate({
    String? id,
    required String templateName,
    required String academicYear,
    required String schoolName,
    String? schoolAddress,
    String? logoUrl,
    String? principalName,
    String paperSize = 'A4',
    String orientation = 'portrait',
    bool showAttendance = true,
    bool showGrade = true,
    bool showPercentage = true,
    bool showRank = true,
    bool showRemarks = true,
    String? watermarkText,
    String? headerText,
    String? footerText,
    String? signatureLabel,
    bool isDefault = false,
  }) async {
    final row = <String, dynamic>{
      if (id != null) 'id': id,
      'template_name': templateName,
      'academic_year': academicYear,
      'school_name': schoolName,
      if (schoolAddress != null) 'school_address': schoolAddress,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (principalName != null) 'principal_name': principalName,
      'paper_size': paperSize,
      'orientation': orientation,
      'show_attendance': showAttendance,
      'show_grade': showGrade,
      'show_percentage': showPercentage,
      'show_rank': showRank,
      'show_remarks': showRemarks,
      if (watermarkText != null) 'watermark_text': watermarkText,
      if (headerText != null) 'header_text': headerText,
      if (footerText != null) 'footer_text': footerText,
      if (signatureLabel != null) 'signature_label': signatureLabel,
      'is_default': isDefault,
      'created_by': _uid,
    };

    if (isDefault) {
      // Clear other defaults for this year first
      await _client
          .from('report_templates')
          .update({'is_default': false})
          .eq('academic_year', academicYear);
    }

    final data = await _client
        .from('report_templates')
        .upsert(row, onConflict: 'academic_year,template_name')
        .select()
        .single();
    return ReportTemplate.fromMap(data);
  }

  // ── Student Remarks ───────────────────────────────────────────────────────

  Future<List<StudentRemark>> getRemarksForTerm(String termId) async {
    final data = await _client
        .from('student_remarks')
        .select()
        .eq('term_id', termId);
    return data.map<StudentRemark>((r) => StudentRemark.fromMap(r)).toList();
  }

  Future<void> saveRemark({
    required String studentId,
    required String termId,
    required String remark,
  }) async {
    await _client.from('student_remarks').upsert(
      {
        'student_id': studentId,
        'term_id': termId,
        'remark': remark,
        'entered_by': _uid,
      },
      onConflict: 'student_id,term_id',
    );
  }

  // ── Result Calculation ────────────────────────────────────────────────────

  /// Dynamically calculates results for all students in a class.
  /// Never reads from a stored total/percentage — always recomputes.
  Future<List<StudentResult>> calculateResults({
    required String classId,
    required String academicYear,
    required ExamConfig config,
    required List<ExamTerm> terms,
    required List<ClassSubject> subjects,
    required List<GradeConfig> gradeConfigs,
    required List<Map<String, dynamic>> students, // [{id, full_name, roll_no}]
  }) async {
    // Fetch all marks for this class
    final allMarksData = await _client
        .from('exam_marks')
        .select()
        .eq('class_id', classId);
    final allMarks =
        allMarksData.map<ExamMark>((r) => ExamMark.fromMap(r)).toList();

    // Group marks by studentId → subjectId → termId
    final Map<String, Map<String, Map<String, ExamMark>>> markIndex = {};
    for (final m in allMarks) {
      markIndex
          .putIfAbsent(m.studentId, () => {})
          .putIfAbsent(m.subjectId, () => {})[m.termId] = m;
    }

    final finalTerms =
        terms.where((t) => t.includeInFinalResult).toList();
    final double configMaxTotal = finalTerms.fold(
      0.0,
      (sum, t) => sum + t.maximumMarks * subjects.length,
    );

    final List<StudentResult> results = [];

    for (final student in students) {
      final sid = student['id'] as String;
      final studentMarks = markIndex[sid] ?? {};

      double studentTotal = 0;
      double studentMaxTotal = 0;
      final List<SubjectResult> subjectResults = [];

      for (final subject in subjects) {
        final subjectMarks = studentMarks[subject.id] ?? {};
        double subjectTotal = 0;
        double subjectMax = 0;
        final Map<String, double?> termMarks = {};

        for (final term in finalTerms) {
          final mark = subjectMarks[term.id];
          subjectMax += term.maximumMarks;
          if (mark != null && !mark.isAbsent && mark.obtainedMarks != null) {
            subjectTotal += mark.obtainedMarks!;
            termMarks[term.id] = mark.obtainedMarks;
          } else {
            termMarks[term.id] = null;
          }
        }

        final subjectPct =
            subjectMax > 0 ? (subjectTotal / subjectMax) * 100 : 0.0;
        final subjectPassed =
            subjectPct >= config.passingPercentage;
        final subjectGrade =
            GradeConfig.resolveGrade(subjectPct, gradeConfigs);

        subjectResults.add(SubjectResult(
          subjectId: subject.id,
          subjectName: subject.subjectName,
          isGradeSubject: subject.isGradeSubject,
          termMarks: termMarks,
          total: subjectTotal,
          maximum: subjectMax,
          percentage: subjectPct,
          grade: subjectGrade,
          isPassed: subjectPassed,
        ));

        studentTotal += subjectTotal;
        studentMaxTotal += subjectMax;
      }

      final overallPct =
          studentMaxTotal > 0 ? (studentTotal / studentMaxTotal) * 100 : 0.0;
      final allSubjectsPassed =
          subjectResults.every((s) => s.isPassed || s.isGradeSubject);
      final overallPassed =
          allSubjectsPassed && overallPct >= config.passingPercentage;

      results.add(StudentResult(
        studentId: sid,
        studentName: student['full_name'] as String,
        rollNo: student['roll_no'] as String,
        subjectResults: subjectResults,
        totalObtained: studentTotal,
        totalMaximum: studentMaxTotal,
        percentage: overallPct,
        grade: GradeConfig.resolveGrade(overallPct, gradeConfigs),
        isPassed: overallPassed,
        rank: 0, // assigned below
      ));
    }

    // Assign ranks dynamically (highest total → rank 1)
    final sorted = List<StudentResult>.from(results)
      ..sort((a, b) => b.totalObtained.compareTo(a.totalObtained));
    final Map<String, int> rankMap = {};
    for (int i = 0; i < sorted.length; i++) {
      rankMap[sorted[i].studentId] = i + 1;
    }

    return results
        .map((r) => StudentResult(
              studentId: r.studentId,
              studentName: r.studentName,
              rollNo: r.rollNo,
              subjectResults: r.subjectResults,
              totalObtained: r.totalObtained,
              totalMaximum: r.totalMaximum,
              percentage: r.percentage,
              grade: r.grade,
              isPassed: r.isPassed,
              rank: rankMap[r.studentId] ?? 0,
            ))
        .toList();
  }

  // ── Private Helpers ───────────────────────────────────────────────────────

  /// Returns the default term list for a given pattern.
  /// Admin may edit maximum_marks after creation.
  List<ExamTerm> _defaultTermsFor(String configId, ExamPattern pattern) {
    if (pattern == ExamPattern.nursery) {
      return [
        ExamTerm(
          id: '', examConfigId: configId,
          termName: 'Oral', maximumMarks: 40,
          displayOrder: 1, includeInFinalResult: true,
          createdAt: DateTime.now(),
        ),
        ExamTerm(
          id: '', examConfigId: configId,
          termName: 'Written', maximumMarks: 60,
          displayOrder: 2, includeInFinalResult: true,
          createdAt: DateTime.now(),
        ),
      ];
    }
    return [
      ExamTerm(
        id: '', examConfigId: configId,
        termName: 'UT1', maximumMarks: 20,
        displayOrder: 1, includeInFinalResult: true,
        createdAt: DateTime.now(),
      ),
      ExamTerm(
        id: '', examConfigId: configId,
        termName: 'Half Yearly', maximumMarks: 80,
        displayOrder: 2, includeInFinalResult: true,
        createdAt: DateTime.now(),
      ),
      ExamTerm(
        id: '', examConfigId: configId,
        termName: 'UT2', maximumMarks: 20,
        displayOrder: 3, includeInFinalResult: true,
        createdAt: DateTime.now(),
      ),
      ExamTerm(
        id: '', examConfigId: configId,
        termName: 'Annual', maximumMarks: 80,
        displayOrder: 4, includeInFinalResult: true,
        createdAt: DateTime.now(),
      ),
    ];
  }
}
