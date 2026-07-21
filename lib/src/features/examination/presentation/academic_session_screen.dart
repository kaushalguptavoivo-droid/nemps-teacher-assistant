// Academic Session Screen
// Admin creates sessions (e.g. 2026-27) and marks one as ACTIVE.
// Changing active session never deletes old data.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/exam_providers.dart';
import '../models/exam_models.dart';

class AcademicSessionScreen extends ConsumerStatefulWidget {
  const AcademicSessionScreen({super.key});

  @override
  ConsumerState<AcademicSessionScreen> createState() =>
      _AcademicSessionScreenState();
}

class _AcademicSessionScreenState
    extends ConsumerState<AcademicSessionScreen> {
  bool _saving = false;

  // ── Create session ──────────────────────────────────────────────────────────

  Future<void> _showCreateDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Naya Session Banayein'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Session Label',
            hintText: '2026-27',
            prefixIcon: Icon(Icons.calendar_month_rounded),
          ),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Banayein')),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(examRepoProvider).createSession(ctrl.text.trim());
      ref.invalidate(academicSessionsProvider);
      ref.invalidate(activeSessionProvider);
      if (mounted) {
        _snack('Session "${ctrl.text.trim()}" ban gayi! ✓', Colors.green);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Activate session ────────────────────────────────────────────────────────

  Future<void> _activate(AcademicSession session) async {
    if (session.isActive) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Session Active Karein?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(
            '"${session.label}" ko active session banana chahte hain?\n\nPichhla data safe rahega.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Active Karein')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await ref.read(examRepoProvider).activateSession(session.id);
      ref.invalidate(academicSessionsProvider);
      ref.invalidate(activeSessionProvider);
      ref.invalidate(activeYearProvider);
      if (mounted) {
        _snack('"${session.label}" ab active hai ✓', Colors.green);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(academicSessionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Academic Sessions')),
      body: Stack(
        children: [
          sessions.when(
            data: (list) => list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_month_outlined,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant),
                        const SizedBox(height: 12),
                        const Text(
                            'Koi session nahi.\nNeeche + se add karein.',
                            textAlign: TextAlign.center),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final s = list[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: s.isActive
                                  ? const Color(0xFF4F46E5).withOpacity(0.12)
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              s.isActive
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: s.isActive
                                  ? const Color(0xFF4F46E5)
                                  : Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          title: Text(
                            s.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: s.isActive
                                  ? const Color(0xFF4F46E5)
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            s.isActive ? 'ACTIVE' : 'Inactive',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: s.isActive
                                  ? const Color(0xFF4F46E5)
                                  : Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          trailing: s.isActive
                              ? const Chip(
                                  label: Text('Active',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                  backgroundColor: Color(0xFF4F46E5),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 4),
                                )
                              : FilledButton.tonal(
                                  onPressed:
                                      _saving ? null : () => _activate(s),
                                  child: const Text('Activate'),
                                ),
                        ),
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
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Session'),
      ),
    );
  }
}
