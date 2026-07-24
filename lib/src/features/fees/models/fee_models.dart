// Fees Module — Data Models
// Complete Professional School Fee Management System

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

// Concession Types
enum ConcessionType {
  none('None', 0),
  ews('EWS', 100),
  scholarship('Scholarship', 50),
  merit('Merit Based', 25),
  sports('Sports', 30),
  staffWard('Staff Ward', 50),
  sibling2nd('Sibling (2nd Child)', 10),
  sibling3rd('Sibling (3rd Child)', 20),
  other('Other', 0);

  const ConcessionType(this.label, this.percentage);
  final String label;
  final int percentage;
}

// Installment Plans
enum InstallmentPlan {
  none('Full Payment', 0),
  one('1 Installment', 1),
  two('2 Installments', 2),
  three('3 Installments', 3);

  const InstallmentPlan(this.label, this.count);
  final String label;
  final int count;
}

class FeeType {
  const FeeType({
    required this.id,
    required this.name,
    required this.description,
    required this.amount,
    required this.frequency,
    required this.isActive,
    this.academicYear = '',
    this.isOneTime = false,
    this.lateFeePerMonth = 0,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final double amount;
  final String frequency;
  final bool isActive;
  final String academicYear;
  final bool isOneTime;
  final double lateFeePerMonth;
  final DateTime createdAt;

  factory FeeType.fromMap(Map<String, dynamic> m) => FeeType(
        id: m['id'] as String,
        name: m['name'] as String,
        description: m['description'] as String? ?? '',
        amount: (m['amount'] as num).toDouble(),
        frequency: m['frequency'] as String? ?? 'monthly',
        isActive: m['is_active'] as bool? ?? true,
        academicYear: m['academic_year'] as String? ?? '',
        isOneTime: m['is_one_time'] as bool? ?? false,
        lateFeePerMonth: (m['late_fee_per_month'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'name': name,
        'description': description,
        'amount': amount,
        'frequency': frequency,
        'is_active': isActive,
        'academic_year': academicYear,
        'is_one_time': isOneTime,
        'late_fee_per_month': lateFeePerMonth,
      };
}

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
    this.installmentPlan = 'none',
    this.siblingDiscount2nd = 0,
    this.siblingDiscount3rd = 0,
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
  final String installmentPlan;
  final double siblingDiscount2nd;
  final double siblingDiscount3rd;
  final DateTime createdAt;

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
        installmentPlan: m['installment_plan'] as String? ?? 'none',
        siblingDiscount2nd: (m['sibling_discount_2nd'] as num?)?.toDouble() ?? 0,
        siblingDiscount3rd: (m['sibling_discount_3rd'] as num?)?.toDouble() ?? 0,
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
        'installment_plan': installmentPlan,
        'sibling_discount_2nd': siblingDiscount2nd,
        'sibling_discount_3rd': siblingDiscount3rd,
      };

  Map<String, dynamic> toUpdateMap() => {
        'is_enabled': isEnabled,
        'custom_amount': customAmount,
        'due_date': dueDate.toIso8601String().substring(0, 10),
        'late_fee': lateFee,
        'concession_allowed': concessionAllowed,
        'installment_plan': installmentPlan,
        'sibling_discount_2nd': siblingDiscount2nd,
        'sibling_discount_3rd': siblingDiscount3rd,
      };
}

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
    this.status = 'due',
    this.concession = 0,
    this.concessionType = 'none',
    this.lateFee = 0,
    this.isInstallment = false,
    this.installmentNo = 0,
    this.remarks,
    required this.createdAt,
  });

  final String id;
  final String studentId;
  final String classId;
  final String month;
  final int year;
  final String academicYear;
  final double totalAmount;
  final double paidAmount;
  final String status;
  final double concession;
  final String concessionType;
  final double lateFee;
  final bool isInstallment;
  final int installmentNo;
  final String? remarks;
  final DateTime createdAt;

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
        concessionType: m['concession_type'] as String? ?? 'none',
        lateFee: (m['late_fee'] as num?)?.toDouble() ?? 0,
        isInstallment: m['is_installment'] as bool? ?? false,
        installmentNo: m['installment_no'] as int? ?? 0,
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
        'concession_type': concessionType,
        'late_fee': lateFee,
        'is_installment': isInstallment,
        'installment_no': installmentNo,
        'remarks': remarks,
      };
}

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
    this.concessionType = 'none',
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
  final String concessionType;
  final double lateFee;
  final String? remarks;
  final DateTime createdAt;

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
        concessionType: m['concession_type'] as String? ?? 'none',
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
        'concession_type': concessionType,
        'late_fee': lateFee,
        'remarks': remarks,
      };
}

class StudentFeeSummary {
  StudentFeeSummary({
    required this.totalDue,
    required this.totalPaid,
    required this.totalPending,
    required this.totalConcession,
    required this.totalLateFee,
    required this.monthsPending,
    required this.monthsPaid,
    this.concessionType = 'none',
    this.siblingDiscount = 0,
  });

  final double totalDue;
  final double totalPaid;
  final double totalPending;
  final double totalConcession;
  final double totalLateFee;
  final List<String> monthsPending;
  final List<String> monthsPaid;
  final String concessionType;
  final double siblingDiscount;
}

class DueStudent {
  DueStudent({
    required this.studentId,
    required this.studentName,
    required this.rollNo,
    required this.className,
    required this.section,
    required this.totalPending,
    required this.monthsPending,
    this.lastPaidDate,
  });

  final String studentId;
  final String studentName;
  final String rollNo;
  final String className;
  final String section;
  final double totalPending;
  final List<String> monthsPending;
  final DateTime? lastPaidDate;
}

class DailyCollection {
  DailyCollection({
    required this.date,
    required this.totalCollected,
    required this.totalConcession,
    required this.totalLateFee,
    required this.studentCount,
    required this.payments,
  });

  final DateTime date;
  final double totalCollected;
  final double totalConcession;
  final double totalLateFee;
  final int studentCount;
  final List<FeePayment> payments;
}

class FeeRefund {
  FeeRefund({
    required this.id,
    required this.studentId,
    required this.amount,
    required this.reason,
    required this.approvedBy,
    required this.refundDate,
    required this.createdAt,
  });

  final String id;
  final String studentId;
  final double amount;
  final String reason;
  final String approvedBy;
  final DateTime refundDate;
  final DateTime createdAt;

  String? studentName;

  factory FeeRefund.fromMap(Map<String, dynamic> m) => FeeRefund(
        id: m['id'] as String,
        studentId: m['student_id'] as String,
        amount: (m['amount'] as num).toDouble(),
        reason: m['reason'] as String,
        approvedBy: m['approved_by'] as String,
        refundDate: DateTime.parse(m['refund_date'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'student_id': studentId,
        'amount': amount,
        'reason': reason,
        'approved_by': approvedBy,
        'refund_date': refundDate.toIso8601String().substring(0, 10),
      };
}

// Fee Summary (for class/school level)
class FeeSummary {
  FeeSummary({
    required this.totalStudents,
    required this.totalExpected,
    required this.totalCollected,
    required this.totalPending,
    required this.totalConcession,
    required this.totalLateFee,
  });

  final int totalStudents;
  final double totalExpected;
  final double totalCollected;
  final double totalPending;
  final double totalConcession;
  final double totalLateFee;
}

// Legacy StudentFee for backward compatibility
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
        'paid_date': paidDate?.toIso8601String().substring(0, 10),
        'concession': concession,
        'late_fee_applied': lateFeeApplied,
        'remarks': remarks,
      };

  Map<String, dynamic> toUpdateMap() => {
        'paid_amount': paidAmount,
        'status': status,
        'paid_date': paidDate?.toIso8601String().substring(0, 10),
        'concession': concession,
        'late_fee_applied': lateFeeApplied,
        'remarks': remarks,
      };
}
