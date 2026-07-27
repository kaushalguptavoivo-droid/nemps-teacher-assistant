import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/fee_management_models.dart';
import '../data/fee_management_service.dart';

// Provides active academic year string
final activeAcademicYearProvider = Provider<String>((ref) => '2023-2024');

final dueStudentsProvider = FutureProvider.family<List<StudentFeeAssignment>, String>((ref, classId) async {
  final academicYear = ref.watch(activeAcademicYearProvider);
  final assignments = await ref.watch(studentFeeAssignmentsProvider((studentId: classId, academicYear: academicYear)).future);

  return assignments.where((a) => a.status != 'paid').toList();
});

final paymentProcessorProvider = Provider<FeeManagementService>((ref) {
  return ref.watch(feeManagementServiceProvider);
});
