// Fees Module — Data Models
// All fee-specific models for the Fees Management System.

class FeeType {
  const FeeType({
    required this.id,
    required this.name,
    required this.description,
    required this.amount,
    required this.frequency,
    required this.isActive,
    this.academicYear = '',
    required this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final double amount;
  final String frequency;
  final bool isActive;
  final String academicYear;
  final DateTime createdAt;

  factory FeeType.fromMap(Map<String, dynamic> m) => FeeType(
        id: m['id'] as String,
        name: m['name'] as String,
        description: m['description'] as String? ?? '',
        amount: (m['amount'] as num).toDouble(),
        frequency: m['frequency'] as String? ?? 'one-time',
        isActive: m['is_active'] as bool? ?? true,
        academicYear: m['academic_year'] as String? ?? '',
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'name': name,
        'description': description,
        'amount': amount,
        'frequency': frequency,
        'is_active': isActive,
        'academic_year': academicYear,
      };
}

// Student Fee model
class StudentFee {
  StudentFee({
    required this.id,
    required this.studentId,
    required this.feeTypeId,
    required this.classId,
    required this.academicYear,
    required this.amount,
    this.paidAmount = 0,
    this.status = 'due',
    required this.dueDate,
    this.paidDate,
    this.concession = 0,
    this.lateFeeApplied = 0,
    this.remarks,
    required this.createdAt,
  });

  final String id;
  final String studentId;
  final String feeTypeId;
  final String classId;
  final String academicYear;
  final double amount;
  final double paidAmount;
  final String status;
  final DateTime dueDate;
  final DateTime? paidDate;
  final double concession;
  final double lateFeeApplied;
  final String? remarks;
  final DateTime createdAt;

  // Relations (populated separately)
  String? studentName;
  String? studentRollNo;
  String? feeTypeName;
  String? className;

  double get pendingAmount => amount - paidAmount + lateFeeApplied - concession;
  bool get isPaid => status == 'paid';
  bool get isOverdue => !isPaid && dueDate.isBefore(DateTime.now());

  factory StudentFee.fromMap(Map<String, dynamic> m) => StudentFee(
        id: m['id'] as String,
        studentId: m['student_id'] as String,
        feeTypeId: m['fee_type_id'] as String,
        classId: m['class_id'] as String,
        academicYear: m['academic_year'] as String,
        amount: (m['amount'] as num).toDouble(),
        paidAmount: (m['paid_amount'] as num?)?.toDouble() ?? 0,
        status: m['status'] as String? ?? 'due',
        dueDate: DateTime.parse(m['due_date'] as String),
        paidDate: m['paid_date'] != null
            ? DateTime.parse(m['paid_date'] as String)
            : null,
        concession: (m['concession'] as num?)?.toDouble() ?? 0,
        lateFeeApplied: (m['late_fee_applied'] as num?)?.toDouble() ?? 0,
        remarks: m['remarks'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'student_id': studentId,
        'fee_type_id': feeTypeId,
        'class_id': classId,
        'academic_year': academicYear,
        'amount': amount,
        'paid_amount': paidAmount,
        'status': status,
        'due_date': dueDate.toIso8601String().substring(0, 10),
        if (paidDate != null) 'paid_date': paidDate!.toIso8601String().substring(0, 10),
        'concession': concession,
        'late_fee_applied': lateFeeApplied,
        if (remarks != null) 'remarks': remarks,
      };
}

// Payment record model
class FeePayment {
  const FeePayment({
    required this.id,
    required this.studentFeeId,
    required this.studentId,
    required this.amount,
    required this.paymentDate,
    this.paymentMethod = 'cash',
    this.transactionId,
    this.receivedBy,
    this.remarks,
    required this.createdAt,
  });

  final String id;
  final String studentFeeId;
  final String studentId;
  final double amount;
  final DateTime paymentDate;
  final String paymentMethod;
  final String? transactionId;
  final String? receivedBy;
  final String? remarks;
  final DateTime createdAt;

  factory FeePayment.fromMap(Map<String, dynamic> m) => FeePayment(
        id: m['id'] as String,
        studentFeeId: m['student_fee_id'] as String,
        studentId: m['student_id'] as String,
        amount: (m['amount'] as num).toDouble(),
        paymentDate: DateTime.parse(m['payment_date'] as String),
        paymentMethod: m['payment_method'] as String? ?? 'cash',
        transactionId: m['transaction_id'] as String?,
        receivedBy: m['received_by'] as String?,
        remarks: m['remarks'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'student_fee_id': studentFeeId,
        'student_id': studentId,
        'amount': amount,
        'payment_date': paymentDate.toIso8601String().substring(0, 10),
        'payment_method': paymentMethod,
        if (transactionId != null) 'transaction_id': transactionId,
        if (receivedBy != null) 'received_by': receivedBy,
        if (remarks != null) 'remarks': remarks,
      };
}

// Fee summary for reports
class FeeSummary {
  const FeeSummary({
    required this.totalStudents,
    required this.totalAmount,
    required this.collectedAmount,
    required this.pendingAmount,
    required this.overdueCount,
  });

  final int totalStudents;
  final double totalAmount;
  final double collectedAmount;
  final double pendingAmount;
  final int overdueCount;

  double get collectionPercent =>
      totalAmount > 0 ? (collectedAmount / totalAmount) * 100 : 0;
}

class ClassFeeConfig {
  const ClassFeeConfig({
    required this.id,
    required this.classId,
    required this.feeTypeId,
    required this.academicYear,
    required this.isEnabled,
    this.customAmount,
    this.dueDate,
    this.lateFee = 0,
    this.concessionAllowed = false,
    required this.createdAt,
  });

  final String id;
  final String classId;
  final String feeTypeId;
  final String academicYear;
  final bool isEnabled;
  final double? customAmount;
  final DateTime? dueDate;
  final double lateFee;
  final bool concessionAllowed;
  final DateTime createdAt;

  factory ClassFeeConfig.fromMap(Map<String, dynamic> m) => ClassFeeConfig(
        id: m['id'] as String,
        classId: m['class_id'] as String,
        feeTypeId: m['fee_type_id'] as String,
        academicYear: m['academic_year'] as String,
        isEnabled: m['is_enabled'] as bool? ?? true,
        customAmount: m['custom_amount'] != null
            ? (m['custom_amount'] as num).toDouble()
            : null,
        dueDate: m['due_date'] != null
            ? DateTime.parse(m['due_date'] as String)
            : null,
        lateFee: (m['late_fee'] as num?)?.toDouble() ?? 0,
        concessionAllowed: m['concession_allowed'] as bool? ?? false,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'class_id': classId,
        'fee_type_id': feeTypeId,
        'academic_year': academicYear,
        'is_enabled': isEnabled,
        if (customAmount != null) 'custom_amount': customAmount,
        if (dueDate != null) 'due_date': dueDate!.toIso8601String().substring(0, 10),
        'late_fee': lateFee,
        'concession_allowed': concessionAllowed,
      };

  Map<String, dynamic> toUpdateMap() => {
        'is_enabled': isEnabled,
        if (customAmount != null) 'custom_amount': customAmount,
        if (dueDate != null) 'due_date': dueDate!.toIso8601String().substring(0, 10),
        'late_fee': lateFee,
        'concession_allowed': concessionAllowed,
      };
}
