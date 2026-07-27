import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/fee_management_models.dart';
import 'fee_management_repository.dart';

final feeManagementRepositoryProvider = Provider<FeeManagementRepository>((ref) {
  return FeeManagementRepository();
});

final feeCategoriesProvider = FutureProvider<List<FeeCategory>>((ref) async {
  final repository = ref.read(feeManagementRepositoryProvider);
  return repository.getCategories();
});

final discountsProvider = FutureProvider<List<Discount>>((ref) async {
  final repository = ref.read(feeManagementRepositoryProvider);
  return repository.getDiscounts();
});

final finesProvider = FutureProvider<List<Fine>>((ref) async {
  final repository = ref.read(feeManagementRepositoryProvider);
  return repository.getFines();
});

final feeStructuresProvider = FutureProvider.family<List<FeeStructure>, ({String classId, String academicYear})>((ref, args) async {
  final repository = ref.read(feeManagementRepositoryProvider);
  return repository.getFeeStructures(args.classId, args.academicYear);
});

final studentFeeAssignmentsProvider = FutureProvider.family<List<StudentFeeAssignment>, ({String studentId, String academicYear})>((ref, args) async {
  final repository = ref.read(feeManagementRepositoryProvider);
  return repository.getStudentAssignments(args.studentId, args.academicYear);
});

class FeeManagementService {
  final FeeManagementRepository _repository;

  FeeManagementService(this._repository);

  Future<FeeReceipt> processPayment({
    required String studentId,
    required String academicYear,
    required String paymentMethod,
    required Map<String, Map<String, double>> payments,
    String? remarks,
  }) async {
    return _repository.processPayment(
      studentId: studentId,
      academicYear: academicYear,
      paymentMethod: paymentMethod,
      payments: payments,
      remarks: remarks,
    );
  }
}

final feeManagementServiceProvider = Provider<FeeManagementService>((ref) {
  return FeeManagementService(ref.read(feeManagementRepositoryProvider));
});
