// Phase 5 — Result Screen
// Class-level result overview: ranked list, summary stats, pass/fail filter.
// All totals/percentages/ranks computed dynamically by the Result Engine (Phase 2).
// Tap any student → navigates to ReportCardScreen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/exam_providers.dart';
import '../models/exam_models.dart';
import '../../data/providers.dart';

// ── Public args object (passed via GoRouter extra) ────────────────────────────

class ReportCardArgs {
  const ReportCardArgs({
    required this.config,
    required this.terms,
    required this.subjects,
    required this.gradeConfigs,
    required this.studentResult,
    required this.academicYear,
  });

  final ExamConfig config;
  final List<ExamTerm> terms;
  final List<ClassSubject> subjects;
  final List<GradeConfig> gradeConfigs;
  final StudentResult studentResult;
  final String academicYear;
}

// ── Filter enum ───────────────────────────────────────────────────────────────

enum _Filter { all, pass, fail }

// ── Screen ────────────────────────────────────────────────────────────────────

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key, required this.classId});
  final String classId;

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(activeSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Results'),
        actions: [
          PopupMenuButton<_Filter>(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Filter',
            onSelected: (f) => setState(() => _filter = f),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Filter.all, child: Text('All Students')),
              PopupMenuItem(value: _Filter.pass, child: Text('Pass Only')),
              PopupMenuItem(value: _Filter.fail, child: Text('Fail Only')),
            ],
          ),
        ],
      ),
      body: activeSession.when(
        data: (session) {
          if (session == null) {
            return const Center(
              child: Text(
                'Koi active session nahi.\nAdmin se session activate karwayein.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return _ResultLoader(
            classId: widget.classId,
            academicYear: session.label,
            filter: _filter,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Session error: $e')),
      ),
    );
  }
}

// ── Loader: fetches config → terms+subjects+grades+students → renders ─────────

class _ResultLoader extends ConsumerWidget {
  const _ResultLoader({
    required this.classId,
    required this.academicYear,
    required this.filter,
  });

  final String classId;
  final String academicYear;
  final _Filter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync =
        ref.watch(examConfigProvider((classId: classId, year: academicYear)));

    return configAsync.when(
      data: (config) {
        if (config == null) {
          return const Center(
            child: Text(
              'Is class ke liye exam configuration nahi.\nAdmin → Exam Mgmt → Exam Config mein configure karein.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return _DependencyLoader(
          classId: classId,
          academicYear: academicYear,
          config: config,
          filter: filter,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Config error: $e')),
    );
  }
}

class _DependencyLoader extends ConsumerWidget {
  const _DependencyLoader({
    required this.classId,
    required this.academicYear,
    required this.config,
    required this.filter,
  });

  final String classId;
  final String academicYear;
  final ExamConfig config;
  final _Filter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termsAsync = ref.watch(examTermsProvider(config.id));
    final subjectsAsync = ref.watch(
        classSubjectsProvider((classId: classId, year: academicYear)));
    final gradeAsync = ref.watch(gradeConfigsProvider(academicYear));
    final studentsAsync = ref.watch(studentsProvider(classId));

    if (termsAsync.isLoading ||
        subjectsAsync.isLoading ||
        gradeAsync.isLoading ||
        studentsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final termsErr = termsAsync.error;
    if (termsErr != null) {
      return Center(child: Text('Terms error: $termsErr'));
    }

    final terms = termsAsync.value ?? [];
    final subjects = subjectsAsync.value ?? [];
    final gradeConfigs = gradeAsync.value ?? [];
    final rawStudents = studentsAsync.value ?? [];
    final students = rawStudents
        .map((s) => {'id': s.id, 'full_name': s.fullName, 'roll_no': s.rollNo})
        .toList();

    return _ResultsView(
      classId: classId,
      academicYear: academicYear,
      config: config,
      terms: terms,
      subjects: subjects,
      gradeConfigs: gradeConfigs,
      students: students,
      filter: filter,
    );
  }
}

// ── Results View ──────────────────────────────────────────────────────────────

class _ResultsView extends ConsumerWidget {
  const _ResultsView({
    required this.classId,
    required this.academicYear,
    required this.config,
    required this.terms,
    required this.subjects,
    required this.gradeConfigs,
    required this.students,
    required this.filter,
  });

  final String classId;
  final String academicYear;
  final ExamConfig config;
  final List<ExamTerm> terms;
  final List<ClassSubject> subjects;
  final List<GradeConfig> gradeConfigs;
  final List<Map<String, dynamic>> students;
  final _Filter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(classResultsProvider((
      classId: classId,
      academicYear: academicYear,
      config: config,
      terms: terms,
      subjects: subjects,
      gradeConfigs: gradeConfigs,
      students: students,
    )));

    return resultsAsync.when(
      data: (results) {
        // Sort by rank; students with no marks (rank==0) go to bottom
        final sorted = [...results]..sort((a, b) {
            if (a.rank == 0 && b.rank == 0) return 0;
            if (a.rank == 0) return 1;
            if (b.rank == 0) return -1;
            return a.rank.compareTo(b.rank);
          });

        final filtered = sorted.where((r) {
          switch (filter) {
            case _Filter.pass:
              return r.isPassed;
            case _Filter.fail:
              return !r.isPassed;
            case _Filter.all:
              return true;
          }
        }).toList();

        final passCount = results.where((r) => r.isPassed).length;
        final totalCount = results.length;
        final passPct =
            totalCount > 0 ? passCount / totalCount * 100 : 0.0;

        final rankedStudents =
            sorted.where((r) => r.rank > 0).toList();
        final topper =
            rankedStudents.isNotEmpty ? rankedStudents.first : null;

        return Column(
          children: [
            _SummaryBanner(
              totalCount: totalCount,
              passCount: passCount,
              passPct: passPct,
              topper: topper,
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${filtered.length} student${filtered.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('Koi result nahi is filter mein.'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final r = filtered[i];
                        return _StudentResultTile(
                          result: r,
                          onTap: () => context.push(
                            '/report-card/$classId/${r.studentId}',
                            extra: ReportCardArgs(
                              config: config,
                              terms: terms,
                              subjects: subjects,
                              gradeConfigs: gradeConfigs,
                              studentResult: r,
                              academicYear: academicYear,
                            ),
                          ),
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
}

// ── Summary Banner ────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({
    required this.totalCount,
    required this.passCount,
    required this.passPct,
    required this.topper,
  });

  final int totalCount;
  final int passCount;
  final double passPct;
  final StudentResult? topper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.primaryContainer.withOpacity(0.25),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SumStat(
                  label: 'Total',
                  value: '$totalCount',
                  color: theme.colorScheme.primary),
              const SizedBox(width: 20),
              const _SumStat(
                  label: 'Pass',
                  value: '',
                  color: Color(0xFF10B981)),
              // rebuild below with passCount
              _SumStat(
                  label: 'Pass',
                  value: '$passCount',
                  color: const Color(0xFF10B981)),
              const SizedBox(width: 20),
              _SumStat(
                  label: 'Fail',
                  value: '${totalCount - passCount}',
                  color: const Color(0xFFEF4444)),
              const SizedBox(width: 20),
              _SumStat(
                  label: 'Pass %',
                  value: '${passPct.toStringAsFixed(1)}%',
                  color: const Color(0xFFF59E0B)),
            ],
          ),
          if (topper != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    color: Color(0xFFF59E0B), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Topper: ${topper!.studentName}  '
                    '${topper!.totalObtained.toStringAsFixed(0)}/${topper!.totalMaximum.toStringAsFixed(0)}  '
                    '(${topper!.percentage.toStringAsFixed(1)}%)  '
                    'Grade: ${topper!.grade}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SumStat extends StatelessWidget {
  const _SumStat(
      {required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                )),
      ],
    );
  }
}

// ── Student Result Tile ───────────────────────────────────────────────────────

class _StudentResultTile extends StatelessWidget {
  const _StudentResultTile(
      {required this.result, required this.onTap});
  final StudentResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rankText = result.rank > 0 ? '#${result.rank}' : '-';
    final passColor = result.isPassed
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    final passLabel = result.isPassed ? 'PASS' : 'FAIL';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Rank badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: result.rank == 1
                      ? const Color(0xFFF59E0B).withOpacity(0.15)
                      : theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  rankText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: result.rank == 1
                        ? const Color(0xFFF59E0B)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.studentName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Roll No: ${result.rollNo}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    result.totalMaximum > 0
                        ? '${result.totalObtained.toStringAsFixed(0)}/${result.totalMaximum.toStringAsFixed(0)}'
                        : '-',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    result.totalMaximum > 0
                        ? '${result.percentage.toStringAsFixed(1)}%'
                        : '',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              // Grade badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer
                      .withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result.grade,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: 8),
              // Pass/Fail chip
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: passColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  passLabel,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: passColor),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  color: theme.colorScheme.outlineVariant),
            ],
          ),
        ),
      ),
    );
  }
}
