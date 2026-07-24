// Fees Module — Repository
// Handles all fee-related database operations.

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/fee_models.dart';

class FeeRepository {
  FeeRepository(this._client);
  final SupabaseClient _client;
  final _uuid = const Uuid();

  // ── Fee Types ────────────────────────────────────────────────────────────────

  Future<List<FeeType>> getFeeTypes(String academicYear) async {
    try {
      final data = await _client
          .from('fee_types')
          .select()
          .eq('academic_year', academicYear)
          .order('name');
      return data.map((r) => FeeType.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addFeeType({
    required String name,
    required String description,
    required double amount,
    required String frequency,
    required String academicYear,
  }) async {
    final row = {
      'id': _uuid.v4(),
      'name': name,
      'description': description,
      'amount': amount,
      'frequency': frequency,
      'academic_year': academicYear,
      'is_active': true,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _client.from('fee_types').insert(row);
  }

  Future<void> updateFeeType(FeeType feeType) async {
    await _client.from('fee_types').update({
      'name': feeType.name,
      'description': feeType.description,
      'amount': feeType.amount,
      'frequency': feeType.frequency,
      'is_active': feeType.isActive,
    }).eq('id', feeType.id);
  }

  Future<void> deleteFeeType(String id) async {
    await _client.from('fee_types').delete().eq('id', id);
  }

  // ── Class Fee Config ─────────────────────────────────────────────────────────

  Future<List<ClassFeeConfig>> getClassFeeConfigs(
      String classId, String academicYear) async {
    try {
      final data = await _client
          .from('class_fee_configs')
          .select()
          .eq('class_id', classId)
          .eq('academic_year', academicYear);
      return data.map((r) => ClassFeeConfig.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveClassFeeConfig(ClassFeeConfig config) async {
    final existing = await _client
        .from('class_fee_configs')
        .select()
        .eq('class_id', config.classId)
        .eq('fee_type_id', config.feeTypeId)
        .eq('academic_year', config.academicYear)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('class_fee_configs')
          .update(config.toUpdateMap())
          .eq('id', existing['id']);
    } else {
      await _client.from('class_fee_configs').insert({
        'id': _uuid.v4(),
        ...config.toInsertMap(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  // ── Student Fees ─────────────────────────────────────────────────────────────

  Future<List<StudentFee>> getStudentFees({
    String? classId,
    String? studentId,
    String? academicYear,
    String? status,
  }) async {
    try {
      var query = _client.from('student_fees').select();
      
      if (classId != null) query = query.eq('class_id', classId);
      if (studentId != null) query = query.eq('student_id', studentId);
      if (academicYear != null) query = query.eq('academic_year', academicYear);
      if (status != null) query = query.eq('status', status);
      
      final data = await query.order('due_date');
      return data.map((r) => StudentFee.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<StudentFee?> getStudentFeeById(String id) async {
    try {
      final data = await _client
          .from('student_fees')
          .select()
          .eq('id', id)
          .maybeSingle();
      return data != null ? StudentFee.fromMap(data) : null;
    } catch (e) {
      return null;
    }
  }

  Future<String> createStudentFee(StudentFee fee) async {
    final id = _uuid.v4();
    await _client.from('student_fees').insert({
      'id': id,
      ...fee.toInsertMap(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    return id;
  }

  Future<void> updateStudentFee(StudentFee fee) async {
    await _client.from('student_fees').update({
      'paid_amount': fee.paidAmount,
      'status': fee.status,
      'paid_date': fee.paidDate?.toIso8601String().substring(0, 10),
      'concession': fee.concession,
      'late_fee_applied': fee.lateFeeApplied,
      'remarks': fee.remarks,
    }).eq('id', fee.id);
  }

  Future<void> deleteStudentFee(String id) async {
    await _client.from('student_fees').delete().eq('id', id);
  }

  Future<void> recordPayment(FeePayment payment) async {
    await _client.from('fee_payments').insert({
      'id': _uuid.v4(),
      ...payment.toInsertMap(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<FeePayment>> getPaymentHistory(String studentFeeId) async {
    try {
      final data = await _client
          .from('fee_payments')
          .select()
          .eq('student_fee_id', studentFeeId)
          .order('payment_date', ascending: false);
      return data.map((r) => FeePayment.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  // ── Generate Fees for Class ─────────────────────────────────────────────────

  Future<void> generateFeesForClass({
    required String classId,
    required String academicYear,
    required List<ClassFeeConfig> configs,
    required List<Map<String, dynamic>> students,
    required DateTime dueDate,
  }) async {
    final batch = <Map<String, dynamic>>[];
    final now = DateTime.now().toUtc().toIso8601String();

    for (final student in students) {
      for (final config in configs) {
        if (config.isEnabled) {
          batch.add({
            'id': _uuid.v4(),
            'student_id': student['id'],
            'fee_type_id': config.feeTypeId,
            'class_id': classId,
            'academic_year': academicYear,
            'amount': config.customAmount ?? 0,
            'paid_amount': 0,
            'status': 'due',
            'due_date': dueDate.toIso8601String().substring(0, 10),
            'concession': 0,
            'late_fee_applied': 0,
            'created_at': now,
          });
        }
      }
    }

    if (batch.isNotEmpty) {
      await _client.from('student_fees').insert(batch);
    }
  }

  // ── Fee Reports ──────────────────────────────────────────────────────────────

  Future<FeeSummary> getFeeSummary({
    String? classId,
    String? academicYear,
  }) async {
    try {
      var query = _client.from('student_fees').select();
      
      if (classId != null) query = query.eq('class_id', classId);
      if (academicYear != null) query = query.eq('academic_year', academicYear);
      
      final data = await query;
      final fees = data.map((r) => StudentFee.fromMap(r)).toList();

      double totalAmount = 0;
      double collectedAmount = 0;
      int overdueCount = 0;
      final uniqueStudents = <String>{};

      for (final fee in fees) {
        totalAmount += fee.amount - fee.concession + fee.lateFeeApplied;
        collectedAmount += fee.paidAmount;
        uniqueStudents.add(fee.studentId);
        if (fee.isOverdue) overdueCount++;
      }

      return FeeSummary(
        totalStudents: uniqueStudents.length,
        totalAmount: totalAmount,
        collectedAmount: collectedAmount,
        pendingAmount: totalAmount - collectedAmount,
        overdueCount: overdueCount,
      );
    } catch (e) {
      return const FeeSummary(
        totalStudents: 0,
        totalAmount: 0,
        collectedAmount: 0,
        pendingAmount: 0,
        overdueCount: 0,
      );
    }
  }

  // ── Get all classes with fees ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getClassesWithSummary(String academicYear) async {
    try {
      final classes = await _client
          .from('classes')
          .select()
          .eq('academic_year', academicYear);

      final result = <Map<String, dynamic>>[];
      
      for (final cls in classes) {
        final summary = await getFeeSummary(
          classId: cls['id'],
          academicYear: academicYear,
        );
        result.add({
          ...cls,
          'summary': summary,
        });
      }
      
      return result;
    } catch (e) {
      return [];
    }
  }
}
