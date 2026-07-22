// Feature 1: Attendance Register — Standalone Matrix View
// Role-based: Teachers see their assigned class; Admins can pick any class.
// Zero modification to existing attendance_screen.dart functionality.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/models.dart';
import '../data/providers.dart';

// ── Data model for one student's register row ────────────────────────────────
class _RegisterRow {
  const _RegisterRow({
    required this.studentId,
    required this.rollNo,
    required this.fullName,
    required this.dayStatuses,        // day (1-31) → 'P'/'A'/'H'/null
    required this.currentMonthPresent,
    required this.allTimePresent,
  });
  final String studentId, rollNo, fullName;
  final Map<int, String?> dayStatuses; // null = no record
  final int currentMonthPresent, allTimePresent;

  int get previousPresent => allTimePresent - currentMonthPresent;
}

// ── Screen ───────────────────────────────────────────────────────────────────
class AttendanceRegisterScreen extends ConsumerStatefulWidget {
  /// [classId] is the initial class to show; may be empty for admin default.
  const AttendanceRegisterScreen({super.key, required this.classId});
  final String classId;

  @override
  ConsumerState<AttendanceRegisterScreen> createState() =>
      _AttendanceRegisterScreenState();
}

class _AttendanceRegisterScreenState
    extends ConsumerState<AttendanceRegisterScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _isAdmin = false;
  List<ClassRoom> _allClasses = [];
  String? _selectedClassId;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = true;
  List<_RegisterRow> _rows = [];
  int _totalWorkingDays = 0;

  final _hScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedClassId =
        widget.classId.isNotEmpty ? widget.classId : null;
    _init();
  }

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final role = await ref.read(repoProvider).getCurrentUserRole();
    if (role == UserRole.admin) {
      final data = await Supabase.instance.client
          .from('classes')
          .select()
          .order('name');
      final classes = data.map((r) => ClassRoom.fromMap(r)).toList();
      if (!mounted) return;
      setState(() {
        _isAdmin = true;
        _allClasses = classes;
        _selectedClassId ??=
            classes.isNotEmpty ? classes.first.id : null;
      });
    }
    await _loadData();
  }

  Future<void> _loadData() async {
    if (_selectedClassId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);

    try {
      final repo = ref.read(repoProvider);
      final year = _selectedMonth.year;
      final month = _selectedMonth.month;

      final students = await repo.students(_selectedClassId!);

      // Current month attendance
      final monthAtt = await repo.getAttendanceForMonth(
          _selectedClassId!, year, month);

      // All-time present counts
      final allTime = await repo.getAllTimePresentCounts(_selectedClassId!);

      // Compute days in month that have any attendance record
      final daysMarked = <int>{};
      for (final dayMap in monthAtt.values) {
        daysMarked.addAll(dayMap.keys);
      }

      final rows = students.map((s) {
        final dayMap = monthAtt[s.id] ?? {};
        final currentPresent =
            dayMap.values.where((v) => v == 'P').length;
        return _RegisterRow(
          studentId: s.id,
          rollNo: s.rollNo,
          fullName: s.fullName,
          dayStatuses: dayMap,
          currentMonthPresent: currentPresent,
          allTimePresent: allTime[s.id] ?? 0,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _totalWorkingDays = daysMarked.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    // Use a simple year-month picker via showDatePicker on day 1
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_selectedMonth.year, _selectedMonth.month),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month),
      helpText: 'Select Month',
      fieldLabelText: 'Month/Year',
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
      await _loadData();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);
    final daysInMonth = DateTimeRange(
      start: _selectedMonth,
      end: DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0),
    ).duration.inDays + 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Register'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _buildControls(monthLabel),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(child: Text('No students found for this class.'))
              : _buildRegister(daysInMonth),
    );
  }

  Widget _buildControls(String monthLabel) {
    return Container(
      color: Theme.of(context).colorScheme.primary.withOpacity(0.85),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          if (_isAdmin) ...[
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedClassId,
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                  iconEnabledColor: Colors.white,
                  items: _allClasses
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.label,
                                style: const TextStyle(color: Colors.black87)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedClassId = v);
                    _loadData();
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
          ] else
            const Expanded(child: SizedBox.shrink()),
          TextButton.icon(
            onPressed: _pickMonth,
            icon: const Icon(Icons.calendar_month_rounded,
                color: Colors.white, size: 18),
            label: Text(monthLabel,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRegister(int daysInMonth) {
    // Working days info
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Info bar
        Container(
          width: double.infinity,
          color: cs.primaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            'Total Working Days (attendance marked): $_totalWorkingDays   '
            '| Students: ${_rows.length}',
            style: TextStyle(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w600,
                fontSize: 12),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: _buildTable(daysInMonth),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(int daysInMonth) {
    const double rollW = 40;
    const double nameW = 140;
    const double dayW  = 26;
    const double sumW  = 54;
    const double rowH  = 36;
    const double hdrH  = 40;

    final cs   = Theme.of(context).colorScheme;
    final days = List.generate(daysInMonth, (i) => i + 1);

    // ── Colour helpers ─────────────────────────────────────────────────────
    Color cellColor(String? s) {
      if (s == 'P') return Colors.green.shade100;
      if (s == 'A') return Colors.red.shade100;
      if (s == 'H') return Colors.orange.shade100;
      return Colors.transparent;
    }

    Color textColor(String? s) {
      if (s == 'P') return Colors.green.shade800;
      if (s == 'A') return Colors.red.shade800;
      if (s == 'H') return Colors.orange.shade800;
      return Colors.transparent;
    }

    // ── Compute column totals (how many P per day) ─────────────────────────
    final colTotals = <int, int>{};
    for (final day in days) {
      colTotals[day] = _rows
          .where((r) => r.dayStatuses[day] == 'P')
          .length;
    }
    final sumOfColTotals = colTotals.values.fold(0, (a, b) => a + b);
    final sumOfRowTotals =
        _rows.fold(0, (a, r) => a + r.currentMonthPresent);
    final tallied = sumOfColTotals == sumOfRowTotals && _rows.isNotEmpty;

    // ── Border style ───────────────────────────────────────────────────────
    final border = BorderSide(color: cs.outlineVariant, width: 0.5);
    final borderAll = TableBorder(
      top: border, bottom: border, left: border, right: border,
      horizontalInside: border, verticalInside: border,
    );

    Widget headerCell(String txt, double w, {Color? bg}) => Container(
          width: w,
          height: hdrH,
          color: bg ?? cs.primaryContainer,
          alignment: Alignment.center,
          child: Text(txt,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: cs.onPrimaryContainer)),
        );

    Widget dataCell(String? txt, double w,
        {Color? bg, Color? fg, bool bold = false}) =>
        Container(
          width: w,
          height: rowH,
          color: bg ?? Colors.transparent,
          alignment: Alignment.center,
          child: txt != null && txt.isNotEmpty
              ? Text(txt,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          bold ? FontWeight.bold : FontWeight.normal,
                      color: fg))
              : const SizedBox.shrink(),
        );

    Widget totalCell(String txt, double w, {Color? bg}) => Container(
          width: w,
          height: rowH,
          color: bg ?? cs.surfaceVariant,
          alignment: Alignment.center,
          child: Text(txt,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurfaceVariant)),
        );

    // ── Fixed left columns (Roll No + Name) ───────────────────────────────
    Widget buildLeft() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            headerCell('#', rollW),
            headerCell('Name', nameW),
          ]),
          // Data rows
          ..._rows.map((r) => Row(children: [
                dataCell(r.rollNo, rollW,
                    bg: cs.surface),
                Container(
                  width: nameW,
                  height: rowH,
                  color: cs.surface,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(r.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11)),
                ),
              ])),
          // Totals row
          Row(children: [
            totalCell('', rollW),
            Container(
              width: nameW,
              height: rowH,
              color: cs.secondaryContainer,
              alignment: Alignment.center,
              child: Text('Daily Total',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: cs.onSecondaryContainer)),
            ),
          ]),
        ],
      );
    }

    // ── Scrollable right section ───────────────────────────────────────────
    Widget buildRight() {
      return SingleChildScrollView(
        controller: _hScroll,
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: dates + summary cols
            Row(children: [
              ...days.map((d) => headerCell('$d', dayW)),
              headerCell('CMP', sumW),   // Current Month Present
              headerCell('Prev', sumW),  // Previous attendance
              headerCell('Total', sumW), // All-time
            ]),
            // Data rows
            ..._rows.map((r) => Row(children: [
                  ...days.map((d) {
                    final s = r.dayStatuses[d];
                    return dataCell(s, dayW, bg: cellColor(s), fg: textColor(s));
                  }),
                  dataCell('${r.currentMonthPresent}', sumW,
                      fg: Colors.green.shade800, bold: true),
                  dataCell('${r.previousPresent}', sumW,
                      fg: Colors.blue.shade700, bold: true),
                  dataCell('${r.allTimePresent}', sumW,
                      fg: cs.onSurface, bold: true),
                ])),
            // Totals row
            Row(children: [
              ...days.map((d) =>
                  totalCell('${colTotals[d] ?? 0}', dayW)),
              // Cross-verification cell (bottom-right intersection)
              Container(
                width: sumW * 3,
                height: rowH,
                color: tallied
                    ? Colors.green.shade200
                    : Colors.red.shade200,
                alignment: Alignment.center,
                child: Text(
                  tallied
                      ? '✓ $sumOfRowTotals'
                      : '✗ R:$sumOfRowTotals C:$sumOfColTotals',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: tallied
                          ? Colors.green.shade900
                          : Colors.red.shade900),
                ),
              ),
            ]),
          ],
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildLeft(),
          Expanded(child: buildRight()),
        ],
      ),
    );
  }
}
