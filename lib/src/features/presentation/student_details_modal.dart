// Feature 2: Student Details Modal — full profile tile/popup.
// Feature 4: Date-wise History — attendance + work/remarks timeline inside modal.
// Completely new independent widget; does NOT modify any existing screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/models.dart';
import '../data/providers.dart';

// ── Data model for one date entry in the history ─────────────────────────────
class _HistoryEntry {
  const _HistoryEntry({
    required this.date,
    this.attendanceStatus,
    this.workDone,
    this.remarks,
    this.assignment,
  });
  final DateTime date;
  final String? attendanceStatus; // 'present'/'absent'/'holiday'/null
  final String? workDone, remarks, assignment;
}

// ── Public helper to open the modal ─────────────────────────────────────────
void showStudentDetailsModal(BuildContext context, Student student) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: _StudentDetailsSheet(student: student),
    ),
  );
}

// ── Bottom-sheet widget ───────────────────────────────────────────────────────
class _StudentDetailsSheet extends ConsumerStatefulWidget {
  const _StudentDetailsSheet({required this.student});
  final Student student;

  @override
  ConsumerState<_StudentDetailsSheet> createState() =>
      _StudentDetailsSheetState();
}

class _StudentDetailsSheetState
    extends ConsumerState<_StudentDetailsSheet> {
  bool _historyLoading = true;
  List<_HistoryEntry> _history = [];
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final client = Supabase.instance.client;
      final sid = widget.student.id;

      // Fetch last 60 days of attendance for this student
      final sixtyDaysAgo = DateTime.now().subtract(const Duration(days: 60));
      final attRaw = await client
          .from('attendance')
          .select('date, status')
          .eq('student_id', sid)
          .gte('date', sixtyDaysAgo.toIso8601String().substring(0, 10))
          .order('date', ascending: false);

      // Fetch daily work remarks for this student
      List<dynamic> remarksRaw = [];
      try {
        remarksRaw = await client
            .from('daily_work_remarks')
            .select('date, work_done, remarks, assignment')
            .eq('student_id', sid)
            .gte('date', sixtyDaysAgo.toIso8601String().substring(0, 10))
            .order('date', ascending: false);
      } catch (_) {
        // Table may not exist yet; ignore gracefully.
      }

      // Merge by date
      final attMap = <String, String>{};
      for (final r in attRaw) {
        attMap[r['date'] as String] = r['status'] as String;
      }

      final remMap = <String, Map<String, dynamic>>{};
      for (final r in remarksRaw) {
        remMap[r['date'] as String] = r as Map<String, dynamic>;
      }

      final allDates = <String>{...attMap.keys, ...remMap.keys};
      final entries = allDates.map((d) {
        final rem = remMap[d];
        return _HistoryEntry(
          date: DateTime.parse(d),
          attendanceStatus: attMap[d],
          workDone: rem?['work_done'] as String?,
          remarks: rem?['remarks'] as String?,
          assignment: rem?['assignment'] as String?,
        );
      }).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      if (!mounted) return;
      setState(() {
        _history = entries;
        _historyLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _historyLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final cs = Theme.of(context).colorScheme;
    final dob = s.dob;
    final dobStr = dob != null ? DateFormat('dd MMM yyyy').format(dob) : null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Profile header ───────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 36,
                backgroundColor: cs.primaryContainer,
                backgroundImage: s.photoUrl != null && s.photoUrl!.isNotEmpty
                    ? NetworkImage(s.photoUrl!)
                    : null,
                child: s.photoUrl == null || s.photoUrl!.isEmpty
                    ? Text(
                        s.fullName.isNotEmpty
                            ? s.fullName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimaryContainer),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.fullName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(children: [
                      _Chip(
                          icon: Icons.format_list_numbered,
                          label: 'Roll ${s.rollNo}'),
                      const SizedBox(width: 6),
                      _Chip(icon: Icons.class_, label: s.classLabel),
                    ]),
                    const SizedBox(height: 4),
                    _FeeChip(status: s.feeStatus),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(),

          // ── Details grid ─────────────────────────────────────────────────
          _DetailRow(
              icon: Icons.person_outline,
              label: 'Father',
              value: s.parentName.isEmpty ? '—' : s.parentName),
          if (s.motherName.isNotEmpty)
            _DetailRow(
                icon: Icons.woman_outlined,
                label: 'Mother',
                value: s.motherName),
          if (s.whatsapp.isNotEmpty)
            _DetailRow(
                icon: Icons.phone_outlined,
                label: 'WhatsApp',
                value: s.whatsapp),
          if (dobStr != null)
            _DetailRow(
                icon: Icons.cake_outlined,
                label: 'DOB',
                value: dobStr),
          if (s.address.isNotEmpty)
            _DetailRow(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: s.address),

          const SizedBox(height: 16),
          const Divider(),

          // ── Date-wise History toggle ──────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _showHistory = !_showHistory),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Icon(Icons.history_rounded, color: cs.primary),
                const SizedBox(width: 8),
                Text('Date-wise History (last 60 days)',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                        fontSize: 14)),
                const Spacer(),
                Icon(_showHistory
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                    color: cs.primary),
              ]),
            ),
          ),

          if (_showHistory) ...[
            if (_historyLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_history.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('No history found for last 60 days.',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              )
            else
              ..._history.map((e) => _HistoryTile(entry: e)),
          ],
        ],
      ),
    );
  }
}

// ── Reusable sub-widgets ─────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

class _FeeChip extends StatelessWidget {
  const _FeeChip({required this.status});
  final FeeStatus status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case FeeStatus.paid:
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
        label = '💚 Fee Paid';
        break;
      case FeeStatus.overdue:
        bg = Colors.red.shade100;
        fg = Colors.red.shade800;
        label = '🔴 Fee Overdue';
        break;
      default:
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade800;
        label = '🟡 Fee Due';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, color: fg)),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 10),
        SizedBox(
          width: 70,
          child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                  fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13)),
        ),
      ]),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});
  final _HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateStr = DateFormat('EEE, dd MMM yyyy').format(entry.date);

    Color attColor = cs.outlineVariant;
    String attLabel = '—';
    IconData attIcon = Icons.remove_circle_outline;
    if (entry.attendanceStatus == 'present') {
      attColor = Colors.green;
      attLabel = 'Present';
      attIcon = Icons.check_circle_rounded;
    } else if (entry.attendanceStatus == 'absent') {
      attColor = Colors.red;
      attLabel = 'Absent';
      attIcon = Icons.cancel_rounded;
    } else if (entry.attendanceStatus == 'holiday') {
      attColor = Colors.orange;
      attLabel = 'Holiday';
      attIcon = Icons.beach_access_rounded;
    }

    final hasWork = (entry.workDone ?? '').isNotEmpty ||
        (entry.remarks ?? '').isNotEmpty ||
        (entry.assignment ?? '').isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.event_rounded, size: 15,
                  color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(dateStr,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: cs.onSurface)),
              const Spacer(),
              Icon(attIcon, color: attColor, size: 18),
              const SizedBox(width: 4),
              Text(attLabel,
                  style: TextStyle(
                      color: attColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
            if (hasWork) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              if ((entry.workDone ?? '').isNotEmpty)
                _WorkLine(
                    icon: Icons.book_outlined,
                    label: 'Work',
                    value: entry.workDone!),
              if ((entry.remarks ?? '').isNotEmpty)
                _WorkLine(
                    icon: Icons.comment_outlined,
                    label: 'Remark',
                    value: entry.remarks!),
              if ((entry.assignment ?? '').isNotEmpty)
                _WorkLine(
                    icon: Icons.assignment_outlined,
                    label: 'HW',
                    value: entry.assignment!),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkLine extends StatelessWidget {
  const _WorkLine(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: cs.primary),
        const SizedBox(width: 6),
        Text('$label: ',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant)),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }
}
