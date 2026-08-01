// Fee Collection Screen
// Complete fee collection: collect fees, print receipts, view history, reprint duplicate

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  bool _isPartialPayment = false;

  List<ClassFeeConfig>? _classFeeConfigs;

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _concessionController = TextEditingController(text: '0');
  final _partialAmountController = TextEditingController();
  List<Student> _searchResults = [];
  bool _showSearchResults = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _concessionController.dispose();
    _partialAmountController.dispose();
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
                data: (rawStudents) {
                  final students = [...rawStudents]..sort((a, b) {
                      final na = int.tryParse(a.rollNo.trim());
                      final nb = int.tryParse(b.rollNo.trim());
                      if (na != null && nb != null) return na.compareTo(nb);
                      return a.rollNo.compareTo(b.rollNo);
                    });
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
      _manualConcession = 0;
      _selectedConcessionType = 'none';
      _concessionController.text = '0';
      _isPartialPayment = false;
      _partialAmountController.clear();
    });
    _loadClassFeeConfigs(student.classId);
  }

  Future<void> _loadClassFeeConfigs(String classId) async {
    final session = await ref.read(activeSessionProvider.future);
    if (session == null) return;
    try {
      final configs = await ref
          .read(feeRepoProvider)
          .getClassFeeConfigs(classId, session.label);
      if (mounted) setState(() => _classFeeConfigs = configs);
    } catch (_) {
      // Leave _classFeeConfigs null so _generateFeesForStudent retries the
      // fetch (and surfaces the real error) instead of silently caching [].
    }
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
                  _manualConcession = 0;
                  _selectedConcessionType = 'none';
                  _concessionController.text = '0';
                  _isPartialPayment = false;
                  _partialAmountController.clear();
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
    final monthlyFeesAsync = ref.watch(studentMonthlyFeesProvider((
      studentId: _selectedStudentId!,
      academicYear: academicYear,
    )));

    return _sectionCard(
      title: 'Fee Status',
      icon: Icons.account_balance_wallet,
      child: summaryAsync.when(
        data: (summary) => monthlyFeesAsync.when(
          data: (monthlyFees) =>
              _buildSummaryContent(summary, monthlyFees, academicYear),
          loading: () => const Center(
              child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          )),
          error: (e, _) => Text('Error loading months: $e',
              style: const TextStyle(color: Colors.red)),
        ),
        loading: () => const Center(
            child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        )),
        error: (e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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

  Widget _buildSummaryContent(StudentFeeSummary summary,
      List<StudentMonthlyFee> monthlyFees, String academicYear) {
    final pendingFees = monthlyFees.where((f) => f.isPending).toList();

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
        if (pendingFees.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.pending,
                color: Colors.orange, size: 16),
            const SizedBox(width: 6),
            Text(
              'Pending Months (${pendingFees.length}) — tap to select:',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: pendingFees.map((f) {
              final label = '${f.month} ${f.year}';
              final selected = _selectedMonths.contains(label);
              return FilterChip(
                label: Text(
                    '$label (₹${f.pendingAmount.toStringAsFixed(0)})',
                    style: const TextStyle(fontSize: 11)),
                selected: selected,
                selectedColor: Colors.orange[100],
                checkmarkColor: Colors.orange[800],
                onSelected: (sel) {
                  setState(() {
                    if (sel) {
                      _selectedMonths.add(label);
                      _totalAmount += f.pendingAmount;
                    } else {
                      _selectedMonths.remove(label);
                      _totalAmount -= f.pendingAmount;
                    }
                    if (_totalAmount < 0) _totalAmount = 0;
                  });
                },
              );
            }).toList(),
          ),
        ] else if (monthlyFees.isEmpty) ...[
          const SizedBox(height: 12),
          const Text(
              'Is student ke liye abhi tak koi fee generate nahi hui.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _generateFeesForStudent(academicYear),
            icon: const Icon(Icons.refresh),
            label: const Text('Generate Fees'),
          ),
        ],
      ],
    );
  }

  // ── Payment Section ─────────────────────────────────────────────────────────

  // Net amount payable after concession (never negative).
  double get _netPayable {
    final net = _totalAmount - _manualConcession;
    return net < 0 ? 0 : net;
  }

  // The amount that will actually be collected right now — full net-payable
  // amount, or whatever the teacher typed in for a partial payment.
  double get _amountToCollectNow {
    if (!_isPartialPayment) return _netPayable;
    return double.tryParse(_partialAmountController.text.trim()) ?? 0;
  }

  Widget _buildPaymentSection(String academicYear) {
    return _sectionCard(
      title: 'Collect Payment',
      icon: Icons.payments,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected Months: ${(_selectedMonths.toList()..sort()).join(", ")}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Text('₹${_totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 16),

          // ── Concession ────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _selectedConcessionType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Concession',
                    prefixIcon: Icon(Icons.percent),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: ConcessionType.values
                      .map((c) => DropdownMenuItem(
                            value: c.name,
                            child: Text(
                              c.percentage > 0
                                  ? '${c.label} (${c.percentage}%)'
                                  : c.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    final type = ConcessionType.values.firstWhere(
                        (c) => c.name == v,
                        orElse: () => ConcessionType.none);
                    setState(() {
                      _selectedConcessionType = type.name;
                      // Auto-suggest an amount from the percentage — the
                      // teacher can still overwrite it below.
                      final suggested = _totalAmount * type.percentage / 100;
                      _manualConcession = suggested;
                      _concessionController.text =
                          suggested > 0 ? suggested.toStringAsFixed(0) : '0';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _concessionController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount ₹',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    setState(() {
                      _manualConcession = double.tryParse(v.trim()) ?? 0;
                      if (_manualConcession > _totalAmount) {
                        _manualConcession = _totalAmount;
                      }
                      if (_manualConcession < 0) _manualConcession = 0;
                    });
                  },
                ),
              ),
            ],
          ),

          if (_manualConcession > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Concession (${ConcessionType.values.firstWhere((c) => c.name == _selectedConcessionType, orElse: () => ConcessionType.none).label})',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text('- ₹${_manualConcession.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],

          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Net Payable',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('₹${_netPayable.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF4F46E5))),
            ],
          ),
          const SizedBox(height: 16),

          // ── Full vs Partial Payment ──────────────────────────────────
          const Text('Payment Type',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                  value: false,
                  label: Text('Full Payment'),
                  icon: Icon(Icons.check_circle_outline)),
              ButtonSegment(
                  value: true,
                  label: Text('Partial Payment'),
                  icon: Icon(Icons.payments_outlined)),
            ],
            selected: {_isPartialPayment},
            onSelectionChanged: (sel) {
              setState(() {
                _isPartialPayment = sel.first;
                if (_isPartialPayment) {
                  _partialAmountController.text =
                      _netPayable > 0 ? _netPayable.toStringAsFixed(0) : '';
                } else {
                  _partialAmountController.clear();
                }
              });
            },
          ),

          if (_isPartialPayment) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _partialAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount Collecting Now ₹',
                prefixIcon: Icon(Icons.currency_rupee),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final balance = _netPayable - _amountToCollectNow;
              if (_amountToCollectNow <= 0 || _amountToCollectNow > _netPayable) {
                return Text(
                  _amountToCollectNow > _netPayable
                      ? 'Amount, Net Payable se zyada nahi ho sakta.'
                      : 'Amount 0 se zyada honi chahiye.',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                );
              }
              return Text(
                'Balance rahega: ₹${balance.toStringAsFixed(0)}',
                style: TextStyle(color: Colors.orange[800], fontSize: 12),
              );
            }),
          ],

          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _paymentMethod,
            decoration: const InputDecoration(
              labelText: 'Payment Method',
              prefixIcon: Icon(Icons.payment),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'upi', child: Text('UPI')),
              DropdownMenuItem(value: 'card', child: Text('Card')),
              DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
              DropdownMenuItem(
                  value: 'online', child: Text('Online Transfer')),
            ],
            onChanged: (v) => setState(() => _paymentMethod = v ?? 'cash'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isCollecting ||
                      _amountToCollectNow <= 0 ||
                      _amountToCollectNow > _netPayable
                  ? null
                  : () => _collectPayment(academicYear),
              icon: _isCollecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle),
              label: Text(_isCollecting
                  ? 'Processing...'
                  : 'Collect ₹${_amountToCollectNow.toStringAsFixed(0)}'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _collectPayment(String academicYear) async {
    final student = _selectedStudent;
    final collectedAmount = _amountToCollectNow;
    if (student == null ||
        _selectedMonths.isEmpty ||
        collectedAmount <= 0 ||
        collectedAmount > _netPayable) {
      return;
    }

    setState(() => _isCollecting = true);
    final paymentType = collectedAmount >= _netPayable ? 'full' : 'partial';

    try {
      final repo = ref.read(feeRepoProvider);

      // fee_payments.student_fee_id is NOT NULL on the live DB — the monthly
      // flow has no natural 1:1 student_fees row, so make sure one exists.
      final studentFeeId = await repo.ensureStudentFeeId(
        studentId: student.id,
        classId: student.classId,
        academicYear: academicYear,
        amount: collectedAmount,
      );

      final receiptNo = await repo.generateReceiptNo();
      final monthsList = _selectedMonths.toList()..sort();
      final classLabel =
          '${student.className} ${student.section}'.trim();

      final payment = FeePayment(
        id: '',
        studentFeeId: studentFeeId,
        studentId: student.id,
        amount: collectedAmount,
        paymentDate: DateTime.now(),
        paymentMethod: _paymentMethod,
        receiptNo: receiptNo,
        academicYear: academicYear,
        concession: _manualConcession,
        concessionType: _selectedConcessionType,
        lateFee: _lateFee,
        remarks: 'Months: ${monthsList.join(", ")}',
        monthsCovered: monthsList.join(", "),
        paymentType: paymentType,
        createdAt: DateTime.now(),
      )
        ..studentName = student.fullName
        ..className = classLabel
        ..fatherName = student.parentName
        ..studentRollNo = student.rollNo
        ..schoolName = 'NEMPS School';

      await repo.createFeePayment(payment);

      await repo.markMonthlyFeesAsPaid(
        studentId: student.id,
        academicYear: academicYear,
        monthLabels: monthsList,
        totalPaidAmount: collectedAmount,
        concessionAmount: _manualConcession,
      );

      ref.invalidate(studentFeeSummaryProvider((
        studentId: student.id,
        academicYear: academicYear,
      )));
      ref.invalidate(studentMonthlyFeesProvider((
        studentId: student.id,
        academicYear: academicYear,
      )));
      ref.invalidate(allPaymentsProvider(academicYear));
      ref.invalidate(studentPaymentsProvider((
        studentId: student.id,
        academicYear: academicYear,
      )));

      if (mounted) {
        setState(() {
          _selectedMonths.clear();
          _totalAmount = 0;
          _manualConcession = 0;
          _selectedConcessionType = 'none';
          _concessionController.text = '0';
          _isPartialPayment = false;
          _partialAmountController.clear();
          _lateFee = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(paymentType == 'partial'
                ? '₹${collectedAmount.toStringAsFixed(0)} partial payment collect ho gaya! Receipt: $receiptNo ✓'
                : '₹${collectedAmount.toStringAsFixed(0)} payment collect ho gaya! Receipt: $receiptNo ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCollecting = false);
    }
  }

  // ── Generate Fees for Student ────────────────────────────────────────────────

  Future<void> _generateFeesForStudent(String academicYear) async {
    final student = _selectedStudent;
    if (student == null) return;

    var configs = _classFeeConfigs;
    if (configs == null) {
      await _loadClassFeeConfigs(student.classId);
      configs = _classFeeConfigs;
    }
    if (configs == null) return;

    final enabled = configs.where((c) => c.isEnabled).toList();
    if (enabled.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Is class ke liye koi fee type enabled nahi hai. Pehle Class Config set karein.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final monthlyAmount =
        enabled.fold<double>(0, (sum, c) => sum + c.customAmount);
    final startYear = int.tryParse(academicYear.split('-').first) ??
        DateTime.now().year;

    try {
      var created = 0;
      for (final month in monthNames) {
        final year = (monthIndex[month] ?? 4) >= 4 ? startYear : startYear + 1;
        created += await ref.read(feeRepoProvider).generateMonthlyFeesForStudent(
              studentId: student.id,
              classId: student.classId,
              academicYear: academicYear,
              month: month,
              year: year,
              totalAmount: monthlyAmount,
            );
      }

      ref.invalidate(studentFeeSummaryProvider((
        studentId: student.id,
        academicYear: academicYear,
      )));
      ref.invalidate(studentMonthlyFeesProvider((
        studentId: student.id,
        academicYear: academicYear,
      )));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$created months ke fees generate ho gaye ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Reusable Section Card ────────────────────────────────────────────────────

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  // ── Reusable Summary Chip ────────────────────────────────────────────────────

  Widget _chip(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: color.withOpacity(0.9))),
          const SizedBox(height: 4),
          Text('₹${amount.toStringAsFixed(0)}',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: color)),
        ],
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
  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(activeSessionProvider);
    return activeSession.when(
      data: (session) {
        if (session == null) {
          return const Center(
              child: Text('Koi active session nahi hai.'));
        }
        return _buildList(session.label);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildList(String academicYear) {
    final paymentsAsync = ref.watch(allPaymentsProvider(academicYear));
    return paymentsAsync.when(
      data: (payments) {
        if (payments.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Abhi tak koi payment record nahi hai.',
                  style: TextStyle(color: Colors.grey)),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(allPaymentsProvider(academicYear)),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: payments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final p = payments[i];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1),
                    child: const Icon(Icons.receipt,
                        color: Color(0xFF4F46E5), size: 20),
                  ),
                  title: Text(
                    p.studentName?.isNotEmpty == true
                        ? p.studentName!
                        : 'Receipt: ${p.receiptNo}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${DateFormat('dd MMM yyyy').format(p.paymentDate)}'
                    '${p.monthsCovered != null && p.monthsCovered!.isNotEmpty ? ' • ${p.monthsCovered}' : ''}'
                    '\nReceipt: ${p.receiptNo} • ${p.paymentMethod.toUpperCase()}',
                  ),
                  isThreeLine: true,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${p.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.print, size: 18),
                            tooltip: 'Print receipt',
                            onPressed: () => _printReceipt(p),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                size: 18, color: Colors.red[400]),
                            tooltip: 'Receipt delete karein',
                            onPressed: () =>
                                _confirmDeletePayment(p, academicYear),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  // Deletes a payment AND reverses whatever it applied to the covered
  // months (paid_amount/status), so a mistakenly-recorded payment can be
  // fully undone — the fee goes back to due/partial, not stuck as "paid"
  // with no receipt to show for it.
  Future<void> _confirmDeletePayment(
      FeePayment p, String academicYear) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: Colors.red[400], size: 32),
        title: const Text('Receipt delete karein?'),
        content: Text(
          'Receipt #${p.receiptNo} (₹${p.amount.toStringAsFixed(0)}) delete '
          'hone ke baad ${p.monthsCovered != null && p.monthsCovered!.isNotEmpty ? "in months (${p.monthsCovered}) ki" : "is student ki"} '
          'fee wapas due/partial ho jayegi. Ye action undo nahi ho sakta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red[600]),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Haan, Delete Karein'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(feeRepoProvider).deletePayment(p.id);
      ref.invalidate(allPaymentsProvider(academicYear));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt delete ho gaya, fee status reset ho gaya ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete nahi ho saka: $e')),
        );
      }
    }
  }

  // Full, professional school-fee-receipt layout: letterhead, bordered
  // details block, an itemised fee table (not just one "amount" line),
  // amount-in-words, and signature lines — the format schools actually use,
  // instead of a bare list of label/value rows.
  Future<void> _printReceipt(FeePayment p) async {
    final netPaid = p.amount;
    final schoolName = (p.schoolName?.isNotEmpty ?? false)
        ? p.schoolName!
        : 'NEMPS School';

    // The PDF package's default core font (Helvetica) has no ₹ glyph, so it
    // was rendering as a box (□). Noto Sans includes the Rupee sign, so we
    // load it as the document's default font — fixes ₹ everywhere in this
    // receipt, not just one spot.
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final italicFont = await PdfGoogleFonts.notoSansItalic();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
        italic: italicFont,
      ),
    );
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Letterhead ──────────────────────────────────────────────
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(schoolName,
                      style: pw.TextStyle(
                          fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('FEE RECEIPT',
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                          letterSpacing: 2)),
                ],
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1.2, color: PdfColors.grey800),
            pw.SizedBox(height: 8),

            // ── Receipt No / Date strip ─────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _pdfLabelValue('Receipt No', '#${p.receiptNo}'),
                _pdfLabelValue(
                    'Date', DateFormat('dd MMM yyyy').format(p.paymentDate)),
              ],
            ),
            pw.SizedBox(height: 10),

            // ── Student details block ────────────────────────────────────
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.7),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (p.studentName != null && p.studentName!.isNotEmpty)
                    _pdfRow('Student Name', p.studentName!),
                  pw.Row(
                    children: [
                      if (p.studentRollNo != null &&
                          p.studentRollNo!.isNotEmpty)
                        pw.Expanded(child: _pdfRow('Roll No', p.studentRollNo!)),
                      if (p.className != null && p.className!.isNotEmpty)
                        pw.Expanded(child: _pdfRow('Class', p.className!)),
                    ],
                  ),
                  if (p.fatherName != null && p.fatherName!.isNotEmpty)
                    _pdfRow("Father's Name", p.fatherName!),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // ── Fee breakdown table ───────────────────────────────────────
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
              columnWidths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _pdfCell('Particulars', bold: true),
                    _pdfCell('Amount (₹)', bold: true, alignRight: true),
                  ],
                ),
                pw.TableRow(children: [
                  _pdfCell(p.monthsCovered != null && p.monthsCovered!.isNotEmpty
                      ? 'Fee for: ${p.monthsCovered}'
                      : 'Fee Payment'),
                  _pdfCell(_gross(p).toStringAsFixed(0), alignRight: true),
                ]),
                if (p.concession > 0)
                  pw.TableRow(children: [
                    _pdfCell('Less: Concession (${p.concessionType})'),
                    _pdfCell('- ${p.concession.toStringAsFixed(0)}',
                        alignRight: true),
                  ]),
                if (p.lateFee > 0)
                  pw.TableRow(children: [
                    _pdfCell('Add: Late Fee'),
                    _pdfCell('+ ${p.lateFee.toStringAsFixed(0)}',
                        alignRight: true),
                  ]),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _pdfCell('Net Amount Paid', bold: true),
                    _pdfCell('₹${netPaid.toStringAsFixed(0)}',
                        bold: true, alignRight: true),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text('Amount in words: ${_amountInWords(netPaid)} Rupees Only',
                style: pw.TextStyle(
                    fontSize: 9, fontStyle: pw.FontStyle.italic)),
            pw.SizedBox(height: 8),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _pdfLabelValue('Payment Mode', p.paymentMethod.toUpperCase()),
                _pdfLabelValue(
                    'Status', p.isPartial ? 'PARTIAL' : 'PAID IN FULL'),
              ],
            ),
            if (p.isPartial) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                'Note: Ye partial payment hai — baaki amount abhi pending hai.',
                style:
                    pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
              ),
            ],

            pw.Spacer(),
            pw.Divider(color: PdfColors.grey400),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                        width: 110,
                        child: pw.Divider(color: PdfColors.grey600)),
                    pw.Text("Parent's Signature",
                        style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                        width: 110,
                        child: pw.Divider(color: PdfColors.grey600)),
                    pw.Text('Authorised Signatory',
                        style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                'This is a computer-generated receipt.',
                style: pw.TextStyle(
                    fontSize: 7.5,
                    color: PdfColors.grey600,
                    fontStyle: pw.FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  // Gross amount before concession/late-fee adjustments, so the table's
  // "Particulars" line and the deduction/addition lines foot correctly to
  // Net Amount Paid.
  double _gross(FeePayment p) => p.amount + p.concession - p.lateFee;

  pw.Widget _pdfCell(String text, {bool bold = false, bool alignRight = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(
          text,
          textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
              fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : null),
        ),
      );

  pw.Widget _pdfLabelValue(String label, String value) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style:
                  const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
          pw.Text(value,
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ],
      );

  // For short values that always fit on one line next to the label.
  pw.Widget _pdfRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                  text: '$label: ',
                  style: const pw.TextStyle(
                      fontSize: 9.5, color: PdfColors.grey700)),
              pw.TextSpan(
                  text: value,
                  style: pw.TextStyle(
                      fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      );

  // Converts a whole-rupee amount to words using the Indian numbering
  // system (lakh/crore) so the receipt matches how school receipts
  // conventionally spell out the amount.
  String _amountInWords(double amount) {
    final n = amount.round();
    if (n == 0) return 'Zero';
    const ones = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight',
      'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen',
      'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'
    ];
    const tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy',
      'Eighty', 'Ninety'
    ];
    String twoDigits(int v) {
      if (v < 20) return ones[v];
      return '${tens[v ~/ 10]}${v % 10 != 0 ? ' ${ones[v % 10]}' : ''}';
    }

    String threeDigits(int v) {
      if (v >= 100) {
        final rest = v % 100;
        return '${ones[v ~/ 100]} Hundred${rest != 0 ? ' ${twoDigits(rest)}' : ''}';
      }
      return twoDigits(v);
    }

    var remaining = n;
    final crore = remaining ~/ 10000000;
    remaining %= 10000000;
    final lakh = remaining ~/ 100000;
    remaining %= 100000;
    final thousand = remaining ~/ 1000;
    remaining %= 1000;
    final hundred = remaining;

    final parts = <String>[];
    if (crore > 0) parts.add('${threeDigits(crore)} Crore');
    if (lakh > 0) parts.add('${threeDigits(lakh)} Lakh');
    if (thousand > 0) parts.add('${threeDigits(thousand)} Thousand');
    if (hundred > 0) parts.add(threeDigits(hundred));
    return parts.join(' ');
  }
}
