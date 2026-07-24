// Phase 5 — Report Card Screen
// Individual student report card: subject table, overall summary, PDF + share.
// Uses pdf package (already in pubspec). Layout driven by ReportTemplate fields.
// Never stores totals/percentage/rank — always computed by Result Engine (Phase 2).

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../data/exam_providers.dart';
import '../models/exam_models.dart';
import 'result_screen.dart';
import 'traditional_report_card.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class ReportCardScreen extends ConsumerStatefulWidget {
  const ReportCardScreen({
    super.key,
    required this.classId,
    required this.studentId,
    required this.args,
  });

  final String classId;
  final String studentId;
  final ReportCardArgs args;

  @override
  ConsumerState<ReportCardScreen> createState() => _ReportCardScreenState();
}

class _ReportCardScreenState extends ConsumerState<ReportCardScreen> {
  bool _generating = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.args.studentResult;
    final terms = _sortedFinalTerms(widget.args.terms);
    final templateAsync =
        ref.watch(defaultTemplateProvider(widget.args.academicYear));

    return Scaffold(
      appBar: AppBar(
        title: Text(r.studentName),
        actions: [
          // Traditional Report Card Button
          IconButton(
            tooltip: 'Traditional Report Card',
            icon: const Icon(Icons.print),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TraditionalReportCardScreen(
                    classId: widget.classId,
                    studentId: widget.studentId,
                    args: widget.args,
                  ),
                ),
              );
            },
          ),
          templateAsync.when(
            data: (template) => _generating
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'PDF Generate & Share',
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    onPressed: () => _generateAndShare(template),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StudentHeaderCard(
              result: r,
              academicYear: widget.args.academicYear,
            ),
            const SizedBox(height: 16),
            _SubjectTable(result: r, terms: terms),
            const SizedBox(height: 16),
            _OverallSummaryCard(result: r),
            const SizedBox(height: 24),
            templateAsync.when(
              data: (template) => ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('PDF Generate & Share'),
                onPressed:
                    _generating ? null : () => _generateAndShare(template),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Template error: $e'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  List<ExamTerm> _sortedFinalTerms(List<ExamTerm> terms) {
    final finalTerms =
        terms.where((t) => t.includeInFinalResult).toList();
    finalTerms.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return finalTerms;
  }

  Future<void> _generateAndShare(ReportTemplate? template) async {
    setState(() => _generating = true);
    try {
      final pdfBytes = await _buildPdf(template);
      final safeName = widget.args.studentResult.studentName
          .replaceAll(RegExp(r'[^\w ]'), '_')
          .replaceAll(' ', '_');
      await Share.shareXFiles(
        [XFile.fromData(pdfBytes,
            mimeType: 'application/pdf',
            name: 'report_${safeName}_${widget.args.academicYear}.pdf')],
        subject:
            'Report Card — ${widget.args.studentResult.studentName} (${widget.args.academicYear})',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<Uint8List> _buildPdf(ReportTemplate? template) async {
    final r = widget.args.studentResult;
    final terms = _sortedFinalTerms(widget.args.terms);

    final schoolName = template?.schoolName ?? 'School';
    final schoolAddress = template?.schoolAddress ?? '';
    final principalName = template?.principalName ?? '';
    final showPct = template?.showPercentage ?? true;
    final showRank = template?.showRank ?? true;

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── Header ────────────────────────────────────────────────────
              pw.Center(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      schoolName,
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    if (schoolAddress.isNotEmpty)
                      pw.Text(schoolAddress,
                          style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'REPORT CARD — ${widget.args.academicYear}',
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Divider(thickness: 1.5),
              pw.SizedBox(height: 6),
              // ── Student info ──────────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Student: ${r.studentName}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Roll No: ${r.rollNo}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 8),
              // ── Subject table ─────────────────────────────────────────────
              pw.Table(
                border: pw.TableBorder.all(
                    color: PdfColors.grey400, width: 0.5),
                columnWidths: _pdfColumnWidths(terms.length),
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                        color: PdfColors.indigo100),
                    children: [
                      _pdfCell('Subject', bold: true),
                      for (final t in terms)
                        _pdfCell(t.termName, bold: true),
                      _pdfCell('Total', bold: true),
                      _pdfCell('Grade', bold: true),
                      _pdfCell('Pass/Fail', bold: true),
                    ],
                  ),
                  // Rows
                  for (final sub in r.subjectResults)
                    pw.TableRow(children: [
                      _pdfCell(sub.subjectName),
                      for (final t in terms)
                        _pdfCell(
                          sub.isGradeSubject
                              ? (sub.grade.isNotEmpty ? sub.grade : '-')
                              : _marksLabel(sub.termMarks[t.id]),
                        ),
                      _pdfCell(
                        sub.isGradeSubject
                            ? '-'
                            : '${sub.total.toStringAsFixed(0)}/${sub.maximum.toStringAsFixed(0)}',
                      ),
                      _pdfCell(sub.grade),
                      _pdfCell(
                        sub.isGradeSubject
                            ? '-'
                            : (sub.isPassed ? 'P' : 'F'),
                        color: sub.isGradeSubject
                            ? PdfColors.black
                            : (sub.isPassed
                                ? PdfColors.green800
                                : PdfColors.red700),
                      ),
                    ]),
                ],
              ),
              pw.SizedBox(height: 10),
              // ── Grand total ───────────────────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border:
                      pw.Border.all(color: PdfColors.grey400, width: 0.5),
                ),
                child: pw.Wrap(
                  spacing: 24,
                  children: [
                    pw.Text(
                      'Total: ${r.totalObtained.toStringAsFixed(0)} / ${r.totalMaximum.toStringAsFixed(0)}',
                      style:
                          pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                    ),
                    if (showPct)
                      pw.Text(
                        'Percentage: ${r.percentage.toStringAsFixed(2)}%',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 10),
                      ),
                    pw.Text(
                      'Grade: ${r.grade}',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 10),
                    ),
                    if (showRank && r.rank > 0)
                      pw.Text(
                        'Rank: ${r.rank}',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 10),
                      ),
                    pw.Text(
                      r.isPassed ? 'RESULT: PASS' : 'RESULT: FAIL',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                        color: r.isPassed
                            ? PdfColors.green800
                            : PdfColors.red700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Spacer(),
              // ── Signatures ────────────────────────────────────────────────
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.SizedBox(height: 20),
                      pw.Text('Class Teacher',
                          style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  if (principalName.isNotEmpty)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.SizedBox(height: 20),
                        pw.Text('Principal: $principalName',
                            style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  Map<int, pw.TableColumnWidth> _pdfColumnWidths(int termCount) {
    final m = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(2.5),
    };
    for (int i = 1; i <= termCount; i++) {
      m[i] = const pw.FlexColumnWidth(1);
    }
    m[termCount + 1] = const pw.FlexColumnWidth(1.4); // Total
    m[termCount + 2] = const pw.FlexColumnWidth(0.9); // Grade
    m[termCount + 3] = const pw.FlexColumnWidth(1.0); // Pass/Fail
    return m;
  }

  pw.Widget _pdfCell(String text,
      {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  String _marksLabel(double? marks) {
    if (marks == null) return 'Ab'; // Absent
    return marks.truncateToDouble() == marks
        ? marks.toInt().toString()
        : marks.toStringAsFixed(1);
  }
}

// ── Student Header Card ───────────────────────────────────────────────────────

class _StudentHeaderCard extends StatelessWidget {
  const _StudentHeaderCard(
      {required this.result, required this.academicYear});
  final StudentResult result;
  final String academicYear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passColor = result.isPassed
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.studentName,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                      'Roll No: ${result.rollNo}  |  Session: $academicYear',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (result.totalMaximum > 0) ...[
                        _InfoChip(
                          label:
                              '${result.totalObtained.toStringAsFixed(0)} / ${result.totalMaximum.toStringAsFixed(0)}',
                          color: theme.colorScheme.primary,
                        ),
                        _InfoChip(
                          label: '${result.percentage.toStringAsFixed(2)}%',
                          color: theme.colorScheme.primary,
                        ),
                      ],
                      _InfoChip(
                          label: result.grade,
                          color: const Color(0xFFF59E0B)),
                      if (result.rank > 0)
                        _InfoChip(
                            label: 'Rank #${result.rank}',
                            color: const Color(0xFF8B5CF6)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: passColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                result.isPassed ? 'PASS' : 'FAIL',
                style: TextStyle(
                  color: passColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }
}

// ── Subject Table ─────────────────────────────────────────────────────────────

class _SubjectTable extends StatelessWidget {
  const _SubjectTable({required this.result, required this.terms});
  final StudentResult result;
  final List<ExamTerm> terms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subject-wise Result',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 38,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 44,
                columnSpacing: 14,
                columns: [
                  const DataColumn(label: Text('Subject')),
                  for (final t in terms)
                    DataColumn(
                      label: Text(t.termName,
                          style: const TextStyle(fontSize: 12)),
                      numeric: true,
                    ),
                  const DataColumn(label: Text('Total'), numeric: true),
                  const DataColumn(label: Text('Grade')),
                  const DataColumn(label: Text('P/F')),
                ],
                rows: result.subjectResults.map((sub) {
                  final passColor = sub.isGradeSubject
                      ? Colors.grey
                      : (sub.isPassed
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444));
                  return DataRow(cells: [
                    DataCell(Text(sub.subjectName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 13))),
                    for (final t in terms)
                      DataCell(sub.isGradeSubject
                          ? Text(
                              sub.grade.isNotEmpty ? sub.grade : '-',
                              style: const TextStyle(fontSize: 13),
                            )
                          : Text(
                              _marksLabel(sub.termMarks[t.id]),
                              style: const TextStyle(fontSize: 13),
                            )),
                    DataCell(Text(
                      sub.isGradeSubject
                          ? '-'
                          : '${sub.total.toStringAsFixed(0)}/${sub.maximum.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    )),
                    DataCell(
                        Text(sub.grade, style: const TextStyle(fontSize: 13))),
                    DataCell(sub.isGradeSubject
                        ? const Text('-',
                            style: TextStyle(fontSize: 13))
                        : Text(
                            sub.isPassed ? 'P' : 'F',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: passColor,
                            ),
                          )),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _marksLabel(double? marks) {
    if (marks == null) return 'Ab';
    return marks.truncateToDouble() == marks
        ? marks.toInt().toString()
        : marks.toStringAsFixed(1);
  }
}

// ── Overall Summary Card ──────────────────────────────────────────────────────

class _OverallSummaryCard extends StatelessWidget {
  const _OverallSummaryCard({required this.result});
  final StudentResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passColor = result.isPassed
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overall Result',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (result.totalMaximum > 0) ...[
              _StatRow(
                'Grand Total',
                '${result.totalObtained.toStringAsFixed(0)} / ${result.totalMaximum.toStringAsFixed(0)}',
              ),
              _StatRow('Percentage',
                  '${result.percentage.toStringAsFixed(2)} %'),
            ],
            _StatRow('Overall Grade', result.grade),
            if (result.rank > 0) _StatRow('Class Rank', '#${result.rank}'),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Final Result',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: passColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    result.isPassed ? 'PASS' : 'FAIL',
                    style: TextStyle(
                        color: passColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
