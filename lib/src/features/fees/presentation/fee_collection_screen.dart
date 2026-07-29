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
  
