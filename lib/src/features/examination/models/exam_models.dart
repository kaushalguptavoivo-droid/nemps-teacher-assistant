// Examination Module — Data Models
// All new examination-specific models live here.
// Existing models (Student, ClassRoom, etc.) are NOT duplicated — import from core.

// ─── Enums ───────────────────────────────────────────────────────────────────

enum ExamPattern { nursery, prepTo8 }

// ─── AcademicSession ─────────────────────────────────────────────────────────

class AcademicSession {
  const AcademicSession({
    required this.id,
    required this.label,
    required this.isActive,
    this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String label;       // e.g. "2026-27"
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;

  factory AcademicSession.fromMap(Map<String, dynamic> m) => AcademicSession(
        id: m['id'] as String,
        label: m['label'] as String,
        isActive: m['is_active'] as bool? ?? false,
        createdBy: m['created_by'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'is_active': isActive,
        if (createdBy != null) 'created_by': createdBy,
      };
}

// ─── ExamConfig ──────────────────────────────────────────────────────────────

class ExamConfig {
  const ExamConfig({
    required this.id,
    required this.classId,
    required this.academicYear,
    required this.examPattern,
    required this.passingPercentage,
    required this.resultType,
    required this.isLocked,
    this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String classId;
  final String academicYear;
  final ExamPattern examPattern;
  final double passingPercentage;
  final String resultType;   // 'marks' | 'grade' | 'both'
  final bool isLocked;
  final String? createdBy;
  final DateTime createdAt;

  factory ExamConfig.fromMap(Map<String, dynamic> m) => ExamConfig(
        id: m['id'] as String,
        classId: m['class_id'] as String,
        academicYear: m['academic_year'] as String,
        examPattern: (m['exam_pattern'] as String) == 'nursery'
            ? ExamPattern.nursery
            : ExamPattern.prepTo8,
        passingPercentage: (m['passing_percentage'] as num).toDouble(),
        resultType: m['result_type'] as String? ?? 'marks',
        isLocked: m['is_locked'] as bool? ?? false,
        createdBy: m['created_by'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

// ─── ExamTerm ────────────────────────────────────────────────────────────────

class ExamTerm {
  const ExamTerm({
    required this.id,
    required this.examConfigId,
    required this.termName,
    required this.maximumMarks,
    required this.displayOrder,
    required this.includeInFinalResult,
    required this.createdAt,
  });

  final String id;
  final String examConfigId;
  final String termName;             // "Oral","Written","UT1","Half Yearly","UT2","Annual"
  final double maximumMarks;
  final int displayOrder;
  final bool includeInFinalResult;
  final DateTime createdAt;

  factory ExamTerm.fromMap(Map<String, dynamic> m) => ExamTerm(
        id: m['id'] as String,
        examConfigId: m['exam_config_id'] as String,
        termName: m['term_name'] as String,
        maximumMarks: (m['maximum_marks'] as num).toDouble(),
        displayOrder: m['display_order'] as int? ?? 1,
        includeInFinalResult: m['include_in_final_result'] as bool? ?? true,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'exam_config_id': examConfigId,
        'term_name': termName,
        'maximum_marks': maximumMarks,
        'display_order': displayOrder,
        'include_in_final_result': includeInFinalResult,
      };
}

// ─── ClassSubject ─────────────────────────────────────────────────────────────

class ClassSubject {
  const ClassSubject({
    required this.id,
    required this.classId,
    required this.academicYear,
    required this.subjectName,
    required this.displayOrder,
    required this.isGradeSubject,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String classId;
  final String academicYear;
  final String subjectName;
  final int displayOrder;
  final bool isGradeSubject;   // true → grade (e.g. Drawing); false → marks
  final bool isActive;
  final DateTime createdAt;

  factory ClassSubject.fromMap(Map<String, dynamic> m) => ClassSubject(
        id: m['id'] as String,
        classId: m['class_id'] as String,
        academicYear: m['academic_year'] as String,
        subjectName: m['subject_name'] as String,
        displayOrder: m['display_order'] as int? ?? 1,
        isGradeSubject: m['is_grade_subject'] as bool? ?? false,
        isActive: m['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'class_id': classId,
        'academic_year': academicYear,
        'subject_name': subjectName,
        'display_order': displayOrder,
        'is_grade_subject': isGradeSubject,
        'is_active': isActive,
      };
}

// ─── ExamMark ────────────────────────────────────────────────────────────────

class ExamMark {
  const ExamMark({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.subjectId,
    required this.termId,
    this.obtainedMarks,
    this.grade,
    required this.isAbsent,
    this.remarks,
    this.enteredBy,
    required this.enteredAt,
  });

  final String id;
  final String studentId;
  final String classId;
  final String subjectId;
  final String termId;
  final double? obtainedMarks;   // null for grade subjects or absent
  final String? grade;           // null for marks subjects
  final bool isAbsent;
  final String? remarks;
  final String? enteredBy;
  final DateTime enteredAt;

  factory ExamMark.fromMap(Map<String, dynamic> m) => ExamMark(
        id: m['id'] as String,
        studentId: m['student_id'] as String,
        classId: m['class_id'] as String,
        subjectId: m['subject_id'] as String,
        termId: m['term_id'] as String,
        obtainedMarks: m['obtained_marks'] != null
            ? (m['obtained_marks'] as num).toDouble()
            : null,
        grade: m['grade'] as String?,
        isAbsent: m['is_absent'] as bool? ?? false,
        remarks: m['remarks'] as String?,
        enteredBy: m['entered_by'] as String?,
        enteredAt: DateTime.parse(m['entered_at'] as String),
      );

  Map<String, dynamic> toUpsertMap() => {
        'student_id': studentId,
        'class_id': classId,
        'subject_id': subjectId,
        'term_id': termId,
        if (obtainedMarks != null) 'obtained_marks': obtainedMarks,
        if (grade != null) 'grade': grade,
        'is_absent': isAbsent,
        if (remarks != null) 'remarks': remarks,
        if (enteredBy != null) 'entered_by': enteredBy,
      };
}

// ─── GradeConfig ─────────────────────────────────────────────────────────────

class GradeConfig {
  const GradeConfig({
    required this.id,
    required this.academicYear,
    required this.grade,
    required this.minimumPercentage,
    required this.maximumPercentage,
    this.description,
    required this.displayOrder,
  });

  final String id;
  final String academicYear;
  final String grade;               // "A1","A2","B1" …
  final double minimumPercentage;
  final double maximumPercentage;
  final String? description;        // "Outstanding","Excellent" …
  final int displayOrder;

  factory GradeConfig.fromMap(Map<String, dynamic> m) => GradeConfig(
        id: m['id'] as String,
        academicYear: m['academic_year'] as String,
        grade: m['grade'] as String,
        minimumPercentage: (m['minimum_percentage'] as num).toDouble(),
        maximumPercentage: (m['maximum_percentage'] as num).toDouble(),
        description: m['description'] as String?,
        displayOrder: m['display_order'] as int? ?? 1,
      );

  Map<String, dynamic> toInsertMap() => {
        'academic_year': academicYear,
        'grade': grade,
        'minimum_percentage': minimumPercentage,
        'maximum_percentage': maximumPercentage,
        if (description != null) 'description': description,
        'display_order': displayOrder,
      };

  /// Returns the grade label for a given percentage using this config.
  static String resolveGrade(double percentage, List<GradeConfig> configs) {
    for (final g in configs) {
      if (percentage >= g.minimumPercentage &&
          percentage <= g.maximumPercentage) {
        return g.grade;
      }
    }
    return 'N/A';
  }
}

// ─── ReportTemplate ───────────────────────────────────────────────────────────

class ReportTemplate {
  const ReportTemplate({
    required this.id,
    required this.templateName,
    required this.academicYear,
    required this.schoolName,
    this.schoolAddress,
    this.logoUrl,
    this.principalName,
    required this.paperSize,
    required this.orientation,
    required this.showAttendance,
    required this.showGrade,
    required this.showPercentage,
    required this.showRank,
    required this.showRemarks,
    this.watermarkText,
    this.headerText,
    this.footerText,
    this.signatureLabel,
    required this.isDefault,
    required this.createdAt,
  });

  final String id;
  final String templateName;    // "Half Yearly","Annual","Nursery"
  final String academicYear;
  final String schoolName;
  final String? schoolAddress;
  final String? logoUrl;
  final String? principalName;
  final String paperSize;       // "A4","Legal","Letter","Custom"
  final String orientation;     // "portrait","landscape"
  final bool showAttendance;
  final bool showGrade;
  final bool showPercentage;
  final bool showRank;
  final bool showRemarks;
  final String? watermarkText;
  final String? headerText;
  final String? footerText;
  final String? signatureLabel;
  final bool isDefault;
  final DateTime createdAt;

  factory ReportTemplate.fromMap(Map<String, dynamic> m) => ReportTemplate(
        id: m['id'] as String,
        templateName: m['template_name'] as String,
        academicYear: m['academic_year'] as String,
        schoolName: m['school_name'] as String,
        schoolAddress: m['school_address'] as String?,
        logoUrl: m['logo_url'] as String?,
        principalName: m['principal_name'] as String?,
        paperSize: m['paper_size'] as String? ?? 'A4',
        orientation: m['orientation'] as String? ?? 'portrait',
        showAttendance: m['show_attendance'] as bool? ?? true,
        showGrade: m['show_grade'] as bool? ?? true,
        showPercentage: m['show_percentage'] as bool? ?? true,
        showRank: m['show_rank'] as bool? ?? true,
        showRemarks: m['show_remarks'] as bool? ?? true,
        watermarkText: m['watermark_text'] as String?,
        headerText: m['header_text'] as String?,
        footerText: m['footer_text'] as String?,
        signatureLabel: m['signature_label'] as String?,
        isDefault: m['is_default'] as bool? ?? false,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

// ─── StudentRemark ────────────────────────────────────────────────────────────

class StudentRemark {
  const StudentRemark({
    required this.id,
    required this.studentId,
    required this.termId,
    required this.remark,
    this.enteredBy,
    required this.createdAt,
  });

  final String id;
  final String studentId;
  final String termId;
  final String remark;
  final String? enteredBy;
  final DateTime createdAt;

  factory StudentRemark.fromMap(Map<String, dynamic> m) => StudentRemark(
        id: m['id'] as String,
        studentId: m['student_id'] as String,
        termId: m['term_id'] as String,
        remark: m['remark'] as String,
        enteredBy: m['entered_by'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toUpsertMap() => {
        'student_id': studentId,
        'term_id': termId,
        'remark': remark,
        if (enteredBy != null) 'entered_by': enteredBy,
      };
}

// ─── PromotionRecord ──────────────────────────────────────────────────────────

/// One promotion decision per student per class per academic year.
/// result_status is auto-set from the Result Engine (pass/fail).
/// promotion_status can be overridden by Admin.
class PromotionRecord {
  const PromotionRecord({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.academicYear,
    required this.resultStatus,      // 'pass'|'fail'|'compartment'|'pending'
    required this.promotionStatus,   // 'promoted'|'not_promoted'|'pending'
    this.promotedToClassId,
    required this.isManualOverride,
    this.overrideReason,
    this.overriddenBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String studentId;
  final String classId;
  final String academicYear;
  final String resultStatus;
  final String promotionStatus;
  final String? promotedToClassId;
  final bool isManualOverride;
  final String? overrideReason;
  final String? overriddenBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PromotionRecord.fromMap(Map<String, dynamic> m) => PromotionRecord(
        id: m['id'] as String,
        studentId: m['student_id'] as String,
        classId: m['class_id'] as String,
        academicYear: m['academic_year'] as String,
        resultStatus: m['result_status'] as String? ?? 'pending',
        promotionStatus: m['promotion_status'] as String? ?? 'pending',
        promotedToClassId: m['promoted_to_class_id'] as String?,
        isManualOverride: m['is_manual_override'] as bool? ?? false,
        overrideReason: m['override_reason'] as String?,
        overriddenBy: m['overridden_by'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toUpsertMap() => {
        'student_id': studentId,
        'class_id': classId,
        'academic_year': academicYear,
        'result_status': resultStatus,
        'promotion_status': promotionStatus,
        if (promotedToClassId != null) 'promoted_to_class_id': promotedToClassId,
        'is_manual_override': isManualOverride,
        if (overrideReason != null) 'override_reason': overrideReason,
        if (overriddenBy != null) 'overridden_by': overriddenBy,
      };
}

// ─── SubjectTermConfig ────────────────────────────────────────────────────────

/// Per-subject per-term max marks + inclusion flag.
/// If no row exists for a subject+term, use term's default maximumMarks.
class SubjectTermConfig {
  const SubjectTermConfig({
    required this.id,
    required this.subjectId,
    required this.termId,
    required this.maxMarks,
    required this.isIncluded,
  });

  final String id;
  final String subjectId;
  final String termId;
  final double maxMarks;
  final bool isIncluded; // false = this term does not apply to this subject

  factory SubjectTermConfig.fromMap(Map<String, dynamic> m) =>
      SubjectTermConfig(
        id: m['id'] as String,
        subjectId: m['subject_id'] as String,
        termId: m['term_id'] as String,
        maxMarks: (m['max_marks'] as num).toDouble(),
        isIncluded: m['is_included'] as bool? ?? true,
      );

  Map<String, dynamic> toUpsertMap() => {
        'subject_id': subjectId,
        'term_id': termId,
        'max_marks': maxMarks,
        'is_included': isIncluded,
      };
}

// ─── Result Calculation Helpers ───────────────────────────────────────────────

/// Computed result for one student across all terms in a config.
/// Nothing is stored — always calculated dynamically.
class StudentResult {
  const StudentResult({
    required this.studentId,
    required this.studentName,
    required this.rollNo,
    required this.subjectResults,
    required this.totalObtained,
    required this.totalMaximum,
    required this.percentage,
    required this.grade,
    required this.isPassed,
    required this.rank,
  });

  final String studentId;
  final String studentName;
  final String rollNo;
  final List<SubjectResult> subjectResults;
  final double totalObtained;
  final double totalMaximum;
  final double percentage;
  final String grade;
  final bool isPassed;
  final int rank;           // 0 = not yet ranked
}

// ─── Analytics Models ─────────────────────────────────────────────────────────

/// Aggregate stats for one class — computed from StudentResult list.
/// Never stored in DB; always calculated dynamically.
class ClassAnalyticsSummary {
  const ClassAnalyticsSummary({
    required this.classId,
    required this.className,
    required this.totalStudents,
    required this.passCount,
    required this.passPercent,
    required this.averagePercent,
    required this.highestPercent,
    required this.lowestPercent,
    required this.topperName,
    required this.topperRollNo,
    required this.subjectStats,
  });

  final String classId;
  final String className;
  final int totalStudents;
  final int passCount;
  final double passPercent;
  final double averagePercent;
  final double highestPercent;
  final double lowestPercent;
  final String topperName;
  final String topperRollNo;
  final List<SubjectAnalyticsStat> subjectStats;

  int get failCount => totalStudents - passCount;

  /// Compute summary from a pre-calculated results list.
  static ClassAnalyticsSummary fromResults({
    required String classId,
    required String className,
    required List<StudentResult> results,
  }) {
    if (results.isEmpty) {
      return ClassAnalyticsSummary(
        classId: classId,
        className: className,
        totalStudents: 0,
        passCount: 0,
        passPercent: 0,
        averagePercent: 0,
        highestPercent: 0,
        lowestPercent: 0,
        topperName: '-',
        topperRollNo: '-',
        subjectStats: [],
      );
    }

    final ranked = [...results]
      ..sort((a, b) => b.percentage.compareTo(a.percentage));

    final passCount = results.where((r) => r.isPassed).length;
    final avgPct = results.fold(0.0, (s, r) => s + r.percentage) / results.length;
    final topper = ranked.first;

    // Per-subject stats
    final subjectMap = <String, _SubjectAccum>{};
    for (final r in results) {
      for (final sub in r.subjectResults) {
        if (sub.isGradeSubject) continue;
        subjectMap.putIfAbsent(sub.subjectName, () => _SubjectAccum());
        final acc = subjectMap[sub.subjectName]!;
        acc.totalCount++;
        acc.totalPercent += sub.percentage;
        if (sub.isPassed) acc.passCount++;
      }
    }
    final subjectStats = subjectMap.entries.map((e) {
      final acc = e.value;
      return SubjectAnalyticsStat(
        subjectName: e.key,
        averagePercent: acc.totalCount > 0 ? acc.totalPercent / acc.totalCount : 0,
        passCount: acc.passCount,
        totalCount: acc.totalCount,
      );
    }).toList()
      ..sort((a, b) => a.averagePercent.compareTo(b.averagePercent));

    return ClassAnalyticsSummary(
      classId: classId,
      className: className,
      totalStudents: results.length,
      passCount: passCount,
      passPercent: passCount / results.length * 100,
      averagePercent: avgPct,
      highestPercent: ranked.first.percentage,
      lowestPercent: ranked.last.percentage,
      topperName: topper.studentName,
      topperRollNo: topper.rollNo,
      subjectStats: subjectStats,
    );
  }
}

class _SubjectAccum {
  int totalCount = 0;
  int passCount = 0;
  double totalPercent = 0;
}

class SubjectAnalyticsStat {
  const SubjectAnalyticsStat({
    required this.subjectName,
    required this.averagePercent,
    required this.passCount,
    required this.totalCount,
  });

  final String subjectName;
  final double averagePercent;
  final int passCount;
  final int totalCount;

  double get passPercent =>
      totalCount > 0 ? passCount / totalCount * 100 : 0;
}

/// ExamConfig with its class name — loaded via Supabase join.
class ExamConfigWithClass {
  const ExamConfigWithClass({
    required this.config,
    required this.className,
  });
  final ExamConfig config;
  final String className;
}

class SubjectResult {
  const SubjectResult({
    required this.subjectId,
    required this.subjectName,
    required this.isGradeSubject,
    required this.termMarks,
    required this.total,
    required this.maximum,
    required this.percentage,
    required this.grade,
    required this.isPassed,
  });

  final String subjectId;
  final String subjectName;
  final bool isGradeSubject;
  final Map<String, double?> termMarks;   // termId → marks (null if absent/grade)
  final double total;
  final double maximum;
  final double percentage;
  final String grade;
  final bool isPassed;
}
