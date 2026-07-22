// Phase 8 — Analytics Screen
// Admin-only dashboard showing cross-class examination analytics for the
// active academic session.
//
// Sections:
//   1. Overall summary banner  — total classes, students, pass%, average%
//   2. Class-wise breakdown    — horizontal progress bars, topper, pass%
//   3. Subject weakness table  — ranked by lowest average pass% across classes
//   4. Top performers list     — class toppers side-by-side
//
// All values are computed dynamically from the Result Engine (Phase 2).
// No chart library needed — uses LinearProgressIndicator + Material cards.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/exam_providers.dart';
import '../models/exam_models.dart';
// providers.dart import removed — studentsProvider no longer used here
// (classAnalyticsSummaryProvider loads students internally)

// ── Screen ────────────────────────────────────────────────────────────────────

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(activeSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Result Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              // Re-fetch session, configs, and all per-class summaries
              ref.invalidate(activeSessionProvider);
              ref.invalidate(examConfigsWithClassProvider);
              // classAnalyticsSummaryProvider is autoDispose — it will
              // rebuild automatically when the loaders above rebuild.
            },
          ),
        ],
      ),
      body: activeSession.when(
        data: (session) {
          if (session == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Koi active session nahi.\n'
                  'Admin → Exam Mgmt → Academic Session mein activate karein.\n\n'
                  'Session activate karne ke baad ↻ Refresh karein.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _AnalyticsLoader(academicYear: session.label);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Session error: $e')),
      ),
    );
  }
}

// ── Loader: configs list → per-class result loading ───────────────────────────

class _AnalyticsLoader extends ConsumerWidget {
  const _AnalyticsLoader({required this.academicYear});
  final String academicYear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configsAsync =
        ref.watch(examConfigsWithClassProvider(academicYear));

    return configsAsync.when(
      data: (configs) {
        if (configs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bar_chart_rounded,
                    size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  '$academicYear ke liye koi exam configuration nahi.\n'
                  'Pehle Admin → Exam Mgmt → Exam Config mein configure karein.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return _AnalyticsBody(
          academicYear: academicYear,
          configs: configs,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Config error: $e')),
    );
  }
}

// ── Body: fires one classAnalyticsSummaryProvider per class ──────────────────
// Uses stable string-only keys so the provider is never accidentally recreated
// mid-build (old approach passed full model objects as keys — they lack ==
// so every rebuild was treated as a brand-new key → infinite loading loop).

class _AnalyticsBody extends ConsumerWidget {
  const _AnalyticsBody({
    required this.academicYear,
    required this.configs,
  });

  final String academicYear;
  final List<ExamConfigWithClass> configs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = <ClassAnalyticsSummary>[];
    bool anyLoading = false;

    for (final cc in configs) {
      final summaryAsync = ref.watch(classAnalyticsSummaryProvider((
        classId: cc.config.classId,
        className: cc.className,
        academicYear: academicYear,
      )));

      if (summaryAsync.isLoading) {
        anyLoading = true;
        continue;
      }
      if (summaryAsync.hasError) continue;

      final summary = summaryAsync.value;
      if (summary != null) summaries.add(summary);
    }

    if (anyLoading && summaries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (summaries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bar_chart_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                anyLoading
                    ? 'Data load ho raha hai...'
                    : 'Abhi kisi class mein marks nahi daale gaye.\nPehle marks entry karein fir yahan dekhein.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return _AnalyticsDashboard(
      summaries: summaries,
      academicYear: academicYear,
    );
  }
}

// ── Analytics Dashboard ───────────────────────────────────────────────────────

class _AnalyticsDashboard extends StatelessWidget {
  const _AnalyticsDashboard({
    required this.summaries,
    required this.academicYear,
  });

  final List<ClassAnalyticsSummary> summaries;
  final String academicYear;

  @override
  Widget build(BuildContext context) {
    // Overall aggregates
    final totalClasses = summaries.length;
    final totalStudents = summaries.fold(0, (s, c) => s + c.totalStudents);
    final totalPass = summaries.fold(0, (s, c) => s + c.passCount);
    final overallPassPct =
        totalStudents > 0 ? totalPass / totalStudents * 100 : 0.0;
    final avgPct = summaries.fold(0.0, (s, c) => s + c.averagePercent) /
        summaries.length;

    // Subject weakness across all classes — merge by subject name
    final subjectAcc = <String, _SubjectAgg>{};
    for (final c in summaries) {
      for (final s in c.subjectStats) {
        subjectAcc.putIfAbsent(s.subjectName, () => _SubjectAgg());
        subjectAcc[s.subjectName]!.add(s);
      }
    }
    final weakSubjects = subjectAcc.entries
        .map((e) => (
              name: e.key,
              avgPct: e.value.avgPercent,
              passPct: e.value.avgPassPercent,
            ))
        .toList()
      ..sort((a, b) => a.avgPct.compareTo(b.avgPct));

    // Sort classes: by pass% descending for ranking
    final ranked = [...summaries]
      ..sort((a, b) => b.passPercent.compareTo(a.passPercent));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section 1: Overall Stats ─────────────────────────────────
          Text('Session: $academicYear',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.8,
            children: [
              _StatCard(
                label: 'Classes',
                value: '$totalClasses',
                icon: Icons.school_rounded,
                color: const Color(0xFF4F46E5),
              ),
              _StatCard(
                label: 'Students',
                value: '$totalStudents',
                icon: Icons.people_rounded,
                color: const Color(0xFF0891B2),
              ),
              _StatCard(
                label: 'Overall Pass %',
                value: '${overallPassPct.toStringAsFixed(1)}%',
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF10B981),
              ),
              _StatCard(
                label: 'Average %',
                value: '${avgPct.toStringAsFixed(1)}%',
                icon: Icons.trending_up_rounded,
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Section 2: Class-wise Breakdown ─────────────────────────
          _SectionHeader('Class-wise Performance', Icons.bar_chart_rounded),
          const SizedBox(height: 10),
          ...ranked.map((c) => _ClassBar(summary: c)),
          const SizedBox(height: 20),

          // ── Section 3: Subject Weakness Analysis ─────────────────────
          if (weakSubjects.isNotEmpty) ...[
            _SectionHeader(
                'Subject Analysis (Sabse Kamzor se Strongest)',
                Icons.analytics_rounded),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 3,
                          child: Text('Subject',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        const Expanded(
                          flex: 2,
                          child: Text('Avg %',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        const Expanded(
                          flex: 2,
                          child: Text('Pass %',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ...weakSubjects.asMap().entries.map((entry) {
                    final i = entry.key;
                    final s = entry.value;
                    final isWeak = s.avgPct < 50;
                    return Container(
                      color: i.isEven
                          ? null
                          : Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                if (isWeak)
                                  const Icon(Icons.warning_rounded,
                                      size: 14,
                                      color: Color(0xFFEF4444)),
                                if (isWeak) const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    s.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isWeak
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isWeak
                                          ? const Color(0xFFEF4444)
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${s.avgPct.toStringAsFixed(1)}%',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isWeak
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF10B981)),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${s.passPct.toStringAsFixed(1)}%',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Section 4: Top Performers ────────────────────────────────
          _SectionHeader('Class Toppers', Icons.emoji_events_rounded),
          const SizedBox(height: 10),
          ...ranked.map((c) => _TopperTile(summary: c)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Subject aggregation helper ────────────────────────────────────────────────

class _SubjectAgg {
  int count = 0;
  double totalAvgPct = 0;
  double totalPassPct = 0;

  void add(SubjectAnalyticsStat s) {
    count++;
    totalAvgPct += s.averagePercent;
    totalPassPct += s.passPercent;
  }

  double get avgPercent => count > 0 ? totalAvgPct / count : 0;
  double get avgPassPercent => count > 0 ? totalPassPct / count : 0;
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.icon);
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon,
            size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ClassBar extends StatelessWidget {
  const _ClassBar({required this.summary});
  final ClassAnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = summary.passPercent / 100;
    final color = summary.passPercent >= 75
        ? const Color(0xFF10B981)
        : summary.passPercent >= 50
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(summary.className,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(
                  '${summary.passCount}/${summary.totalStudents}  '
                  '${summary.passPercent.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 10,
                backgroundColor:
                    theme.colorScheme.surfaceVariant,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Avg: ${summary.averagePercent.toStringAsFixed(1)}%  '
              '•  Highest: ${summary.highestPercent.toStringAsFixed(1)}%  '
              '•  Lowest: ${summary.lowestPercent.toStringAsFixed(1)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopperTile extends StatelessWidget {
  const _TopperTile({required this.summary});
  final ClassAnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.emoji_events_rounded,
              color: Color(0xFFF59E0B), size: 22),
        ),
        title: Text(summary.topperName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            '${summary.className}  •  Roll: ${summary.topperRollNo}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${summary.highestPercent.toStringAsFixed(1)}%',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: theme.colorScheme.primary),
            ),
            Text('Highest',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
