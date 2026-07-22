// Exam Configuration Screen
// Admin selects: Active Session → Class → Pattern (Nursery | Prep to 8)
// System auto-creates exam terms. Admin can edit maximum_marks per term.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../data/providers.dart';
import '../data/exam_providers.dart';
import '../models/exam_models.dart';

class ExamConfigScreen extends ConsumerStatefulWidget {
  const ExamConfigScreen({super.key});

  @override
  ConsumerState<ExamConfigScreen> createState() => _ExamConfigScreenState();
}

class _ExamConfigScreenState extends ConsumerState<ExamConfigScreen> {
  String? _selectedClassId;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(activeSessionProvider);
    final allClasses = ref.watch(allClassesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exam Configuration')),
      body: activeSession.when(
        data: (session) {
          if (session == null) {
            return _noSessionWarning(context);
          }
          return Column(
            children: [
              _SessionBanner(session: session),
              // Class picker
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: allClasses.when(
                  data: (classes) => DropdownButtonFormField<String>(
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
                  error: (e, _) =>
                      Text('Classes load nahi hui: $e'),
                ),
              ),
              const SizedBox(height: 12),
              if (_selectedClassId != null)
                Expanded(
                  child: _ClassExamConfig(
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

  Widget _noSessionWarning(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            const Text(
              'Pehle ek Academic Session active karein.\n\n'
              'Admin Panel → Exam Management → Academic Session',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Class-level config ────────────────────────────────────────────────────────

class _ClassExamConfig extends ConsumerStatefulWidget {
  const _ClassExamConfig({
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
  ConsumerState<_ClassExamConfig> createState() =>
      _ClassExamConfigState();
}

class _ClassExamConfigState extends ConsumerState<_ClassExamConfig> {
  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(
      examConfigProvider((
        classId: widget.classId,
        year: widget.academicYear,
      )),
    );

    return configAsync.when(
      data: (config) {
        if (config == null) {
          return _NoConfigView(
            classId: widget.classId,
            academicYear: widget.academicYear,
            saving: widget.saving,
            onSavingChanged: widget.onSavingChanged,
          );
        }
        return _ExistingConfigView(
          config: config,
          saving: widget.saving,
          onSavingChanged: widget.onSavingChanged,
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ── No config yet → choose pattern ──────────────────────────────────────────

class _NoConfigView extends ConsumerStatefulWidget {
  const _NoConfigView({
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
  ConsumerState<_NoConfigView> createState() => _NoConfigViewState();
}

class _NoConfigViewState extends ConsumerState<_NoConfigView> {
  ExamPattern? _pattern;

  Future<void> _create() async {
    if (_pattern == null) return;
    widget.onSavingChanged(true);
    try {
      await ref.read(examRepoProvider).createExamConfig(
            classId: widget.classId,
            academicYear: widget.academicYear,
            pattern: _pattern!,
          );
      ref.invalidate(examConfigProvider((
        classId: widget.classId,
        year: widget.academicYear,
      )));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Exam configuration ban gayi! ✓'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      widget.onSavingChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Exam Pattern Choose Karein',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _PatternCard(
            selected: _pattern == ExamPattern.nursery,
            pattern: ExamPattern.nursery,
            title: 'Nursery Pattern',
            terms: const ['Oral (40)', 'Written (60)'],
            total: '100',
            onTap: () => setState(() => _pattern = ExamPattern.nursery),
          ),
          const SizedBox(height: 12),
          _PatternCard(
            selected: _pattern == ExamPattern.prepTo8,
            pattern: ExamPattern.prepTo8,
            title: 'Prep to Class 8 Pattern',
            terms: const [
              'UT1 (20)',
              'Half Yearly (80)',
              'UT2 (20)',
              'Annual (80)',
            ],
            total: '200',
            onTap: () => setState(() => _pattern = ExamPattern.prepTo8),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  (_pattern == null || widget.saving) ? null : _create,
              icon: const Icon(Icons.check_rounded),
              label: Text(widget.saving ? 'Saving...' : 'Configuration Banayein'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({
    required this.selected,
    required this.pattern,
    required this.title,
    required this.terms,
    required this.total,
    required this.onTap,
  });
  final bool selected;
  final ExamPattern pattern;
  final String title;
  final List<String> terms;
  final String total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.08)
              : Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: selected ? color : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Radio<ExamPattern>(
              value: pattern,
              groupValue: selected ? pattern : null,
              onChanged: (_) => onTap(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: terms
                        .map((t) => Chip(
                              label: Text(t,
                                  style: const TextStyle(fontSize: 11)),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 6),
                  Text('Total: $total marks',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Existing config → show terms, allow edit of max marks ───────────────────

class _ExistingConfigView extends ConsumerWidget {
  const _ExistingConfigView({
    required this.config,
    required this.saving,
    required this.onSavingChanged,
  });
  final ExamConfig config;
  final bool saving;
  final ValueChanged<bool> onSavingChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termsAsync = ref.watch(examTermsProvider(config.id));

    return termsAsync.when(
      data: (terms) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Config summary
          _InfoChipRow(config: config),
          const SizedBox(height: 16),
          Text('Exam Terms',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...terms.map((t) => _TermTile(
                term: t,
                isLocked: config.isLocked,
                onEditMarks: saving
                    ? null
                    : () => _editMaxMarks(context, ref, t),
              )),
          const SizedBox(height: 16),
          // Lock / unlock toggle (admin only)
          _LockToggleTile(
            config: config,
            saving: saving,
            onSavingChanged: onSavingChanged,
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Future<void> _editMaxMarks(
      BuildContext context, WidgetRef ref, ExamTerm term) async {
    final ctrl =
        TextEditingController(text: term.maximumMarks.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${term.termName} — Max Marks Edit'),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Maximum Marks',
            prefixIcon: Icon(Icons.edit_rounded),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || ctrl.text.isEmpty) return;
    final newMax = double.tryParse(ctrl.text);
    if (newMax == null || newMax <= 0) return;
    onSavingChanged(true);
    try {
      await ref
          .read(examRepoProvider)
          .updateTermMaxMarks(term.id, newMax);
      ref.invalidate(examTermsProvider(term.examConfigId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Max marks update ho gaye! ✓'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      onSavingChanged(false);
    }
  }
}

class _InfoChipRow extends StatelessWidget {
  const _InfoChipRow({required this.config});
  final ExamConfig config;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        Chip(
          label: Text(
              config.examPattern == ExamPattern.nursery
                  ? 'Nursery'
                  : 'Prep to 8',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          avatar: const Icon(Icons.schema_rounded, size: 16),
        ),
        Chip(
          label: Text('Pass: ${config.passingPercentage.toStringAsFixed(0)}%'),
          avatar: const Icon(Icons.percent_rounded, size: 16),
        ),
        if (config.isLocked)
          const Chip(
            label: Text('LOCKED',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            backgroundColor: Colors.red,
          ),
      ],
    );
  }
}

class _TermTile extends StatelessWidget {
  const _TermTile({
    required this.term,
    required this.isLocked,
    required this.onEditMarks,
  });
  final ExamTerm term;
  final bool isLocked;
  final VoidCallback? onEditMarks;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            term.displayOrder.toString(),
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(term.termName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${term.maximumMarks.toStringAsFixed(0)} marks max'
            '${term.includeInFinalResult ? '' : ' • Final mein nahi'}'),
        trailing: isLocked
            ? const Icon(Icons.lock_rounded, color: Colors.red)
            : IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                tooltip: 'Max marks edit',
                onPressed: onEditMarks,
              ),
      ),
    );
  }
}

class _LockToggleTile extends ConsumerWidget {
  const _LockToggleTile({
    required this.config,
    required this.saving,
    required this.onSavingChanged,
  });
  final ExamConfig config;
  final bool saving;
  final ValueChanged<bool> onSavingChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: config.isLocked
          ? Colors.red.withOpacity(0.06)
          : Colors.green.withOpacity(0.06),
      child: SwitchListTile(
        secondary: Icon(
            config.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
            color: config.isLocked ? Colors.red : Colors.green),
        title: Text(
          config.isLocked ? 'Result Locked' : 'Result Unlocked',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(config.isLocked
            ? 'Marks enter nahi ho sakti. Unlock karne ke liye toggle karein.'
            : 'Marks entry khuli hai. Lock karne ke liye toggle karein.'),
        value: config.isLocked,
        onChanged: saving
            ? null
            : (val) => _toggleLock(context, ref, val),
      ),
    );
  }

  Future<void> _toggleLock(
      BuildContext context, WidgetRef ref, bool lock) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lock ? 'Result Lock Karein?' : 'Result Unlock Karein?'),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(lock
            ? 'Lock karne ke baad koi marks enter nahi kar sakta.\nSirf Admin unlock kar sakta hai.'
            : 'Unlock karne ke baad teachers marks enter kar sakte hain.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: lock ? Colors.red : Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lock ? 'Lock' : 'Unlock'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    onSavingChanged(true);
    try {
      await ref.read(examRepoProvider).setLocked(config.id, locked: lock);
      ref.invalidate(examConfigProvider((
        classId: config.classId,
        year: config.academicYear,
      )));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(lock ? 'Result lock ho gaya! 🔒' : 'Result unlock ho gaya! 🔓'),
              backgroundColor: lock ? Colors.red : Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      onSavingChanged(false);
    }
  }
}

// ── Session banner ────────────────────────────────────────────────────────────

class _SessionBanner extends StatelessWidget {
  const _SessionBanner({required this.session});
  final AcademicSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF4F46E5).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded,
              color: Color(0xFF4F46E5), size: 18),
          const SizedBox(width: 8),
          Text(
            'Active Session: ${session.label}',
            style: const TextStyle(
                color: Color(0xFF4F46E5),
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
        ],
      ),
    );
  }
}
