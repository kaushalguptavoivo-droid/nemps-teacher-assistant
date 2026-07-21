import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../data/providers.dart';

enum _SortBy { rollNo, name }

int _compareRollNo(String a, String b) {
  final na = int.tryParse(a.trim());
  final nb = int.tryParse(b.trim());
  if (na != null && nb != null) return na.compareTo(nb);
  return a.compareTo(b);
}

class ClassDetailScreen extends ConsumerStatefulWidget {
  const ClassDetailScreen({super.key, required this.classId});
  final String classId;

  @override
  ConsumerState<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends ConsumerState<ClassDetailScreen> {
  _SortBy _sortBy = _SortBy.rollNo;

  @override
  Widget build(BuildContext context) {
    final classId = widget.classId;
    final students = ref.watch(studentsProvider(classId));
    final groupLink = ref.watch(whatsappGroupLinkProvider(classId));
    final attendanceDone = ref.watch(attendanceDoneTodayProvider(classId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Details'),
        actions: [
          IconButton(
            tooltip: _sortBy == _SortBy.rollNo ? 'Roll No se sorted' : 'Naam se sorted',
            icon: Icon(_sortBy == _SortBy.rollNo ? Icons.format_list_numbered : Icons.sort_by_alpha),
            onPressed: () => setState(
              () => _sortBy = _sortBy == _SortBy.rollNo ? _SortBy.name : _SortBy.rollNo,
            ),
          ),
        ],
      ),
      body: students.when(
        data: (rawItems) {
          final items = [...rawItems]..sort((a, b) => _sortBy == _SortBy.name
              ? a.fullName.compareTo(b.fullName)
              : _compareRollNo(a.rollNo, b.rollNo));
          return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats row
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Students',
                      value: '${items.length}',
                      icon: Icons.people_rounded,
                      color: AppTheme.infoColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: attendanceDone.when(
                      data: (done) => _StatCard(
                        label: 'Attendance',
                        value: done ? 'Done ✓' : 'Pending',
                        icon: done ? Icons.check_circle_rounded : Icons.pending_rounded,
                        color: done ? AppTheme.attendanceColor : AppTheme.pendingColor,
                      ),
                      loading: () => const _StatCard(
                          label: 'Attendance', value: '...', icon: Icons.hourglass_empty, color: Colors.grey),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action buttons grid
              Text('Actions',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  _ActionTile(
                    icon: Icons.fact_check_rounded,
                    label: 'Attendance',
                    subtitle: 'Mark daily',
                    color: AppTheme.attendanceColor,
                    onTap: () => context.go('/attendance/$classId'),
                  ),
                  _ActionTile(
                    icon: Icons.assignment_rounded,
                    label: 'Homework',
                    subtitle: 'Assign & track',
                    color: AppTheme.homeworkColor,
                    onTap: () => context.go('/homework/$classId'),
                  ),
                  _ActionTile(
                    icon: Icons.message_rounded,
                    label: 'WhatsApp Alerts',
                    subtitle: 'Absent/present msg',
                    color: AppTheme.whatsappColor,
                    onTap: () => context.go('/absent/$classId'),
                  ),
                  _ActionTile(
                    icon: Icons.people_rounded,
                    label: 'Students',
                    subtitle: 'Manage list',
                    color: AppTheme.infoColor,
                    onTap: () => context.go('/students/$classId'),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // WhatsApp Group Link
              Text('WhatsApp Group',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              groupLink.when(
                data: (link) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.whatsappColor.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.groups_rounded,
                                  color: AppTheme.whatsappColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Class WhatsApp Group',
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text(
                                    link != null && link.isNotEmpty
                                        ? 'Link linked hai ✓'
                                        : 'Abhi link nahi hai',
                                    style: TextStyle(
                                        color: link != null && link.isNotEmpty
                                            ? AppTheme.attendanceColor
                                            : AppTheme.pendingColor,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (link != null && link.isNotEmpty)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final uri = Uri.parse(link);
                                    await launchUrl(uri,
                                        mode: LaunchMode.externalApplication);
                                  },
                                  icon: const Icon(Icons.open_in_new, size: 16),
                                  label: const Text('Open Group'),
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.whatsappColor),
                                ),
                              ),
                            if (link != null && link.isNotEmpty) const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _setGroupLink(context, ref, link),
                                icon: const Icon(Icons.link, size: 16),
                                label: Text(link != null && link.isNotEmpty
                                    ? 'Change Link'
                                    : 'Add Link'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                loading: () => const Card(
                    child: ListTile(title: Text('Loading...'),
                        leading: SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)))),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 20),

              // Students list
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Students (${items.length})',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => context.go('/students/$classId'),
                    child: const Text('Sab Dekho →'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...items.take(5).map((student) => Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Text(student.rollNo,
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold)),
                      ),
                      title: Text(student.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          student.parentName.isNotEmpty
                              ? student.parentName
                              : 'Father nahi'),
                      trailing: student.whatsapp.isNotEmpty
                          ? const Icon(Icons.check_circle,
                              size: 16, color: AppTheme.whatsappColor)
                          : const Icon(Icons.phone_missed,
                              size: 16, color: Colors.grey),
                    ),
                  )),
              if (items.length > 5)
                TextButton(
                  onPressed: () => context.go('/students/$classId'),
                  child: Text('+ ${items.length - 5} aur students dekho'),
                ),
            ],
          ),
        );
        },
        error: (error, _) => Center(child: Text('Error: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _setGroupLink(
      BuildContext context, WidgetRef ref, String? current) async {
    final ctrl = TextEditingController(text: current ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('WhatsApp Group Link'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WhatsApp group ka invite link paste karein.\n'
              'Yeh ek baar save ho jayega — baad mein homework aur notices seedha group mein bhej sakte hain.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Group Link',
                hintText: 'https://chat.whatsapp.com/...',
                prefixIcon: Icon(Icons.link),
              ),
            ),
          ],
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
    if (confirmed != true || ctrl.text.trim().isEmpty) return;
    try {
      await ref.read(repoProvider).saveWhatsAppGroupLink(widget.classId, ctrl.text);
      ref.invalidate(whatsappGroupLinkProvider(widget.classId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Group link save ho gaya! ✓'),
              backgroundColor: AppTheme.whatsappColor),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
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
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: color)),
                Text(label, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label, subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.outlineVariant),
            ],
          ),
        ),
      ),
    );
  }
}
