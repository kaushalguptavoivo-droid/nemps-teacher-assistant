import 'package:flutter_test/flutter_test.dart';
import 'package:nemps_teacher_assistant/src/core/models/models.dart';

void main() {
  test('student maps database fee state and class label', () {
    final student = Student.fromMap({'id':'1','full_name':'Diya','roll_no':'02','class_name':'5','section':'A','fee_status':'overdue'});
    expect(student.classLabel, '5-A');
    expect(student.feeStatus, FeeStatus.overdue);
  });
}
