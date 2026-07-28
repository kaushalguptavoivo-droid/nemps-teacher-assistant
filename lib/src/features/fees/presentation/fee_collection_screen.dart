// Fee Collection Screen
// Complete fee collection: collect fees, print receipts, view history, reprint duplicate

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/providers.dart';
import '../data/fee_providers.dart';
import '../../examination/data/exam_providers.dart';
import '../models/fee_models.dart';
import '../../../core/models/models.dart';

class FeeCollectionScreen extends ConsumerStatefulWidget {
  const FeeCollectionScreen({super.key});

  @override
  ConsumerState<FeeCollectionScreen> createState() => _FeeCollectionScreenState();
}

class _FeeCollectionScreenState extends ConsumerState<FeeCollectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
        title: const Text('Fee Collection'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.payments), text: 'Collect Fees'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Receipt History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _CollectFeesTab(),
          _ReceiptHistoryTab(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// COLLECT FEES TAB
// ══════════════════════════════════════════════════════════════════════════════

class _CollectFeesTab extends ConsumerStatefulWidget {
  const _CollectFeesTab();

  @override
  ConsumerState<_CollectFeesTab> createState() => _CollectFeesTabState();
}

class _CollectFeesTabState extends ConsumerState<_CollectFeesTab> {
  String? _selectedClassId;
  String? _selectedStudentId;
  Student? _selectedStudent;
  final Set<String> _selectedMonths = {};
  double _totalAmount = 0;
  double _manualConcession = 0;
  String _paymentMethod = 'cash';
  String _selectedConcessionType = 'none';
  double _lateFee = 0;
  bool _isCollecting = false;

  List<ClassFeeConfig>? _classFeeConfigs;

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<Student> _searchResults = [];
  bool _showSearchResults = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(activeSessionProvider);
    return activeSession.when(
      data: (session) {
        if (session == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber, size: 64, color: Colors.orange),
                SizedBox(height: 16),
                Text('Koi active session nahi hai.\nAdmin se poochein.',
                    textAlign: TextAlign.center),
              ],
            ),
          );
        }
        return _buildContent(session.label);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildContent(String academicYear) {
    final classesAsync = ref.watch(allClassesProvider);
    final allStudentsAsync = ref.watch(allStudentsProvider);
    final studentsAsync = _selectedClassId != null
        ? ref.watch(studentsProvider(_selectedClassId!))
        : const AsyncValue<List<Student>>.data([]);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search Bar ──────────────────────────────────────────────────────
          _buildSearchBar(allStudentsAsync),

          if (_selectedStudent == null) ...[
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('YA class se select karein',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),

            // ── Select Class ──────────────────────────────────────────────
            _sectionCard(
              title: 'Class Select Karein',
              icon: Icons.class_,
              child: classesAsync.when(
                data: (classes) => DropdownButtonFormField<String>(
                  value: _selectedClassId,
                  decoration: const InputDecoration(
                    hintText: 'Class choose karein',
                    prefixIcon: Icon(Icons.class_),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('-- Class Choose --')),
                    ...classes.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text('${c.name} - ${c.section}'),
                        )),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _selectedClassId = v;
                      _selectedStudentId = null;
                      _selectedStudent = null;
                      _selectedMonths.clear();
                      _totalAmount = 0;
                    });
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Error loading classes'),
              ),
            ),
          ],

          // ── Student from class ───────────────────────────────────────────
          if (_selectedClassId != null && _selectedStudent == null) ...[
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Student Select Karein',
              icon: Icons.person,
              child: studentsAsync.when(
                data: (students) {
                  if (students.isEmpty) {
                    return const Text('Is class mein koi student nahi');
                  }
                  return DropdownButtonFormField<String>(
                    value: _selectedStudentId,
                    decoration: const InputDecoration(
                      hintText: 'Student choose karein',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: students
                        .map((s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(
                                  '${s.fullName} (Roll: ${s.rollNo})'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      final student =
                          students.firstWhere((s) => s.id == v);
                      _selectStudent(student);
                    },
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Error'),
              ),
            ),
          ],

          // ── Student Info ─────────────────────────────────────────────────
          if (_selectedStudent != null) ...[
            _buildStudentCard(_selectedStudent!),
            const SizedBox(height: 16),
            _buildFeeSummarySection(academicYear),
          ],

          // ── Payment Section ──────────────────────────────────────────────
          if (_selectedStudent != null && _selectedMonths.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildPaymentSection(academicYear),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Search Bar ──────────────────────────────────────────────────────────────

  Widget _buildSearchBar(AsyncValue<List<Student>> allStudentsAsync) {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: 'Student naam ya roll no search karein...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchResults = [];
                        _showSearchResults = false;
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (query) {
            if (query.trim().isEmpty) {
              setState(() {
                _searchResults = [];
                _showSearchResults = false;
              });
              return;
            }
            allStudentsAsync.whenData((students) {
              final q = query.toLowerCase();
              setState(() {
                _searchResults = students
                    .where((s) =>
                        s.fullName.toLowerCase().contains(q) ||
                        s.rollNo.toLowerCase().contains(q) ||
                        s.parentName.toLowerCase().contains(q))
                    .take(12)
                    .toList();
                _showSearchResults = true;
              });
            });
          },
        ),
        if (_showSearchResults && _searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = _searchResults[i];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        const Color(0xFF4F46E5).withOpacity(0.1),
                    child: Text(
                      s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : '?',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4F46E5)),
                    ),
                  ),
                  title: Text(s.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      'Roll: ${s.rollNo}  •  ${s.className ?? ""} ${s.section ?? ""}'),
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _showSearchResults = false;
                      _searchResults = [];
                    });
                    _selectStudent(s);
                  },
                );
              },
            ),
          ),
        if (_showSearchResults &&
            _searchController.text.isNotEmpty &&
            _searchResults.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: const Row(
              children: [
                Icon(Icons.search_off, color: Colors.grey),
                SizedBox(width: 8),
                Text('Koi student nahi mila',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
      ],
    );
  }

  void _selectStudent(Student student) {
    setState(() {
      _selectedStudent = student;
      _selectedStudentId = student.id;
      _selectedClassId = student.classId;
      _selectedMonths.clear();
      _totalAmount = 0;
      _classFeeConfigs = null;
    });
    _loadClassFeeConfigs(student.classId);
  }

  Future<void> _loadClassFeeConfigs(String classId) async {
    final session = await ref.read(activeSessionProvider.future);
    if (session == null) return;
    final configs = await ref
        .read(feeRepoProvider)
        .getClassFeeConfigs(classId, session.label);
    if (mounted) setState(() => _classFeeConfigs = configs);
  }

  // ── Student Card ────────────────────────────────────────────────────────────

  Widget _buildStudentCard(Student student) {
    return Card(
      color: const Color(0xFF4F46E5).withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFF4F46E5).withOpacity(0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFF4F46E5),
              child: Text(
                student.fullName.isNotEmpty
                    ? student.fullName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.fullName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    '${student.className ?? ""} ${student.section ?? ""}  •  Roll: ${student.rollNo}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                  if (student.parentName.isNotEmpty)
                    Text('Parent: ${student.parentName}',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'Change student',
              onPressed: () {
                setState(() {
                  _selectedStudent = null;
                  _selectedStudentId = null;
                  _selectedClassId = null;
                  _selectedMonths.clear();
                  _totalAmount = 0;
                  _classFeeConfigs = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Fee Summary Section ─────────────────────────────────────────────────────

  Widget _buildFeeSummarySection(String academicYear) {
    final summaryAsync = ref.watch(studentFeeSummaryProvider((
      studentId: _selectedStudentId!,
      academicYear: academicYear,
    )));

    return _sectionCard(
      title: 'Fee Status',
      icon: Icons.account_balance_wallet,
      child: summaryAsync.when(
        data: (summary) => _buildSummaryContent(summary, academicYear),
        loading: () => const Center(
            child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        )),
        error: (e, _) => Column(
          children: [
            Text('Error loading fees: $e',
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _generateFeesForStudent(academicYear),
              icon: const Icon(Icons.refresh),
              label: const Text('Generate Fees'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryContent(
      StudentFeeSummary summary, String academicYear) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary chips
        Row(
          children: [
            Expanded(
                child: _chip('Total Due', summary.totalDue, Colors.blue)),
            const SizedBox(width: 8),
            Expanded(
                child: _chip('Paid', summary.totalPaid, Colors.green)),
            const SizedBox(width: 8),
            Expanded(
                child: _chip(
                    'Pending', summary.totalPending, Colors.orange)),
          ],
        ),

        // Paid months
        if (summary.monthsPaid.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.check_circle,
                color: Colors.green, size: 16),
            const SizedBox(width: 6),
            Text(
                'Paid Months (${summary.monthsPaid.length})',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: summary.monthsPaid
                .map((m) => Chip(
                      label: Text(m,
                          style: const TextStyle(fontSize: 11)),
                      backgroundColor: Colors.green[50],
                      side: BorderSide(color: Colors.green[200]!),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
        ],

        // Pending months (selectable)
        if (summary.monthsPending.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.pending,
                color: Colors.orange, size: 16),
            const SizedBox(width: 6),
            Text(
              'Pending Months (${summary.monthsPending.length}) — tap to select:',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: summary.monthsPending
                .map((m) => FilterChip(
                      label: Text(m,
                          style: const TextStyle(fontSize: 11)),
                      selected: _selectedMonths.contains(m),
                      onSelected: (sel) {
                        setState(() {
                          if (sel) {
                            _selectedMonths.add(m);
                          } else {
                            _selectedMonths.remove(m);
                          }
                          _recalcTotal();
                        });
                      },
                      selectedColor:
                          const Color(0xFF4F46E5).withOpacity(0.15),
                      checkmarkColor: const Color(0xFF4F46E5),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (summary.monthsPending.length > 1)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedMonths
                          .addAll(summary.monthsPending);
                      _recalcTotal();
                    });
                  },
                  icon: const Icon(Icons.select_all, size: 16),
                  label: const Text('Sab Select'),
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                ),
              if (_selectedMonths.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedMonths.clear();
                      _totalAmount = 0;
                    });
                  },
                  icon: const Icon(Icons.deselect, size: 16),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.red),
                ),
            ],
          ),
          if (_selectedMonths.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month,
                      color: Color(0xFF4F46E5), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_selectedMonths.length} months selected: ${_selectedMonths.join(", ")}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
        ],

        // No fee records
        if (summary.monthsPending.isEmpty && summary.monthsPaid.isEmpty) ...[
          const SizedBox(height: 12),
          const Text(
              'Is student ke liye koi fee record nahi hai.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => _generateFeesForStudent(academicYear),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('12 Mahine ki Fees Generate Karein'),
          ),
        ],

        // All paid
        if (summary.monthsPending.isEmpty &&
            summary.monthsPaid.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('✅ Is student ki sab fees clear hain!',
                    style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _chip(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 10),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── Payment Section ─────────────────────────────────────────────────────────

  Widget _buildPaymentSection(String academicYear) {
    return _sectionCard(
      title: '💳 Payment — ${_selectedMonths.length} months',
      icon: Icons.payment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Months summary
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month,
                    color: Color(0xFF4F46E5), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedMonths.join(', '),
                    style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Payment Method
          DropdownButtonFormField<String>(
            value: _paymentMethod,
            decoration: const InputDecoration(
              labelText: 'Payment Method',
              prefixIcon: Icon(Icons.payment),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('💵 Cash')),
              DropdownMenuItem(value: 'upi', child: Text('📱 UPI')),
              DropdownMenuItem(value: 'card', child: Text('💳 Card')),
              DropdownMenuItem(
                  value: 'cheque', child: Text('📝 Cheque')),
              DropdownMenuItem(
                  value: 'online',
                  child: Text('🌐 Online Transfer')),
            ],
            onChanged: (v) =>
                setState(() => _paymentMethod = v ?? 'cash'),
          ),
          const SizedBox(height: 14),

          // Concession
          DropdownButtonFormField<String>(
            value: _selectedConcessionType,
            decoration: const InputDecoration(
              labelText: 'Concession (Optional)',
              prefixIcon: Icon(Icons.discount),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: ConcessionType.values
                .map((t) => DropdownMenuItem(
                      value: t.name,
                      child: Text(
                          '${t.label}${t.percentage > 0 ? " (${t.percentage}%)" : ""}'),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() {
                _selectedConcessionType = v ?? 'none';
                if (v != 'other') _manualConcession = 0;
              });
            },
          ),

          if (_selectedConcessionType == 'other') ...[
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Concession Amount (₹)',
                prefixIcon: Icon(Icons.currency_rupee),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => setState(
                  () => _manualConcession = double.tryParse(v) ?? 0),
            ),
          ],
          const SizedBox(height: 14),

          // Late Fee
          TextField(
            decoration: const InputDecoration(
              labelText: 'Late Fee (₹) — Optional',
              prefixIcon: Icon(Icons.timer_off),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) =>
                setState(() => _lateFee = double.tryParse(v) ?? 0),
          ),
          const SizedBox(height: 20),

          // Amount Breakdown
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              children: [
                _amtRow(
                    '${_selectedMonths.length} months × ₹${_monthlyAmt().toStringAsFixed(0)}',
                    _totalAmount),
                if (_calcConcession() > 0)
                  _amtRow(
                      'Concession (${_concessionLabel()})',
                      _calcConcession(),
                      isDiscount: true),
                if (_lateFee > 0)
                  _amtRow('Late Fee', _lateFee, isLateFee: true),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Final Amount:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    Text(
                      '₹${_finalAmt().toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                          color: Colors.green),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // COLLECT BUTTON
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  _isCollecting ? null : () => _collectFees(academicYear),
              icon: _isCollecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.receipt_long),
              label: Text(
                _isCollecting
                    ? 'Processing...'
                    : 'Collect ₹${_finalAmt().toStringAsFixed(0)} & Print Receipt',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green[700],
                minimumSize: const Size(double.infinity, 54),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amtRow(String label, double amount,
      {bool isDiscount = false, bool isLateFee = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(label,
                  style:
                      TextStyle(color: Colors.grey[700], fontSize: 13))),
          Text(
            '${isDiscount ? "- " : ""}₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDiscount
                    ? Colors.green[700]
                    : (isLateFee ? Colors.orange[700] : null)),
          ),
        ],
      ),
    );
  }

  // ── Calculations ────────────────────────────────────────────────────────────

  double _monthlyAmt() {
    final configs =
        (_classFeeConfigs ?? []).where((c) => c.isEnabled).toList();
    return configs.fold(0.0, (s, c) => s + c.customAmount);
  }

  void _recalcTotal() {
    _totalAmount = _selectedMonths.length * _monthlyAmt();
  }

  double _calcConcession() {
    if (_selectedConcessionType == 'other') return _manualConcession;
    if (_selectedConcessionType == 'none') return 0;
    final type = ConcessionType.values.firstWhere(
      (t) => t.name == _selectedConcessionType,
      orElse: () => ConcessionType.none,
    );
    return (_totalAmount * type.percentage) / 100;
  }

  String _concessionLabel() {
    if (_selectedConcessionType == 'other') return 'Custom';
    final type = ConcessionType.values.firstWhere(
      (t) => t.name == _selectedConcessionType,
      orElse: () => ConcessionType.none,
    );
    return '${type.label} ${type.percentage}%';
  }

  double _finalAmt() =>
      (_totalAmount - _calcConcession() + _lateFee).clamp(0, double.infinity);

  // ── Generate Monthly Fees ────────────────────────────────────────────────────

  Future<void> _generateFeesForStudent(String academicYear) async {
    if (_selectedStudent == null || _selectedClassId == null) return;

    List<ClassFeeConfig> configs = _classFeeConfigs ?? [];
    if (configs.isEmpty) {
      configs = await ref
          .read(feeRepoProvider)
          .getClassFeeConfigs(_selectedClassId!, academicYear);
      if (mounted) setState(() => _classFeeConfigs = configs);
    }

    final enabledConfigs = configs.where((c) => c.isEnabled).toList();
    if (enabledConfigs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Koi fee type enable nahi.\nAdmin → Fees Mgmt → Class Config mein enable karein.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    final double totalMonthly =
        enabledConfigs.fold(0.0, (s, c) => s + c.customAmount);

    final parts = academicYear.split('-');
    final startYear = int.tryParse(parts[0]) ?? DateTime.now().year;
    final endYear = parts.length > 1
        ? (int.tryParse(parts[1].length == 2
                ? '${startYear ~/ 100}${parts[1]}'
                : parts[1]) ??
            startYear + 1)
        : startYear + 1;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fees generate ho rahe hain...')));
    }

    int generated = 0;
    for (final month in monthNames) {
      final monthIdx = monthIndex[month]!;
      final year = monthIdx >= 4 ? startYear : endYear;
      generated += await ref
          .read(feeRepoProvider)
          .generateMonthlyFeesForStudent(
            studentId: _selectedStudent!.id,
            classId: _selectedClassId!,
            academicYear: academicYear,
            month: month,
            year: year,
            totalAmount: totalMonthly,
          );
    }

    ref.invalidate(studentFeeSummaryProvider((
      studentId: _selectedStudentId!,
      academicYear: academicYear,
    )));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(generated > 0
              ? '$generated mahine ki fees generate ho gayi! ₹${totalMonthly.toStringAsFixed(0)}/month ✓'
              : 'Fees pehle se exist karti hain.'),
          backgroundColor: generated > 0 ? Colors.green : Colors.blue,
        ),
      );
    }
  }

  // ── Collect Fees ─────────────────────────────────────────────────────────────

  Future<void> _collectFees(String academicYear) async {
    if (_selectedMonths.isEmpty || _selectedStudent == null) return;
    if (_isCollecting) return;

    setState(() => _isCollecting = true);

    final concessionAmt = _calcConcession();
    final finalAmt = _finalAmt();
    final student = _selectedStudent!;
    final monthsCovered = _selectedMonths.join(', ');

    try {
      final receiptNo =
          await ref.read(feeRepoProvider).generateReceiptNo();

      // 1. Build payment object with full info for receipt
      final payment = FeePayment(
        id: '',
        studentId: student.id,
        amount: finalAmt,
        paymentDate: DateTime.now(),
        paymentMethod: _paymentMethod,
        receiptNo: receiptNo,
        academicYear: academicYear,
        concession: concessionAmt,
        concessionType: _selectedConcessionType,
        lateFee: _lateFee,
        remarks: 'Months: $monthsCovered',
        monthsCovered: monthsCovered,
        createdAt: DateTime.now(),
      )
        ..studentName = student.fullName
        ..studentRollNo = student.rollNo
        ..className =
            '${student.className ?? ""} ${student.section ?? ""}'.trim();

      // 2. Save to DB
      await ref.read(feeRepoProvider).createFeePayment(payment);

      // 3. Mark each month as paid in student_monthly_fees
      await ref.read(feeRepoProvider).markMonthlyFeesAsPaid(
            studentId: student.id,
            academicYear: academicYear,
            monthLabels: _selectedMonths.toList(),
            totalPaidAmount: finalAmt,
            concessionAmount: concessionAmt,
          );

      // 4. Refresh providers
      ref.invalidate(studentPaymentsProvider(
          (studentId: student.id, academicYear: academicYear)));
      ref.invalidate(studentFeeSummaryProvider(
          (studentId: student.id, academicYear: academicYear)));
      ref.invalidate(studentMonthlyFeesProvider(
          (studentId: student.id, academicYear: academicYear)));
      ref.invalidate(allPaymentsProvider(academicYear));

      // 5. Clear state
      setState(() {
        _selectedMonths.clear();
        _totalAmount = 0;
        _manualConcession = 0;
        _selectedConcessionType = 'none';
        _lateFee = 0;
        _isCollecting = false;
      });

      // 6. Show success dialog with print option
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text('Payment Successful!',
                    style: TextStyle(fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _receiptInfoRow('Student', student.fullName),
                _receiptInfoRow('Receipt No', receiptNo),
                _receiptInfoRow('Amount Paid',
                    '₹${finalAmt.toStringAsFixed(0)}'),
                _receiptInfoRow('Months', monthsCovered),
                _receiptInfoRow(
                    'Payment Mode', _paymentMethod.toUpperCase()),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close',
                    style: TextStyle(color: Colors.grey)),
              ),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _printReceipt(payment, student);
                },
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Print Receipt'),
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isCollecting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error collecting fees: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Print Receipt ─────────────────────────────────────────────────────────

  Future<void> _printReceipt(FeePayment payment, Student student) async {
    await _generateAndPrint(payment, student, isDuplicate: false);
  }

  static Future<void> _generateAndPrint(
    FeePayment payment,
    Student? student, {
    bool isDuplicate = false,
  }) async {
    final pdf = pw.Document();
    final df = DateFormat('dd/MM/yyyy');
    final studentName =
        payment.studentName ?? student?.fullName ?? 'N/A';
    final rollNo =
        payment.studentRollNo ?? student?.rollNo ?? 'N/A';
    final className = payment.className ??
        '${student?.className ?? ""} ${student?.section ?? ""}'.trim();
    final monthsText = payment.monthsCovered ??
        (payment.remarks?.startsWith('Months:') == true
            ? payment.remarks!.replaceFirst('Months: ', '')
            : payment.remarks ?? '');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: pw.EdgeInsets.all(22),
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('NEMPS SCHOOL',
                      style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 3),
                  pw.Text(
                      isDuplicate
                          ? 'Fee Receipt  ** DUPLICATE COPY **'
                          : 'Fee Receipt',
                      style: pw.TextStyle(
                          fontSize: 12,
                          color: isDuplicate
                              ? PdfColors.red700
                              : PdfColors.grey700)),
                ],
              ),
            ),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 6),

            // Receipt meta
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.RichText(
                  text: pw.TextSpan(children: [
                    pw.TextSpan(
                        text: 'Receipt No: ',
                        style: pw.TextStyle(fontSize: 11)),
                    pw.TextSpan(
                        text: payment.receiptNo,
                        style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold)),
                  ]),
                ),
                pw.Text(
                    'Date: ${df.format(payment.paymentDate)}',
                    style: pw.TextStyle(fontSize: 11)),
              ],
            ),
            pw.SizedBox(height: 12),

            // Student info box
            pw.Container(
              padding: pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius:
                    pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Name: $studentName',
                          style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text('Roll No: $rollNo',
                          style:
                              pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Class: $className',
                          style:
                              pw.TextStyle(fontSize: 11)),
                      pw.Text(
                          'Academic Year: ${payment.academicYear}',
                          style:
                              pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Payment details box
            pw.Container(
              padding: pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius:
                    pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Payment Details',
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  if (monthsText.isNotEmpty) ...[
                    pw.Row(
                      crossAxisAlignment:
                          pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Fee For: ',
                            style:
                                pw.TextStyle(fontSize: 11)),
                        pw.Expanded(
                          child: pw.Text(monthsText,
                              style: pw.TextStyle(
                                  fontSize: 11,
                                  fontWeight:
                                      pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                  ],
                  _pRow('Gross Amount',
                      '₹${(payment.amount + payment.concession - payment.lateFee).toStringAsFixed(0)}'),
                  if (payment.concession > 0)
                    _pRow(
                        'Concession (${payment.concessionType})',
                        '- ₹${payment.concession.toStringAsFixed(0)}',
                        color: PdfColors.green800),
                  if (payment.lateFee > 0)
                    _pRow('Late Fee',
                        '+ ₹${payment.lateFee.toStringAsFixed(0)}',
                        color: PdfColors.orange),
                  pw.Divider(height: 10),
                  pw.Row(
                    mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Paid:',
                          style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                          '₹${payment.amount.toStringAsFixed(0)}',
                          style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green800)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Payment Mode:',
                          style:
                              pw.TextStyle(fontSize: 11)),
                      pw.Text(
                          payment.paymentMethod.toUpperCase(),
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),

            pw.Spacer(),
            pw.Divider(),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment:
                  pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Parent Signature',
                        style:
                            pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(height: 22),
                    pw.Container(
                        width: 90,
                        decoration: pw.BoxDecoration(
                            border: pw.Border(
                                bottom: pw.BorderSide()))),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Authorised Signatory',
                        style:
                            pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(height: 22),
                    pw.Container(
                        width: 90,
                        decoration: pw.BoxDecoration(
                            border: pw.Border(
                                bottom: pw.BorderSide()))),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(
                  'This is a computer generated receipt',
                  style: pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey)),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      name: isDuplicate
          ? 'Receipt_${payment.receiptNo}_dup.pdf'
          : 'Receipt_${payment.receiptNo}.pdf',
    );
  }

  static pw.Widget _pRow(String label, String value,
      {PdfColor? color}) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(fontSize: 11)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  // ── Receipt Info Row helper (used in success dialog) ───────────────────────

  static Widget _receiptInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ── Card helper ─────────────────────────────────────────────────────────────

  Widget _sectionCard(
      {required String title,
      required IconData icon,
      required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF4F46E5), size: 20),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15))),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// RECEIPT HISTORY TAB
// ══════════════════════════════════════════════════════════════════════════════

class _ReceiptHistoryTab extends ConsumerStatefulWidget {
  const _ReceiptHistoryTab();

  @override
  ConsumerState<_ReceiptHistoryTab> createState() =>
      _ReceiptHistoryTabState();
}

class _ReceiptHistoryTabState extends ConsumerState<_ReceiptHistoryTab> {
  String? _selectedStudentId;
  Student? _selectedStudent;
  final _searchController = TextEditingController();
  List<Student> _searchResults = [];
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(activeSessionProvider);
    return activeSession.when(
      data: (session) {
        if (session == null) return const Center(child: Text('No session'));
        return _buildContent(session.label);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildContent(String academicYear) {
    final allStudentsAsync = ref.watch(allStudentsProvider);
    final df = DateFormat('dd MMM yyyy');

    return Column(
      children: [
        // Search / filter bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Student naam search karein (ya sab dekhen)...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _selectedStudent = null;
                              _selectedStudentId = null;
                              _searchResults = [];
                              _showSearch = false;
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  isDense: true,
                ),
                onChanged: (q) {
                  allStudentsAsync.whenData((students) {
                    final ql = q.toLowerCase();
                    setState(() {
                      _searchResults = students
                          .where((s) =>
                              s.fullName.toLowerCase().contains(ql) ||
                              s.rollNo.toLowerCase().contains(ql))
                          .take(10)
                          .toList();
                      _showSearch = q.isNotEmpty;
                    });
                  });
                },
              ),
              if (_showSearch && _searchResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8)
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final s = _searchResults[i];
                      return ListTile(
                        dense: true,
                        title: Text(s.fullName),
                        subtitle: Text('Roll: ${s.rollNo}'),
                        onTap: () {
                          _searchController.text = s.fullName;
                          setState(() {
                            _selectedStudent = s;
                            _selectedStudentId = s.id;
                            _showSearch = false;
                          });
                        },
                      );
                    },
                  ),
                ),
              if (_selectedStudent != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Chip(
                        label: Text(
                            '${_selectedStudent!.fullName} (Roll: ${_selectedStudent!.rollNo})'),
                        deleteIcon:
                            const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          _searchController.clear();
                          setState(() {
                            _selectedStudent = null;
                            _selectedStudentId = null;
                          });
                        },
                        backgroundColor:
                            const Color(0xFF4F46E5).withOpacity(0.1),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Payment list
        Expanded(
          child: _selectedStudentId != null
              ? _studentPayments(academicYear, _selectedStudentId!, df)
              : _allPayments(academicYear, df),
        ),
      ],
    );
  }

  Widget _allPayments(String academicYear, DateFormat df) {
    final paymentsAsync = ref.watch(allPaymentsProvider(academicYear));
    return paymentsAsync.when(
      data: (payments) {
        if (payments.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Koi payment record nahi hai abhi tak.',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return _paymentList(payments, df);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _studentPayments(
      String academicYear, String studentId, DateFormat df) {
    final paymentsAsync = ref.watch(studentPaymentsProvider(
        (studentId: studentId, academicYear: academicYear)));
    return paymentsAsync.when(
      data: (payments) {
        if (payments.isEmpty) {
          return const Center(
            child: Text(
                'Is student ki koi payment history nahi hai.',
                style: TextStyle(color: Colors.grey)),
          );
        }
        return _paymentList(payments, df);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _paymentList(List<FeePayment> payments, DateFormat df) {
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: payments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) => _paymentCard(payments[i], df),
    );
  }

  Widget _paymentCard(FeePayment payment, DateFormat df) {
    final monthsText = payment.monthsCovered ??
        (payment.remarks?.startsWith('Months:') == true
            ? payment.remarks!.replaceFirst('Months: ', '')
            : '');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Receipt icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt, color: Colors.green, size: 26),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          payment.studentName ?? 'Student',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#${payment.receiptNo}',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (monthsText.isNotEmpty)
                    Text('For: $monthsText',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[700])),
                  Text(
                      '${df.format(payment.paymentDate)}  •  ${payment.paymentMethod.toUpperCase()}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Amount + reprint
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${payment.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _reprint(payment),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.print,
                            size: 13, color: Color(0xFF4F46E5)),
                        SizedBox(width: 3),
                        Text('Reprint',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF4F46E5),
                                fontWeight: FontWeight.w600)),
                      ],
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

  Future<void> _reprint(FeePayment payment) async {
    // Try to fetch student for extra info
    final allStudents = await ref.read(allStudentsProvider.future);
    Student? student;
    try {
      student = allStudents.firstWhere((s) => s.id == payment.studentId);
    } catch (_) {}

    await _CollectFeesTabState._generateAndPrint(payment, student,
        isDuplicate: true);
  }
}
