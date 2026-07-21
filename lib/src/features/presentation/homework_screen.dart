import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../data/providers.dart';

// Subject colors for visual differentiation
const _subjectColors = {
  'Math': Color(0xFF4F46E5),
  'English': Color(0xFF059669),
  'Hindi': Color(0xFFDC2626),
  'Science': Color(0xFF2563EB),
  'Social Studies': Color(0xFFF59E0B),
  'Computer': Color(0xFF7C3AED),
  'Drawing': Color(0xFFEC4899),
  'EVS': Color(0xFF16A34A),
};

Color _colorForSubject(String s) =>
    _subjectColors[s] ?? const Color(0xFF6B7280);

const _subjects = [
  'Math', 'English', 'Hindi', 'Science', 'Social Studies',
  'Computer', 'Drawing', 'EVS',
];

class HomeworkScreen extends ConsumerStatefulWidget {
  const HomeworkScreen({super.key, required this.classId});
  final String classId;

  @override
  ConsumerState<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends ConsumerState<HomeworkScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Homework'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline), text: 'Assign'),
            Tab(icon: Icon(Icons.send_rounded), text: 'Send to Parents'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AssignTab(classId: widget.classId),
          _CombinedSendTab(classId: widget.classId),
        ],
      ),
    );
  }
}

// ── Tab 1: Assign Homework ───────────────────────────────────────────────────

class _AssignTab extends ConsumerStatefulWidget {
  const _AssignTab({required this.classId});
  final String classId;

  @override
  ConsumerState<_AssignTab> createState() => _AssignTabState();
}

class _AssignTabState extends ConsumerState<_AssignTab> {
  String? selectedSubject;
  final descController = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homework = ref.watch(homeworkProvider(widget.classId));

    return Column(
      children: [
        // Assign form
        Container(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Aaj ka Homework Assign Karein',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedSubject,
                decoration: const InputDecoration(
                    labelText: 'Subject choose karein',
                    prefixIcon: Icon(Icons.book_outlined)),
                items: _subjects
                    .map((s) => DropdownMenuItem(
                        value: s,
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                  color: _colorForSubject(s),
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(s),
                          ],
                        )))
                    .toList(),
                onChanged: (v) => setState(() => selectedSubject = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                    labelText: 'Homework description',
                    hintText: 'Kya karna hai likho...',
                    prefixIcon: Icon(Icons.edit_note)),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (selectedSubject == null || saving)
                      ? null
                      : () async {
                          setState(() => saving = true);
                          try {
                            await ref.read(repoProvider).saveHomework(
                                  classId: widget.classId,
                                  subject: selectedSubject!,
                                  description: descController.text,
                                );
                            if (mounted) {
                              descController.clear();
                              setState(() {
                                selectedSubject = null;
                                saving = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Homework assign ho gaya! ✓'),
                                    backgroundColor: AppTheme.homeworkColor),
                              );
                              ref.invalidate(homeworkProvider(widget.classId));
                              ref.invalidate(homeworkForDateProvider);
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() => saving = false);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red));
                            }
                          }
                        },
                  icon: saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_task),
                  label: Text(saving ? 'Saving...' : 'Assign Homework'),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Homework list
        Expanded(
          child: homework.when(
            data: (items) => items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.assignment_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.outlineVariant),
                        const SizedBox(height: 12),
                        const Text('Abhi koi homework assign nahi hua.'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      final hw = items[index];
                      return _HomeworkCard(hw: hw, classId: widget.classId);
                    },
                  ),
            error: (e, _) => Center(child: Text('Error: $e')),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }
}

class _HomeworkCard extends ConsumerWidget {
  const _HomeworkCard({required this.hw, required this.classId});
  final Homework hw;
  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _colorForSubject(hw.subject);
    final isAfter12PM = DateTime.now().hour >= 12;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(hw.subject,
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd MMM').format(hw.assignedDate),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12),
                ),
              ],
            ),
            if (hw.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(hw.description),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _markHomework(context, hw.id, classId),
                    icon: const Icon(Icons.edit_note, size: 16),
                    label: const Text('Mark Status'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.homeworkColor,
                        side: const BorderSide(color: AppTheme.homeworkColor)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: isAfter12PM
                        ? () => _sendPendingWhatsApp(context, ref, hw)
                        : null,
                    icon: Icon(
                      Icons.message,
                      size: 16,
                      color: isAfter12PM
                          ? AppTheme.whatsappColor
                          : null,
                    ),
                    label: Text(
                      isAfter12PM ? 'WA Pending' : 'WA (12 baje ke baad)',
                      style: TextStyle(
                          fontSize: 12,
                          color: isAfter12PM
                              ? AppTheme.whatsappColor
                              : Theme.of(context).disabledColor),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _markHomework(BuildContext context, String homeworkId, String classId) {
    // Fix: pass the already-loaded students list directly to the dialog.
    // Previously the dialog re-subscribed to studentsProvider from inside
    // showDialog(), causing a fresh Supabase round-trip that left names blank
    // until the new stream emitted (often several seconds).
    final students = ref.read(studentsProvider(classId)).valueOrNull ?? [];
    showDialog(
      context: context,
      builder: (_) => HomeworkMarkDialog(
        homeworkId: homeworkId,
        classId: classId,
        students: students,
      ),
    );
  }

  Future<void> _sendPendingWhatsApp(
      BuildContext context, WidgetRef ref, Homework hw) async {
    final pending =
        await ref.read(repoProvider).getPendingHomeworkStudents(classId, hw.id);
    if (!context.mounted) return;
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sabhi students ka homework complete hai! 🎉')));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => _PendingWhatsAppDialog(
        students: pending,
        subject: hw.subject,
        classId: classId,
        homeworkId: hw.id,
        date: hw.assignedDate,
      ),
    );
  }
}

// ── Tab 2: Combined Send ─────────────────────────────────────────────────────

class _CombinedSendTab extends ConsumerStatefulWidget {
  const _CombinedSendTab({required this.classId});
  final String classId;

  @override
  ConsumerState<_CombinedSendTab> createState() => _CombinedSendTabState();
}

class _CombinedSendTabState extends ConsumerState<_CombinedSendTab> {
  DateTime selectedDate = DateTime.now();
  final Set<String> selectedHomeworkIds = {};

  @override
  Widget build(BuildContext context) {
    final homeworkToday =
        ref.watch(homeworkForDateProvider((widget.classId, selectedDate)));
    final groupLink = ref.watch(whatsappGroupLinkProvider(widget.classId));
    final students = ref.watch(studentsProvider(widget.classId));
    final isAfter12PM = DateTime.now().hour >= 12;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.homeworkColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.homeworkColor.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.homeworkColor),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Yahan aap multiple subjects ka homework ek saath sab parents ko bhej sakte hain.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Date selector
        Row(
          children: [
            Text('Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    selectedDate = picked;
                    selectedHomeworkIds.clear();
                  });
                  ref.invalidate(homeworkForDateProvider);
                }
              },
              icon: const Icon(Icons.calendar_today, size: 16),
              label: const Text('Date Badlo'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Homework list for that date
        homeworkToday.when(
          data: (hwList) => hwList.isEmpty
              ? Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.assignment_outlined,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                            'Is date ko koi homework assign nahi hua.\n"Assign" tab mein pehle assign karein.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${hwList.length} subjects assigned',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        TextButton(
                          onPressed: () => setState(() {
                            if (selectedHomeworkIds.length == hwList.length) {
                              selectedHomeworkIds.clear();
                            } else {
                              selectedHomeworkIds.addAll(hwList.map((h) => h.id));
                            }
                          }),
                          child: Text(
                              selectedHomeworkIds.length == hwList.length
                                  ? 'Deselect All'
                                  : 'Select All'),
                        ),
                      ],
                    ),
                    ...hwList.map((hw) {
                      final color = _colorForSubject(hw.subject);
                      final selected = selectedHomeworkIds.contains(hw.id);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: selected ? color : Colors.transparent,
                              width: 2),
                        ),
                        child: CheckboxListTile(
                          value: selected,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              selectedHomeworkIds.add(hw.id);
                            } else {
                              selectedHomeworkIds.remove(hw.id);
                            }
                          }),
                          activeColor: color,
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                shape: BoxShape.circle),
                            child: Icon(Icons.book, color: color, size: 20),
                          ),
                          title: Text(hw.subject,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: hw.description.isNotEmpty
                              ? Text(hw.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)
                              : null,
                        ),
                      );
                    }),

                    if (selectedHomeworkIds.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      // Preview message
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Message Preview:',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 6),
                            Text(
                              _buildCombinedGroupMessage(
                                  hwList
                                      .where((h) =>
                                          selectedHomeworkIds.contains(h.id))
                                      .toList(),
                                  DateFormat('dd MMM yyyy')
                                      .format(selectedDate)),
                              style: const TextStyle(
                                  fontSize: 12, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Action buttons
                      if (!isAfter12PM)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: AppTheme.pendingColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Row(
                            children: [
                              Icon(Icons.access_time,
                                  color: AppTheme.pendingColor),
                              SizedBox(width: 8),
                              Text(
                                  'WhatsApp send karne ki facility\n12 baje ke baad available hogi.',
                                  style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),

                      if (isAfter12PM) ...[
                        // Send to group button
                        groupLink.when(
                          data: (link) => link != null && link.isNotEmpty
                              ? SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () => _sendToGroup(
                                        context,
                                        ref,
                                        link,
                                        hwList
                                            .where((h) =>
                                                selectedHomeworkIds.contains(h.id))
                                            .toList()),
                                    style: FilledButton.styleFrom(
                                        backgroundColor: AppTheme.whatsappColor),
                                    icon: const Icon(Icons.groups_rounded),
                                    label: const Text(
                                        'Group mein bhejo (Copy + Open)'),
                                  ),
                                )
                              : Card(
                                  child: ListTile(
                                    leading: const Icon(Icons.groups_outlined,
                                        color: Colors.grey),
                                    title: const Text('Group link nahi set hai'),
                                    subtitle: const Text(
                                        'Class Detail screen mein group link add karein'),
                                    trailing: const Icon(Icons.info_outline),
                                  ),
                                ),
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 8),
                        // Send individually
                        students.when(
                          data: (studentList) => SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _sendIndividually(
                                  context,
                                  ref,
                                  studentList,
                                  hwList
                                      .where((h) =>
                                          selectedHomeworkIds.contains(h.id))
                                      .toList()),
                              icon: const Icon(Icons.person_rounded),
                              label: Text(
                                  'Parents ko individually bhejo (${studentList.length})'),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.whatsappColor,
                                  side: const BorderSide(
                                      color: AppTheme.whatsappColor)),
                            ),
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ],
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  String _buildCombinedGroupMessage(List<Homework> selected, String dateStr) {
    final lines = selected.map((hw) {
      final emoji = _subjectEmoji(hw.subject);
      return '$emoji *${hw.subject}:* ${hw.description.isNotEmpty ? hw.description : "(Dekha jayega)"}';
    }).join('\n');
    return '📚 *Homework | गृहकार्य*\n'
        'Date: $dateStr\n\n'
        'Aaj ka homework:\n$lines\n\n'
        'Sab bacche aaj raat tak homework poora karein. 🙏\n'
        '— *New Era Modern Public School, Vrindavan*';
  }

  String _subjectEmoji(String subject) {
    switch (subject) {
      case 'Math':
        return '📐';
      case 'English':
        return '📖';
      case 'Hindi':
        return '🔤';
      case 'Science':
        return '🔬';
      case 'Social Studies':
        return '🌍';
      case 'Computer':
        return '💻';
      case 'Drawing':
        return '🎨';
      case 'EVS':
        return '🌱';
      default:
        return '📝';
    }
  }

  Future<void> _sendToGroup(BuildContext context, WidgetRef ref, String groupLink,
      List<Homework> selected) async {
    final dateStr = DateFormat('dd MMM yyyy').format(selectedDate);
    final message = _buildCombinedGroupMessage(selected, dateStr);
    // Copy to clipboard
    await Clipboard.setData(ClipboardData(text: message));
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.groups_rounded, color: AppTheme.whatsappColor),
            SizedBox(width: 8),
            Text('Group mein bhejo'),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10)),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 6),
                  Expanded(
                      child: Text('Message clipboard mein copy ho gaya!',
                          style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 13))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '1. "Open Group" tap karein\n'
              '2. Group mein message paste karein (long press → paste)\n'
              '3. Send karein',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(groupLink);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            style:
                FilledButton.styleFrom(backgroundColor: AppTheme.whatsappColor),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open Group'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendIndividually(BuildContext context, WidgetRef ref,
      List<Student> students, List<Homework> selected) async {
    if (students.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => _CombinedBulkDialog(
        students: students,
        selectedHomework: selected,
        classId: widget.classId,
        date: selectedDate,
      ),
    );
  }
}

// ── Combined Bulk Dialog ─────────────────────────────────────────────────────

class _CombinedBulkDialog extends ConsumerStatefulWidget {
  const _CombinedBulkDialog({
    required this.students,
    required this.selectedHomework,
    required this.classId,
    required this.date,
  });
  final List<Student> students;
  final List<Homework> selectedHomework;
  final String classId;
  final DateTime date;

  @override
  ConsumerState<_CombinedBulkDialog> createState() =>
      _CombinedBulkDialogState();
}

class _CombinedBulkDialogState extends ConsumerState<_CombinedBulkDialog> {
  int currentIndex = 0;

  Student get current => widget.students[currentIndex];
  bool get isLast => currentIndex == widget.students.length - 1;

  String _buildMessage() {
    final parentName =
        current.parentName.isNotEmpty ? current.parentName : 'Madam/Sir';
    final dateStr = DateFormat('dd MMM yyyy').format(widget.date);
    final lines = widget.selectedHomework.map((hw) {
      final emoji = _subjectEmoji(hw.subject);
      return '$emoji *${hw.subject}:* ${hw.description.isNotEmpty ? hw.description : "Dekha jayega"}';
    }).join('\n');
    return '📚 *Homework Reminder | गृहकार्य सूचना*\n\n'
        'Dear $parentName / नमस्ते $parentName जी,\n\n'
        'Date: $dateStr\n'
        '*${current.fullName}* ka aaj ka homework:\n\n'
        '$lines\n\n'
        'Kripaya aaj raat tak homework poora karwayein. 🙏\n'
        '— *New Era Modern Public School, Vrindavan*';
  }

  String _subjectEmoji(String subject) {
    const map = {
      'Math': '📐', 'English': '📖', 'Hindi': '🔤',
      'Science': '🔬', 'Social Studies': '🌍', 'Computer': '💻',
      'Drawing': '🎨', 'EVS': '🌱',
    };
    return map[subject] ?? '📝';
  }

  Future<void> _sendAndAdvance() async {
    if (current.whatsapp.isEmpty) {
      _advance();
      return;
    }
    final uri = Uri.parse(
        'https://wa.me/${current.whatsapp.replaceAll(RegExp(r"[^0-9]"), "")}?text=${Uri.encodeComponent(_buildMessage())}');
    await launchUrl(uri, mode: LaunchMode.platformDefault);
    // Track sent
    for (final hw in widget.selectedHomework) {
      await ref.read(repoProvider).markWhatsAppSent(
            classId: widget.classId,
            studentId: current.id,
            date: widget.date,
            type: 'homework',
            subject: hw.subject,
          );
    }
    _advance();
  }

  void _advance() {
    if (isLast) {
      Navigator.pop(context);
    } else {
      setState(() => currentIndex++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.message, color: AppTheme.whatsappColor),
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
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text('Parent: ${current.parentName.isNotEmpty ? current.parentName : "—"}'),
          Text('WhatsApp: ${current.whatsapp.isNotEmpty ? current.whatsapp : "—Not set—"}'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_buildMessage(),
                style: const TextStyle(fontSize: 12)),
          ),
          if (current.whatsapp.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No WhatsApp — skip ho jayega',
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
          onPressed:
              current.whatsapp.isNotEmpty ? _sendAndAdvance : _advance,
          style:
              FilledButton.styleFrom(backgroundColor: AppTheme.whatsappColor),
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

// ── Pending WhatsApp Dialog (single subject) ─────────────────────────────────

class _PendingWhatsAppDialog extends ConsumerStatefulWidget {
  const _PendingWhatsAppDialog({
    required this.students,
    required this.subject,
    required this.classId,
    required this.homeworkId,
    required this.date,
  });
  final List<Student> students;
  final String subject, classId, homeworkId;
  final DateTime date;

  @override
  ConsumerState<_PendingWhatsAppDialog> createState() =>
      _PendingWhatsAppDialogState();
}

class _PendingWhatsAppDialogState
    extends ConsumerState<_PendingWhatsAppDialog> {
  int currentIndex = 0;

  Student get current => widget.students[currentIndex];
  bool get isLast => currentIndex == widget.students.length - 1;

  Future<void> _sendAndAdvance() async {
    if (current.whatsapp.isEmpty) {
      _advance();
      return;
    }
    final parentName =
        current.parentName.isNotEmpty ? current.parentName : 'Madam/Sir';
    final dateStr = DateFormat('dd MMM yyyy').format(widget.date);
    final msg =
        '📚 *Homework Reminder | गृहकार्य सूचना*\n\n'
        'Dear $parentName / नमस्ते $parentName जी,\n\n'
        '*${current.fullName}* ka *${widget.subject}* homework ($dateStr) abhi poora nahi hua hai.\n\n'
        'Kripaya aaj raat tak karwa dein. 🙏\n'
        '— *New Era Modern Public School, Vrindavan*';
    final uri = Uri.parse(
        'https://wa.me/${current.whatsapp.replaceAll(RegExp(r"[^0-9]"), "")}?text=${Uri.encodeComponent(msg)}');
    await launchUrl(uri, mode: LaunchMode.platformDefault);
    await ref.read(repoProvider).markWhatsAppSent(
          classId: widget.classId,
          studentId: current.id,
          date: widget.date,
          type: 'homework',
          subject: widget.subject,
        );
    _advance();
  }

  void _advance() {
    if (isLast) {
      Navigator.pop(context);
    } else {
      setState(() => currentIndex++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Pending: ${currentIndex + 1} of ${widget.students.length}'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(current.fullName,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18)),
          Text('Parent: ${current.parentName}'),
          Text(
              'WhatsApp: ${current.whatsapp.isNotEmpty ? current.whatsapp : "—Not set—"}'),
          if (current.whatsapp.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No number — will skip',
                  style: TextStyle(color: Colors.orange)),
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
          onPressed:
              current.whatsapp.isNotEmpty ? _sendAndAdvance : null,
          style:
              FilledButton.styleFrom(backgroundColor: AppTheme.whatsappColor),
          icon: const Icon(Icons.message, size: 18),
          label: Text(isLast ? 'Send & Done' : 'Send & Next'),
        ),
      ],
    );
  }
}

// ── Homework Mark Dialog ──────────────────────────────────────────────────────

class HomeworkMarkDialog extends ConsumerStatefulWidget {
  const HomeworkMarkDialog({
    super.key,
    required this.homeworkId,
    required this.classId,
    required this.students,
  });
  final String homeworkId, classId;
  // Students passed in from the parent so the dialog shows names instantly
  // without opening a fresh Supabase subscription.
  final List<Student> students;

  @override
  ConsumerState<HomeworkMarkDialog> createState() =>
      _HomeworkMarkDialogState();
}

class _HomeworkMarkDialogState extends ConsumerState<HomeworkMarkDialog> {
  // Teacher's in-session changes; merged on top of the stream values on Save.
  final _localOverrides = <String, String>{};
  bool saving = false;

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.attendanceColor;
      case 'incomplete':
        return AppTheme.absentColor;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // homeworkStatusStreamProvider streams { studentId → status } in real time.
    final statusStream =
        ref.watch(homeworkStatusStreamProvider(widget.homeworkId));

    return AlertDialog(
      title: const Text('Homework Status Mark Karein'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: double.maxFinite,
        child: statusStream.when(
          // Show a spinner only on the very first emission (no cached data yet).
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
          data: (streamStatuses) {
            if (widget.students.isEmpty) {
              return const Center(child: Text('Koi student nahi mila.'));
            }
            return ListView.builder(
              shrinkWrap: true,
              itemCount: widget.students.length,
              itemBuilder: (_, index) {
                final student = widget.students[index];
                // Teacher's in-session override takes priority over the stream.
                final status = _localOverrides[student.id] ??
                    streamStatuses[student.id] ??
                    'not_checked';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _statusColor(status).withOpacity(0.2),
                    child: Icon(
                      status == 'completed'
                          ? Icons.check_circle
                          : status == 'incomplete'
                              ? Icons.cancel
                              : Icons.help_outline,
                      color: _statusColor(status),
                      size: 20,
                    ),
                  ),
                  title: Text(student.fullName),
                  trailing: DropdownButton<String>(
                    value: status,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(
                          value: 'completed',
                          child: Text('✓ Done',
                              style: TextStyle(
                                  color: AppTheme.attendanceColor))),
                      DropdownMenuItem(
                          value: 'incomplete',
                          child: Text('✗ Incomplete',
                              style:
                                  TextStyle(color: AppTheme.absentColor))),
                      DropdownMenuItem(
                          value: 'not_checked',
                          child: Text('? Not checked')),
                    ],
                    onChanged: (value) => setState(() =>
                        _localOverrides[student.id] =
                            value ?? 'not_checked'),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  setState(() => saving = true);
                  try {
                    // Only persist rows the teacher actually changed this
                    // session; untouched rows keep whatever is already in DB.
                    for (final entry in _localOverrides.entries) {
                      await ref.read(repoProvider).markHomeworkStatus(
                            homeworkId: widget.homeworkId,
                            studentId: entry.key,
                            status: entry.value,
                          );
                    }
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Homework status save ho gaya! ✓'),
                            backgroundColor: AppTheme.homeworkColor),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => saving = false);
                  }
                },
          child: Text(saving ? 'Saving...' : 'Save All'),
        ),
      ],
    );
  }
}
