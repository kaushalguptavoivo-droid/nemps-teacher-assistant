// Phase 7 — Promotion Engine Screen
// Admin-only screen for reviewing and managing student promotions.
//
// Flow:
//   Admin Exam Tab → "Promotion" → PromotionScreen
//   Admin picks a class → results load → promotion table shown
//   "Generate" button → auto-populates promotion_records from result engine
//   Per-student override → PROMOTED / NOT_PROMOTED + optional reason
//
// Design rules:
//   • Never re-stores totals/percentage — only result_status (pass/fail)
//     and promotion_status (promoted/not_promoted/pending).
//   • Previous years' data never deleted; academic_year scopes every record.
//   • Admin can override any system-generated promotion decision.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/exam_providers.dart';
import '../models/exam_models.dart';
import '../../core/models/models.dart';    // ClassRoom
import '../../data/providers.dart';        // allClassesProvider, studentsProvider

// ── Screen ────────────────────────────────────────────────────────────────────

class PromotionScreen extends ConsumerStatefulWidget {
  const PromotionScreen({super.key});

  @override
  ConsumerState<PromotionScreen> createState() => _PromotionScreenState();
}

class _PromotionScreenState extends ConsumerState<PromotionScreen> {
  String? _selectedClassId;
  String? _selectedClassName;

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(allClassesProvider);
    final activeSession = ref.watch(activeSessionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Promotion Engine')),
      body: activeSession.when(
        data: (session) {
          if (session == null) {
            return const Center(
              child: Text(
                'Koi active session nahi.\nAdmin → Exam Mgmt → Academic Session mein activate karein.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return _PromotionBody(
            academicYear: session.label,
            selectedClassId: _selectedClassId,
            selectedClassName: _selectedClassName,
            classesAsync: classesAsync,
            onClassSelected: (id, name) =>
                setState(() {
                  _selectedClassId = id;
                  _selectedClassName = name;
                }),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Session error: $e')),
      ),
    );
  }
}

// ── Body: class picker + promotion table ──────────────────────────────────────

class _PromotionBody extends ConsumerWidget {
  const _PromotionBody({
    required this.academicYear,
    required this.selectedClassId,
    required this.selectedClassName,
    required this.classesAsync,
    required this.onClassSelected,
  });

  final String academicYear;
  final String? selectedClassId;
  final String? selectedClassName;
  final AsyncValue<List<ClassRoom>> classesAsync;
  final void Function(String id, String name) onClassSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Class picker ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: classesAsync.when(
                data: (classes) => DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('Class chunein...'),
                    value: selectedClassId,
                    items: classes.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.label),   // ClassRoom.label = '$name-$section'
                        )).toList(),
                    onChanged: (id) {
                      if (id == null) return;
                      final cls = classes.firstWhere((c) => c.id == id);
                      onClassSelected(cls.id, cls.label);
                    },
                  ),
                ),
                loading: () => const ListTile(
                  title: Text('Classes load ho rahi hain...'),
                  trailing: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (e, _) => Text('Error: $e'),
              ),
            ),
          ),
        ),

        // ── Promotion table or placeholder ────────────────────────────────
        if (selectedClassId == null)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'Upar se ek class chunein\nfir promotions generate karein.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: _PromotionLoader(
              classId: selectedClassId!,
              className: selectedClassName ?? selectedClassId!,
              academicYear: academicYear,
            ),
          ),
      ],
    );
  }
}

// ── Loader: fetches config → results → promotion records ──────────────────────

class _PromotionLoader extends ConsumerWidget {
  const _PromotionLoader({
    required this.classId,
    required this.className,
    required this.academicYear,
  });

  final String classId;
  final String className;
  final String academicYear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync =
        ref.watch(examConfigProvider((classId: classId, year: academicYear)));

    return configAsync.when(
      data: (config) {
        if (config == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '$className ke liye exam configuration nahi.\n'
                'Admin → Exam Mgmt → Exam Config mein configure karein.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return _PromotionDataLoader(
          classId: classId,
          className: className,
          academicYear: academicYear,
          config: config,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Config error: $e')),
    );
  }
}

class _PromotionDataLoader extends ConsumerWidget {
  const _PromotionDataLoader({
    required this.classId,
    required this.className,
    required this.academicYear,
    required this.config,
  });

  final String classId;
  final String className;
  final String academicYear;
  final ExamConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termsAsync = ref.watch(examTermsProvider(config.id));
    final subjectsAsync = ref.watch(
        classSubjectsProvider((classId: classId, year: academicYear)));
    final gradeAsync = ref.watch(gradeConfigsProvider(academicYear));
    final studentsAsync = ref.watch(studentsProvider(classId));
    final promotionAsync =
        ref.watch(promotionRecordsProvider((classId: classId, year: academicYear)));

    if (termsAsync.isLoading ||
        subjectsAsync.isLoading ||
        gradeAsync.isLoading ||
        studentsAsync.isLoading ||
        promotionAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final terms = termsAsync.value ?? [];
    final subjects = subjectsAsync.value ?? [];
    final gradeConfigs = gradeAsync.value ?? [];
    final rawStudents = studentsAsync.value ?? [];
    final existingRecords = promotionAsync.value ?? [];

    final students = rawStudents
        .map((s) => {'id': s.id, 'full_name': s.fullName, 'roll_no': s.rollNo})
        .toList();

    return _PromotionView(
      classId: classId,
      className: className,
      academicYear: academicYear,
      config: config,
      terms: terms,
      subjects: subjects,
      gradeConfigs: gradeConfigs,
      students: students,
      existingRecords: existingRecords,
    );
  }
}

// ── Promotion View: loads results then shows table ────────────────────────────

class _PromotionView extends ConsumerStatefulWidget {
  const _PromotionView({
    required this.classId,
    required this.className,
    required this.academicYear,
    required this.config,
    required this.terms,
    required this.subjects,
    required this.gradeConfigs,
    required this.students,
    required this.existingRecords,
  });

  final String classId;
  final String className;
  final String academicYear;
  final ExamConfig config;
  final List<ExamTerm> terms;
  final List<ClassSubject> subjects;
  final List<GradeConfig> gradeConfigs;
  final List<Map<String, dynamic>> students;
  final List<PromotionRecord> existingRecords;

  @override
  ConsumerState<_PromotionView> createState() => _PromotionViewState();
}

class _PromotionViewState extends ConsumerState<_PromotionView> {
  bool _generating = false;

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(classResultsProvider((
      classId: widget.classId,
      academicYear: widget.academicYear,
      config: widget.config,
      terms: widget.terms,
      subjects: widget.subjects,
      gradeConfigs: widget.gradeConfigs,
      students: widget.students,
    )));

    return resultsAsync.when(
      data: (results) {
        // Sort by roll number
        final sorted = [...results]..sort((a, b) {
            final na = int.tryParse(a.rollNo.trim());
            final nb = int.tryParse(b.rollNo.trim());
            if (na != null && nb != null) return na.compareTo(nb);
            return a.rollNo.compareTo(b.rollNo);
          });

        // Build record map for quick lookup
        final recordMap = {
          for (final r in widget.existingRecords) r.studentId: r,
        };

        final pendingCount =
            widget.existingRecords.where((r) => r.promotionStatus == 'pending').length;
        final promotedCount =
            widget.existingRecords.where((r) => r.promotionStatus == 'promoted').length;
        final notPromotedCount =
            widget.existingRecords.where((r) => r.promotionStatus == 'not_promoted').length;

        return Column(
          children: [
            // ── Stats banner ────────────────────────────────────────────
            _PromotionBanner(
              total: results.length,
              promoted: promotedCount,
              notPromoted: notPromotedCount,
              pending: pendingCount,
              passCount: results.where((r) => r.isPassed).length,
            ),

            // ── Generate button ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _generating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_fix_high_rounded),
                  label: Text(_generating
                      ? 'Generating...'
                      : widget.existingRecords.isEmpty
                          ? 'Auto-Generate Promotions'
                          : 'Re-Generate Promotions'),
                  onPressed: _generating
                      ? null
                      : () => _generate(results),
                ),
              ),
            ),
            if (widget.existingRecords.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Re-generate karoge toh sirf non-overridden records update honge.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),

            // ── Student promotion table ──────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                itemCount: sorted.length,
                itemBuilder: (context, i) {
                  final r = sorted[i];
                  final record = recordMap[r.studentId];
                  return _PromotionTile(
                    result: r,
                    record: record,
                    onOverride: () => _showOverrideDialog(r, record),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Result error: $e')),
    );
  }

  // ── Generate promotions ───────────────────────────────────────────────────

  Future<void> _generate(List<StudentResult> results) async {
    setState(() => _generating = true);
    try {
      await ref.read(examRepoProvider).generatePromotions(
            classId: widget.classId,
            academicYear: widget.academicYear,
            results: results,
          );
      ref.invalidate(
          promotionRecordsProvider((classId: widget.classId, year: widget.academicYear)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${results.length} promotions generate ho gayi ✓'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  // ── Override dialog ───────────────────────────────────────────────────────

  Future<void> _showOverrideDialog(
      StudentResult result, PromotionRecord? existing) async {
    String status =
        existing?.promotionStatus == 'promoted' ? 'promoted' : 'not_promoted';
    final reasonCtrl =
        TextEditingController(text: existing?.overrideReason ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Override: ${result.studentName}'),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Result: ${result.isPassed ? "PASS" : "FAIL"}  •  '
                  '${result.percentage.toStringAsFixed(1)}%  •  ${result.grade}',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              const Text('Promotion Status:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'promoted',
                      label: Text('Promoted'),
                      icon: Icon(Icons.arrow_upward_rounded)),
                  ButtonSegment(
                      value: 'not_promoted',
                      label: Text('Not Promoted'),
                      icon: Icon(Icons.block_rounded)),
                ],
                selected: {status},
                onSelectionChanged: (s) => setDlg(() => status = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'e.g. Medical reason, re-exam...',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save Override')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(examRepoProvider).overridePromotion(
            studentId: result.studentId,
            classId: widget.classId,
            academicYear: widget.academicYear,
            promotionStatus: status,
            overrideReason: reasonCtrl.text.trim().isEmpty
                ? null
                : reasonCtrl.text.trim(),
          );
      ref.invalidate(
          promotionRecordsProvider((classId: widget.classId, year: widget.academicYear)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Override save ho gaya ✓'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ── Promotion Banner ──────────────────────────────────────────────────────────

class _PromotionBanner extends StatelessWidget {
  const _PromotionBanner({
    required this.total,
    required this.promoted,
    required this.notPromoted,
    required this.pending,
    required this.passCount,
  });

  final int total;
  final int promoted;
  final int notPromoted;
  final int pending;
  final int passCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.primaryContainer.withOpacity(0.2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _Stat('Total', '$total', theme.colorScheme.primary),
          const SizedBox(width: 20),
          _Stat('Pass', '$passCount', const Color(0xFF10B981)),
          const SizedBox(width: 20),
          _Stat('Promoted', '$promoted', const Color(0xFF0EA5E9)),
          const SizedBox(width: 20),
          _Stat('Not', '$notPromoted', const Color(0xFFEF4444)),
          const SizedBox(width: 20),
          _Stat('Pending', '$pending', const Color(0xFFF59E0B)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

// ── Promotion Tile ────────────────────────────────────────────────────────────

class _PromotionTile extends StatelessWidget {
  const _PromotionTile({
    required this.result,
    required this.record,
    required this.onOverride,
  });

  final StudentResult result;
  final PromotionRecord? record;
  final VoidCallback onOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passColor =
        result.isPassed ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (record?.promotionStatus) {
      case 'promoted':
        statusColor = const Color(0xFF0EA5E9);
        statusLabel = 'Promoted';
        statusIcon = Icons.arrow_upward_rounded;
        break;
      case 'not_promoted':
        statusColor = const Color(0xFFEF4444);
        statusLabel = 'Not Promoted';
        statusIcon = Icons.block_rounded;
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'Pending';
        statusIcon = Icons.hourglass_empty_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Roll no badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                result.rollNo,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: theme.colorScheme.primary),
              ),
            ),
            const SizedBox(width: 10),

            // Name + grade
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.studentName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  Row(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: passColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          result.isPassed ? 'PASS' : 'FAIL',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: passColor),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${result.percentage.toStringAsFixed(1)}%  ${result.grade}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      if (record?.isManualOverride == true) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.edit_rounded,
                            size: 12, color: theme.colorScheme.tertiary),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Promotion status chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 12, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Override button
            IconButton(
              tooltip: 'Override',
              icon: Icon(Icons.tune_rounded,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
              onPressed: onOverride,
            ),
          ],
        ),
      ),
    );
  }
}
