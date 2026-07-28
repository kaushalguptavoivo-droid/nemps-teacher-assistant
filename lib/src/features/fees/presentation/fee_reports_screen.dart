// Fee Reports Screen
// Due List, Daily Collection, Monthly Reports, Excel Export

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/providers.dart';
import '../data/fee_providers.dart';
import '../../examination/data/exam_providers.dart';
import '../models/fee_models.dart';

class FeeReportsScreen extends ConsumerStatefulWidget {
  const FeeReportsScreen({super.key});

  @override
  ConsumerState<FeeReportsScreen> createState() => _FeeReportsScreenState();
}

class _FeeReportsScreenState extends ConsumerState<FeeReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  String? _selectedClassId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: const Text('Fee Reports'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.warning_amber), text: 'Due List'),
            Tab(icon: Icon(Icons.today), text: 'Collection'),
            Tab(icon: Icon(Icons.download), text: 'Export'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DueListTab(
            selectedClassId: _selectedClassId,
            onClassChanged: (id) => setState(() => _selectedClassId = id),
          ),
          _DailyCollectionTab(
            selectedDate: _selectedDate,
            onDateChanged: (date) => setState(() => _selectedDate = date),
          ),
          _ExportTab(
            selectedClassId: _selectedClassId,
            onClassChanged: (id) => setState(() => _selectedClassId = id),
          ),
        ],
      ),
    );
  }
}

// ── Due List Tab ──────────────────────────────────────────────────────────────

class _DueListTab extends ConsumerWidget {
  final String? selectedClassId;
  final Function(String?) onClassChanged;

  const _DueListTab({
    required this.selectedClassId,
    required this.onClassChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(activeSessionProvider);

    return activeSession.when(
      data: (session) {
        if (session == null) return const Center(child: Text('No session'));

        return Column(
          children: [
            // Filters
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ref.watch(allClassesProvider).when(
                      data: (classes) => DropdownButtonFormField<String>(
                        value: selectedClassId,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Class',
                          prefixIcon: Icon(Icons.class_),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Classes')),
                          ...classes.map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.name} - ${c.section}'),
                          )),
                        ],
                        onChanged: (v) => onClassChanged(v),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Error'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => ref.invalidate(dueStudentsProvider(session.label)),
                  ),
                ],
              ),
            ),

            // Due Students List
            Expanded(
              child: _DueStudentsList(
                academicYear: session.label,
                selectedClassId: selectedClassId,
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _DueStudentsList extends ConsumerWidget {
  final String academicYear;
  final String? selectedClassId;

  const _DueStudentsList({
    required this.academicYear,
    this.selectedClassId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueAsync = ref.watch(dueStudentsProvider(academicYear));

    return dueAsync.when(
      data: (dueStudents) {
        // Filter by class name client-side if a class is selected
        List<DueStudent> filtered = dueStudents;
        if (selectedClassId != null) {
          final classRoom = ref.read(allClassesProvider).valueOrNull
              ?.firstWhere((c) => c.id == selectedClassId, orElse: () => ref.read(allClassesProvider).valueOrNull!.first);
          if (classRoom != null) {
            filtered = dueStudents.where((s) => s.className == classRoom.name).toList();
          }
        }

        if (filtered.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text('🎉 Sab students ne fees pay kar di!'),
                Text('Koi pending fees nahi hai.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Summary
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('${filtered.length}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red[700])),
                      const Text('Due Students'),
                    ],
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  Column(
                    children: [
                      Text(
                        '₹${filtered.fold<double>(0, (sum, s) => sum + s.totalPending).toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red[700]),
                      ),
                      const Text('Total Due'),
                    ],
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final student = filtered[index];
                  return _DueStudentCard(student: student);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _DueStudentCard extends StatelessWidget {
  final DueStudent student;

  const _DueStudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.red[50],
              child: Text(
                student.studentName.isNotEmpty
                    ? student.studentName.substring(0, 1).toUpperCase()
                    : '?',
                style: TextStyle(color: Colors.red[700]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.studentName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${student.className} - ${student.section} | Roll: ${student.rollNo}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: student.monthsPending.map((m) => Chip(
                      label: Text(m, style: const TextStyle(fontSize: 10)),
                      backgroundColor: Colors.red[50],
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${student.totalPending.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.red[700],
                  ),
                ),
                const Text('Pending', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Daily Collection Tab ───────────────────────────────────────────────────────

class _DailyCollectionTab extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateChanged;

  const _DailyCollectionTab({
    required this.selectedDate,
    required this.onDateChanged,
  });

  @override
  ConsumerState<_DailyCollectionTab> createState() => _DailyCollectionTabState();
}

class _DailyCollectionTabState extends ConsumerState<_DailyCollectionTab> {
  Future<void> _selectDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: widget.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      widget.onDateChanged(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(activeSessionProvider);

    return activeSession.when(
      data: (session) {
        if (session == null) return const Center(child: Text('No session'));

        return Column(
          children: [
            // Date Selector
            Container(
              padding: const EdgeInsets.all(16),
              child: InkWell(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('EEEE, dd MMM yyyy').format(widget.selectedDate),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ),

            // Collection Summary — uses DateTime directly from dailyCollectionProvider
            Expanded(
              child: _DailyCollectionList(
                date: widget.selectedDate,
                academicYear: session.label,
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _DailyCollectionList extends ConsumerWidget {
  final DateTime date;
  final String academicYear;

  const _DailyCollectionList({
    required this.date,
    required this.academicYear,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // dailyCollectionProvider takes DateTime (defined in fee_providers.dart)
    final collectionAsync = ref.watch(dailyCollectionProvider(date));

    return collectionAsync.when(
      data: (collection) {
        if (collection.payments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.money_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text('Aaj koi collection nahi'),
                Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Summary Cards
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[700]!, Colors.green[500]!],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '₹${collection.totalCollected.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const Text('Total Collected', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                      Container(width: 1, height: 50, color: Colors.white30),
                      Column(
                        children: [
                          Text(
                            '${collection.studentCount}',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const Text('Students', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ],
                  ),
                  if (collection.totalConcession > 0 || collection.totalLateFee > 0) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white30),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        if (collection.totalConcession > 0)
                          Column(
                            children: [
                              Text(
                                '₹${collection.totalConcession.toStringAsFixed(0)}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const Text('Concession', style: TextStyle(fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                        if (collection.totalLateFee > 0)
                          Column(
                            children: [
                              Text(
                                '₹${collection.totalLateFee.toStringAsFixed(0)}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const Text('Late Fee', style: TextStyle(fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Payment List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: collection.payments.length,
                itemBuilder: (context, index) {
                  final payment = collection.payments[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green[50],
                        child: Icon(Icons.check, color: Colors.green[700]),
                      ),
                      title: Text(payment.studentName ?? 'Student'),
                      subtitle: Text(
                        '${DateFormat('hh:mm a').format(payment.paymentDate)} • ${payment.paymentMethod.toUpperCase()}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${payment.amount.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '#${payment.receiptNo}',
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ── Export Tab ────────────────────────────────────────────────────────────────

class _ExportTab extends ConsumerStatefulWidget {
  final String? selectedClassId;
  final Function(String?) onClassChanged;

  const _ExportTab({
    required this.selectedClassId,
    required this.onClassChanged,
  });

  @override
  ConsumerState<_ExportTab> createState() => _ExportTabState();
}

class _ExportTabState extends ConsumerState<_ExportTab> {
  String _exportType = 'due';
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(activeSessionProvider);

    return activeSession.when(
      data: (session) {
        if (session == null) return const Center(child: Text('No session'));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Export Type Selection
              const Text(
                'Select Report Type',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ExportTypeChip(
                    label: '📋 Due List',
                    value: 'due',
                    selected: _exportType == 'due',
                    onSelected: () => setState(() => _exportType = 'due'),
                  ),
                  _ExportTypeChip(
                    label: '💰 Collection Summary',
                    value: 'collection',
                    selected: _exportType == 'collection',
                    onSelected: () => setState(() => _exportType = 'collection'),
                  ),
                  _ExportTypeChip(
                    label: '👥 Student Ledger',
                    value: 'ledger',
                    selected: _exportType == 'ledger',
                    onSelected: () => setState(() => _exportType = 'ledger'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Class Filter
              const Text(
                'Filter by Class (Optional)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ref.watch(allClassesProvider).when(
                data: (classes) => DropdownButtonFormField<String>(
                  value: widget.selectedClassId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.class_),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Classes')),
                    ...classes.map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text('${c.name} - ${c.section}'),
                    )),
                  ],
                  onChanged: (v) => widget.onClassChanged(v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Error'),
              ),

              const SizedBox(height: 32),

              // Export Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isExporting
                      ? null
                      : () => _exportReport(session.label),
                  icon: _isExporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.download),
                  label: Text(_isExporting ? 'Exporting...' : 'Export to CSV'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Info Card
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Export Info',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('• CSV file save aur share hoga'),
                      const Text('• Excel ya Google Sheets mein open karein'),
                      const Text('• Current academic year ka report'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Future<void> _exportReport(String academicYear) async {
    setState(() => _isExporting = true);

    try {
      List<List<dynamic>> csvData = [];

      if (_exportType == 'due') {
        final dueStudents = await ref.read(dueStudentsProvider(academicYear).future);

        csvData = [
          ['S.No', 'Student Name', 'Roll No', 'Class', 'Section', 'Pending Months', 'Total Due (₹)'],
        ];

        int i = 1;
        for (final student in dueStudents) {
          csvData.add([
            i++,
            student.studentName,
            student.rollNo,
            student.className,
            student.section,
            student.monthsPending.join(', '),
            student.totalPending,
          ]);
        }
      } else if (_exportType == 'collection') {
        final startOfMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
        final payments = await ref.read(feeRepoProvider).getPaymentsInRange(
          startOfMonth,
          DateTime.now(),
        );

        csvData = [
          ['Date', 'Receipt No', 'Student ID', 'Amount (₹)', 'Concession (₹)', 'Late Fee (₹)', 'Method', 'Remarks'],
        ];

        for (final payment in payments) {
          csvData.add([
            DateFormat('yyyy-MM-dd').format(payment.paymentDate),
            payment.receiptNo,
            payment.studentId,
            payment.amount,
            payment.concession,
            payment.lateFee,
            payment.paymentMethod,
            payment.remarks ?? '',
          ]);
        }
      } else {
        // Student Ledger
        final students = await ref.read(feeRepoProvider).getAllStudents();

        csvData = [
          ['Roll No', 'Student Name', 'Class', 'Section', 'Total Due (₹)', 'Total Paid (₹)', 'Balance (₹)'],
        ];

        for (final student in students) {
          final studentId = student['id'] as String;
          final summary = await ref.read(feeRepoProvider).getStudentFeeSummary(studentId, academicYear);
          csvData.add([
            student['roll_no'] ?? '',
            student['full_name'] ?? '',
            student['class_name'] ?? '',
            student['section'] ?? '',
            summary.totalDue,
            summary.totalPaid,
            summary.totalPending,
          ]);
        }
      }

      // Convert to CSV
      final csv = const ListToCsvConverter().convert(csvData);

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'fee_${_exportType}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csv);

      // Share
      await Share.shareXFiles([XFile(file.path)], text: 'Fee $_exportType Report');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Report exported: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }
}

class _ExportTypeChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onSelected;

  const _ExportTypeChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: const Color(0xFF4F46E5).withOpacity(0.2),
      checkmarkColor: const Color(0xFF4F46E5),
    );
  }
}
