import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../data/providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(classesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Summary')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Aaj ka Summary',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          classes.when(
            data: (items) => Column(
              children: items.map((room) => _ClassSummaryCard(classId: room.id, className: room.label)).toList(),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 24),
          Text('Reports',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _ReportTile(
            icon: Icons.bar_chart_rounded,
            title: 'Attendance Report',
            subtitle: 'Daily/monthly attendance dekho',
            color: AppTheme.attendanceColor,
            onTap: () => _showAttendanceReport(context, ref),
          ),
          const SizedBox(height: 8),
          _ReportTile(
            icon: Icons.assignment_turned_in_rounded,
            title: 'Homework Report',
            subtitle: 'Homework completion rate dekho',
            color: AppTheme.homeworkColor,
            onTap: () => _showHomeworkReport(context, ref),
          ),
          const SizedBox(height: 8),
          _ReportTile(
            icon: Icons.message_rounded,
            title: 'WhatsApp Report',
            subtitle: 'Kitne parents ko message bheja',
            color: AppTheme.whatsappColor,
            onTap: () => _showWhatsAppReport(context, ref),
          ),
        ],
      ),
    );
  }

  void _showAttendanceReport(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Attendance Report',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.bar_chart, size: 64, color: AppTheme.attendanceColor),
                    SizedBox(height: 8),
                    Text('Supabase se detailed attendance report\nApp ka next version mein available hoga.',
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHomeworkReport(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Homework Report',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Center(
              child: Column(
                children: [
                  Icon(Icons.assignment, size: 64, color: AppTheme.homeworkColor),
                  SizedBox(height: 8),
                  Text('Subject-wise homework completion data\nApp ka next version mein available hoga.',
                      textAlign: TextAlign.center),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showWhatsAppReport(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WhatsApp Notification Report',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Center(
              child: Column(
                children: [
                  Icon(Icons.message, size: 64, color: AppTheme.whatsappColor),
                  SizedBox(height: 8),
                  Text('Kitne parents ko message bheja gaya\nyeh track hota hai WhatsApp screen mein.',
                      textAlign: TextAlign.center),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ClassSummaryCard extends ConsumerWidget {
  const _ClassSummaryCard({required this.classId, required this.className});
  final String classId, className;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final count = ref.watch(dailyAttendanceCountProvider((classId, today)));
    final attendanceDone = ref.watch(attendanceDoneTodayProvider(classId));
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Class $className',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(DateFormat('dd MMM yyyy').format(today),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              children: [
                attendanceDone.when(
                  data: (done) => _SummaryPill(
                      label: done ? 'Attendance ✓' : 'Attendance Pending',
                      color: done ? AppTheme.attendanceColor : AppTheme.pendingColor),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(width: 8),
                count.when(
                  data: (data) => _SummaryPill(
                      label:
                          'P: ${data['present']} | A: ${data['absent']}',
                      color: AppTheme.infoColor),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(subtitle,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12)),
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
