import 'package:flutter_test/flutter_test.dart';
import 'package:nemps_teacher_assistant/src/features/fees/models/fee_management_models.dart';

void main() {
  group('Fee Management Models', () {
    test('StudentFeeAssignment calculates pending amount correctly', () {
      final assignment = StudentFeeAssignment(
        id: '1',
        studentId: 's1',
        structureId: 'st1',
        academicYear: '2023-2024',
        totalAmount: 1000,
        dueDate: DateTime.now(),
        paidAmount: 200,
        fineAmount: 50,
      );

      expect(assignment.pendingAmount, 850);
    });

    test('FeeCategory fromMap parses correctly', () {
      final map = {
        'id': '1',
        'name': 'Tuition',
        'description': 'Monthly tuition fee',
        'is_active': true,
        'created_at': '2023-01-01T00:00:00Z',
      };

      final category = FeeCategory.fromMap(map);

      expect(category.id, '1');
      expect(category.name, 'Tuition');
      expect(category.isActive, true);
    });
  });
}
