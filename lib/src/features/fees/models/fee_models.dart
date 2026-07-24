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
