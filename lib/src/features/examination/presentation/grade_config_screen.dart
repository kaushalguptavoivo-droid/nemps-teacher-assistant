// Grade Configuration Screen
// Admin defines grade ranges per academic year.
// Example: A1 (91–100 Outstanding), A2 (81–90 Excellent) … E (0–32 Fail)
// Nothing is hardcoded — all grades come from this screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/exam_providers.dart';
import '../models/exam_models.dart';

class GradeConfigScreen extends ConsumerStatefulWidget {
  const GradeConfigScreen({super.key});

  @override
  ConsumerState<GradeConfigScreen> createState() =>
      _GradeConfigScreenState();
}

class _GradeConfigScreenState extends ConsumerState<GradeConfigScreen> {
  bool _saving = false;

  void _invalidate(String year) {
    ref.invalidate(gradeConfigsProvider(year));
  }

  Future<void> _showGradeDialog({
    required String academicYear,
    GradeConfig? existing,
  }) async {
    final gradeCtrl =
        TextEditingController(text: existing?.grade ?? '');
    final minCtrl = TextEditingController(
        text: existing?.minimumPercentage.toStringAsFixed(0) ?? '');
    final maxCtrl = TextEditingController(
        text: existing?.maximumPercentage.toStringAsFixed(0) ?? '');
    final descCtrl =
        TextEditingController(text: existing?.description ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(existing == null ? 'Grade Add Karein' : 'Grade Edit Karein'),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: gradeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Grade (A1, A2, B1...)',
                  prefixIcon: Icon(Icons.grade_rounded),
                ),
                textCapitalization: TextCapitalization.characters,
                autofocus: existing == null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: const InputDecoration(
                          labelText: 'Min %',
                          prefixIcon: Icon(Icons.arrow_downward_rounded)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: maxCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: const InputDecoration(
                          labelText: 'Max %',
                          prefixIcon: Icon(Icons.arrow_upward_rounded)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (Outstanding, Excellent...)',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(existing == null ? 'Add' : 'Save')),
        ],
      ),
    );

    if (ok != true) return;
    if (gradeCtrl.text.trim().isEmpty ||
        minCtrl.text.isEmpty ||
        maxCtrl.text.isEmpty) return;

    final min = double.tryParse(minCtrl.text);
    final max = double.tryParse(maxCtrl.text);
    if (min == null || max == null || min > max) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Min % max % se zyada nahi ho sakta.'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final config = GradeConfig(
        id: existing?.id ?? '',
        academicYear: academicYear,
        grade: gradeCtrl.text.trim().toUpperCase(),
        minimumPercentage: min,
        maximumPercentage: max,
        description:
            descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        displayOrder: existing?.displayOrder ?? 99,
      );
      await ref.read(examRepoProvider).saveGradeConfig(config);
      _invalidate(academicYear);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Grade save ho gaya! ✓'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteGrade(String academicYear, GradeConfig g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Grade Delete Karein?'),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text('"${g.grade}" delete karein?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await ref.read(examRepoProvider).deleteGradeConfig(g.id);
      _invalidate(academicYear);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grade delete ho gaya!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(activeSessionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Grade Configuration')),
      body: activeSession.when(
        data: (session) {
          if (session == null) {
            return const Center(
              child: Text(
                'Pehle ek Academic Session active karein.',
                textAlign: TextAlign.center,
              ),
            );
          }

          final gradesAsync =
              ref.watch(gradeConfigsProvider(session.label));

          return Stack(
            children: [
              gradesAsync.when(
                data: (grades) => grades.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.grade_outlined,
                                size: 64,
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant),
                            const SizedBox(height: 12),
                            const Text(
                                'Koi grade nahi.\nNeeche + se add karein.',
                                textAlign: TextAlign.center),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: grades.length,
                        itemBuilder: (_, i) {
                          final g = grades[i];
                          return _GradeCard(
                            grade: g,
                            onEdit: _saving
                                ? null
                                : () => _showGradeDialog(
                                      academicYear: session.label,
                                      existing: g,
                                    ),
                            onDelete: _saving
                                ? null
                                : () =>
                                    _deleteGrade(session.label, g),
                          );
                        },
                      ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
              if (_saving)
                Container(
                  color: Colors.black12,
                  child:
                      const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: Builder(
        builder: (ctx) {
          final session = ref.watch(activeSessionProvider).valueOrNull;
          return FloatingActionButton.extended(
            onPressed: (_saving || session == null)
                ? null
                : () => _showGradeDialog(academicYear: session.label),
            icon: const Icon(Icons.add),
            label: const Text('Grade Add'),
          );
        },
      ),
    );
  }
}

// ── Grade card ────────────────────────────────────────────────────────────────

class _GradeCard extends StatelessWidget {
  const _GradeCard({
    required this.grade,
    required this.onEdit,
    required this.onDelete,
  });
  final GradeConfig grade;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  Color _gradeColor() {
    switch (grade.grade) {
      case 'A1':
        return const Color(0xFF059669);
      case 'A2':
        return const Color(0xFF10B981);
      case 'B1':
        return const Color(0xFF0891B2);
      case 'B2':
        return const Color(0xFF0EA5E9);
      case 'C1':
        return const Color(0xFFD97706);
      case 'C2':
        return const Color(0xFFF59E0B);
      case 'D':
        return const Color(0xFFEA580C);
      case 'E':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _gradeColor();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              grade.grade,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
        ),
        title: Text(
          grade.description ?? grade.grade,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${grade.minimumPercentage.toStringAsFixed(0)}% – ${grade.maximumPercentage.toStringAsFixed(0)}%',
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Colors.blue),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.red),
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}
