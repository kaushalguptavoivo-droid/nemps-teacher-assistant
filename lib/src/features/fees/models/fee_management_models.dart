import 'package:flutter/foundation.dart';

@immutable
class FeeCategory {
  final String id;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  const FeeCategory({
    required this.id,
    required this.name,
    this.description,
    this.isActive = true,
    required this.createdAt,
  });

  factory FeeCategory.fromMap(Map<String, dynamic> map) {
    return FeeCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'is_active': isActive,
    };
  }
}

@immutable
class Discount {
  final String id;
  final String name;
  final String type; // 'percentage' or 'fixed'
  final double value;
  final String? description;
  final bool isActive;

  const Discount({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    this.description,
    this.isActive = true,
  });

  factory Discount.fromMap(Map<String, dynamic> map) {
    return Discount(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      value: (map['value'] as num).toDouble(),
      description: map['description'] as String?,
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'value': value,
      'description': description,
      'is_active': isActive,
    };
  }
}

@immutable
class Fine {
  final String id;
  final String name;
  final String type; // 'daily', 'fixed_per_month', 'percentage'
  final double value;
  final int gracePeriodDays;
  final double? maxFineAmount;
  final bool isActive;

  const Fine({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    this.gracePeriodDays = 0,
    this.maxFineAmount,
    this.isActive = true,
  });

  factory Fine.fromMap(Map<String, dynamic> map) {
    return Fine(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      value: (map['value'] as num).toDouble(),
      gracePeriodDays: map['grace_period_days'] as int? ?? 0,
      maxFineAmount: (map['max_fine_amount'] as num?)?.toDouble(),
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'value': value,
      'grace_period_days': gracePeriodDays,
      'max_fine_amount': maxFineAmount,
      'is_active': isActive,
    };
  }
}

@immutable
class FeeStructure {
  final String id;
  final String categoryId;
  final String classId;
  final String academicYear;
  final double totalAmount;
  final String frequency; // 'monthly', 'quarterly', 'half_yearly', 'yearly', 'one_time'
  final int dueDay;
  final bool isActive;
  final FeeCategory? category;

  const FeeStructure({
    required this.id,
    required this.categoryId,
    required this.classId,
    required this.academicYear,
    required this.totalAmount,
    this.frequency = 'monthly',
    this.dueDay = 10,
    this.isActive = true,
    this.category,
  });

  factory FeeStructure.fromMap(Map<String, dynamic> map) {
    return FeeStructure(
      id: map['id'] as String,
      categoryId: map['category_id'] as String,
      classId: map['class_id'] as String,
      academicYear: map['academic_year'] as String,
      totalAmount: (map['total_amount'] as num).toDouble(),
      frequency: map['frequency'] as String? ?? 'monthly',
      dueDay: map['due_day'] as int? ?? 10,
      isActive: map['is_active'] as bool? ?? true,
      category: map['fee_categories'] != null
          ? FeeCategory.fromMap(map['fee_categories'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category_id': categoryId,
      'class_id': classId,
      'academic_year': academicYear,
      'total_amount': totalAmount,
      'frequency': frequency,
      'due_day': dueDay,
      'is_active': isActive,
    };
  }
}

@immutable
class StudentFeeAssignment {
  final String id;
  final String studentId;
  final String structureId;
  final String? discountId;
  final String? fineId;
  final String academicYear;
  final int installmentNo;
  final double totalAmount;
  final DateTime dueDate;
  final double paidAmount;
  final double fineAmount;
  final String status; // 'pending', 'partial', 'paid', 'cancelled'

  final FeeStructure? structure;
  final Discount? discount;
  final Fine? fine;

  const StudentFeeAssignment({
    required this.id,
    required this.studentId,
    required this.structureId,
    this.discountId,
    this.fineId,
    required this.academicYear,
    this.installmentNo = 1,
    required this.totalAmount,
    required this.dueDate,
    this.paidAmount = 0,
    this.fineAmount = 0,
    this.status = 'pending',
    this.structure,
    this.discount,
    this.fine,
  });

  double get pendingAmount => (totalAmount + fineAmount) - paidAmount;

  factory StudentFeeAssignment.fromMap(Map<String, dynamic> map) {
    return StudentFeeAssignment(
      id: map['id'] as String,
      studentId: map['student_id'] as String,
      structureId: map['structure_id'] as String,
      discountId: map['discount_id'] as String?,
      fineId: map['fine_id'] as String?,
      academicYear: map['academic_year'] as String,
      installmentNo: map['installment_no'] as int? ?? 1,
      totalAmount: (map['total_amount'] as num).toDouble(),
      dueDate: DateTime.parse(map['due_date'] as String),
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0,
      fineAmount: (map['fine_amount'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? 'pending',
      structure: map['fee_structures'] != null
          ? FeeStructure.fromMap(map['fee_structures'])
          : null,
      discount: map['discounts'] != null
          ? Discount.fromMap(map['discounts'])
          : null,
      fine: map['fines'] != null
          ? Fine.fromMap(map['fines'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'student_id': studentId,
      'structure_id': structureId,
      'discount_id': discountId,
      'fine_id': fineId,
      'academic_year': academicYear,
      'installment_no': installmentNo,
      'total_amount': totalAmount,
      'due_date': dueDate.toIso8601String().split('T')[0],
      'paid_amount': paidAmount,
      'fine_amount': fineAmount,
      'status': status,
    };
  }
}

@immutable
class FeeReceipt {
  final String id;
  final String receiptNo;
  final String studentId;
  final String academicYear;
  final double totalPaid;
  final String paymentMethod;
  final DateTime paymentDate;
  final String? remarks;
  final String? receivedBy;

  final List<FeeTransaction>? transactions;

  const FeeReceipt({
    required this.id,
    required this.receiptNo,
    required this.studentId,
    required this.academicYear,
    required this.totalPaid,
    required this.paymentMethod,
    required this.paymentDate,
    this.remarks,
    this.receivedBy,
    this.transactions,
  });

  factory FeeReceipt.fromMap(Map<String, dynamic> map) {
    return FeeReceipt(
      id: map['id'] as String,
      receiptNo: map['receipt_no'] as String,
      studentId: map['student_id'] as String,
      academicYear: map['academic_year'] as String,
      totalPaid: (map['total_paid'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      paymentDate: DateTime.parse(map['payment_date'] as String),
      remarks: map['remarks'] as String?,
      receivedBy: map['received_by'] as String?,
      transactions: map['fee_transactions'] != null
          ? (map['fee_transactions'] as List)
              .map((e) => FeeTransaction.fromMap(e))
              .toList()
          : null,
    );
  }
}

@immutable
class FeeTransaction {
  final String id;
  final String assignmentId;
  final String receiptId;
  final double amountPaid;
  final double finePaid;

  const FeeTransaction({
    required this.id,
    required this.assignmentId,
    required this.receiptId,
    required this.amountPaid,
    this.finePaid = 0,
  });

  factory FeeTransaction.fromMap(Map<String, dynamic> map) {
    return FeeTransaction(
      id: map['id'] as String,
      assignmentId: map['assignment_id'] as String,
      receiptId: map['receipt_id'] as String,
      amountPaid: (map['amount_paid'] as num).toDouble(),
      finePaid: (map['fine_paid'] as num?)?.toDouble() ?? 0,
    );
  }
}
