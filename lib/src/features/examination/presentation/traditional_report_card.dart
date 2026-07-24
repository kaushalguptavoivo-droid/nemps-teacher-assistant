// Traditional Indian School Report Card
// Excel-style report card with traditional layout
// Uses HTML tables, black borders, Times New Roman font

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/exam_providers.dart';
import '../models/exam_models.dart';
import 'result_screen.dart';

class TraditionalReportCardScreen extends ConsumerStatefulWidget {
  const TraditionalReportCardScreen({
    super.key,
    required this.classId,
    required this.studentId,
    required this.args,
  });

  final String classId;
  final String studentId;
  final ReportCardArgs args;

  @override
  ConsumerState<TraditionalReportCardScreen> createState() =>
      _TraditionalReportCardScreenState();
}

class _TraditionalReportCardScreenState
    extends ConsumerState<TraditionalReportCardScreen> {
  bool _generating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Card'),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        actions: [
          if (_generating)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Print Report Card',
              icon: const Icon(Icons.print),
              onPressed: _printReportCard,
            ),
        ],
      ),
      body: PdfPreview(
        build: (format) => _buildPdf(format),
        pdfFileName: 'report_card_${widget.args.studentResult.studentName}.pdf',
        canChangeOrientation: false,
        canChangePageFormat: false,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }

  Future<void> _printReportCard() async {
    setState(() => _generating = true);
    try {
      final pdfBytes = await _buildPdf(PdfPageFormat.a4);
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'Report Card - ${widget.args.studentResult.studentName}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final r = widget.args.studentResult;
    final terms = _sortedFinalTerms(widget.args.terms);
    final templateAsync =
        ref.watch(defaultTemplateProvider(widget.args.academicYear));

    final template = templateAsync.valueOrNull;
    final schoolName = template?.schoolName ?? 'NEW ERA MODERN PUBLIC SCHOOL';
    final schoolAddress =
        template?.schoolAddress ?? 'BANKEY BIHARI COLONY, RAMAN RETI ROAD, VRINDAVAN';
    final session = widget.args.academicYear;

    final pdf = pw.Document();

    // Get student info from result
    final studentName = r.studentName;
    final rollNo = r.rollNo;
    final className = template?.className ?? '';

    // Calculate totals
    double totalObtained = 0;
    double totalMaximum = 0;
    for (final sub in r.subjectResults) {
      if (!sub.isGradeSubject) {
        totalObtained += sub.total;
        totalMaximum += sub.maximum;
      }
    }
    final percentage =
        totalMaximum > 0 ? (totalObtained / totalMaximum * 100) : 0.0;
    final grade = r.grade;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(8 * PdfPageFormat.mm),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ═══════════════════════════════════════════════════════════════
              // HEADER SECTION
              // ═══════════════════════════════════════════════════════════════
              _buildHeader(schoolName, schoolAddress, session),
              pw.SizedBox(height: 3),

              // ═══════════════════════════════════════════════════════════════
              // STUDENT DETAILS
              // ═══════════════════════════════════════════════════════════════
              _buildStudentDetails(studentName, className, rollNo),
              pw.SizedBox(height: 3),

              // ═══════════════════════════════════════════════════════════════
              // SUBJECT MARKS TABLE
              // ═══════════════════════════════════════════════════════════════
              _buildMarksTable(r, terms),
              pw.SizedBox(height: 3),

              // ═══════════════════════════════════════════════════════════════
              // ATTENDANCE & RESULT
              // ═══════════════════════════════════════════════════════════════
              _buildAttendanceResult(totalObtained, totalMaximum, percentage, grade, r.isPassed),
              pw.SizedBox(height: 3),

              // ═══════════════════════════════════════════════════════════════
              // FOOTER - SIGNATURES
              // ═══════════════════════════════════════════════════════════════
              _buildFooter(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(String schoolName, String address, String session) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 2),
      ),
      child: pw.Column(
        children: [
          // School Name
          pw.Text(
            schoolName,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              font: pw.Font.timesBold(),
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 2),
          // Tagline
          pw.Text(
            '(AN ENGLISH MEDIUM REGD. & RECOGNIZED INSTITUTION)',
            style: pw.TextStyle(
              fontSize: 7,
              font: pw.Font.times(),
            ),
            textAlign: pw.TextAlign.center,
          ),
          // Address
          pw.Text(
            address,
            style: pw.TextStyle(
              fontSize: 8,
              font: pw.Font.times(),
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 3),
          // Progress Report Title
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1.5),
            ),
            child: pw.Text(
              'PROGRESS REPORT',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                font: pw.Font.timesBold(),
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 2),
          // Session
          pw.Text(
            '(Session $session)',
            style: pw.TextStyle(
              fontSize: 9,
              font: pw.Font.times(),
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStudentDetails(
      String studentName, String className, String rollNo) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Row(
              children: [
                pw.Text('Student Name : ',
                    style: _labelStyle(), textAlign: pw.TextAlign.left),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.only(left: 3),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide()),
                    ),
                    child: pw.Text(studentName,
                        style: _valueStyle(), textAlign: pw.TextAlign.left),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Row(
              children: [
                pw.Text('Class : ',
                    style: _labelStyle(), textAlign: pw.TextAlign.left),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.only(left: 3),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide()),
                    ),
                    child: pw.Text(className,
                        style: _valueStyle(), textAlign: pw.TextAlign.left),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Row(
              children: [
                pw.Text('Roll No. : ',
                    style: _labelStyle(), textAlign: pw.TextAlign.left),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.only(left: 3),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide()),
                    ),
                    child: pw.Text(rollNo,
                        style: _valueStyle(), textAlign: pw.TextAlign.left),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMarksTable(StudentResult r, List<ExamTerm> terms) {
    // Split terms into Bi-Annual and Annual sections
    final biAnnualTerms = terms.take(2).toList(); // UT1, Half Yearly
    final annualTerms = terms.skip(2).toList(); // UT2, Annual

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1),
      ),
      child: pw.Column(
        children: [
          // Header Row
          _buildTableRow([
            pw.Container(
              padding: const pw.EdgeInsets.all(2),
              child: pw.Text('SUBJECT',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    font: pw.Font.timesBold(),
                  ),
                  textAlign: pw.TextAlign.center),
            ),
            // Bi-Annual Section Header
            pw.Container(
              padding: const pw.EdgeInsets.all(2),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              child: pw.Column(
                children: [
                  pw.Text('BI-ANNUAL',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        font: pw.Font.timesBold(),
                      ),
                      textAlign: pw.TextAlign.center),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: biAnnualTerms.map((t) => pw.Container(
                          width: 35,
                          padding: const pw.EdgeInsets.symmetric(vertical: 1),
                          child: pw.Text(t.termName,
                              style: pw.TextStyle(
                                  fontSize: 7,
                                  font: pw.Font.timesBold()),
                              textAlign: pw.TextAlign.center),
                        )).toList(),
                  ),
                ],
              ),
            ),
            // Annual Section Header
            pw.Container(
              padding: const pw.EdgeInsets.all(2),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              child: pw.Column(
                children: [
                  pw.Text('ANNUAL',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        font: pw.Font.timesBold(),
                      ),
                      textAlign: pw.TextAlign.center),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: annualTerms.map((t) => pw.Container(
                          width: 35,
                          padding: const pw.EdgeInsets.symmetric(vertical: 1),
                          child: pw.Text(t.termName,
                              style: pw.TextStyle(
                                  fontSize: 7,
                                  font: pw.Font.timesBold()),
                              textAlign: pw.TextAlign.center),
                        )).toList(),
                  ),
                ],
              ),
            ),
            // Total & Grade
            pw.Container(
              padding: const pw.EdgeInsets.all(2),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              child: pw.Column(
                children: [
                  pw.Text('TOTAL',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        font: pw.Font.timesBold(),
                      ),
                      textAlign: pw.TextAlign.center),
                  pw.Text('200',
                      style: pw.TextStyle(fontSize: 7, font: pw.Font.timesBold()),
                      textAlign: pw.TextAlign.center),
                ],
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(2),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              child: pw.Column(
                children: [
                  pw.Text('GRADE',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        font: pw.Font.timesBold(),
                      ),
                      textAlign: pw.TextAlign.center),
                  pw.Text('',
                      style: pw.TextStyle(fontSize: 7, font: pw.Font.timesBold()),
                      textAlign: pw.TextAlign.center),
                ],
              ),
            ),
          ], isHeader: true),

          // Subject Rows
          ...r.subjectResults.map((sub) {
            if (sub.isGradeSubject) {
              // Drawing - only show grade, no marks
              return _buildGradeSubjectRow(sub, terms);
            } else {
              return _buildSubjectRow(sub, terms);
            }
          }),

          // Grand Total Row
          _buildGrandTotalRow(r),
        ],
      ),
    );
  }

  pw.Widget _buildTableRow(List<pw.Widget> cells, {bool isHeader = false}) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: const pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 1),
        ),
      ),
      child: pw.Row(
        children: cells.map((cell) {
          return pw.Expanded(
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              child: cell,
            ),
          );
        }).toList(),
      ),
    );
  }

  pw.Widget _buildSubjectRow(SubjectResult sub, List<ExamTerm> terms) {
    final biAnnualTerms = terms.take(2).toList();
    final annualTerms = terms.skip(2).toList();

    // Get marks for each term
    final ut1Marks = sub.termMarks[biAnnualTerms.isNotEmpty ? biAnnualTerms[0].id : ''];
    final hyMarks = sub.termMarks[biAnnualTerms.length > 1 ? biAnnualTerms[1].id : ''];
    final ut2Marks = sub.termMarks[annualTerms.isNotEmpty ? annualTerms[0].id : ''];
    final annualMarks = sub.termMarks[annualTerms.length > 1 ? annualTerms[1].id : ''];

    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
        ),
      ),
      child: pw.Row(
        children: [
          // Subject Name
          pw.Expanded(
            flex: 2,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(2),
              child: pw.Text(sub.subjectName,
                  style: pw.TextStyle(
                    fontSize: 8,
                    font: pw.Font.times(),
                  )),
            ),
          ),
          // Bi-Annual marks
          pw.Expanded(
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              child: pw.Row(
                children: biAnnualTerms.map((t) {
                  final marks = sub.termMarks[t.id];
                  return pw.Container(
                    width: 35,
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Text(
                      marks != null ? marks.toInt().toString() : '-',
                      style: pw.TextStyle(fontSize: 8, font: pw.Font.times()),
                      textAlign: pw.TextAlign.center,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Annual marks
          pw.Expanded(
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              child: pw.Row(
                children: annualTerms.map((t) {
                  final marks = sub.termMarks[t.id];
                  return pw.Container(
                    width: 35,
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Text(
                      marks != null ? marks.toInt().toString() : '-',
                      style: pw.TextStyle(fontSize: 8, font: pw.Font.times()),
                      textAlign: pw.TextAlign.center,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Total
          pw.Expanded(
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              padding: const pw.EdgeInsets.all(2),
              child: pw.Text(
                '${sub.total.toInt()}/${sub.maximum.toInt()}',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  font: pw.Font.timesBold(),
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ),
          // Grade
          pw.Expanded(
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              padding: const pw.EdgeInsets.all(2),
              child: pw.Text(
                sub.grade,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  font: pw.Font.timesBold(),
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildGradeSubjectRow(SubjectResult sub, List<ExamTerm> terms) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
        ),
      ),
      child: pw.Row(
        children: [
          // Subject Name
          pw.Expanded(
            flex: 2,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(2),
              child: pw.Text(sub.subjectName,
                  style: pw.TextStyle(
                    fontSize: 8,
                    font: pw.Font.times(),
                  )),
            ),
          ),
          // Bi-Annual - empty
          pw.Expanded(
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              padding: const pw.EdgeInsets.all(2),
              child: pw.Text('-', style: pw.TextStyle(fontSize: 8)),
            ),
          ),
          // Annual - empty
          pw.Expanded(
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              padding: const pw.EdgeInsets.all(2),
              child: pw.Text('-', style: pw.TextStyle(fontSize: 8)),
            ),
          ),
          // Total - empty for grade subjects
          pw.Expanded(
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              padding: const pw.EdgeInsets.all(2),
              child: pw.Text('-', style: pw.TextStyle(fontSize: 8)),
            ),
          ),
          // Grade
          pw.Expanded(
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              padding: const pw.EdgeInsets.all(2),
              child: pw.Text(
                sub.grade.isNotEmpty ? sub.grade : 'A',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  font: pw.Font.timesBold(),
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildGrandTotalRow(StudentResult r) {
    double totalObtained = 0;
    double totalMax = 0;
    for (final sub in r.subjectResults) {
      if (!sub.isGradeSubject) {
        totalObtained += sub.total;
        totalMax += sub.maximum;
      }
    }
    final percentage = totalMax > 0 ? (totalObtained / totalMax * 100) : 0.0;

    return pw.Container(
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey200,
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.black, width: 1.5),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(3),
              child: pw.Text('GRAND TOTAL',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    font: pw.Font.timesBold(),
                  )),
            ),
          ),
          // Bi-Annual total
          pw.Expanded(
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              padding: const pw.EdgeInsets.all(3),
              child: pw.Text(
                  '${_getBiAnnualTotal(r).toInt()}',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    font: pw.Font.timesBold(),
                  ),
                  textAlign: pw.TextAlign.center),
            ),
          ),
          // Annual total
          pw.Expanded(
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              padding: const pw.EdgeInsets.all(3),
              child: pw.Text(
                  '${_getAnnualTotal(r).toInt()}',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    font: pw.Font.timesBold(),
                  ),
                  textAlign: pw.TextAlign.center),
            ),
          ),
          // Grand Total
          pw.Expanded(
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              padding: const pw.EdgeInsets.all(3),
              child: pw.Text(
                  '${totalObtained.toInt()}/${totalMax.toInt()}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    font: pw.Font.timesBold(),
                  ),
                  textAlign: pw.TextAlign.center),
            ),
          ),
          // Percentage
          pw.Expanded(
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              padding: const pw.EdgeInsets.all(3),
              child: pw.Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    font: pw.Font.timesBold(),
                  ),
                  textAlign: pw.TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }

  double _getBiAnnualTotal(StudentResult r) {
    double total = 0;
    for (final sub in r.subjectResults) {
      if (!sub.isGradeSubject) {
        final marks = sub.termMarks.values.take(2).fold<double>(0, (a, b) => a + (b ?? 0));
        total += marks;
      }
    }
    return total;
  }

  double _getAnnualTotal(StudentResult r) {
    double total = 0;
    for (final sub in r.subjectResults) {
      if (!sub.isGradeSubject) {
        final marks = sub.termMarks.values.skip(2).fold<double>(0, (a, b) => a + (b ?? 0));
        total += marks;
      }
    }
    return total;
  }

  pw.Widget _buildAttendanceResult(
      double obtained, double maximum, double percentage, String grade, bool isPassed) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Result
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Text('Result : ', style: _labelStyle()),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 1),
                      ),
                      child: pw.Text(
                        isPassed ? 'PASS' : 'FAIL',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          font: pw.Font.timesBold(),
                          color: isPassed ? PdfColors.green800 : PdfColors.red800,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Text('Grade : ', style: _labelStyle()),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 1),
                      ),
                      child: pw.Text(
                        grade,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          font: pw.Font.timesBold(),
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Text('Percentage : ${percentage.toStringAsFixed(1)}%',
                    style: pw.TextStyle(fontSize: 9, font: pw.Font.times())),
              ],
            ),
          ),
          // Attendance
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(3),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('ATTENDANCE',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        font: pw.Font.timesBold(),
                      )),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    children: [
                      pw.Text('Days Present : ', style: _smallLabel()),
                      pw.Container(
                        width: 40,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(bottom: pw.BorderSide()),
                        ),
                        child: pw.Text('____',
                            style: pw.TextStyle(fontSize: 9, font: pw.Font.times())),
                      ),
                      pw.Text(' / ', style: pw.TextStyle(fontSize: 9)),
                      pw.Container(
                        width: 40,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(bottom: pw.BorderSide()),
                        ),
                        child: pw.Text('____',
                            style: pw.TextStyle(fontSize: 9, font: pw.Font.times())),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Teacher Signature
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 100,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide()),
                ),
                child: pw.SizedBox(height: 20),
              ),
              pw.SizedBox(height: 3),
              pw.Text('Teacher\'s Signature',
                  style: pw.TextStyle(fontSize: 8, font: pw.Font.times())),
            ],
          ),
          // Parent Signature
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 100,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide()),
                ),
                child: pw.SizedBox(height: 20),
              ),
              pw.SizedBox(height: 3),
              pw.Text('Parent\'s Signature',
                  style: pw.TextStyle(fontSize: 8, font: pw.Font.times())),
            ],
          ),
          // Principal Signature
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 100,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide()),
                ),
                child: pw.SizedBox(height: 20),
              ),
              pw.SizedBox(height: 3),
              pw.Text('Principal\'s Signature',
                  style: pw.TextStyle(fontSize: 8, font: pw.Font.times())),
            ],
          ),
        ],
      ),
    );
  }

  pw.TextStyle _labelStyle() {
    return pw.TextStyle(
      fontSize: 9,
      font: pw.Font.timesBold(),
    );
  }

  pw.TextStyle _valueStyle() {
    return pw.TextStyle(
      fontSize: 9,
      font: pw.Font.times(),
    );
  }

  pw.TextStyle _smallLabel() {
    return pw.TextStyle(
      fontSize: 8,
      font: pw.Font.times(),
    );
  }

  List<ExamTerm> _sortedFinalTerms(List<ExamTerm> terms) {
    final finalTerms = terms.where((t) => t.includeInFinalResult).toList();
    finalTerms.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return finalTerms;
  }
}
