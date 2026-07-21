// Subject Configuration Screen
// Admin manages subjects per class per active session.
// Add / Rename / Reorder / Toggle grade-subject / Disable (soft delete).
// Subjects with marks cannot be deleted — only disabled.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';
import '../data/exam_providers.dart';
import '../models/exam_models.dart';

class SubjectConfigScreen extends ConsumerStatefulWidget {
  const SubjectConfigScreen({super.key});

  @override
  ConsumerState<SubjectConfigScreen> createState() =>
      _SubjectConfigScreenState();
}

class _SubjectConfigScreenState
    extends ConsumerState<SubjectConfigScreen> {
  String? _selectedClassId;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(activeSessionProvider);
    final allClasses = ref.watch(allClassesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subject Configuration')),
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
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: allClasses.when(
                  data: (classes) =>
                      DropdownButtonFormField<String>(
                    value: _selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Class choose karein',
                      prefixIcon: Icon(Icons.class_rounded),
                    ),
                    items: classes
                        .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text('Class ${c.label}')))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedClassId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                ),
              ),
              const SizedBox(height: 8),
              if (_selectedClassId != null)
                Expanded(
                  child: _SubjectList(
                    classId: _selectedClassId!,
                    academicYear: session.label,
                    saving: _saving,
                    onSavingChanged: (v) =>
                        setState(() => _saving = v),
                  ),
                ),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ── Subject list ──────────────────────────────────────────────────────────────

class _SubjectList extends ConsumerStatefulWidget {
  const _SubjectList({
    required this.classId,
    required this.academicYear,
    required this.saving,
    required this.onSavingChanged,
  });
  final String classId;
  final String academicYear;
  final bool saving;
  final ValueChanged<bool> onSavingChanged;

  @override
  ConsumerState<_SubjectList> createState() => _SubjectListState();
}

class _SubjectListState extends ConsumerState<_SubjectList> {
  void _invalidate() {
    ref.invalidate(classSubjectsProvider((
      classId: widget.classId,
      year: widget.academicYear,
    )));
  }

  Future<void> _addSubject(List<ClassSubject> existing) async {
    final nameCtrl = TextEditingController();
    bool isGrade = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => AlertDialog(
          title: const Text('Subject Add Karein'),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subject Name',
                  hintText: 'Hindi, Maths, Drawing...',
                  prefixIcon: Icon(Icons.menu_book_rounded),
                ),
                autofocus: true,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: isGrade,
                title: const Text('Grade Subject (jaise Drawing)'),
                subtitle: const Text(
                    'Marks ki jagah A/B/C grade milti hai'),
                onChanged: (v) => setSt(() => isGrade = v ?? false),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    widget.onSavingChanged(true);
    try {
      await ref.read(examRepoProvider).addSubject(
            classId: widget.classId,
            academicYear: widget.academicYear,
            subjectName: nameCtrl.text.trim(),
            displayOrder: existing.length + 1,
            isGradeSubject: isGrade,
          );
      _invalidate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Subject add ho gaya! ✓'),
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
      widget.onSavingChanged(false);
    }
  }

  Future<void> _renameSubject(ClassSubject subject) async {
    final ctrl = TextEditingController(text: subject.subjectName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Subject Rename Karein'),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Naya Naam',
            prefixIcon: Icon(Icons.drive_file_rename_outline_rounded),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Rename')),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    widget.onSavingChanged(true);
    try {
      await ref
          .read(examRepoProvider)
          .renameSubject(subject.id, ctrl.text.trim());
      _invalidate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Naam badal gaya! ✓'),
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
      widget.onSavingChanged(false);
    }
  }

  Future<void> _toggleGrade(ClassSubject subject) async {
    widget.onSavingChanged(true);
    try {
      await ref.read(examRepoProvider).toggleGradeSubject(
            subject.id,
            isGrade: !subject.isGradeSubject,
          );
      _invalidate();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      widget.onSavingChanged(false);
    }
  }

  Future<void> _disableSubject(ClassSubject subject) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Subject Disable Karein?'),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(
            '"${subject.subjectName}" ko disable karein?\n\n'
            'Agar marks exist hain toh disable nahi hoga.\n'
            'Data safe rahega.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disable'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    widget.onSavingChanged(true);
    try {
      await ref.read(examRepoProvider).disableSubject(subject.id);
      _invalidate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Subject disable ho gaya.'),
              backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString().contains('marks')
                  ? 'Marks exist hain — disable nahi ho sakta.'
                  : 'Error: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      widget.onSavingChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(classSubjectsProvider((
      classId: widget.classId,
      year: widget.academicYear,
    )));

    return subjectsAsync.when(
      data: (subjects) => Scaffold(
        body: subjects.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book_outlined,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant),
                    const SizedBox(height: 12),
                    const Text(
                        'Koi subject nahi.\nNeeche + se add karein.',
                        textAlign: TextAlign.center),
                  ],
                ),
              )
            : ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: subjects.length,
                onReorder: (oldIndex, newIndex) async {
                  if (newIndex > oldIndex) newIndex--;
                  final s = subjects[oldIndex];
                  await ref
                      .read(examRepoProvider)
                      .reorderSubject(s.id, newIndex + 1);
                  _invalidate();
                },
                itemBuilder: (_, i) {
                  final s = subjects[i];
                  return Card(
                    key: ValueKey(s.id),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_handle_rounded,
                            color: Colors.grey),
                      ),
                      title: Text(s.subjectName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(s.isGradeSubject
                          ? 'Grade Subject'
                          : 'Marks Subject'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'rename') _renameSubject(s);
                          if (v == 'toggle_grade') _toggleGrade(s);
                          if (v == 'disable') _disableSubject(s);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: ListTile(
                              leading: Icon(Icons.drive_file_rename_outline_rounded,
                                  color: Colors.blue),
                              title: Text('Rename'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'toggle_grade',
                            child: ListTile(
                              leading: Icon(
                                s.isGradeSubject
                                    ? Icons.format_list_numbered_rounded
                                    : Icons.grade_rounded,
                                color: Colors.purple,
                              ),
                              title: Text(s.isGradeSubject
                                  ? 'Marks Subject Banao'
                                  : 'Grade Subject Banao'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'disable',
                            child: ListTile(
                              leading: Icon(Icons.visibility_off_rounded,
                                  color: Colors.orange),
                              title: Text('Disable',
                                  style: TextStyle(
                                      color: Colors.orange)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed:
              widget.saving ? null : () => _addSubject(subjects),
          icon: const Icon(Icons.add),
          label: const Text('Subject Add'),
        ),
      ),
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
