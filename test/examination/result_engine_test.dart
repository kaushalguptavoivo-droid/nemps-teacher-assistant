// Phase 9 — Unit Tests: Result Engine & Models
// Pure Dart tests — no Flutter, no DB, no network.
// Run with: flutter test test/examination/result_engine_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:nemps_teacher_assistant/src/features/examination/models/exam_models.dart';

void main() {
  // ── GradeConfig.resolveGrade ───────────────────────────────────────────────

  group('GradeConfig.resolveGrade', () {
    final grades = [
      GradeConfig(id: '1', academicYear: '2026-27', grade: 'A1',
          minimumPercentage: 91, maximumPercentage: 100, displayOrder: 1),
      GradeConfig(id: '2', academicYear: '2026-27', grade: 'A2',
          minimumPercentage: 81, maximumPercentage: 90, displayOrder: 2),
      GradeConfig(id: '3', academicYear: '2026-27', grade: 'B1',
          minimumPercentage: 71, maximumPercentage: 80, displayOrder: 3),
      GradeConfig(id: '4', academicYear: '2026-27', grade: 'D',
          minimumPercentage: 33, maximumPercentage: 40, displayOrder: 7),
      GradeConfig(id: '5', academicYear: '2026-27', grade: 'E',
          minimumPercentage: 0, maximumPercentage: 32, displayOrder: 8),
    ];

    test('returns A1 for 95%', () {
      expect(GradeConfig.resolveGrade(95, grades), 'A1');
    });

    test('returns A1 for exactly 91%', () {
      expect(GradeConfig.resolveGrade(91, grades), 'A1');
    });

    test('returns A2 for 85%', () {
      expect(GradeConfig.resolveGrade(85, grades), 'A2');
    });

    test('returns E for 0%', () {
      expect(GradeConfig.resolveGrade(0, grades), 'E');
    });

    test('returns E for 30%', () {
      expect(GradeConfig.resolveGrade(30, grades), 'E');
    });

    test('returns D for exactly 33%', () {
      expect(GradeConfig.resolveGrade(33, grades), 'D');
    });

    test('returns N/A when no grade matches', () {
      expect(GradeConfig.resolveGrade(50, []), 'N/A');
    });

    test('returns A1 for 100%', () {
      expect(GradeConfig.resolveGrade(100, grades), 'A1');
    });
  });

  // ── ClassAnalyticsSummary.fromResults ─────────────────────────────────────

  group('ClassAnalyticsSummary.fromResults', () {
    SubjectResult makeSubject(String name, double total, double max, bool passed) {
      return SubjectResult(
        subjectId: name,
        subjectName: name,
        isGradeSubject: false,
        termMarks: {},
        total: total,
        maximum: max,
        percentage: max > 0 ? total / max * 100 : 0,
        grade: total / max * 100 >= 33 ? 'D' : 'E',
        isPassed: passed,
      );
    }

    StudentResult makeResult(String id, String name, String rollNo,
        double obtained, double maximum, bool passed, int rank) {
      return StudentResult(
        studentId: id,
        studentName: name,
        rollNo: rollNo,
        subjectResults: [
          makeSubject('Hindi', obtained * 0.5, maximum * 0.5, passed),
          makeSubject('Maths', obtained * 0.5, maximum * 0.5, passed),
        ],
        totalObtained: obtained,
        totalMaximum: maximum,
        percentage: maximum > 0 ? obtained / maximum * 100 : 0,
        grade: obtained / maximum * 100 >= 33 ? 'D' : 'E',
        isPassed: passed,
        rank: rank,
      );
    }

    test('empty results returns zero summary', () {
      final s = ClassAnalyticsSummary.fromResults(
          classId: 'c1', className: 'Class 1', results: []);
      expect(s.totalStudents, 0);
      expect(s.passCount, 0);
      expect(s.passPercent, 0);
    });

    test('correct pass count and percent', () {
      final results = [
        makeResult('s1', 'Rahul', '01', 160, 200, true, 1),
        makeResult('s2', 'Priya', '02', 120, 200, true, 2),
        makeResult('s3', 'Mohan', '03', 50, 200, false, 3),
      ];
      final s = ClassAnalyticsSummary.fromResults(
          classId: 'c1', className: 'Class 1', results: results);

      expect(s.totalStudents, 3);
      expect(s.passCount, 2);
      expect(s.failCount, 1);
      expect(s.passPercent, closeTo(66.67, 0.01));
    });

    test('topper is the highest scorer', () {
      final results = [
        makeResult('s1', 'Rahul', '01', 160, 200, true, 1),
        makeResult('s2', 'Priya', '02', 190, 200, true, 2),
        makeResult('s3', 'Mohan', '03', 50, 200, false, 3),
      ];
      final s = ClassAnalyticsSummary.fromResults(
          classId: 'c1', className: 'Class 1', results: results);

      expect(s.topperName, 'Priya');
      expect(s.topperRollNo, '02');
    });

    test('highest and lowest percent are correct', () {
      final results = [
        makeResult('s1', 'A', '01', 180, 200, true, 1),
        makeResult('s2', 'B', '02', 100, 200, true, 2),
        makeResult('s3', 'C', '03', 60, 200, false, 3),
      ];
      final s = ClassAnalyticsSummary.fromResults(
          classId: 'c1', className: 'Class 1', results: results);

      expect(s.highestPercent, closeTo(90.0, 0.001));
      expect(s.lowestPercent, closeTo(30.0, 0.001));
    });

    test('average percent is correct', () {
      final results = [
        makeResult('s1', 'A', '01', 200, 200, true, 1),   // 100%
        makeResult('s2', 'B', '02', 100, 200, true, 2),   // 50%
      ];
      final s = ClassAnalyticsSummary.fromResults(
          classId: 'c1', className: 'Class 1', results: results);

      expect(s.averagePercent, closeTo(75.0, 0.001));
    });

    test('subjectStats sorted by lowest average percent first', () {
      // Maths average will be lower than Hindi
      final hindiPass = SubjectResult(
        subjectId: 'hindi', subjectName: 'Hindi', isGradeSubject: false,
        termMarks: {}, total: 80, maximum: 100,
        percentage: 80, grade: 'B1', isPassed: true,
      );
      final mathsPass = SubjectResult(
        subjectId: 'maths', subjectName: 'Maths', isGradeSubject: false,
        termMarks: {}, total: 40, maximum: 100,
        percentage: 40, grade: 'D', isPassed: true,
      );
      final result = StudentResult(
        studentId: 's1', studentName: 'Test', rollNo: '01',
        subjectResults: [hindiPass, mathsPass],
        totalObtained: 120, totalMaximum: 200,
        percentage: 60, grade: 'C1', isPassed: true, rank: 1,
      );
      final s = ClassAnalyticsSummary.fromResults(
          classId: 'c1', className: 'Class 1', results: [result]);

      // Maths (40%) should be first (weakest)
      expect(s.subjectStats.first.subjectName, 'Maths');
      expect(s.subjectStats.last.subjectName, 'Hindi');
    });

    test('grade subjects excluded from subjectStats', () {
      final drawing = SubjectResult(
        subjectId: 'd1', subjectName: 'Drawing', isGradeSubject: true,
        termMarks: {}, total: 0, maximum: 0,
        percentage: 0, grade: 'A', isPassed: true,
      );
      final hindi = SubjectResult(
        subjectId: 'h1', subjectName: 'Hindi', isGradeSubject: false,
        termMarks: {}, total: 70, maximum: 100,
        percentage: 70, grade: 'B1', isPassed: true,
      );
      final result = StudentResult(
        studentId: 's1', studentName: 'Test', rollNo: '01',
        subjectResults: [drawing, hindi],
        totalObtained: 70, totalMaximum: 100,
        percentage: 70, grade: 'B1', isPassed: true, rank: 1,
      );
      final s = ClassAnalyticsSummary.fromResults(
          classId: 'c1', className: 'Class 1', results: [result]);

      expect(s.subjectStats.length, 1);
      expect(s.subjectStats.first.subjectName, 'Hindi');
    });
  });

  // ── PromotionRecord.fromMap / toUpsertMap round-trip ─────────────────────

  group('PromotionRecord', () {
    final now = DateTime.parse('2026-07-22T10:00:00.000Z');

    test('fromMap reads all fields correctly', () {
      final map = {
        'id': 'pr1',
        'student_id': 's1',
        'class_id': 'c1',
        'academic_year': '2026-27',
        'result_status': 'pass',
        'promotion_status': 'promoted',
        'promoted_to_class_id': null,
        'is_manual_override': false,
        'override_reason': null,
        'overridden_by': null,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      final record = PromotionRecord.fromMap(map);
      expect(record.id, 'pr1');
      expect(record.resultStatus, 'pass');
      expect(record.promotionStatus, 'promoted');
      expect(record.isManualOverride, false);
    });

    test('toUpsertMap includes mandatory fields', () {
      final record = PromotionRecord(
        id: 'pr1',
        studentId: 's1',
        classId: 'c1',
        academicYear: '2026-27',
        resultStatus: 'fail',
        promotionStatus: 'not_promoted',
        isManualOverride: true,
        overrideReason: 'Medical',
        createdAt: now,
        updatedAt: now,
      );
      final map = record.toUpsertMap();
      expect(map['student_id'], 's1');
      expect(map['result_status'], 'fail');
      expect(map['promotion_status'], 'not_promoted');
      expect(map['is_manual_override'], true);
      expect(map['override_reason'], 'Medical');
    });

    test('toUpsertMap omits null optional fields', () {
      final record = PromotionRecord(
        id: 'pr1',
        studentId: 's1',
        classId: 'c1',
        academicYear: '2026-27',
        resultStatus: 'pass',
        promotionStatus: 'promoted',
        isManualOverride: false,
        createdAt: now,
        updatedAt: now,
      );
      final map = record.toUpsertMap();
      expect(map.containsKey('override_reason'), false);
      expect(map.containsKey('promoted_to_class_id'), false);
    });
  });

  // ── ExamTerm.toInsertMap ──────────────────────────────────────────────────

  group('ExamTerm', () {
    test('toInsertMap contains required fields', () {
      final term = ExamTerm(
        id: '',
        examConfigId: 'config1',
        termName: 'UT1',
        maximumMarks: 20,
        displayOrder: 1,
        includeInFinalResult: true,
        createdAt: DateTime.now(),
      );
      final map = term.toInsertMap();
      expect(map['exam_config_id'], 'config1');
      expect(map['term_name'], 'UT1');
      expect(map['maximum_marks'], 20.0);
      expect(map['display_order'], 1);
      expect(map['include_in_final_result'], true);
    });
  });

  // ── SubjectAnalyticsStat ──────────────────────────────────────────────────

  group('SubjectAnalyticsStat.passPercent', () {
    test('100% pass', () {
      final s = SubjectAnalyticsStat(
          subjectName: 'Maths', averagePercent: 75, passCount: 10, totalCount: 10);
      expect(s.passPercent, 100.0);
    });

    test('50% pass', () {
      final s = SubjectAnalyticsStat(
          subjectName: 'Maths', averagePercent: 45, passCount: 5, totalCount: 10);
      expect(s.passPercent, 50.0);
    });

    test('zero totalCount returns 0', () {
      final s = SubjectAnalyticsStat(
          subjectName: 'Maths', averagePercent: 0, passCount: 0, totalCount: 0);
      expect(s.passPercent, 0.0);
    });
  });
}
