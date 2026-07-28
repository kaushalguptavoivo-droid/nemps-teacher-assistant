// Fee Collection Screen
// Month-wise fee collection with receipt printing

import "package:flutter/material.dart";
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

class _FeeCollectionScreenState extends ConsumerState<FeeCollectionScreen> {
  String? _selectedClassId;
  String? _selectedStudentId;
  Student? _selectedStudent;
  final Set<String> _selectedMonths = {};
  double _totalAmount = 0;
  double _concession = 0;
  String _paymentMethod = 'cash';
  String _selectedConcessionType = 'none';
  double _lateFee = 0;

  // Class fee configs cache
  List<ClassFeeConfig>? _classFeeConfigs;

  // Search
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(activeSessionProvider);

    return activeSession.when(
      data: (session) {
        if (session == null) {
          return const Center(child: Text('No active session'));
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

    return Column(
      children: [
        // ── Search Bar ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Student ka naam / roll no search karein...',
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) => _onSearch(value, allStudentsAsync),
                onTap: () {
                  if (_searchController.text.isNotEmpty) {
                    setState(() => _showSearchResults = true);
                  }
                },
              ),

              if (_showSearchResults && _searchResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  constraints: const BoxConstraints(maxHeight: 250),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final student = _searchResults[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1),
                          child: Text(
                            student.fullName.isNotEmpty
                                ? student.fullName.substring(0, 1).toUpperCase()
                                : '?',
                            style: const TextStyle(color: Color(0xFF4F46E5)),
                          ),
                        ),
                        title: Text(student.fullName),
                        subtitle: Text('Class: ${student.className} - ${student.section} | Roll: ${student.rollNo}'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _selectStudentFromSearch(student),
                      );
                    },
                  ),
                ),

              if (_showSearchResults && _searchController.text.isNotEmpty && _searchResults.isEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search_off, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Koi student nahi mila', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // ── Main Scrollable Content ─────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // OR divider shown only when no student selected
                if (_selectedStudent == null) ...[
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('YA', style: TextStyle(color: Colors.grey)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Class select karke student choose karein:',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                ],

                // Step 1: Select Class
                _buildSectionCard(
                  title: 'Class Select Karein',
                  icon: Icons.class_,
                  child: classesAsync.when(
                    data: (classes) => DropdownButtonFormField<String>(
                      value: _selectedClassId,
                      decoration: const InputDecoration(
                        hintText: 'Class choose karein',
                        prefixIcon: Icon(Icons.class_),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Classes')),
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

                if (_selectedClassId != null) ...[
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Student Select Karein',
                    icon: Icons.person,
                    child: studentsAsync.when(
                      data: (students) {
                        if (students.isEmpty) {
                          return const Text('Is class mein koi student nahi hai');
                        }
                        return DropdownButtonFormField<String>(
                          value: _selectedStudentId,
                          decoration: const InputDecoration(
                            hintText: 'Student choose karein',
                            prefixIcon: Icon(Icons.person),
                          ),
                          items: students.map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text('${s.fullName} (Roll: ${s.rollNo})'),
                          )).toList(),
                          onChanged: (v) {
                            final student = students.firstWhere((s) => s.id == v);
                            setState(() {
                              _selectedStudentId = v;
                              _selectedStudent = student;
                              _selectedClassId = student.classId;
                              _selectedMonths.clear();
                              _totalAmount = 0;
                              _classFeeConfigs = null;
                            });
                            _loadClassFeeConfigs(student.classId);
                          },
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Error loading students'),
                    ),
                  ),
                ],

                if (_selectedStudent != null) ...[
                  const SizedBox(height: 16),
                  _buildStudentInfoCard(),
                  const SizedBox(height: 16),
                  _buildReceiptHistory(academicYear),
                  const SizedBox(height: 16),
                  _buildStudentFeeSummary(academicYear),
                ],

                if (_selectedStudent != null && _selectedMonths.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildPaymentSection(academicYear),
                ],

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Receipt History ─────────────────────────────────────────────────────────

  Widget _buildReceiptHistory(String academicYear) {
    final paymentsAsync = ref.watch(studentPaymentsProvider((
      studentId: _selectedStudentId!,
      academicYear: academicYear,
    )));

    return _buildSectionCard(
      title: '📋 Receipt History',
      icon: Icons.history,
      child: paymentsAsync.when(
        data: (payments) {
          if (payments.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Koi receipt nahi hai', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: payments.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final payment = payments[index];
              final dateFormat = DateFormat('dd MMM yyyy');

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green[50],
                  child: Icon(Icons.receipt, color: Colors.green[700]),
                ),
                title: Row(
                  children: [
                    Text(
                      '₹${payment.amount.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#${payment.receiptNo}',
                        style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  '${dateFormat.format(payment.paymentDate)} • ${payment.paymentMethod.toUpperCase()}',
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'print') {
                      _printReceipt(payment, _selectedStudent!);
                    } else if (value == 'delete') {
                      _confirmDeleteReceipt(payment, academicYear);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'print',
                      child: Row(
                        children: [
                          Icon(Icons.print, size: 20),
                          SizedBox(width: 8),
                          Text('Print Again'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Error: $e'),
      ),
    );
  }

  Future<void> _confirmDeleteReceipt(FeePayment payment, String academicYear) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Delete Receipt?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receipt No: ${payment.receiptNo}'),
            Text('Amount: ₹${payment.amount.toStringAsFixed(0)}'),
            Text('Date: ${DateFormat('dd MMM yyyy').format(payment.paymentDate)}'),
            const SizedBox(height: 12),
            const Text(
              '⚠️ Warning: This action cannot be undone!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteReceipt(payment, academicYear);
    }
  }

  Future<void> _deleteReceipt(FeePayment payment, String academicYear) async {
    try {
      await ref.read(feeRepoProvider).deletePayment(payment.id);

      ref.invalidate(studentPaymentsProvider((
        studentId: _selectedStudentId!,
        academicYear: academicYear,
      )));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Receipt ${payment.receiptNo} deleted'),
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

  // ── Search ──────────────────────────────────────────────────────────────────

  void _onSearch(String query, AsyncValue<List<Student>> allStudentsAsync) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    allStudentsAsync.whenData((students) {
      final q = query.toLowerCase();
      final results = students.where((s) =>
        s.fullName.toLowerCase().contains(q) ||
        s.rollNo.toLowerCase().contains(q) ||
        s.parentName.toLowerCase().contains(q)
      ).toList();

      setState(() {
        _searchResults = results;
        _showSearchResults = true;
      });
    });
  }

  void _selectStudentFromSearch(Student student) {
    _searchController.clear();
    setState(() {
      _selectedStudent = student;
      _selectedStudentId = student.id;
      _selectedClassId = student.classId;
      _selectedMonths.clear();
      _totalAmount = 0;
      _classFeeConfigs = null;
      _searchResults = [];
      _showSearchResults = false;
    });
    _searchFocusNode.unfocus();
    _loadClassFeeConfigs(student.classId);
  }

  Future<void> _loadClassFeeConfigs(String classId) async {
    final session = ref.read(activeSessionProvider).valueOrNull;
    if (session == null) return;
    try {
      final configs = await ref
          .read(feeRepoProvider)
          .getClassFeeConfigs(classId, session.label);
      if (mounted) setState(() => _classFeeConfigs = configs);
    } catch (_) {}
  }

  // ── Section Card Helper ─────────────────────────────────────────────────────

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF4F46E5)),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  // ── Student Info Card ───────────────────────────────────────────────────────

  Widget _buildStudentInfoCard() {
    final student = _selectedStudent!;
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF4F46E5),
                  child: Text(
                    student.fullName.isNotEmpty
                        ? student.fullName.substring(0, 1).toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Class: ${student.className} - ${student.section}  |  Roll: ${student.rollNo}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text('Father: ${student.parentName.isNotEmpty ? student.parentName : "N/A"}')),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.woman, size: 18, color: Colors.pink),
                const SizedBox(width: 8),
                Expanded(child: Text('Mother: ${student.motherName.isNotEmpty ? student.motherName : "N/A"}')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Fee Summary ─────────────────────────────────────────────────────────────

  Widget _buildStudentFeeSummary(String academicYear) {
    final summaryAsync = ref.watch(studentFeeSummaryProvider((
      studentId: _selectedStudentId!,
      academicYear: academicYear,
    )));

    return _buildSectionCard(
      title: 'Student Fee Status',
      icon: Icons.account_balance_wallet,
      child: summaryAsync.when(
        data: (summary) => Column(
          children: [
            // Summary chips
            Row(
              children: [
                Expanded(child: _buildSummaryChip('Total', summary.totalDue, Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _buildSummaryChip('Paid', summary.totalPaid, Colors.green)),
                const SizedBox(width: 8),
                Expanded(child: _buildSummaryChip('Pending', summary.totalPending, Colors.red)),
              ],
            ),

            if (summary.monthsPaid.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('✅ Paid Months:', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: summary.monthsPaid.map((m) => Chip(
                  label: Text(m),
                  backgroundColor: Colors.green[50],
                  avatar: const Icon(Icons.check_circle, size: 18, color: Colors.green),
                )).toList(),
              ),
            ],

            if (summary.monthsPending.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('⏳ Pending Months:', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: summary.monthsPending.map((m) => FilterChip(
                  label: Text(m),
                  selected: _selectedMonths.contains(m),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedMonths.add(m);
                      } else {
                        _selectedMonths.remove(m);
                      }
                      _recalculateTotal();
                    });
                  },
                  selectedColor: Colors.indigo[100],
                  checkmarkColor: Colors.indigo,
                  avatar: Icon(Icons.pending, size: 18, color: Colors.red[400]),
                )).toList(),
              ),
              if (summary.monthsPending.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Upar se months select karein aur payment karein',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
            ],

            if (summary.monthsPending.isEmpty && summary.monthsPaid.isEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Is student ke liye koi fee record nahi hai.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _generateFeesForStudent(academicYear),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate Fees (12 Months)'),
              ),
            ],
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Error: $e'),
      ),
    );
  }

  Widget _buildSummaryChip(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 12)),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // ── Payment Section ─────────────────────────────────────────────────────────

  Widget _buildPaymentSection(String academicYear) {
    return _buildSectionCard(
      title: '💳 Payment Details',
      icon: Icons.payment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected Months Summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.indigo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Selected: ${_selectedMonths.join(", ")}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Payment Method
          DropdownButtonFormField<String>(
            value: _paymentMethod,
            decoration: const InputDecoration(
              labelText: 'Payment Method',
              prefixIcon: Icon(Icons.payment),
            ),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('💵 Cash')),
              DropdownMenuItem(value: 'upi', child: Text('📱 UPI')),
              DropdownMenuItem(value: 'card', child: Text('💳 Card')),
              DropdownMenuItem(value: 'cheque', child: Text('📝 Cheque')),
              DropdownMenuItem(value: 'online', child: Text('🌐 Online Transfer')),
            ],
            onChanged: (v) => setState(() => _paymentMethod = v ?? 'cash'),
          ),
          const SizedBox(height: 16),

          // Concession Type
          DropdownButtonFormField<String>(
            value: _selectedConcessionType,
            decoration: const InputDecoration(
              labelText: 'Concession Type',
              prefixIcon: Icon(Icons.discount),
            ),
            items: ConcessionType.values.map((type) {
              return DropdownMenuItem(
                value: type.name,
                child: Text('${type.label} (${type.percentage}%)'),
              );
            }).toList(),
            onChanged: (v) {
              setState(() {
                _selectedConcessionType = v ?? 'none';
                _recalculateTotal();
              });
            },
          ),
          const SizedBox(height: 12),

          // Custom concession amount (only for 'other')
          if (_selectedConcessionType == 'other')
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Concession Amount (₹)',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                setState(() {
                  _concession = double.tryParse(v) ?? 0;
                  _recalculateTotal();
                });
              },
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.discount, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Concession: ₹${_calculateConcessionAmount().toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Amount breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              children: [
                _buildAmountRow('Base Amount (${_selectedMonths.length} months)', _totalAmount),
                if (_calculateConcessionAmount() > 0)
                  _buildAmountRow('Concession', _calculateConcessionAmount(), isDiscount: true),
                if (_lateFee > 0)
                  _buildAmountRow('Late Fee', _lateFee, isLateFee: true),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Final Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      '₹${_finalAmount().toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.green),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Collect Button
          ElevatedButton.icon(
            onPressed: () => _collectFees(academicYear),
            icon: const Icon(Icons.receipt),
            label: Text('Collect ₹${_finalAmount().toStringAsFixed(0)} & Print Receipt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, double amount, {bool isDiscount = false, bool isLateFee = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(
            '${isDiscount ? '-' : ''}₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDiscount ? Colors.green : (isLateFee ? Colors.orange : null),
            ),
          ),
        ],
      ),
    );
  }

  // ── Calculations ────────────────────────────────────────────────────────────

  void _recalculateTotal() {
    final configs = _classFeeConfigs ?? [];
    final enabledConfigs = configs.where((c) => c.isEnabled).toList();
    if (enabledConfigs.isEmpty) {
      _totalAmount = 0;
    } else {
      final monthlyAmount = enabledConfigs.fold(0.0, (sum, c) => sum + c.customAmount);
      _totalAmount = _selectedMonths.length * monthlyAmount;
    }
    _lateFee = 0; // Can add late fee logic here if needed
  }

  double _calculateConcessionAmount() {
    if (_selectedConcessionType == 'other') return _concession;
    if (_selectedConcessionType == 'none') return 0;
    final type = ConcessionType.values.firstWhere(
      (t) => t.name == _selectedConcessionType,
      orElse: () => ConcessionType.none,
    );
    return (_totalAmount * type.percentage) / 100;
  }

  double _finalAmount() {
    return (_totalAmount - _calculateConcessionAmount() + _lateFee).clamp(0, double.infinity);
  }

  // ── Generate Fees ───────────────────────────────────────────────────────────

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
              'Is class ke liye koi fee type enable nahi hai.\n'
              'Admin → Fees → Class Config mein fee types ON karein.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    final double totalMonthlyAmount =
        enabledConfigs.fold(0.0, (sum, c) => sum + c.customAmount);

    final parts = academicYear.split('-');
    final startYear = int.tryParse(parts[0]) ?? DateTime.now().year;
    final endYear = parts.length > 1
        ? (parts[1].length == 2 ? startYear + 1 : int.tryParse(parts[1]) ?? startYear + 1)
        : startYear + 1;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fees generate ho rahe hain...')),
      );
    }

    int generated = 0;
    for (final month in monthNames) {
      final monthIdx = monthIndex[month]!;
      final year = monthIdx >= 4 ? startYear : endYear;
      generated += await ref.read(feeRepoProvider).generateMonthlyFeesForStudent(
        studentId: _selectedStudent!.id,
        classId: _selectedClassId!,
        academicYear: academicYear,
        month: month,
        year: year,
        totalAmount: totalMonthlyAmount,
      );
    }

    // Refresh
    ref.invalidate(studentFeeSummaryProvider((
      studentId: _selectedStudentId!,
      academicYear: academicYear,
    )));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            generated > 0
                ? '$generated mahine ki fees generate ho gayi! ₹${totalMonthlyAmount.toStringAsFixed(0)}/month ✓'
                : 'Fees pehle se exist karti hain.',
          ),
          backgroundColor: generated > 0 ? Colors.green : Colors.blue,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ── Collect Fees ─────────────────────────────────────────────────────────────
  // This is the core fix: after recording the payment, we also update
  // each selected month's student_monthly_fees record to 'paid'.

  Future<void> _collectFees(String academicYear) async {
    if (_selectedMonths.isEmpty || _selectedStudent == null) return;

    final concessionAmount = _calculateConcessionAmount();
    final finalAmt = _finalAmount();

    try {
      final receiptNo = await ref.read(feeRepoProvider).generateReceiptNo();

      // 1. Create fee_payments record
      final payment = FeePayment(
        id: '',
        studentId: _selectedStudentId!,
        amount: finalAmt,
        paymentDate: DateTime.now(),
        paymentMethod: _paymentMethod,
        receiptNo: receiptNo,
        academicYear: academicYear,
        concession: concessionAmount,
        concessionType: _selectedConcessionType,
        lateFee: _lateFee,
        remarks: 'Months: ${_selectedMonths.join(", ")}',
        createdAt: DateTime.now(),
      );

      await ref.read(feeRepoProvider).createFeePayment(payment);

      // 2. ✅ KEY FIX: Mark each selected month as 'paid' in student_monthly_fees
      await ref.read(feeRepoProvider).markMonthlyFeesAsPaid(
        studentId: _selectedStudentId!,
        academicYear: academicYear,
        monthLabels: _selectedMonths.toList(),
        totalPaidAmount: finalAmt,
        concessionAmount: concessionAmount,
      );

      // 3. Print receipt
      await _printReceipt(payment, _selectedStudent!);

      // 4. Refresh all relevant providers
      final studentId = _selectedStudentId!;
      ref.invalidate(studentPaymentsProvider((
        studentId: studentId,
        academicYear: academicYear,
      )));
      ref.invalidate(studentFeeSummaryProvider((
        studentId: studentId,
        academicYear: academicYear,
      )));
      ref.invalidate(studentMonthlyFeesProvider((
        studentId: studentId,
        academicYear: academicYear,
      )));

      // 5. Clear selection
      setState(() {
        _selectedMonths.clear();
        _totalAmount = 0;
        _concession = 0;
        _selectedConcessionType = 'none';
        _lateFee = 0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Payment successful! Receipt: $receiptNo'),
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

  // ── Print Receipt ────────────────────────────────────────────────────────────

  Future<void> _printReceipt(FeePayment payment, Student student) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // School Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'NEMPS SCHOOL',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Fee Receipt', style: const pw.TextStyle(fontSize: 14)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 10),

            // Receipt & Student Details
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Receipt No: ${payment.receiptNo}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: ${dateFormat.format(payment.paymentDate)}'),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Student: ${student.fullName}'),
                      pw.Text('Roll No: ${student.rollNo}'),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Class: ${student.className} - ${student.section}'),
                      pw.Text('AY: ${payment.academicYear}'),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),

            // Parent Details
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Father: ${student.parentName}', style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 2),
                  pw.Text('Mother: ${student.motherName}', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),
            pw.SizedBox(height: 8),

            // Amount Details
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Months Paid:'),
                      pw.Expanded(
                        child: pw.Text(
                          payment.remarks?.replaceFirst('Months: ', '') ?? '',
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Base Amount:'),
                      pw.Text('₹${(_totalAmount > 0 ? _totalAmount : payment.amount + payment.concession).toStringAsFixed(0)}'),
                    ],
                  ),
                  if (payment.concession > 0) ...[
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Concession (${payment.concessionType}):'),
                        pw.Text('-₹${payment.concession.toStringAsFixed(0)}'),
                      ],
                    ),
                  ],
                  if (payment.lateFee > 0) ...[
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Late Fee:'),
                        pw.Text('+₹${payment.lateFee.toStringAsFixed(0)}'),
                      ],
                    ),
                  ],
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Payment Method:'),
                      pw.Text(payment.paymentMethod.toUpperCase()),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Divider(),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Net Amount:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      pw.Text('₹${payment.amount.toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
                    ],
                  ),
                ],
              ),
            ),

            pw.Spacer(),

            // Footer
            pw.Divider(),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Parent Signature', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 20),
                    pw.Container(width: 100, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide()))),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Receiver Signature', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 20),
                    pw.Container(width: 100, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide()))),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'This is a computer generated receipt',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      name: 'Receipt_${payment.receiptNo}.pdf',
    );
  }
}
