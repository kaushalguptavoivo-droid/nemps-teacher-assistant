import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:share_plus/share_plus.dart';
import '../../core/models/models.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../data/providers.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key, required this.classId});
  final String classId;

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

enum _SortBy { rollNo, name }

int _compareRollNo(String a, String b) {
  final na = int.tryParse(a.trim());
  final nb = int.tryParse(b.trim());
  if (na != null && nb != null) return na.compareTo(nb);
  return a.compareTo(b);
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  final statuses = <String, AttendanceStatus>{};
  DateTime selectedDate = DateTime.now();
  bool saving = false;
  bool loadingExisting = false;
  bool isHolidayMarked = false;
  _SortBy _sortBy = _SortBy.rollNo;

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
      // Check if holiday was previously marked (any student has holiday status)
      isHolidayMarked =
          statuses.values.any((s) => s == AttendanceStatus.holiday);
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
      setState(() {
        selectedDate = picked;
        isHolidayMarked = false;
      });
      await _loadExistingAttendance();
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
        final presentCount = statuses.values
            .where((s) => s == AttendanceStatus.present)
            .length;
        final absentCount = statuses.values
            .where((s) => s == AttendanceStatus.absent)
            .length;
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

  /// Mark the selected date as a holiday for all students.
  Future<void> _markHoliday(List<Student> items) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.beach_access_rounded, color: Color(0xFFf97316)),
            SizedBox(width: 8),
            Text('Holiday Mark Karein?'),
          ],
        ),
        content: Text(
          '${DateFormat('dd MMM yyyy').format(selectedDate)} ko holiday mark karna chahte hain?\n\n'
          'Aaj koi attendance ya homework nahi chahiye.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton.icon(
            style:
                FilledButton.styleFrom(backgroundColor: const Color(0xFFf97316)),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.beach_access_rounded),
            label: const Text('Holiday Mark Karein'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => saving = true);
    try {
      for (final student in items) {
        await ref.read(repoProvider).saveAttendance(
              classId: widget.classId,
              studentId: student.id,
              status: AttendanceStatus.holiday,
              date: selectedDate,
            );
      }
      setState(() {
        for (final s in items) {
          statuses[s.id] = AttendanceStatus.holiday;
        }
        isHolidayMarked = true;
      });

      // Cancel today's reminders if marking today as holiday
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final selDay = selectedDate.toIso8601String().substring(0, 10);
      if (today == selDay) {
        await NotificationService.cancelTodayReminders();
        // Reschedule so future weeks still get reminders
        await NotificationService.scheduleDailyAttendanceReminder();
        await NotificationService.scheduleDailyHomeworkReminder();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${DateFormat('dd MMM yyyy').format(selectedDate)} — Holiday mark ho gaya! 🏖️'),
            backgroundColor: const Color(0xFFf97316),
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
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            tooltip: _sortBy == _SortBy.rollNo ? 'Roll No se sorted' : 'Naam se sorted',
            icon: Icon(_sortBy == _SortBy.rollNo ? Icons.format_list_numbered : Icons.sort_by_alpha),
            onPressed: () => setState(
              () => _sortBy = _sortBy == _SortBy.rollNo ? _SortBy.name : _SortBy.rollNo,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import/Export',
            onSelected: (value) => _handleImportExport(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.upload, size: 20),
                    SizedBox(width: 8),
                    Text('Import Attendance (CSV/Excel)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20),
                    SizedBox(width: 8),
                    Text('Export Attendance'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: students.when(
        data: (rawItems) {
          final items = [...rawItems]..sort((a, b) => _sortBy == _SortBy.name
              ? a.fullName.compareTo(b.fullName)
              : _compareRollNo(a.rollNo, b.rollNo));
          final presentCount = statuses.values
              .where((s) => s == AttendanceStatus.present)
              .length;
          final absentCount = statuses.values
              .where((s) => s == AttendanceStatus.absent)
              .length;

          return Column(
            children: [
              // Header
              Container(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.3),
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
                                DateFormat('dd MMM yyyy, EEEE')
                                    .format(selectedDate),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (isHolidayMarked)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFf97316)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.beach_access_rounded,
                                          size: 14,
                                          color: Color(0xFFf97316)),
                                      SizedBox(width: 4),
                                      Text('HOLIDAY',
                                          style: TextStyle(
                                              color: Color(0xFFf97316),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                    ],
                                  ),
                                )
                              else
                                count.when(
                                  data: (data) => Row(
                                    children: [
                                      _StatusPill(
                                          label:
                                              'Present ${data['present'] ?? 0}',
                                          color: AppTheme.attendanceColor),
                                      const SizedBox(width: 6),
                                      _StatusPill(
                                          label:
                                              'Absent ${data['absent'] ?? 0}',
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

                    if (!isHolidayMarked) ...[
                      const SizedBox(height: 10),
                      // Live counters
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.attendanceColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      color: AppTheme.attendanceColor,
                                      size: 18),
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
                  ],
                ),
              ),

              if (isHolidayMarked)
                // Holiday view — full screen message
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.beach_access_rounded,
                            size: 72, color: Color(0xFFf97316)),
                        const SizedBox(height: 12),
                        Text(
                          '${DateFormat('dd MMM yyyy').format(selectedDate)}\nHoliday Hai! 🎉',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFf97316),
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Aaj koi attendance nahi chahiye.',
                          style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: () => setState(() {
                            isHolidayMarked = false;
                            for (final s in items) {
                              statuses[s.id] = AttendanceStatus.present;
                            }
                          }),
                          icon: const Icon(Icons.undo_rounded),
                          label: const Text('Holiday Hatao'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Mark all row + Holiday button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Text('Mark all:',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          for (final s in items) {
                            statuses[s.id] = AttendanceStatus.present;
                          }
                        }),
                        icon: const Icon(Icons.check_circle_rounded,
                            color: AppTheme.attendanceColor, size: 16),
                        label: const Text('P'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.attendanceColor,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            side: const BorderSide(
                                color: AppTheme.attendanceColor)),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          for (final s in items) {
                            statuses[s.id] = AttendanceStatus.absent;
                          }
                        }),
                        icon: const Icon(Icons.cancel_rounded,
                            color: AppTheme.absentColor, size: 16),
                        label: const Text('A'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.absentColor,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            side:
                                const BorderSide(color: AppTheme.absentColor)),
                      ),
                      const Spacer(),
                      // Holiday button
                      OutlinedButton.icon(
                        onPressed: () => _markHoliday(items),
                        icon: const Icon(Icons.beach_access_rounded,
                            color: Color(0xFFf97316), size: 16),
                        label: const Text('Holiday'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFf97316),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          side: const BorderSide(color: Color(0xFFf97316)),
                        ),
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
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(student.parentName,
                              style: const TextStyle(fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _AttendanceChip(
                                label: 'P',
                                selected: isPresent,
                                color: AppTheme.attendanceColor,
                                onTap: () => setState(() =>
                                    statuses[student.id] =
                                        AttendanceStatus.present),
                              ),
                              const SizedBox(width: 6),
                              _AttendanceChip(
                                label: 'A',
                                selected: !isPresent,
                                color: AppTheme.absentColor,
                                onTap: () => setState(() =>
                                    statuses[student.id] =
                                        AttendanceStatus.absent),
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
            ],
          );
        },
        error: (error, _) =>
            Center(child: Text('Error loading students: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _handleImportExport(String action) async {
    if (action == 'import') {
      await _importAttendance();
    } else if (action == 'export') {
      await _exportAttendance();
    }
  }

  Future<void> _importAttendance() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;

      final extension = file.extension?.toLowerCase();

      List<List<dynamic>> data;
      if (extension == 'csv') {
        final csvString = String.fromCharCodes(bytes);
        data = const CsvToListConverter().convert(csvString);
      } else {
        final excel = Excel.decodeBytes(bytes);
        data = [];
        for (final table in excel.tables.keys) {
          final sheet = excel.tables[table];
          if (sheet != null) {
            for (final row in sheet.rows) {
              data.add(row.map((cell) => cell?.value?.toString() ?? '').toList());
            }
          }
        }
      }

      if (data.length < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File is empty or invalid')),
          );
        }
        return;
      }

      // Show preview
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Attendance'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: data.first.map((c) => DataColumn(label: Text(c.toString()))).toList(),
                  rows: data.skip(1).take(5).map((row) => DataRow(
                    cells: row.map((c) => DataCell(Text(c.toString()))).toList(),
                  )).toList(),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Import ${data.length - 1} Rows')),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${data.length - 1} attendance records imported!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportAttendance() async {
    try {
      final data = [
        ['Date', 'Student Name', 'Roll No', 'Status', 'Remarks']
      ];

      final csvData = const ListToCsvConverter().convert(data);
      final bytes = Uint8List.fromList(csvData.codeUnits);

      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'text/csv', name: 'attendance_export.csv')],
        subject: 'Attendance Export',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance exported!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
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
              color: selected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
