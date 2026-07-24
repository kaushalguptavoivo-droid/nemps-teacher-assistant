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

class FeeCollectionScreen extends ConsumerStatefulWidget {
  const FeeCollectionScreen({super.key});

  @override
  ConsumerState<FeeCollectionScreen> createState() => _FeeCollectionScreenState();
}

class _FeeCollectionScreenState extends ConsumerState<FeeCollectionScreen> {
  String? _selectedClassId;
  String? _selectedStudentId;
  final Set<String> _selectedMonths = {};
  double _totalAmount = 0;
  double _concession = 0;
  String _paymentMethod = 'cash';

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
    final studentsAsync = ref.watch(classStudentsProvider(_selectedClassId ?? ''));

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
                      child: Text('${s.name} (Roll: ${s.rollNo ?? "N/A"})'),
                    )).toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedStudentId = v;
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

          if (_selectedStudentId != null) ...[
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
    // This would calculate based on class fee config
    // For now, using placeholder
    _totalAmount = _selectedMonths.length * 1000; // Placeholder
  }

  Future<void> _generateFeesForStudent(String academicYear) async {
    // Generate fees for all months
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fees generate ho rahe hain...')),
    );
  }

  Future<void> _collectFees(String academicYear) async {
    if (_selectedMonths.isEmpty) return;

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

      // Get student details
      final students = await ref.read(classStudentsProvider(_selectedClassId!).future);
      final student = students.firstWhere((s) => s.id == _selectedStudentId);

      // Show receipt
      await _printReceipt(payment, student.name, student.rollNo ?? 'N/A');

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

  Future<void> _printReceipt(FeePayment payment, String studentName, String rollNo) async {
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
            pw.Divider(),
            pw.SizedBox(height: 10),
            
            // Receipt Details
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Receipt No: ${payment.receiptNo}'),
                pw.Text('Date: ${dateFormat.format(payment.paymentDate)}'),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Student: $studentName'),
                pw.Text('Roll No: $rollNo'),
              ],
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
                      pw.Text(payment.remarks ?? ''),
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
                      pw.Text('Net Amount:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('₹${payment.amount.toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ],
              ),
            ),
            
            pw.Spacer(),
            
            // Footer
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Parent Signature', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Receiver Signature', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 5),
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

// Student Fee Summary Provider
final studentFeeSummaryProvider = FutureProvider.family<StudentFeeSummary, ({
  String studentId,
  String academicYear,
})>((ref, args) async {
  return ref.read(feeRepoProvider).getStudentFeeSummary(args.studentId, args.academicYear);
});
