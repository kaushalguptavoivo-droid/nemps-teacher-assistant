// Fees Module — Riverpod Providers
// All providers for the Fees Module.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/fee_models.dart';
import 'fee_repository.dart';

// ── Repository Provider ───────────────────────────────────────────────────────

final feeRepoProvider = Provider<FeeRepository>(
  (_) => FeeRepository(Supabase.instance.client),
);

// ── Fee Types ─────────────────────────────────────────────────────────────────

final feeTypesProvider = FutureProvider.family<List<FeeType>, String>(
    (ref, academicYear) async {
  return ref.read(feeRepoProvider).getFeeTypes(academicYear);
});

// ── Class Fee Configs ────────────────────────────────────────────────────────

final classFeeConfigsProvider =
    FutureProvider.family<List<ClassFeeConfig>, ({String classId, String year})>(
        (ref, args) async {
  return ref.read(feeRepoProvider).getClassFeeConfigs(args.classId, args.year);
});

// ── Student Fees ─────────────────────────────────────────────────────────────

final studentFeesProvider = FutureProvider.family<List<StudentFee>, ({
  String? classId,
  String? studentId,
  String academicYear,
  String? status
})>((ref, args) async {
  return ref.read(feeRepoProvider).getStudentFees(
    classId: args.classId,
    studentId: args.studentId,
    academicYear: args.academicYear,
    status: args.status,
  );
});

// ── Fee Summary ──────────────────────────────────────────────────────────────

final feeSummaryProvider = FutureProvider.family<FeeSummary, ({
  String? classId,
  String academicYear
})>((ref, args) async {
  return ref.read(feeRepoProvider).getFeeSummary(
    classId: args.classId,
    academicYear: args.academicYear,
  );
});

// ── Classes with Fee Summary ─────────────────────────────────────────────────

final classesWithFeeSummaryProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
    (ref, academicYear) async {
  return ref.read(feeRepoProvider).getClassesWithSummary(academicYear);
});

// ── Payment History ──────────────────────────────────────────────────────────

final paymentHistoryProvider = FutureProvider.family<List<FeePayment>, String>(
    (ref, studentFeeId) async {
  return ref.read(feeRepoProvider).getPaymentHistory(studentFeeId);
});

// ── Student Monthly Fees (New) ───────────────────────────────────────────────

final studentMonthlyFeesProvider = FutureProvider.family<List<StudentMonthlyFee>, ({
  String studentId,
  String academicYear
})>((ref, args) async {
  return ref.read(feeRepoProvider).getStudentMonthlyFees(args.studentId, args.academicYear);
});

// ── Student Fee Summary (New) ────────────────────────────────────────────────

final studentFeeSummaryProvider = FutureProvider.family<StudentFeeSummary, ({
  String studentId,
  String academicYear
})>((ref, args) async {
  return ref.read(feeRepoProvider).getStudentFeeSummary(args.studentId, args.academicYear);
});

// ── Student Payments (New) ───────────────────────────────────────────────────

final studentPaymentsProvider = FutureProvider.family<List<FeePayment>, ({
  String studentId,
  String academicYear
})>((ref, args) async {
  return ref.read(feeRepoProvider).getStudentPayments(args.studentId, args.academicYear);
});

// ── Due Students Provider ───────────────────────────────────────────────────

final dueStudentsProvider = FutureProvider.family<List<DueStudent>, String>((ref, academicYear) async {
  return ref.read(feeRepoProvider).getDueStudents(academicYear);
});

// ── Daily Collection Provider ───────────────────────────────────────────────

final dailyCollectionProvider = FutureProvider.family<DailyCollection, DateTime>((ref, date) async {
  return ref.read(feeRepoProvider).getDailyCollection(date);
});
