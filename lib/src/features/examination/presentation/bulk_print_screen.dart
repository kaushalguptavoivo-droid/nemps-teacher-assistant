// Phase 6 — Bulk Print Screen
// Generates a single PDF containing one report card per page for:
//   • All students in the class
//   • A hand-picked selection (checkboxes)
//   • A roll-number range
// Paper size configurable: A4 / Legal / A5.
// Uses the same per-student PDF layout as ReportCardScreen (Phase 5).
// Never re-fetches marks from Supabase — reuses precomputed StudentResult list.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../data/exam_providers.dart';
import '../models/exam_models.dart';
import 'result_screen.dart' show BulkPrintArgs, ReportCardArgs;

// ── Print mode ────────────────────────────────────────────────────────────────

enum _PrintMode { all, selected, rollRange }

// ── Screen ────────────────────────────────────────────────────────────────────

class BulkPrintScreen extends ConsumerStatefulWidget {
  const BulkPrintScreen({
    super.key,
    required this.classId,
    required this.args,
  });

  final String classId;
  final BulkPrintArgs args;

  @override
  ConsumerState<BulkPrintScreen> createState() => _BulkPrintScreenState();
}

class _BulkPrintScreenState extends ConsumerState<BulkPrintScreen> {
  _PrintMode _mode = _PrintMode.all;
  PdfPageFormat _pageFormat = PdfPageFormat.a4;
  String _pageSizeLabel = 'A4';

  // Selected-students mode
  final Set<String> _selectedIds = {};

  // Roll-range mode
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();

  // Generation state
  bool _generating = false;
  int _progress = 0;
  int _progressTotal = 0;
  Uint8List? _generatedBytes;

  @override
  void initState() {
    super.initState();
    // Default: all selected
    for (final r in widget.args.allResults) {
      _selectedIds.add(r.studentId);
    }
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  List<StudentResult> get _filteredResults {
    final all = widget.args.allResults;
    switch (_mode) {
      case _PrintMode.all:
        return all;
      case _PrintMode.selected:
        return all.where((r) => _selectedIds.contains(r.studentId)).toList();
      case _PrintMode.rollRange:
        final from = int.tryParse(_fromCtrl.text.trim());
        final to = int.tryParse(_toCtrl.text.trim());
        if (from == null || to == null) return all;
        return all.where((r) {
          final roll = int.tryParse(r.rollNo.trim());
          if (roll == null) return false;
          return roll >= from && roll <= to;
        }).toList();
    }
  }

  List<ExamTerm> get _finalTerms {
    final t = widget.args.terms.where((t) => t.includeInFinalResult).toList();
    t.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return t;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredResults;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Print'),
        actions: [
          if (_generatedBytes != null)
            IconButton(
              tooltip: 'Share PDF',
              icon: const Icon(Icons.share_rounded),
              onPressed: _share,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Mode selector ─────────────────────────────────────────────
            _SectionTitle('Print Mode'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _ModeTile(
                    value: _PrintMode.all,
                    groupValue: _mode,
                    title: 'All Students',
                    subtitle: 'Puri class ka ek PDF',
                    icon: Icons.groups_rounded,
                    onChanged: (v) => setState(() {
                      _mode = v!;
                      _generatedBytes = null;
                    }),
                  ),
                  _ModeTile(
                    value: _PrintMode.selected,
                    groupValue: _mode,
                    title: 'Selected Students',
                    subtitle: 'Checkboxes se choose karein',
                    icon: Icons.checklist_rounded,
                    onChanged: (v) => setState(() {
                      _mode = v!;
                      _generatedBytes = null;
                    }),
                  ),
                  _ModeTile(
                    value: _PrintMode.rollRange,
                    groupValue: _mode,
                    title: 'Roll Number Range',
                    subtitle: 'From–To range specify karein',
                    icon: Icons.format_list_numbered_rounded,
                    onChanged: (v) => setState(() {
                      _mode = v!;
                      _generatedBytes = null;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Mode-specific controls ────────────────────────────────────
            if (_mode == _PrintMode.selected) ...[
              _SectionTitle('Students Chunein'),
              const SizedBox(height: 8),
              _StudentChecklist(
                allResults: widget.args.allResults,
                selectedIds: _selectedIds,
                onToggle: (id, selected) {
                  setState(() {
                    if (selected) {
                      _selectedIds.add(id);
                    } else {
                      _selectedIds.remove(id);
                    }
                    _generatedBytes = null;
                  });
                },
                onSelectAll: () => setState(() {
                  _selectedIds
                    ..clear()
                    ..addAll(widget.args.allResults.map((r) => r.studentId));
                  _generatedBytes = null;
                }),
                onClearAll: () => setState(() {
                  _selectedIds.clear();
                  _generatedBytes = null;
                }),
              ),
              const SizedBox(height: 16),
            ],
            if (_mode == _PrintMode.rollRange) ...[
              _SectionTitle('Roll Number Range'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _fromCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'From (Roll No)',
                            prefixIcon: Icon(Icons.looks_one_rounded),
                          ),
                          onChanged: (_) => setState(() => _generatedBytes = null),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _toCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'To (Roll No)',
                            prefixIcon: Icon(Icons.last_page_rounded),
                          ),
                          onChanged: (_) => setState(() => _generatedBytes = null),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Paper size selector ───────────────────────────────────────
            _SectionTitle('Paper Size'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.description_rounded, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _pageSizeLabel,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'A4', child: Text('A4')),
                            DropdownMenuItem(
                                value: 'Legal', child: Text('Legal')),
                            DropdownMenuItem(value: 'A5', child: Text('A5')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _pageSizeLabel = v;
                              _pageFormat = v == 'A4'
                                  ? PdfPageFormat.a4
                                  : v == 'Legal'
                                      ? PdfPageFormat.legal
                                      : PdfPageFormat.a5;
                              _generatedBytes = null;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Student count summary ─────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.people_rounded,
                      color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${filtered.length} student${filtered.length == 1 ? '' : 's'} — ${filtered.length} pages ka PDF banega',
                    style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Progress ─────────────────────────────────────────────────
            if (_generating) ...[
              LinearProgressIndicator(
                value: _progressTotal > 0
                    ? _progress / _progressTotal
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                _progressTotal > 0
                    ? 'Generating $_progress / $_progressTotal...'
                    : 'Preparing...',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
            ],

            // ── Generate button ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: _generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf_rounded),
                label: Text(_generating ? 'Generating...' : 'PDF Generate Karo'),
                onPressed:
                    (_generating || filtered.isEmpty) ? null : _generate,
              ),
            ),
            if (_generatedBytes != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share / Download PDF'),
                  onPressed: _share,
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── PDF generation ────────────────────────────────────────────────────────

  Future<void> _generate() async {
    final students = _filteredResults;
    if (students.isEmpty) return;

    setState(() {
      _generating = true;
      _progress = 0;
      _progressTotal = students.length;
      _generatedBytes = null;
    });

    try {
      final templateAsync =
          await ref.read(defaultTemplateProvider(widget.args.academicYear).future);
      final bytes = await _buildBulkPdf(students, templateAsync);
      if (mounted) {
        setState(() {
          _generating = false;
          _generatedBytes = bytes;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF ready — ${students.length} report cards'),
            backgroundColor: const Color(0xFF10B981),
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: _share,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('PDF error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<Uint8List> _buildBulkPdf(
      List<StudentResult> students, ReportTemplate? template) async {
    final terms = _finalTerms;
    final schoolName = template?.schoolName ?? 'School';
    final schoolAddress = template?.schoolAddress ?? '';
    final principalName = template?.principalName ?? '';
    final showPct = template?.showPercentage ?? true;
    final showRank = template?.showRank ?? true;

    final pdf = pw.Document();

    for (int i = 0; i < students.length; i++) {
      final r = students[i];
      pdf.addPage(
        pw.Page(
          pageFormat: _pageFormat,
          margin: const pw.EdgeInsets.all(28),
          build: (ctx) => _buildStudentPage(
            r: r,
            terms: terms,
            schoolName: schoolName,
            schoolAddress: schoolAddress,
            principalName: principalName,
            showPct: showPct,
            showRank: showRank,
          ),
        ),
      );

      if (mounted) setState(() => _progress = i + 1);
    }

    return await pdf.save();
  }

  pw.Widget _buildStudentPage({
    required StudentResult r,
    required List<ExamTerm> terms,
    required String schoolName,
    required String schoolAddress,
    required String principalName,
    required bool showPct,
    required bool showRank,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // ── Header ────────────────────────────────────────────────────────
        pw.Center(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(schoolName,
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
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
        // ── Student info ──────────────────────────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Student: ${r.studentName}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Roll No: ${r.rollNo}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ],
        ),
        if (showRank && r.rank > 0)
          pw.Text('Class Rank: #${r.rank}',
              style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 8),
        // ── Subject table ─────────────────────────────────────────────────
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: _colWidths(terms.length),
          children: [
            // Header row
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.indigo100),
              children: [
                _cell('Subject', bold: true),
                for (final t in terms) _cell(t.termName, bold: true),
                _cell('Total', bold: true),
                _cell('Grade', bold: true),
                _cell('P/F', bold: true),
              ],
            ),
            // Data rows
            for (final sub in r.subjectResults)
              pw.TableRow(children: [
                _cell(sub.subjectName),
                for (final t in terms)
                  _cell(sub.isGradeSubject
                      ? (sub.grade.isNotEmpty ? sub.grade : '-')
                      : _marksLabel(sub.termMarks[t.id])),
                _cell(sub.isGradeSubject
                    ? '-'
                    : '${sub.total.toStringAsFixed(0)}/${sub.maximum.toStringAsFixed(0)}'),
                _cell(sub.grade),
                _cell(
                  sub.isGradeSubject ? '-' : (sub.isPassed ? 'P' : 'F'),
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
        // ── Grand total box ────────────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          ),
          child: pw.Wrap(
            spacing: 24,
            children: [
              if (r.totalMaximum > 0)
                pw.Text(
                  'Total: ${r.totalObtained.toStringAsFixed(0)} / ${r.totalMaximum.toStringAsFixed(0)}',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 10),
                ),
              if (showPct && r.totalMaximum > 0)
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
        // ── Signatures ────────────────────────────────────────────────────
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
  }

  // ── PDF helpers ─────────────────────────────────────────────────────────────

  Map<int, pw.TableColumnWidth> _colWidths(int termCount) {
    final m = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(2.5),
    };
    for (int i = 1; i <= termCount; i++) {
      m[i] = const pw.FlexColumnWidth(1);
    }
    m[termCount + 1] = const pw.FlexColumnWidth(1.4);
    m[termCount + 2] = const pw.FlexColumnWidth(0.9);
    m[termCount + 3] = const pw.FlexColumnWidth(1.0);
    return m;
  }

  pw.Widget _cell(String text,
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
    if (marks == null) return 'Ab';
    return marks.truncateToDouble() == marks
        ? marks.toInt().toString()
        : marks.toStringAsFixed(1);
  }

  // ── Share ────────────────────────────────────────────────────────────────────

  Future<void> _share() async {
    final bytes = _generatedBytes;
    if (bytes == null) return;
    final safeYear = widget.args.academicYear.replaceAll('/', '-');
    await Share.shareXFiles(
      [XFile.fromData(bytes,
          mimeType: 'application/pdf',
          name: 'bulk_report_${widget.classId}_$safeYear.pdf')],
      subject:
          'Report Cards — ${widget.args.academicYear} (${_filteredResults.length} students)',
    );
  }
}

// ── Student checklist widget ──────────────────────────────────────────────────

class _StudentChecklist extends StatelessWidget {
  const _StudentChecklist({
    required this.allResults,
    required this.selectedIds,
    required this.onToggle,
    required this.onSelectAll,
    required this.onClearAll,
  });

  final List<StudentResult> allResults;
  final Set<String> selectedIds;
  final void Function(String id, bool selected) onToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          // Header row
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${selectedIds.length} / ${allResults.length} selected',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    TextButton(
                        onPressed: onSelectAll,
                        child: const Text('All')),
                    TextButton(
                        onPressed: onClearAll,
                        child: const Text('None')),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...allResults.map((r) => CheckboxListTile(
                dense: true,
                value: selectedIds.contains(r.studentId),
                title: Text(r.studentName,
                    style:
                        const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text('Roll: ${r.rollNo}  •  ${r.grade}  '
                    '${r.isPassed ? "✓ Pass" : "✗ Fail"}'),
                onChanged: (v) => onToggle(r.studentId, v ?? false),
              )),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold));
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onChanged,
  });

  final _PrintMode value;
  final _PrintMode groupValue;
  final String title;
  final String subtitle;
  final IconData icon;
  final ValueChanged<_PrintMode?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return RadioListTile<_PrintMode>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      title: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: color)),
        ],
      ),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12)),
    );
  }
}
