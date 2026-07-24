// Fee Collection Screen
// Complete month-wise fee collection with receipt printing

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/providers.dart';
import '../data/fee_providers.dart';
import '../models/fee_models.dart';
import '../../core/theme/app_theme.dart';
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
  String? _selectedAcademicYear;

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(activeSessionProvider);

    return activeSession.when(
      data: (session) {
        if (session == null) {
          return const Center(child: Text('No active session'));
        }
        _selectedAcademicYear = session.label;
        return _buildContent(session.label);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildContent(String academicYear) {
    final classesAsync = ref.watch(allClassesProvider);
    final studentsAsync = _selectedClassId != null 
        ? ref.watch(studentsProvider(_selectedClassId!))
        : const AsyncValue<List<Student>>.data([]);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step 1: Select Class
          _buildSectionCard(
            title: 'Step 1: Class Select Karein',
            icon: Icons.class_,
            child: classesAsync.when(
              data: (classes) => DropdownButtonFormField<String>(
                value: _selectedClassId,
                decoration: const InputDecoration(
                  hintText: 'Class choose karein',
                  prefixIcon: Icon(Icons.class_),
                ),
                items: classes.map((c) => DropdownMenuItem(
                  value: c.id,
                  child: Text('${c.name} - ${c.section}'),
                )).toList(),
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
            
            // Step 2: Select Student
            _buildSectionCard(
              title: 'Step 2: Student Select Karein',
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
                      child: Text('${s.fullName} (Roll: ${s.rollNo ?? "N/A"})'),
                    )).toList(),
                    onChanged: (v) {
                      final student = students.firstWhere((s) => s.id == v);
                      setState(() {
                        _selectedStudentId = v;
                        _selectedStudent = student;
                        _selectedMonths.clear();
                        _totalAmount = 0;
                      });
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
            
            // Student Info Card
            _buildStudentInfoCard(),
            
            const SizedBox(height: 16),
            
            // Step 3: Student Fee Summary
            _buildStudentFeeSummary(academicYear),
          ],

          if (_selectedMonths.isNotEmpty) ...[
            const SizedBox(height: 16),
            
            // Step 4: Payment Details
            _buildPaymentSection(academicYear),
          ],
        ],
      ),
    );
  }

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
                Icon(icon, color: AppTheme.primaryColor),
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
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    student.fullName.substring(0, 1).toUpperCase(),
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
                        'Class: ${student.className} - ${student.section}  |  Roll No: ${student.rollNo ?? "N/A"}',
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
            // Summary Cards
            Row(
              children: [
                Expanded(child: _buildSummaryChip('Total', summary.totalDue, Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _buildSummaryChip('Paid', summary.totalPaid, Colors.green)),
                const SizedBox(width: 8),
                Expanded(child: _buildSummaryChip('Pending', summary.totalPending, Colors.red)),
              ],
            ),

            if (summary.monthsPending.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Pending Months:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: summary.monthsPending.map((m) => Chip(
                  label: Text(m),
                  backgroundColor: Colors.red[50],
                  avatar: const Icon(Icons.pending, size: 18, color: Colors.red),
                )).toList(),
              ),
            ],

            if (summary.monthsPaid.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Paid Months:', style: TextStyle(fontWeight: FontWeight.bold)),
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
              const Divider(),
              const SizedBox(height: 8),
              const Text('Select Months to Collect:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      _calculateTotal(academicYear);
                    });
                  },
                  selectedColor: Colors.green[200],
                )).toList(),
              ),
              
              if (_selectedMonths.isNotEmpty) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _collectFees(academicYear),
                  icon: const Icon(Icons.payment),
                  label: Text('Collect ₹${_totalAmount.toStringAsFixed(0)} for ${_selectedMonths.length} month(s)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ],

            if (summary.monthsPending.isEmpty && summary.monthsPaid.isEmpty) ...[
              const SizedBox(height: 16),
              const Text('Is student ke liye koi fee record nahi hai.',
                          style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _generateFeesForStudent(academicYear),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate Fees'),
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
          Text('₹${amount.toStringAsFixed(0)}', 
               style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(String academicYear) {
    return _buildSectionCard(
      title: 'Payment Details',
      icon: Icons.payment,
      child: Column(
        children: [
          // Payment Method
          DropdownButtonFormField<String>(
            value: _paymentMethod,
            decoration: const InputDecoration(
              labelText: 'Payment Method',
              prefixIcon: Icon(Icons.payment),
            ),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'upi', child: Text('UPI')),
              DropdownMenuItem(value: 'card', child: Text('Card')),
              DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
              DropdownMenuItem(value: 'online', child: Text('Online Transfer')),
            ],
            onChanged: (v) => setState(() => _paymentMethod = v ?? 'cash'),
          ),
          const SizedBox(height: 12),
          
          // Concession
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Concession (₹)',
              prefixIcon: Icon(Icons.discount),
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              _concession = double.tryParse(v) ?? 0;
              _calculateTotal(academicYear);
            },
          ),
          const SizedBox(height: 16),
          
          // Total
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Final Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text('₹${(_totalAmount - _concession).toStringAsFixed(0)}', 
                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.green)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Collect Button
          ElevatedButton.icon(
            onPressed: () => _collectFees(academicYear),
            icon: const Icon(Icons.receipt),
            label: const Text('Collect & Print Receipt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }

  void _calculateTotal(String academicYear) {
    // TODO: Calculate based on class fee config
    _totalAmount = _selectedMonths.length * 1000; // Placeholder
  }

  Future<void> _generateFeesForStudent(String academicYear) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fees generate ho rahe hain...')),
    );
  }

  Future<void> _collectFees(String academicYear) async {
    if (_selectedMonths.isEmpty || _selectedStudent == null) return;

    try {
      final receiptNo = await ref.read(feeRepoProvider).generateReceiptNo();
      
      // Create payment record
      final payment = FeePayment(
        id: '',
        studentId: _selectedStudentId!,
        amount: _totalAmount - _concession,
        paymentDate: DateTime.now(),
        paymentMethod: _paymentMethod,
        receiptNo: receiptNo,
        academicYear: academicYear,
        concession: _concession,
        remarks: 'Months: ${_selectedMonths.join(", ")}',
        createdAt: DateTime.now(),
      );

      await ref.read(feeRepoProvider).createFeePayment(payment);

      // Show receipt with full student details
      await _printReceipt(payment, _selectedStudent!);

      // Clear selection
      setState(() {
        _selectedMonths.clear();
        _totalAmount = 0;
        _concession = 0;
      });

      // Refresh
      ref.invalidate(studentFeeSummaryProvider((
        studentId: _selectedStudentId!,
        academicYear: academicYear,
      )));

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

  Future<void> _printReceipt(FeePayment payment, Student student) async {
    final pdf = pw.Document();
    
    final dateFormat = DateFormat('dd MMM yyyy');
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // School Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('NEMPS SCHOOL', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Fee Receipt', style: const pw.TextStyle(fontSize: 14)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 10),
            
            // Receipt Details
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
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
                  pw.SizedBox(height: 5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Student: ${student.fullName}'),
                      pw.Text('Roll No: ${student.rollNo ?? "N/A"}'),
                    ],
                  ),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Class: ${student.className} - ${student.section}'),
                      pw.Text('Academic Year: ${payment.academicYear}'),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            
            // Parent Details
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Father: ${student.parentName}', style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 2),
                        pw.Text('Mother: ${student.motherName}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),
            pw.SizedBox(height: 10),
            
            // Amount Details
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
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
                      pw.Text(payment.remarks?.replaceFirst('Months: ', '') ?? ''),
                    ],
                  ),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Amount:'),
                      pw.Text('₹${payment.amount.toStringAsFixed(0)}'),
                    ],
                  ),
                  if (payment.concession > 0) ...[
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Concession:'),
                        pw.Text('-₹${payment.concession.toStringAsFixed(0)}'),
                      ],
                    ),
                  ],
                  pw.SizedBox(height: 5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Payment Method:'),
                      pw.Text(payment.paymentMethod.toUpperCase()),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Divider(),
                  pw.SizedBox(height: 5),
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
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Parent Signature', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 20),
                    pw.Container(
                      width: 100,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide()),
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Receiver Signature', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 20),
                    pw.Container(
                      width: 100,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text('This is a computer generated receipt', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
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
