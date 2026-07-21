import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/models.dart';
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
              children: items
                  .map((room) =>
                      _ClassSummaryCard(classId: room.id, className: room.label))
                  .toList(),
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
            subtitle: 'Class-wise daily attendance dekho',
            color: AppTheme.attendanceColor,
            onTap: () => _openSheet(context, const _AttendanceReportSheet()),
          ),
          const SizedBox(height: 8),
          _ReportTile(
            icon: Icons.assignment_turned_in_rounded,
            title: 'Homework Report',
            subtitle: 'Subject-wise completion rate dekho',
            color: AppTheme.homeworkColor,
            onTap: () => _openSheet(context, const _HomeworkReportSheet()),
          ),
          const SizedBox(height: 8),
          _ReportTile(
            icon: Icons.message_rounded,
            title: 'WhatsApp Report',
            subtitle: 'Aaj kitne parents ko message bheja',
            color: AppTheme.whatsappColor,
            onTap: () => _openSheet(context, const _WhatsAppReportSheet()),
          ),
        ],
      ),
    );
  }

  void _openSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => sheet,
    );
  }
}

// ── Attendance Report Sheet ───────────────────────────────────────────────────

class _AttendanceReportSheet extends ConsumerStatefulWidget {
  const _AttendanceReportSheet();

  @override
  ConsumerState<_AttendanceReportSheet> createState() =>
      _AttendanceReportSheetState();
}

class _AttendanceReportSheetState
    extends ConsumerState<_AttendanceReportSheet> {
  DateTime _date = DateTime.now();
  // classId → {present, absent, students}
  Map<ClassRoom, _AttendData> _data = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(repoProvider);
    final classes = await repo.myClasses();
    final Map<ClassRoom, _AttendData> result = {};
    for (final cls in classes) {
      final statusMap = await repo.getAttendanceForDate(cls.id, _date);
      final students = await repo.students(cls.id);
      final present =
          students.where((s) => statusMap[s.id] == AttendanceStatus.present).toList();
      final absent =
          students.where((s) => statusMap[s.id] == AttendanceStatus.absent).toList();
      result[cls] = _AttendData(present: present, absent: absent, total: students.length);
    }
    if (mounted) setState(() { _data = result; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy').format(_date);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppTheme.attendanceColor.withOpacity(0.15),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.bar_chart_rounded,
                      color: AppTheme.attendanceColor),
                ),
                const SizedBox(width: 10),
                Text('Attendance Report',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                // Date picker
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      _date = picked;
                      _load();
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 14),
                  label: Text(dateStr,
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const Divider(height: 20),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_data.isEmpty)
              const Expanded(
                  child: Center(child: Text('Koi class nahi mili.')))
            else
              Expanded(
                child: ListView(
                  controller: controller,
                  children: _data.entries.map((e) {
                    final cls = e.key;
                    final d = e.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        title: Text('Class ${cls.label}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            'Present: ${d.present.length}  |  Absent: ${d.absent.length}  |  Total: ${d.total}',
                            style: const TextStyle(fontSize: 12)),
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.attendanceColor.withOpacity(0.15),
                          child: Text('${d.present.length}/${d.total}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.attendanceColor,
                                  fontWeight: FontWeight.bold)),
                        ),
                        children: d.absent.isEmpty
                            ? [
                                const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('Sab present hain! 🎉',
                                      style: TextStyle(
                                          color: AppTheme.attendanceColor)),
                                )
                              ]
                            : [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Absent students:',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.absentColor,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      ...d.absent.map((s) => Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 2),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.circle,
                                                    size: 6,
                                                    color: AppTheme.absentColor),
                                                const SizedBox(width: 8),
                                                Text(s.fullName,
                                                    style: const TextStyle(
                                                        fontSize: 13)),
                                              ],
                                            ),
                                          )),
                                    ],
                                  ),
                                ),
                              ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AttendData {
  final List<Student> present, absent;
  final int total;
  const _AttendData(
      {required this.present, required this.absent, required this.total});
}

// ── Homework Report Sheet ─────────────────────────────────────────────────────

class _HomeworkReportSheet extends ConsumerStatefulWidget {
  const _HomeworkReportSheet();

  @override
  ConsumerState<_HomeworkReportSheet> createState() =>
      _HomeworkReportSheetState();
}

class _HomeworkReportSheetState extends ConsumerState<_HomeworkReportSheet> {
  List<ClassRoom> _classes = [];
  ClassRoom? _selectedClass;
  List<_HwData> _homeworkData = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final repo = ref.read(repoProvider);
    final classes = await repo.myClasses();
    if (mounted) {
      setState(() {
        _classes = classes;
        _selectedClass = classes.isNotEmpty ? classes.first : null;
      });
      if (_selectedClass != null) _loadHomework(_selectedClass!);
    }
  }

  Future<void> _loadHomework(ClassRoom cls) async {
    setState(() => _loading = true);
    final repo = ref.read(repoProvider);
    final homeworkList = await repo.getHomeworkForClass(cls.id);
    final students = await repo.students(cls.id);
    final total = students.length;

    final List<_HwData> result = [];
    for (final hw in homeworkList.take(15)) {
      final statusRecords = await repo.getHomeworkStatus(hw.id);
      final completed =
          statusRecords.where((r) => r.status == 'completed').length;
      final incomplete =
          statusRecords.where((r) => r.status == 'incomplete').length;
      result.add(_HwData(
          hw: hw,
          completed: completed,
          incomplete: incomplete,
          total: total));
    }
    if (mounted) setState(() { _homeworkData = result; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppTheme.homeworkColor.withOpacity(0.15),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.assignment_turned_in_rounded,
                      color: AppTheme.homeworkColor),
                ),
                const SizedBox(width: 10),
                Text('Homework Report',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            // Class selector
            if (_classes.isNotEmpty)
              DropdownButtonFormField<ClassRoom>(
                value: _selectedClass,
                decoration: InputDecoration(
                  labelText: 'Class chunein',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                items: _classes
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text('Class ${c.label}'),
                        ))
                    .toList(),
                onChanged: (c) {
                  if (c != null) {
                    setState(() => _selectedClass = c);
                    _loadHomework(c);
                  }
                },
              ),
            const Divider(height: 20),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_homeworkData.isEmpty)
              const Expanded(
                  child: Center(child: Text('Is class ka koi homework nahi mila.')))
            else
              Expanded(
                child: ListView(
                  controller: controller,
                  children: _homeworkData.map((d) {
                    final pct = d.total > 0
                        ? (d.completed / d.total * 100).toStringAsFixed(0)
                        : '0';
                    final dateStr =
                        DateFormat('dd MMM').format(d.hw.assignedDate);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Subject badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.homeworkColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(d.hw.subject,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppTheme.homeworkColor)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(dateStr,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant)),
                                  Text(
                                      '${d.completed} complete • ${d.incomplete} incomplete • ${d.total - d.completed - d.incomplete} unchecked',
                                      style: const TextStyle(fontSize: 11)),
                                ],
                              ),
                            ),
                            // % circle
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: int.parse(pct) >= 70
                                  ? AppTheme.attendanceColor.withOpacity(0.15)
                                  : int.parse(pct) >= 40
                                      ? Colors.orange.withOpacity(0.15)
                                      : AppTheme.absentColor.withOpacity(0.15),
                              child: Text('$pct%',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: int.parse(pct) >= 70
                                          ? AppTheme.attendanceColor
                                          : int.parse(pct) >= 40
                                              ? Colors.orange
                                              : AppTheme.absentColor)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HwData {
  final Homework hw;
  final int completed, incomplete, total;
  const _HwData(
      {required this.hw,
      required this.completed,
      required this.incomplete,
      required this.total});
}

// ── WhatsApp Report Sheet ─────────────────────────────────────────────────────

class _WhatsAppReportSheet extends ConsumerStatefulWidget {
  const _WhatsAppReportSheet();

  @override
  ConsumerState<_WhatsAppReportSheet> createState() =>
      _WhatsAppReportSheetState();
}

class _WhatsAppReportSheetState extends ConsumerState<_WhatsAppReportSheet> {
  DateTime _date = DateTime.now();
  Map<ClassRoom, _WaData> _data = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(repoProvider);
    final classes = await repo.myClasses();
    final Map<ClassRoom, _WaData> result = {};
    for (final cls in classes) {
      final absent = await repo.getWhatsAppSentStudents(
          classId: cls.id, date: _date, type: 'absent');
      final present = await repo.getWhatsAppSentStudents(
          classId: cls.id, date: _date, type: 'present');
      final homework = await repo.getWhatsAppSentStudents(
          classId: cls.id, date: _date, type: 'homework');
      result[cls] =
          _WaData(absent: absent.length, present: present.length, homework: homework.length);
    }
    if (mounted) setState(() { _data = result; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy').format(_date);
    final totalSent =
        _data.values.fold(0, (s, d) => s + d.absent + d.present + d.homework);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppTheme.whatsappColor.withOpacity(0.15),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.message_rounded,
                      color: AppTheme.whatsappColor),
                ),
                const SizedBox(width: 10),
                Text('WhatsApp Report',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      _date = picked;
                      _load();
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 14),
                  label: Text(dateStr, style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            if (!_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.whatsappColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Aaj kul $totalSent WhatsApp messages bheje gaye',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.whatsappColor),
                  ),
                ),
              ),
            const Divider(height: 4),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_data.isEmpty)
              const Expanded(
                  child: Center(child: Text('Koi data nahi mila.')))
            else
              Expanded(
                child: ListView(
                  controller: controller,
                  children: _data.entries.map((e) {
                    final cls = e.key;
                    final d = e.value;
                    final total = d.absent + d.present + d.homework;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Class ${cls.label}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: total > 0
                                        ? AppTheme.whatsappColor
                                            .withOpacity(0.12)
                                        : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('$total bheje',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: total > 0
                                              ? AppTheme.whatsappColor
                                              : Colors.grey)),
                                ),
                              ],
                            ),
                            if (total > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _WaPill('Absent: ${d.absent}',
                                      AppTheme.absentColor),
                                  const SizedBox(width: 6),
                                  _WaPill('Present: ${d.present}',
                                      AppTheme.attendanceColor),
                                  const SizedBox(width: 6),
                                  _WaPill('Homework: ${d.homework}',
                                      AppTheme.homeworkColor),
                                ],
                              ),
                            ] else
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text('Koi message nahi bheja',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WaData {
  final int absent, present, homework;
  const _WaData(
      {required this.absent, required this.present, required this.homework});
}

class _WaPill extends StatelessWidget {
  const _WaPill(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Class Summary Card (top section) ─────────────────────────────────────────

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
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(DateFormat('dd MMM yyyy').format(today),
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                attendanceDone.when(
                  data: (done) => _SummaryPill(
                      label: done ? 'Attendance ✓' : 'Attendance Pending',
                      color: done
                          ? AppTheme.attendanceColor
                          : AppTheme.pendingColor),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                count.when(
                  data: (data) => _SummaryPill(
                      label: 'Present: ${data['present']} | Absent: ${data['absent']}',
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
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 12)),
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
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
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
