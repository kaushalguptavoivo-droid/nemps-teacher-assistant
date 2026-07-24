// Fees Module — Data Models
// Complete School Fee Management System

// Monthly names for display
const List<String> monthNames = [
  'April', 'May', 'June', 'July', 'August', 'September',
  'October', 'November', 'December', 'January', 'February', 'March'
];

// Month index mapping (Academic year: April to March)
const Map<String, int> monthIndex = {
  'April': 4, 'May': 5, 'June': 6, 'July': 7, 'August': 8,
  'September': 9, 'October': 10, 'November': 11, 'December': 12,
  'January': 1, 'February': 2, 'March': 3,
};

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
  final String frequency; // 'monthly', 'quarterly', 'exam', 'transport', 'one-time'
  final bool isActive;
  final String academicYear;
  final DateTime createdAt;

  factory FeeType.fromMap(Map<String, dynamic> m) => FeeType(
        id: m['id'] as String,
        name: m['name'] as String,
        description: m['description'] as String? ?? '',
        amount: (m['amount'] as num).toDouble(),
        frequency: m['frequency'] as String? ?? 'monthly',
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

// Class Fee Configuration
class ClassFeeConfig {
  ClassFeeConfig({
    required this.id,
    required this.classId,
    required this.feeTypeId,
    required this.academicYear,
    required this.isEnabled,
    required this.customAmount,
    required this.dueDate,
    this.lateFee = 0,
    this.concessionAllowed = false,
    required this.createdAt,
  });

  final String id;
  final String classId;
  final String feeTypeId;
  final String academicYear;
  final bool isEnabled;
  final double customAmount;
  final DateTime dueDate;
  final double lateFee;
  final bool concessionAllowed;
  final DateTime createdAt;

  // Relations
  String? feeTypeName;
  String? className;

  factory ClassFeeConfig.fromMap(Map<String, dynamic> m) => ClassFeeConfig(
        id: m['id'] as String,
        classId: m['class_id'] as String,
        feeTypeId: m['fee_type_id'] as String,
        academicYear: m['academic_year'] as String,
        isEnabled: m['is_enabled'] as bool? ?? false,
        customAmount: (m['custom_amount'] as num?)?.toDouble() ?? 0,
        dueDate: DateTime.parse(m['due_date'] as String),
        lateFee: (m['late_fee'] as num?)?.toDouble() ?? 0,
        concessionAllowed: m['concession_allowed'] as bool? ?? false,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'class_id': classId,
        'fee_type_id': feeTypeId,
        'academic_year': academicYear,
        'is_enabled': isEnabled,
        'custom_amount': customAmount,
        'due_date': dueDate.toIso8601String().substring(0, 10),
        'late_fee': lateFee,
        'concession_allowed': concessionAllowed,
      };

  Map<String, dynamic> toUpdateMap() => {
        'is_enabled': isEnabled,
        'custom_amount': customAmount,
        'due_date': dueDate.toIso8601String().substring(0, 10),
        'late_fee': lateFee,
        'concession_allowed': concessionAllowed,
      };
}

// Student Monthly Fee Record
class StudentMonthlyFee {
  StudentMonthlyFee({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.month,
    required this.year,
    required this.academicYear,
    required this.totalAmount,
    this.paidAmount = 0,
    this.status = 'due', // 'due', 'partial', 'paid'
    this.concession = 0,
    this.lateFee = 0,
    this.remarks,
    required this.createdAt,
  });

  final String id;
  final String studentId;
  final String classId;
  final String month; // 'April', 'May', etc.
  final int year;
  final String academicYear;
  final double totalAmount;
  final double paidAmount;
  final String status;
  final double concession;
  final double lateFee;
  final String? remarks;
  final DateTime createdAt;

  // Relations
  String? studentName;
  String? studentRollNo;
  String? className;

  double get pendingAmount => totalAmount - paidAmount;
  bool get isPaid => status == 'paid';
  bool get isPending => status == 'due' || status == 'partial';

  factory StudentMonthlyFee.fromMap(Map<String, dynamic> m) => StudentMonthlyFee(
        id: m['id'] as String,
        studentId: m['student_id'] as String,
        classId: m['class_id'] as String,
        month: m['month'] as String,
        year: m['year'] as int,
        academicYear: m['academic_year'] as String,
        totalAmount: (m['total_amount'] as num).toDouble(),
        paidAmount: (m['paid_amount'] as num?)?.toDouble() ?? 0,
        status: m['status'] as String? ?? 'due',
        concession: (m['concession'] as num?)?.toDouble() ?? 0,
        lateFee: (m['late_fee'] as num?)?.toDouble() ?? 0,
        remarks: m['remarks'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'student_id': studentId,
        'class_id': classId,
        'month': month,
        'year': year,
        'academic_year': academicYear,
        'total_amount': totalAmount,
        'paid_amount': paidAmount,
        'status': status,
        'concession': concession,
        'late_fee': lateFee,
        'remarks': remarks,
      };
}

// Individual Fee Payment (for tracking which fee type paid)
class FeePaymentDetail {
  FeePaymentDetail({
    required this.id,
    required this.monthlyFeeId,
    required this.feeTypeId,
    required this.amount,
    required this.paymentId,
  });

  final String id;
  final String monthlyFeeId;
  final String feeTypeId;
  final double amount;
  final String paymentId;

  // Relations
  String? feeTypeName;

  factory FeePaymentDetail.fromMap(Map<String, dynamic> m) => FeePaymentDetail(
        id: m['id'] as String,
        monthlyFeeId: m['monthly_fee_id'] as String,
        feeTypeId: m['fee_type_id'] as String,
        amount: (m['amount'] as num).toDouble(),
        paymentId: m['payment_id'] as String,
      );
}

// Fee Payment Record
class FeePayment {
  FeePayment({
    required this.id,
    required this.studentId,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    required this.receiptNo,
    required this.academicYear,
    this.concession = 0,
    this.lateFee = 0,
    this.remarks,
    required this.createdAt,
  });

  final String id;
  final String studentId;
  final double amount;
  final DateTime paymentDate;
  final String paymentMethod;
  final String receiptNo;
  final String academicYear;
  final double concession;
  final double lateFee;
  final String? remarks;
  final DateTime createdAt;

  // Relations
  String? studentName;
  String? studentRollNo;
  String? className;

  factory FeePayment.fromMap(Map<String, dynamic> m) => FeePayment(
        id: m['id'] as String,
        studentId: m['student_id'] as String,
        amount: (m['amount'] as num).toDouble(),
        paymentDate: DateTime.parse(m['payment_date'] as String),
        paymentMethod: m['payment_method'] as String,
        receiptNo: m['receipt_no'] as String,
        academicYear: m['academic_year'] as String,
        concession: (m['concession'] as num?)?.toDouble() ?? 0,
        lateFee: (m['late_fee'] as num?)?.toDouble() ?? 0,
        remarks: m['remarks'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'student_id': studentId,
        'amount': amount,
        'payment_date': paymentDate.toIso8601String().substring(0, 10),
        'payment_method': paymentMethod,
        'receipt_no': receiptNo,
        'academic_year': academicYear,
        'concession': concession,
        'late_fee': lateFee,
        'remarks': remarks,
      };
}

// Student Fee Summary
class StudentFeeSummary {
  StudentFeeSummary({
    required this.totalDue,
    required this.totalPaid,
    required this.totalPending,
    required this.monthsPending,
    required this.monthsPaid,
  });

  final double totalDue;
  final double totalPaid;
  final double totalPending;
  final List<String> monthsPending;
  final List<String> monthsPaid;
}

// Legacy model for backward compatibility
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

  // Relations
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
