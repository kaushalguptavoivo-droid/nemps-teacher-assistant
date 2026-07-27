import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/fee_management_models.dart';

class FeeManagementRepository {
  final SupabaseClient _client;

  FeeManagementRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ── Categories ─────────────────────────────────────────────────────────────

  Future<List<FeeCategory>> getCategories() async {
    final response = await _client
        .from('fee_categories')
        .select()
        .order('name');
    return response.map((e) => FeeCategory.fromMap(e)).toList();
  }

  // ── Discounts & Fines ──────────────────────────────────────────────────────

  Future<List<Discount>> getDiscounts() async {
    final response = await _client
        .from('discounts')
        .select()
        .eq('is_active', true)
        .order('name');
    return response.map((e) => Discount.fromMap(e)).toList();
  }

  Future<List<Fine>> getFines() async {
    final response = await _client
        .from('fines')
        .select()
        .eq('is_active', true)
        .order('name');
    return response.map((e) => Fine.fromMap(e)).toList();
  }

  // ── Fee Structures ─────────────────────────────────────────────────────────

  Future<List<FeeStructure>> getFeeStructures(String classId, String academicYear) async {
    final response = await _client
        .from('fee_structures')
        .select('*, fee_categories(*)')
        .eq('class_id', classId)
        .eq('academic_year', academicYear)
        .eq('is_active', true);
    return response.map((e) => FeeStructure.fromMap(e)).toList();
  }

  Future<void> createFeeStructure(FeeStructure structure) async {
    await _client.from('fee_structures').insert(structure.toMap());
  }

  // ── Student Assignments & Payments ─────────────────────────────────────────

  Future<List<StudentFeeAssignment>> getStudentAssignments(String studentId, String academicYear) async {
    final response = await _client
        .from('student_fee_assignments')
        .select('*, fee_structures(*, fee_categories(*)), discounts(*), fines(*)')
        .eq('student_id', studentId)
        .eq('academic_year', academicYear)
        .order('due_date');
    return response.map((e) => StudentFeeAssignment.fromMap(e)).toList();
  }

  Future<FeeReceipt> processPayment({
    required String studentId,
    required String academicYear,
    required String paymentMethod,
    required Map<String, Map<String, double>> payments, // assignmentId -> { 'amount': 100, 'fine': 0 }
    String? remarks,
  }) async {
    // Generate receipt number
    final year = DateTime.now().year;
    final count = await _client
        .from('fee_receipts')
        .select('id')
        .gte('receipt_no', 'FR-$year-')
        .then((data) => data.length);
    final receiptNo = 'FR-$year-${(count + 1).toString().padLeft(5, '0')}';

    double totalPaid = 0;
    payments.forEach((_, values) {
      totalPaid += values['amount'] ?? 0;
      totalPaid += values['fine'] ?? 0;
    });

    final receipt = await _client.from('fee_receipts').insert({
      'receipt_no': receiptNo,
      'student_id': studentId,
      'academic_year': academicYear,
      'total_paid': totalPaid,
      'payment_method': paymentMethod,
      'payment_date': DateTime.now().toIso8601String().split('T')[0],
      'remarks': remarks,
      'received_by': _client.auth.currentUser?.id,
    }).select().single();

    final receiptId = receipt['id'];

    // Process transactions and update assignments
    for (final entry in payments.entries) {
      final assignmentId = entry.key;
      final amountPaid = entry.value['amount'] ?? 0;
      final finePaid = entry.value['fine'] ?? 0;

      await _client.from('fee_transactions').insert({
        'assignment_id': assignmentId,
        'receipt_id': receiptId,
        'amount_paid': amountPaid,
        'fine_paid': finePaid,
      });

      // Update assignment status
      final assignment = await _client
          .from('student_fee_assignments')
          .select()
          .eq('id', assignmentId)
          .single();

      final currentPaid = (assignment['paid_amount'] as num).toDouble();
      final currentFine = (assignment['fine_amount'] as num).toDouble();
      final totalAmount = (assignment['total_amount'] as num).toDouble();

      final newPaid = currentPaid + amountPaid;
      final newFine = currentFine + finePaid;

      String status = 'partial';
      if (newPaid >= totalAmount) {
        status = 'paid';
      }

      await _client.from('student_fee_assignments').update({
        'paid_amount': newPaid,
        'fine_amount': newFine,
        'status': status,
      }).eq('id', assignmentId);
    }

    return FeeReceipt.fromMap(receipt);
  }
}
