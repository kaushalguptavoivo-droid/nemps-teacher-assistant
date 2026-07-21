import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../data/providers.dart';

class AbsentNotifyScreen extends ConsumerStatefulWidget {
  const AbsentNotifyScreen({super.key, required this.classId});
  final String classId;

  @override
  ConsumerState<AbsentNotifyScreen> createState() =>
      _AbsentNotifyScreenState();
}

enum _SortBy { rollNo, name }

int _compareRollNo(String a, String b) {
  final na = int.tryParse(a.trim());
  final nb = int.tryParse(b.trim());
  if (na != null && nb != null) return na.compareTo(nb);
  return a.compareTo(b);
}

class _AbsentNotifyScreenState extends ConsumerState<AbsentNotifyScreen>
    with SingleTickerProviderStateMixin {
  DateTime selectedDate = DateTime.now();
  late TabController _tabController;
  _SortBy _sortBy = _SortBy.rollNo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
      ref.invalidate(absentStudentsProvider);
      ref.invalidate(presentStudentsProvider);
      ref.invalidate(whatsappSentStudentsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final absent = ref.watch(
        absentStudentsProvider((widget.classId, selectedDate)));
    final present = ref.watch(
        presentStudentsProvider((widget.classId, selectedDate)));
    final dateStr = DateFormat('dd MMM yyyy').format(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp Notifications'),
        actions: [
          IconButton(
            tooltip: _sortBy == _SortBy.rollNo ? 'Roll No se sorted' : 'Naam se sorted',
            icon: Icon(_sortBy == _SortBy.rollNo ? Icons.format_list_numbered : Icons.sort_by_alpha),
            onPressed: () => setState(
              () => _sortBy = _sortBy == _SortBy.rollNo ? _SortBy.name : _SortBy.rollNo,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: absent.when(
            data: (a) => present.when(
              data: (p) => [
                Tab(
                    icon: const Icon(Icons.close_rounded),
                    text: 'Absent (${a.length})'),
                Tab(
                    icon: const Icon(Icons.check_rounded),
                    text: 'Present (${p.length})'),
              ],
              loading: () => const [Tab(text: 'Absent'), Tab(text: 'Present')],
              error: (_, __) => const [Tab(text: 'Absent'), Tab(text: 'Present')],
            ),
            loading: () => const [Tab(text: 'Absent'), Tab(text: 'Present')],
            error: (_, __) => const [Tab(text: 'Absent'), Tab(text: 'Present')],
          ),
        ),
      ),
      body: Column(
        children: [
          // Date picker row
          Container(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dateStr,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      absent.when(
                        data: (a) => present.when(
                          data: (p) => Row(
                            children: [
                              _MiniPill(
                                  label: '${a.length} Absent',
                                  color: AppTheme.absentColor),
                              const SizedBox(width: 6),
                              _MiniPill(
                                  label: '${p.length} Present',
                                  color: AppTheme.attendanceColor),
                            ],
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text('Date'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                absent.when(
                  data: (items) {
                    final sorted = [...items]..sort((a, b) => _sortBy == _SortBy.name
                        ? a.fullName.compareTo(b.fullName)
                        : _compareRollNo(a.rollNo, b.rollNo));
                    return _StudentNotifyList(
                      classId: widget.classId,
                      students: sorted,
                      isAbsent: true,
                      date: selectedDate,
                      dateStr: dateStr,
                    );
                  },
                  error: (e, _) => Center(child: Text('Error: $e')),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),
                present.when(
                  data: (items) {
                    final sorted = [...items]..sort((a, b) => _sortBy == _SortBy.name
                        ? a.fullName.compareTo(b.fullName)
                        : _compareRollNo(a.rollNo, b.rollNo));
                    return _StudentNotifyList(
                      classId: widget.classId,
                      students: sorted,
                      isAbsent: false,
                      date: selectedDate,
                      dateStr: dateStr,
                    );
                  },
                  error: (e, _) => Center(child: Text('Error: $e')),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentNotifyList extends ConsumerWidget {
  const _StudentNotifyList({
    required this.classId,
    required this.students,
    required this.isAbsent,
    required this.date,
    required this.dateStr,
  });
  final String classId, dateStr;
  final List<Student> students;
  final bool isAbsent;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = isAbsent ? 'absent' : 'present';
    final sentStudents =
        ref.watch(whatsappSentStudentsProvider((classId, date, type)));

    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAbsent ? Icons.check_circle_outline : Icons.person_off_outlined,
              size: 64,
              color: isAbsent ? AppTheme.attendanceColor : Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              isAbsent
                  ? 'Aaj koi absent nahi! 🎉'
                  : 'Is date present nahi hai koi',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Sent summary banner
        sentStudents.when(
          data: (sent) {
            final notSent = students.where((s) => !sent.contains(s.id)).length;
            return Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: notSent == 0
                    ? AppTheme.attendanceColor.withOpacity(0.1)
                    : AppTheme.pendingColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    notSent == 0 ? Icons.check_circle : Icons.pending_rounded,
                    color: notSent == 0
                        ? AppTheme.attendanceColor
                        : AppTheme.pendingColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    notSent == 0
                        ? 'Sabhi parents ko message bhej diya! ✓'
                        : '$notSent parents ko abhi message nahi gaya',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: notSent == 0
                          ? AppTheme.attendanceColor
                          : AppTheme.pendingColor,
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // Send all button
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _sendAllOneByOne(context, ref),
              style: FilledButton.styleFrom(
                  backgroundColor:
                      isAbsent ? AppTheme.absentColor : AppTheme.attendanceColor),
              icon: const Icon(Icons.send_rounded),
              label: Text(
                  'Sabko bhejo (${students.length}) — One by one'),
            ),
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: students.length,
            itemBuilder: (_, index) {
              final student = students[index];
              final wasSent = sentStudents.whenOrNull(
                    data: (sent) => sent.contains(student.id),
                  ) ??
                  false;
              return _StudentNotifyCard(
                student: student,
                isAbsent: isAbsent,
                dateStr: dateStr,
                date: date,
                classId: classId,
                wasSent: wasSent,
                onSent: () =>
                    ref.invalidate(whatsappSentStudentsProvider((classId, date, type))),
              );
            },
          ),
        ),
      ],
    );
  }

  void _sendAllOneByOne(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _BulkWhatsAppDialog(
        students: students,
        isAbsent: isAbsent,
        dateStr: dateStr,
        classId: classId,
        date: date,
      ),
    );
  }
}

class _StudentNotifyCard extends ConsumerStatefulWidget {
  const _StudentNotifyCard({
    required this.student,
    required this.isAbsent,
    required this.dateStr,
    required this.date,
    required this.classId,
    required this.wasSent,
    required this.onSent,
  });
  final Student student;
  final bool isAbsent, wasSent;
  final String dateStr, classId;
  final DateTime date;
  final VoidCallback onSent;

  @override
  ConsumerState<_StudentNotifyCard> createState() => _StudentNotifyCardState();
}

class _StudentNotifyCardState extends ConsumerState<_StudentNotifyCard> {
  bool sending = false;

  String _buildMessage() {
    final parentName = widget.student.parentName.isNotEmpty
        ? widget.student.parentName
        : 'Madam/Sir';
    if (widget.isAbsent) {
      return '🔔 *Attendance Alert | उपस्थिति सूचना*\n\n'
          'Dear $parentName / नमस्ते $parentName जी,\n\n'
          '*${widget.student.fullName}* aaj ${widget.dateStr} ko school mein *absent* rhe.\n'
          'आपके बच्चे *${widget.student.fullName}* आज ${widget.dateStr} को *अनुपस्थित* रहे।\n\n'
          'Koi karan ho to school ko suchit karein.\n\n'
          'Thank you 🙏\n'
          '— *New Era Modern Public School, Vrindavan*';
    } else {
      return '✅ *Attendance Confirmation | उपस्थिति पुष्टि*\n\n'
          'Dear $parentName / नमस्ते $parentName जी,\n\n'
          '*${widget.student.fullName}* aaj ${widget.dateStr} ko school mein *present* hain.\n'
          'आपके बच्चे *${widget.student.fullName}* आज ${widget.dateStr} को *उपस्थित* हैं।\n\n'
          'Thank you 🙏\n'
          '— *New Era Modern Public School, Vrindavan*';
    }
  }

  Future<void> _send() async {
    setState(() => sending = true);
    try {
      final uri = Uri.parse(
          'https://wa.me/${widget.student.whatsappE164}?text=${Uri.encodeComponent(_buildMessage())}');
      final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (opened) {
        await ref.read(repoProvider).markWhatsAppSent(
              classId: widget.classId,
              studentId: widget.student.id,
              date: widget.date,
              type: widget.isAbsent ? 'absent' : 'present',
            );
        widget.onSent();
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isAbsent ? AppTheme.absentColor : AppTheme.attendanceColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: widget.wasSent
            ? const BorderSide(color: AppTheme.whatsappColor, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(
                    widget.isAbsent ? Icons.close : Icons.check,
                    color: color,
                  ),
                ),
                if (widget.wasSent)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppTheme.whatsappColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.student.fullName,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(
                    '${widget.student.parentName.isNotEmpty ? widget.student.parentName : "Parent nahi"}'
                    '${widget.student.whatsapp.isNotEmpty ? " · ${widget.student.whatsapp}" : " · No number"}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (widget.wasSent)
                    const Text('Message bhej diya ✓',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.whatsappColor,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (widget.student.whatsapp.isNotEmpty)
              FilledButton.tonalIcon(
                onPressed: sending ? null : _send,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  backgroundColor: widget.wasSent
                      ? AppTheme.whatsappColor.withOpacity(0.1)
                      : null,
                ),
                icon: sending
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(
                        widget.wasSent ? Icons.refresh : Icons.message,
                        size: 16,
                        color: widget.wasSent ? AppTheme.whatsappColor : null,
                      ),
                label: Text(
                  widget.wasSent ? 'Resend' : 'Send',
                  style: TextStyle(
                      fontSize: 12,
                      color: widget.wasSent ? AppTheme.whatsappColor : null),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('No number',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Bulk WhatsApp Dialog ─────────────────────────────────────────────────────

class _BulkWhatsAppDialog extends ConsumerStatefulWidget {
  const _BulkWhatsAppDialog({
    required this.students,
    required this.isAbsent,
    required this.dateStr,
    required this.classId,
    required this.date,
  });
  final List<Student> students;
  final bool isAbsent;
  final String dateStr, classId;
  final DateTime date;

  @override
  ConsumerState<_BulkWhatsAppDialog> createState() =>
      _BulkWhatsAppDialogState();
}

class _BulkWhatsAppDialogState extends ConsumerState<_BulkWhatsAppDialog> {
  int currentIndex = 0;

  Student get current => widget.students[currentIndex];
  bool get isLast => currentIndex == widget.students.length - 1;

  String get message {
    final parentName =
        current.parentName.isNotEmpty ? current.parentName : 'Madam/Sir';
    if (widget.isAbsent) {
      return '🔔 *Attendance Alert | उपस्थिति सूचना*\n\n'
          'Dear $parentName / नमस्ते $parentName जी,\n\n'
          '*${current.fullName}* aaj ${widget.dateStr} ko school mein *absent* rhe.\n\n'
          'Thank you 🙏\n'
          '— *New Era Modern Public School, Vrindavan*';
    } else {
      return '✅ *Attendance Confirmation | उपस्थिति पुष्टि*\n\n'
          'Dear $parentName / नमस्ते $parentName जी,\n\n'
          '*${current.fullName}* aaj ${widget.dateStr} ko school mein *present* hain.\n\n'
          'Thank you 🙏\n'
          '— *New Era Modern Public School, Vrindavan*';
    }
  }

  Future<void> _sendAndAdvance() async {
    if (current.whatsapp.isEmpty) {
      _advance();
      return;
    }
    final uri = Uri.parse(
        'https://wa.me/${current.whatsappE164}?text=${Uri.encodeComponent(message)}');
    await launchUrl(uri, mode: LaunchMode.platformDefault);
    await ref.read(repoProvider).markWhatsAppSent(
          classId: widget.classId,
          studentId: current.id,
          date: widget.date,
          type: widget.isAbsent ? 'absent' : 'present',
        );
    _advance();
  }

  void _advance() {
    if (isLast) {
      Navigator.pop(context);
      // Refresh providers
      ref.invalidate(whatsappSentStudentsProvider);
    } else {
      setState(() => currentIndex++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.isAbsent ? Icons.close_rounded : Icons.check_rounded,
            color: widget.isAbsent ? AppTheme.absentColor : AppTheme.attendanceColor,
          ),
          const SizedBox(width: 8),
          Text('${currentIndex + 1} / ${widget.students.length}'),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(current.fullName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text('Parent: ${current.parentName.isNotEmpty ? current.parentName : "—"}'),
          Text('WA: ${current.whatsapp.isNotEmpty ? current.whatsapp : "—No number—"}'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(message, style: const TextStyle(fontSize: 12)),
          ),
          if (current.whatsapp.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No number — skip hoga',
                  style: TextStyle(color: Colors.orange, fontSize: 12)),
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        TextButton(
            onPressed: _advance,
            child: Text(isLast ? 'Skip & Done' : 'Skip')),
        FilledButton.icon(
          onPressed: current.whatsapp.isNotEmpty ? _sendAndAdvance : _advance,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.whatsappColor),
          icon: const Icon(Icons.message, size: 18),
          label: Text(current.whatsapp.isEmpty
              ? 'Skip'
              : isLast
                  ? 'Send & Done'
                  : 'Send & Next'),
        ),
      ],
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
