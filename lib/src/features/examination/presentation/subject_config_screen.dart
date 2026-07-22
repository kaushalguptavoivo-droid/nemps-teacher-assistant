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

  /// Opens the per-term max-marks configuration dialog for [subject].
  Future<void> _configureTermMarks(ClassSubject subject) async {
    await showDialog(
      context: context,
      builder: (ctx) => _TermMarksConfigDialog(
        subject: subject,
        classId: widget.classId,
        academicYear: widget.academicYear,
      ),
    );
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
                          if (v == 'term_marks') _configureTermMarks(s);
                        },
                        itemBuilder: (_) => [
                          if (!s.isGradeSubject)
                            const PopupMenuItem(
                              value: 'term_marks',
                              child: ListTile(
                                leading: Icon(Icons.tune_rounded,
                                    color: Colors.teal),
                                title: Text('Term-wise Marks'),
                                subtitle: Text(
                                    'Har term ka max marks set karein',
                                    style: TextStyle(fontSize: 11)),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
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

// ── Term Marks Config Dialog ───────────────────────────────────────────────────
// Shows all terms for this class's exam config and lets admin set per-subject
// max marks + whether the term applies to this subject at all.

class _TermMarksConfigDialog extends ConsumerStatefulWidget {
  const _TermMarksConfigDialog({
    required this.subject,
    required this.classId,
    required this.academicYear,
  });
  final ClassSubject subject;
  final String classId;
  final String academicYear;

  @override
  ConsumerState<_TermMarksConfigDialog> createState() =>
      _TermMarksConfigDialogState();
}

class _TermMarksConfigDialogState
    extends ConsumerState<_TermMarksConfigDialog> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<ExamTerm> _terms = [];
  // termId → {isIncluded, maxMarks controller}
  final Map<String, bool> _included = {};
  final Map<String, TextEditingController> _maxCtrl = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _maxCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(examRepoProvider);

      // 1. Get exam config for this class
      final config =
          await repo.getExamConfig(widget.classId, widget.academicYear);
      if (config == null) {
        if (mounted) {
          setState(() {
            _error =
                'Is class ka exam configuration nahi bana.\nPehle Exam Config banayein.';
            _loading = false;
          });
        }
        return;
      }

      // 2. Get all terms for this config
      final terms = await repo.getTerms(config.id);

      // 3. Get existing SubjectTermConfigs for this subject
      final stcs = await repo.getSubjectTermConfigs(
          terms.map((t) => t.id).toList());
      final subjectStcs =
          stcs.where((c) => c.subjectId == widget.subject.id).toList();

      if (!mounted) return;
      setState(() {
        _terms = terms;
        for (final term in terms) {
          final existing = subjectStcs
              .where((c) => c.termId == term.id)
              .firstOrNull;
          _included[term.id] = existing?.isIncluded ?? true;
          _maxCtrl[term.id] = TextEditingController(
            text: (existing?.maxMarks ?? term.maximumMarks)
                .toStringAsFixed(0),
          );
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = 'Error: $e'; _loading = false; });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final configs = <SubjectTermConfig>[];
      for (final term in _terms) {
        final isIncluded = _included[term.id] ?? true;
        final raw = _maxCtrl[term.id]?.text.trim() ?? '';
        final maxMarks = double.tryParse(raw) ?? term.maximumMarks;
        configs.add(SubjectTermConfig(
          id: '',
          subjectId: widget.subject.id,
          termId: term.id,
          maxMarks: isIncluded ? maxMarks : 0,
          isIncluded: isIncluded,
        ));
      }
      await ref.read(examRepoProvider).saveSubjectTermConfigs(configs);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Term marks save ho gaye! ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Term-wise Marks Configuration'),
          Text(
            widget.subject.subjectName,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: _loading
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : _error != null
              ? Text(_error!, style: const TextStyle(color: Colors.red))
              : _terms.isEmpty
                  ? const Text(
                      'Koi term nahi mila.\nPehle Exam Configuration banayein.')
                  : SizedBox(
                      width: double.maxFinite,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Har term ke liye:\n'
                            '• "Lagta hai" — yeh term is subject pe apply hoti hai\n'
                            '• "Max Marks" — is term mein kitne marks ka paper hai',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          ..._terms.map((term) {
                            final isIncluded =
                                _included[term.id] ?? true;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            term.termName,
                                            style: const TextStyle(
                                                fontWeight:
                                                    FontWeight.bold),
                                          ),
                                        ),
                                        Switch(
                                          value: isIncluded,
                                          onChanged: (v) => setState(
                                              () => _included[term.id] =
                                                  v),
                                        ),
                                        Text(
                                          isIncluded
                                              ? 'Lagta hai'
                                              : 'Nahi lagta',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isIncluded
                                                ? Colors.green
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (isIncluded) ...[
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _maxCtrl[term.id],
                                        decoration: InputDecoration(
                                          labelText: 'Max Marks',
                                          hintText: term.maximumMarks
                                              .toStringAsFixed(0),
                                          prefixIcon: const Icon(
                                              Icons.numbers_rounded,
                                              size: 18),
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 10),
                                        ),
                                        keyboardType: const TextInputType
                                            .numberWithOptions(
                                                decimal: false),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (!_loading && _error == null)
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save'),
          ),
      ],
    );
  }
}
