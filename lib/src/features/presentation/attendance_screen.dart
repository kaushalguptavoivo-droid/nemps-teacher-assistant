import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../data/providers.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key, required this.classId});
  final String classId;

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  final statuses = <String, AttendanceStatus>{};
  DateTime selectedDate = DateTime.now();
  bool saving = false;
  bool loadingExisting = false;

  @override
  void initState() {
    super.initState();
    _loadExistingAttendance();
  }

  Future<void> _loadExistingAttendance() async {
    if (!mounted) return;
    setState(() => loadingExisting = true);
    final existing = await ref
        .read(repoProvider)
        .getAttendanceForDate(widget.classId, selectedDate);
    if (!mounted) return;
    setState(() {
      statuses..clear()..addAll(existing);
      loadingExisting = false;
    });
  }

  Future<void> _changeDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
      await _loadExistingAttendance();
      ref.invalidate(dailyAttendanceCountProvider);
    }
  }

  Future<void> _saveAttendance(List<Student> items) async {
    setState(() => saving = true);
    try {
      int saved = 0;
      for (final student in items) {
        await ref.read(repoProvider).saveAttendance(
              classId: widget.classId,
              studentId: student.id,
              status: statuses[student.id] ?? AttendanceStatus.present,
              date: selectedDate,
            );
        saved++;
      }
      if (mounted) {
        ref.invalidate(dailyAttendanceCountProvider);
        ref.invalidate(attendanceDoneTodayProvider(widget.classId));
        final presentCount =
            statuses.values.where((s) => s == AttendanceStatus.present).length;
        final absentCount =
            statuses.values.where((s) => s == AttendanceStatus.absent).length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Attendance save ho gayi! ✓ $saved students | Present: $presentCount | Absent: $absentCount'),
            backgroundColor: AppTheme.attendanceColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(studentsProvider(widget.classId));
    final count = ref.watch(
        dailyAttendanceCountProvider((widget.classId, selectedDate)));

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: students.when(
        data: (items) {
          final presentCount =
              statuses.values.where((s) => s == AttendanceStatus.present).length;
          final absentCount =
              statuses.values.where((s) => s == AttendanceStatus.absent).length;

          return Column(
            children: [
              // Header
              Container(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('dd MMM yyyy, EEEE').format(selectedDate),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold),
                              ),
                              count.when(
                                data: (data) => Row(
                                  children: [
                                    _StatusPill(
                                        label: 'Present ${data['present'] ?? 0}',
                                        color: AppTheme.attendanceColor),
                                    const SizedBox(width: 6),
                                    _StatusPill(
                                        label: 'Absent ${data['absent'] ?? 0}',
                                        color: AppTheme.absentColor),
                                  ],
                                ),
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _changeDate,
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: const Text('Date'),
                        ),
                      ],
                    ),
                    if (loadingExisting)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(),
                      ),
                    const SizedBox(height: 10),
                    // Live counters
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.attendanceColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: AppTheme.attendanceColor, size: 18),
                                const SizedBox(width: 6),
                                Text('$presentCount Present',
                                    style: const TextStyle(
                                        color: AppTheme.attendanceColor,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.absentColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cancel_rounded,
                                    color: AppTheme.absentColor, size: 18),
                                const SizedBox(width: 6),
                                Text('$absentCount Absent',
                                    style: const TextStyle(
                                        color: AppTheme.absentColor,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Mark all row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Text('Mark all:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        for (final s in items) {
                          statuses[s.id] = AttendanceStatus.present;
                        }
                      }),
                      icon: const Icon(Icons.check_circle_rounded,
                          color: AppTheme.attendanceColor, size: 16),
                      label: const Text('All Present'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.attendanceColor,
                          side: const BorderSide(color: AppTheme.attendanceColor)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        for (final s in items) {
                          statuses[s.id] = AttendanceStatus.absent;
                        }
                      }),
                      icon: const Icon(Icons.cancel_rounded,
                          color: AppTheme.absentColor, size: 16),
                      label: const Text('All Absent'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.absentColor,
                          side: const BorderSide(color: AppTheme.absentColor)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Student list
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, index) {
                    final student = items[index];
                    final status =
                        statuses[student.id] ?? AttendanceStatus.present;
                    final isPresent = status == AttendanceStatus.present;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isPresent
                            ? AppTheme.attendanceColor.withOpacity(0.04)
                            : AppTheme.absentColor.withOpacity(0.04),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPresent
                              ? AppTheme.attendanceColor
                              : AppTheme.absentColor,
                          child: Text(student.rollNo,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        title: Text(student.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(student.parentName,
                            style: const TextStyle(fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _AttendanceChip(
                              label: 'P',
                              selected: isPresent,
                              color: AppTheme.attendanceColor,
                              onTap: () => setState(
                                  () => statuses[student.id] = AttendanceStatus.present),
                            ),
                            const SizedBox(width: 6),
                            _AttendanceChip(
                              label: 'A',
                              selected: !isPresent,
                              color: AppTheme.absentColor,
                              onTap: () => setState(
                                  () => statuses[student.id] = AttendanceStatus.absent),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Save button
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: saving ? null : () => _saveAttendance(items),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AppTheme.attendanceColor),
                  icon: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: Text(saving
                      ? 'Saving...'
                      : 'Save Attendance (${items.length} students)'),
                ),
              ),
            ],
          );
        },
        error: (error, _) =>
            Center(child: Text('Error loading students: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _AttendanceChip extends StatelessWidget {
  const _AttendanceChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Theme.of(context).colorScheme.outline,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
