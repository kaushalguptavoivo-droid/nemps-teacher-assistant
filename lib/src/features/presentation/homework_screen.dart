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
                    onPressed: () => _markHomework(context, ref, hw.id, classId),
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

  void _markHomework(BuildContext context, WidgetRef ref, String homeworkId, String classId) {
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
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        // ── Section heading ────────────────────────────────────────────
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.whatsappColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.send_rounded,
                  color: AppTheme.whatsappColor, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Homework Bhejein',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Subjects chunein, parents ko notify karein',
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Date selector card ─────────────────────────────────────────
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: theme.colorScheme.outlineVariant, width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.homeworkColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calendar_month_rounded,
                      color: AppTheme.homeworkColor, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Homework ki Date',
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEEE, dd MMMM yyyy').format(selectedDate),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(Icons.edit_calendar_rounded,
                    color: theme.colorScheme.onSurfaceVariant, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Homework list for chosen date ──────────────────────────────
        homeworkToday.when(
          loading: () => const Center(
              child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator())),
          error: (e, _) => Text('Error: $e'),
          data: (hwList) {
            if (hwList.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.assignment_outlined,
                        size: 52,
                        color: theme.colorScheme.onSurfaceVariant
                            .withOpacity(0.5)),
                    const SizedBox(height: 12),
                    const Text(
                      'Is date ka koi homework nahi mila',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '"Assign" tab mein pehle homework add karein',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              );
            }

            final selectedList = hwList
                .where((h) => selectedHomeworkIds.contains(h.id))
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subject list header
                Row(
                  children: [
                    Text(
                      '${hwList.length} subject${hwList.length > 1 ? 's' : ''} assigned',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13),
                    ),
                    const Spacer(),
                    if (selectedHomeworkIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              AppTheme.whatsappColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${selectedHomeworkIds.length} selected',
                          style: const TextStyle(
                              color: AppTheme.whatsappColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                        ),
                      ),
                    const SizedBox(width: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(60, 32)),
                      onPressed: () => setState(() {
                        if (selectedHomeworkIds.length == hwList.length) {
                          selectedHomeworkIds.clear();
                        } else {
                          selectedHomeworkIds
                              .addAll(hwList.map((h) => h.id));
                        }
                      }),
                      child: Text(
                          selectedHomeworkIds.length == hwList.length
                              ? 'Deselect All'
                              : 'Select All',
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Subject cards
                ...hwList.map((hw) {
                  final color = _colorForSubject(hw.subject);
                  final selected = selectedHomeworkIds.contains(hw.id);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        selectedHomeworkIds.remove(hw.id);
                      } else {
                        selectedHomeworkIds.add(hw.id);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withOpacity(0.07)
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: selected
                                ? color
                                : theme.colorScheme.outlineVariant,
                            width: selected ? 2 : 1),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                    color: color.withOpacity(0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3))
                              ]
                            : [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1))
                              ],
                      ),
                      child: Row(
                        children: [
                          // Colored left accent bar
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 5,
                            height: 68,
                            decoration: BoxDecoration(
                              color: selected ? color : Colors.transparent,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Subject icon
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                                color: color.withOpacity(0.13),
                                borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.menu_book_rounded,
                                color: color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          // Subject info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(hw.subject,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: selected
                                            ? color
                                            : theme.colorScheme.onSurface)),
                                if (hw.description.isNotEmpty)
                                  Text(hw.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme
                                              .onSurfaceVariant)),
                              ],
                            ),
                          ),
                          // Checkmark
                          Padding(
                            padding:
                                const EdgeInsets.only(right: 14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: selected ? color : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: selected
                                        ? color
                                        : theme.colorScheme.outlineVariant,
                                    width: 2),
                              ),
                              child: selected
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 14)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                // ── Selected: preview + send buttons ────────────────
                if (selectedList.isNotEmpty) ...[
                  const SizedBox(height: 8),

                  // WhatsApp message preview bubble
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF075E54), Color(0xFF128C7E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Preview header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                          child: Row(
                            children: [
                              const Icon(Icons.chat_bubble_rounded,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              const Text('Message Preview',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${selectedList.length} subject${selectedList.length > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Message bubble
                        Container(
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _buildCombinedGroupMessage(
                                selectedList,
                                DateFormat('dd MMM yyyy')
                                    .format(selectedDate)),
                            style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.6,
                                color: Color(0xFF1a1a1a)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Time restriction warning
                  if (!isAfter12PM)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.pendingColor.withOpacity(0.4))),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              color: AppTheme.pendingColor, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: const [
                                Text('Abhi send nahi kar sakte',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.pendingColor,
                                        fontSize: 13)),
                                SizedBox(height: 2),
                                Text(
                                  'WhatsApp send facility dopahar 12 baje ke baad milegi',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.brown),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Send buttons (only after 12 PM)
                  if (isAfter12PM) ...[
                    groupLink.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (link) {
                        final hasLink = link != null && link.isNotEmpty;
                        return Column(
                          children: [
                            // Group send button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: hasLink
                                  ? FilledButton.icon(
                                      onPressed: () => _sendToGroup(
                                          context,
                                          ref,
                                          link!,
                                          selectedList),
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            AppTheme.whatsappColor,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                      ),
                                      icon: const Icon(Icons.groups_rounded,
                                          size: 20),
                                      label: const Text(
                                        'WhatsApp Group mein Bhejo',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15),
                                      ),
                                    )
                                  : OutlinedButton.icon(
                                      onPressed: null,
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                        side: BorderSide(
                                            color: theme.colorScheme
                                                .outlineVariant),
                                      ),
                                      icon: Icon(Icons.groups_outlined,
                                          color: theme.colorScheme
                                              .onSurfaceVariant,
                                          size: 20),
                                      label: Text(
                                        'Group link set nahi hai',
                                        style: TextStyle(
                                            color: theme.colorScheme
                                                .onSurfaceVariant),
                                      ),
                                    ),
                            ),
                            if (!hasLink)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Class Detail screen mein group link add karein',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme
                                          .onSurfaceVariant),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            const SizedBox(height: 10),

                            // Individual send button
                            students.when(
                              loading: () =>
                                  const LinearProgressIndicator(),
                              error: (_, __) =>
                                  const SizedBox.shrink(),
                              data: (studentList) => SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: OutlinedButton.icon(
                                  onPressed: () => _sendIndividually(
                                      context,
                                      ref,
                                      studentList,
                                      selectedList),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        AppTheme.whatsappColor,
                                    side: const BorderSide(
                                        color: AppTheme.whatsappColor,
                                        width: 1.5),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                  ),
                                  icon: const Icon(
                                      Icons.person_pin_rounded,
                                      size: 20),
                                  label: Text(
                                    'Har Parent ko Alag Bhejo (${studentList.length})',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ],
            );
          },
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

  Future<void> _sendToGroup(BuildContext context, WidgetRef ref,
      String groupLink, List<Homework> selected) async {
    final dateStr = DateFormat('dd MMM yyyy').format(selectedDate);
    final message = _buildCombinedGroupMessage(selected, dateStr);
    await Clipboard.setData(ClipboardData(text: message));
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Green header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF075E54), Color(0xFF128C7E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.groups_rounded,
                            color: Colors.white, size: 24),
                        SizedBox(width: 10),
                        Text('WhatsApp Group mein Bhejo',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          const Text(
                            'Message clipboard mein copy ho gaya!',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Step-by-step instructions
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  children: [
                    _StepTile(
                      number: '1',
                      icon: Icons.open_in_new_rounded,
                      title: 'Group kholo',
                      subtitle:
                          'Neeche "Open Group" button dabao — WhatsApp group khul jayega',
                    ),
                    const SizedBox(height: 10),
                    _StepTile(
                      number: '2',
                      icon: Icons.content_paste_rounded,
                      title: 'Message paste karo',
                      subtitle:
                          'Message box mein long-press karo → "Paste" chunein',
                    ),
                    const SizedBox(height: 10),
                    _StepTile(
                      number: '3',
                      icon: Icons.send_rounded,
                      title: 'Send karo',
                      subtitle:
                          'Green send button dabao — sab parents ko ek saath message jayega',
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                      color:
                                          theme.colorScheme.outlineVariant)),
                            ),
                            child: Text('Cancel',
                                style: TextStyle(
                                    color:
                                        theme.colorScheme.onSurfaceVariant)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final uri = Uri.parse(groupLink);
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.whatsappColor,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.open_in_new_rounded,
                                size: 18),
                            label: const Text(
                              'Open Group',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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

// ── Step tile helper (used in group-send dialog) ──────────────────────────────

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.number,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final String number, title, subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Numbered circle
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppTheme.whatsappColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(number,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.whatsappColor,
                  fontSize: 14)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: AppTheme.whatsappColor),
                  const SizedBox(width: 6),
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
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
    final theme = Theme.of(context);
    final hasNumber = current.whatsapp.isNotEmpty;
    final progress = (currentIndex + 1) / widget.students.length;
    final initials = current.fullName.trim().isNotEmpty
        ? current.fullName.trim().split(' ').take(2).map((w) => w[0]).join()
        : '?';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Green header with progress ────────────────────────────
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF075E54), Color(0xFF128C7E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Text('Individual Send',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${currentIndex + 1} of ${widget.students.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

          // ── Student card + message preview ────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student info row
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: hasNumber
                            ? AppTheme.whatsappColor.withOpacity(0.15)
                            : Colors.grey.shade200,
                        child: Text(
                          initials,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: hasNumber
                                  ? AppTheme.whatsappColor
                                  : Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(current.fullName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.person_outline_rounded,
                                    size: 13,
                                    color:
                                        theme.colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    current.parentName.isNotEmpty
                                        ? current.parentName
                                        : '—',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: theme
                                            .colorScheme.onSurfaceVariant),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  hasNumber
                                      ? Icons.phone_rounded
                                      : Icons.phone_disabled_rounded,
                                  size: 13,
                                  color: hasNumber
                                      ? AppTheme.whatsappColor
                                      : Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  hasNumber
                                      ? current.whatsapp
                                      : 'Number nahi hai — skip hoga',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: hasNumber
                                          ? AppTheme.whatsappColor
                                          : Colors.orange),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Subject chips being sent
                  if (widget.selectedHomework.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.selectedHomework.map((hw) {
                        final c = _colorForSubject(hw.subject);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: c.withOpacity(0.4), width: 1),
                          ),
                          child: Text(hw.subject,
                              style: TextStyle(
                                  color: c,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Message preview
                  if (hasNumber)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECF5EC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.whatsappColor.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded,
                                  size: 13, color: AppTheme.whatsappColor),
                              const SizedBox(width: 5),
                              Text('Message',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.whatsappColor
                                          .withOpacity(0.8))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(_buildMessage(),
                              style: const TextStyle(
                                  fontSize: 12, height: 1.55)),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Is student ka WhatsApp number save nahi hai. Yeh automatically skip ho jayega.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Action buttons ────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                  top: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                      width: 1)),
            ),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                      foregroundColor:
                          theme.colorScheme.onSurfaceVariant),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: _advance,
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: theme.colorScheme.outlineVariant)),
                  child: Text(isLast ? 'Done' : 'Skip'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: hasNumber ? _sendAndAdvance : _advance,
                  style: FilledButton.styleFrom(
                      backgroundColor: hasNumber
                          ? AppTheme.whatsappColor
                          : theme.colorScheme.primary),
                  icon: Icon(
                      hasNumber
                          ? Icons.send_rounded
                          : Icons.skip_next_rounded,
                      size: 18),
                  label: Text(
                    hasNumber
                        ? (isLast ? 'Send & Done' : 'Send & Next')
                        : 'Skip',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final theme = Theme.of(context);
    final hasNumber = current.whatsapp.isNotEmpty;
    final progress = (currentIndex + 1) / widget.students.length;
    final initials = current.fullName.trim().isNotEmpty
        ? current.fullName.trim().split(' ').take(2).map((w) => w[0]).join()
        : '?';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ─────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF075E54), Color(0xFF128C7E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.pending_actions_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text('Pending: ${widget.subject}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${currentIndex + 1} of ${widget.students.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

          // ── Student info ────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: hasNumber
                          ? AppTheme.whatsappColor.withOpacity(0.15)
                          : Colors.grey.shade200,
                      child: Text(initials,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: hasNumber
                                  ? AppTheme.whatsappColor
                                  : Colors.grey)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(current.fullName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 17)),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.person_outline_rounded,
                                  size: 13,
                                  color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  current.parentName.isNotEmpty
                                      ? current.parentName
                                      : '—',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: theme
                                          .colorScheme.onSurfaceVariant),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                hasNumber
                                    ? Icons.phone_rounded
                                    : Icons.phone_disabled_rounded,
                                size: 13,
                                color: hasNumber
                                    ? AppTheme.whatsappColor
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                hasNumber
                                    ? current.whatsapp
                                    : 'Number nahi — skip hoga',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: hasNumber
                                        ? AppTheme.whatsappColor
                                        : Colors.orange),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!hasNumber) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'WhatsApp number nahi hai — yeh student automatically skip hoga.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Action buttons ──────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                  top: BorderSide(
                      color: theme.colorScheme.outlineVariant, width: 1)),
            ),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                      foregroundColor:
                          theme.colorScheme.onSurfaceVariant),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: _advance,
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: theme.colorScheme.outlineVariant)),
                  child: Text(isLast ? 'Done' : 'Skip'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: hasNumber ? _sendAndAdvance : null,
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.whatsappColor),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    isLast ? 'Send & Done' : 'Send & Next',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      title: const Text('Homework Status'),
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
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _statusColor(status).withOpacity(0.2),
                        child: Icon(
                          status == 'completed'
                              ? Icons.check_circle
                              : status == 'incomplete'
                                  ? Icons.cancel
                                  : Icons.help_outline,
                          color: _statusColor(status),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          student.fullName,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 130,
                        child: DropdownButton<String>(
                          value: status,
                          isDense: true,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(
                                value: 'completed',
                                child: Text('✓ Done',
                                    style: TextStyle(
                                        color: AppTheme.attendanceColor,
                                        fontSize: 12))),
                            DropdownMenuItem(
                                value: 'incomplete',
                                child: Text('✗ Pending',
                                    style: TextStyle(
                                        color: AppTheme.absentColor,
                                        fontSize: 12))),
                            DropdownMenuItem(
                                value: 'not_checked',
                                child: Text('? Check nahi',
                                    style: TextStyle(fontSize: 12))),
                          ],
                          onChanged: (value) => setState(() =>
                              _localOverrides[student.id] =
                                  value ?? 'not_checked'),
                        ),
                      ),
                    ],
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
