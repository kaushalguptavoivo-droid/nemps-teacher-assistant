// Fees Module — Repository
// Handles all fee-related database operations.

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/fee_models.dart';

class FeeRepository {
  FeeRepository(this._client);
  final SupabaseClient _client;
  final _uuid = const Uuid();

  // ── Fee Types ────────────────────────────────────────────────────────────────

  Future<List<FeeType>> getFeeTypes(String academicYear) async {
    try {
      final data = await _client
          .from('fee_types')
          .select()
          .eq('academic_year', academicYear)
          .order('name');
      return data.map((r) => FeeType.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addFeeType(FeeType feeType) async {
    final row = {
      'id': _uuid.v4(),
      'name': feeType.name,
      'description': feeType.description,
      'amount': feeType.amount,
      'frequency': feeType.frequency,
      'academic_year': feeType.academicYear,
      'is_active': true,
      'is_mandatory': feeType.isMandatory,
      'depends_on_transport': feeType.dependsOnTransport,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _client.from('fee_types').insert(row);
  }

  Future<void> updateFeeType(FeeType feeType) async {
    await _client.from('fee_types').update({
      'name': feeType.name,
      'description': feeType.description,
      'amount': feeType.amount,
      'frequency': feeType.frequency,
      'is_active': feeType.isActive,
      'is_mandatory': feeType.isMandatory,
      'depends_on_transport': feeType.dependsOnTransport,
    }).eq('id', feeType.id);
  }

  Future<void> deleteFeeType(String id) async {
    await _client.from('fee_types').delete().eq('id', id);
  }

  // ── Class Fee Config ─────────────────────────────────────────────────────────

  Future<List<ClassFeeConfig>> getClassFeeConfigs(
      String classId, String academicYear) async {
    try {
      final data = await _client
          .from('class_fee_configs')
          .select()
          .eq('class_id', classId)
          .eq('academic_year', academicYear);
      return data.map((r) => ClassFeeConfig.fromMap(r)).toList();
    } catch (e) {
      // Re-throw instead of silently returning []. A caught-and-hidden
      // error here previously looked identical to "no fee types enabled",
      // which made real failures (auth, RLS, bad data) undiagnosable.
      rethrow;
    }
  }

  Future<void> saveClassFeeConfig(ClassFeeConfig config) async {
    final existing = await _client
        .from('class_fee_configs')
        .select()
        .eq('class_id', config.classId)
        .eq('fee_type_id', config.feeTypeId)
        .eq('academic_year', config.academicYear)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('class_fee_configs')
          .update(config.toUpdateMap())
          .eq('id', existing['id']);
    } else {
      await _client.from('class_fee_configs').insert({
        'id': _uuid.v4(),
        ...config.toInsertMap(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  // ── Student Fees (legacy — used by fee_config_screen) ────────────────────────

  Future<List<StudentFee>> getStudentFees({
    String? classId,
    String? studentId,
    String? academicYear,
    String? status,
  }) async {
    try {
      var query = _client.from('student_fees').select();

      if (classId != null) query = query.eq('class_id', classId);
      if (studentId != null) query = query.eq('student_id', studentId);
      if (academicYear != null) query = query.eq('academic_year', academicYear);
      if (status != null) query = query.eq('status', status);

      final data = await query.order('due_date');
      return data.map((r) => StudentFee.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<StudentFee?> getStudentFeeById(String id) async {
    try {
      final data = await _client
          .from('student_fees')
          .select()
          .eq('id', id)
          .maybeSingle();
      return data != null ? StudentFee.fromMap(data) : null;
    } catch (e) {
      return null;
    }
  }

  Future<String> createStudentFee(StudentFee fee) async {
    final id = _uuid.v4();
    await _client.from('student_fees').insert({
      'id': id,
      ...fee.toInsertMap(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    return id;
  }

  Future<void> updateStudentFee(StudentFee fee) async {
    await _client.from('student_fees').update({
      'paid_amount': fee.paidAmount,
      'status': fee.status,
      'paid_date': fee.paidDate?.toIso8601String().substring(0, 10),
      'concession': fee.concession,
      'late_fee_applied': fee.lateFeeApplied,
      'remarks': fee.remarks,
    }).eq('id', fee.id);
  }

  Future<void> deleteStudentFee(String id) async {
    await _client.from('student_fees').delete().eq('id', id);
  }

  /// Legacy record payment — kept for backward compat with fee_config_screen
  Future<void> recordPayment(FeePayment payment) async {
    await _client.from('fee_payments').insert({
      'id': _uuid.v4(),
      ...payment.toInsertMap(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // ── Payment History ─────────────────────────────────────────────────────────
  // Looks up by student_id (fee_payments also has a NOT NULL student_fee_id
  // FK, but querying history for a student spans multiple student_fees rows,
  // so student_id is the right column to filter on here).

  Future<List<FeePayment>> getPaymentHistory(String studentId) async {
    try {
      final data = await _client
          .from('fee_payments')
          .select()
          .eq('student_id', studentId)
          .order('payment_date', ascending: false);
      return data.map((r) => FeePayment.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  // ── Get Students for Class ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getStudentsForClass(String classId) async {
    try {
      final data = await _client
          .from('students')
          .select('id')
          .eq('class_id', classId)
          .eq('active', true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  // ── Student Monthly Fee Records ─────────────────────────────────────────────

  Future<List<StudentMonthlyFee>> getStudentMonthlyFees(
      String studentId, String academicYear) async {
    try {
      final data = await _client
          .from('student_monthly_fees')
          .select()
          .eq('student_id', studentId)
          .eq('academic_year', academicYear)
          .order('year')
          .order('month');
      return data.map((r) => StudentMonthlyFee.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<StudentMonthlyFee?> getStudentMonthFee(
      String studentId, String month, int year) async {
    // .maybeSingle() already returns null (no throw) when no row matches,
    // so any exception caught here is a real error (RLS, network, bad
    // data) — it must not be silently treated as "record doesn't exist",
    // or callers like generateMonthlyFeesForStudent will proceed to
    // insert on top of a masked failure.
    final data = await _client
        .from('student_monthly_fees')
        .select()
        .eq('student_id', studentId)
        .eq('month', month)
        .eq('year', year)
        .maybeSingle();
    return data != null ? StudentMonthlyFee.fromMap(data) : null;
  }

  Future<void> createStudentMonthlyFee(StudentMonthlyFee fee) async {
    await _client.from('student_monthly_fees').insert({
      'id': _uuid.v4(),
      ...fee.toInsertMap(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> updateStudentMonthlyFee(StudentMonthlyFee fee) async {
    await _client.from('student_monthly_fees').update({
      'paid_amount': fee.paidAmount,
      'status': fee.status,
      'concession': fee.concession,
      'late_fee': fee.lateFee,
      'remarks': fee.remarks,
    }).eq('id', fee.id);
  }

  // ── Mark Monthly Fees as Paid ──────────────────────────────────────────────
  // Called after a payment is collected for one or more months.
  // monthLabels format: 'April 2024', 'May 2024', etc.

  Future<void> markMonthlyFeesAsPaid({
    required String studentId,
    required String academicYear,
    required List<String> monthLabels,
    required double totalPaidAmount,
    required double concessionAmount,
  }) async {
    if (monthLabels.isEmpty) return;

    final perMonth = totalPaidAmount / monthLabels.length;
    final perConcession = concessionAmount / monthLabels.length;

    for (final label in monthLabels) {
      // label is 'Month Year', e.g. 'April 2024'
      final parts = label.trim().split(' ');
      if (parts.length < 2) continue;
      final month = parts[0];
      final year = int.tryParse(parts[1]);
      if (year == null) continue;

      final existing = await getStudentMonthFee(studentId, month, year);
      if (existing == null) continue;

      final newPaid = existing.paidAmount + perMonth;
      final newConcession = existing.concession + perConcession;
      // Only mark 'paid' when the amount actually covers what's due —
      // otherwise 'partial'. The model already understands this status
      // (see StudentMonthlyFee.isPending), it just was never written here.
      final newStatus =
          newPaid >= (existing.totalAmount - newConcession) ? 'paid' : 'partial';

      await _client.from('student_monthly_fees').update({
        'paid_amount': newPaid,
        'status': newStatus,
        'concession': newConcession,
        'paid_date': DateTime.now().toIso8601String().substring(0, 10),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', existing.id);
    }
  }

  // ── Collect Fee Payment (atomic) ────────────────────────────────────────────
  // Records the payment AND marks the covered months paid/partial in a single
  // DB transaction via RPC, instead of two separate client calls. Prevents a
  // dropped connection between the two steps from leaving a receipt with no
  // matching status update (or vice versa). Use this instead of calling
  // createFeePayment() + markMonthlyFeesAsPaid() separately.

  Future<String> collectMonthlyFeePayment({
    required FeePayment payment,
    required List<String> monthLabels,
  }) async {
    if (monthLabels.isEmpty) {
      throw ArgumentError('At least one month must be selected');
    }
    final result = await _client.rpc('collect_fee_payment', params: {
      'p_payment': payment.toInsertMap(),
      'p_month_labels': monthLabels,
    });
    return result as String;
  }

  // ── Ensure a student_fees row exists (for fee_payments FK) ──────────────────
  // fee_payments.student_fee_id is NOT NULL on the live DB. The monthly-fee
  // flow (student_monthly_fees) has no natural 1:1 student_fees row per
  // payment, so we reuse an existing student_fees row for this student/year
  // if one exists, or create a minimal one on the fly so the payment insert
  // always has a valid, non-null FK to satisfy the constraint.
  Future<String> ensureStudentFeeId({
    required String studentId,
    required String classId,
    required String academicYear,
    required double amount,
  }) async {
    final existing = await getStudentFees(
      studentId: studentId,
      academicYear: academicYear,
    );
    if (existing.isNotEmpty) return existing.first.id;

    final feeTypes = await getFeeTypes(academicYear);
    if (feeTypes.isEmpty) {
      throw StateError(
          'Koi fee type configured nahi hai $academicYear ke liye. Pehle Fee Types set up karein.');
    }

    return createStudentFee(StudentFee(
      id: '',
      studentId: studentId,
      feeTypeId: feeTypes.first.id,
      classId: classId,
      academicYear: academicYear,
      amount: amount,
      dueDate: DateTime.now(),
      createdAt: DateTime.now(),
    ));
  }

  // ── Fee Payment ─────────────────────────────────────────────────────────────

  Future<String> createFeePayment(FeePayment payment) async {
    final id = _uuid.v4();
    await _client.from('fee_payments').insert({
      'id': id,
      ...payment.toInsertMap(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    return id;
  }

  // Deletes the payment AND reverses whatever it applied to
  // student_monthly_fees (paid_amount/status), atomically via RPC.
  // Previously this only deleted the fee_payments row, leaving the months it
  // had marked paid stuck as "paid" forever with no matching receipt.
  Future<void> deletePayment(String paymentId) async {
    await _client.rpc('delete_fee_payment', params: {
      'p_payment_id': paymentId,
    });
  }

  Future<List<FeePayment>> getStudentPayments(
      String studentId, String academicYear) async {
    try {
      final data = await _client
          .from('fee_payments')
          .select()
          .eq('student_id', studentId)
          .eq('academic_year', academicYear)
          .order('payment_date', ascending: false);
      return data.map((r) => FeePayment.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  // ── Get All Payments (for receipt history tab) ────────────────────────────

  Future<List<FeePayment>> getAllPayments(String academicYear) async {
    try {
      final data = await _client
          .from('fee_payments')
          .select()
          .eq('academic_year', academicYear)
          .order('payment_date', ascending: false);
      return data.map((r) => FeePayment.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  // ── Get Pending Months for Student ─────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPendingMonthsForStudent(
    String studentId,
    String academicYear,
  ) async {
    try {
      final data = await _client
          .from('student_monthly_fees')
          .select()
          .eq('student_id', studentId)
          .eq('academic_year', academicYear)
          .neq('status', 'paid');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  // ── Generate Monthly Fees for a Student ─────────────────────────────────────

  Future<int> generateMonthlyFeesForStudent({
    required String studentId,
    required String classId,
    required String academicYear,
    required String month,
    required int year,
    required double totalAmount,
  }) async {
    // Check if already exists
    final existing = await getStudentMonthFee(studentId, month, year);
    if (existing != null) return 0;

    await createStudentMonthlyFee(StudentMonthlyFee(
      id: '',
      studentId: studentId,
      classId: classId,
      month: month,
      year: year,
      academicYear: academicYear,
      totalAmount: totalAmount,
      status: 'due',
      createdAt: DateTime.now(),
    ));
    return 1;
  }

  // ── Ensure Monthly Fees Exist (used by Due List) ────────────────────────────
  // Monthly fee rows are normally created lazily the first time a student is
  // opened in the Collect Fees screen. Reports (like the Due List) iterate
  // ALL active students, so a student who was never opened there has zero
  // rows in student_monthly_fees — which made them silently look "not due"
  // even though they genuinely owe fees. This fills in the missing rows
  // on-the-fly (idempotent — skips students who already have rows), so the
  // Due List reflects what's actually owed instead of what happens to be
  // pre-generated.
  Future<void> ensureMonthlyFeesGenerated({
    required String studentId,
    required String classId,
    required String academicYear,
  }) async {
    final existing = await getStudentMonthlyFees(studentId, academicYear);
    if (existing.isNotEmpty) return; // already generated, nothing to do

    final configs = await getClassFeeConfigs(classId, academicYear);
    final enabled = configs.where((c) => c.isEnabled).toList();
    if (enabled.isEmpty) return; // no fee configured for this class yet

    final monthlyAmount =
        enabled.fold<double>(0, (sum, c) => sum + c.customAmount);
    if (monthlyAmount <= 0) return;

    final startYear =
        int.tryParse(academicYear.split('-').first) ?? DateTime.now().year;

    for (final month in monthNames) {
      final year = (monthIndex[month] ?? 4) >= 4 ? startYear : startYear + 1;
      await generateMonthlyFeesForStudent(
        studentId: studentId,
        classId: classId,
        academicYear: academicYear,
        month: month,
        year: year,
        totalAmount: monthlyAmount,
      );
    }
  }

  // ── Receipt Number Generator ──────────────────────────────────────────────

  Future<String> generateReceiptNo() async {
    final year = DateTime.now().year;
    try {
      // Use the highest existing suffix, not the row count — counting rows
      // produces a number that's already taken (and rejected by the unique
      // index on receipt_no) whenever a payment has been deleted.
      final data = await _client
          .from('fee_payments')
          .select('receipt_no')
          .like('receipt_no', 'R-$year-%');
      var maxSeq = 0;
      for (final row in data) {
        final receiptNo = row['receipt_no'] as String?;
        if (receiptNo == null) continue;
        final suffix = receiptNo.split('-').last;
        final seq = int.tryParse(suffix);
        if (seq != null && seq > maxSeq) maxSeq = seq;
      }
      return 'R-$year-${(maxSeq + 1).toString().padLeft(4, '0')}';
    } catch (e) {
      return 'R-$year-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    }
  }

  // ── Student Fee Summary ────────────────────────────────────────────────────

  Future<StudentFeeSummary> getStudentFeeSummary(
      String studentId, String academicYear) async {
    try {
      final fees = await getStudentMonthlyFees(studentId, academicYear);

      double totalDue = 0;
      double totalPaid = 0;
      double totalConcession = 0;
      double totalLateFee = 0;
      final List<String> monthsPending = [];
      final List<String> monthsPaid = [];

      for (final fee in fees) {
        totalDue += fee.totalAmount;
        totalPaid += fee.paidAmount;
        totalConcession += fee.concession;
        totalLateFee += fee.lateFee;
        if (fee.isPaid) {
          monthsPaid.add('${fee.month} ${fee.year}');
        } else {
          monthsPending.add('${fee.month} ${fee.year}');
        }
      }

      return StudentFeeSummary(
        totalDue: totalDue,
        totalPaid: totalPaid,
        totalPending: totalDue - totalPaid,
        totalConcession: totalConcession,
        totalLateFee: totalLateFee,
        monthsPending: monthsPending,
        monthsPaid: monthsPaid,
      );
    } catch (e) {
      return StudentFeeSummary(
        totalDue: 0,
        totalPaid: 0,
        totalPending: 0,
        totalConcession: 0,
        totalLateFee: 0,
        monthsPending: [],
        monthsPaid: [],
      );
    }
  }

  // ── Due Students List ───────────────────────────────────────────────────────

  Future<List<DueStudent>> getDueStudents(String academicYear) async {
    try {
      final students = await _client
          .from('students')
          .select('*, classes(name, section)')
          .eq('active', true);

      final dueStudents = <DueStudent>[];

      for (final student in students) {
        final studentId = student['id'] as String;
        final classId = student['class_id'] as String? ?? '';

        // Backfill missing monthly-fee rows first — otherwise a student who
        // was never opened in Collect Fees has no rows at all and would
        // wrongly be skipped as "not due".
        if (classId.isNotEmpty) {
          try {
            await ensureMonthlyFeesGenerated(
              studentId: studentId,
              classId: classId,
              academicYear: academicYear,
            );
          } catch (_) {
            // Don't let one student's misconfigured class fee break the
            // whole Due List — fall through and use whatever rows exist.
          }
        }

        final fees = await getStudentMonthlyFees(studentId, academicYear);

        double totalPending = 0;
        final List<String> monthsPending = [];
        DateTime? lastPaid;

        for (final fee in fees) {
          if (!fee.isPaid) {
            totalPending += fee.pendingAmount;
            monthsPending.add(fee.month);
          } else {
            if (lastPaid == null || fee.createdAt.isAfter(lastPaid)) {
              lastPaid = fee.createdAt;
            }
          }
        }

        if (monthsPending.isNotEmpty) {
          final classInfo = student['classes'] as Map<String, dynamic>?;
          dueStudents.add(DueStudent(
            id: studentId,
            studentId: studentId,
            studentName: student['full_name'] as String? ?? '',
            rollNo: student['roll_no'] as String? ?? '',
            className: classInfo?['name'] as String? ?? '',
            section: classInfo?['section'] as String? ?? '',
            totalPending: totalPending,
            monthsPending: monthsPending,
            lastPaidDate: lastPaid,
          ));
        }
      }

      dueStudents.sort((a, b) => b.totalPending.compareTo(a.totalPending));
      return dueStudents;
    } catch (e) {
      return [];
    }
  }

  // ── Daily Collection ────────────────────────────────────────────────────────

  Future<DailyCollection> getDailyCollection(DateTime date) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final nextStr = DateFormat('yyyy-MM-dd')
          .format(date.add(const Duration(days: 1)));

      final payments = await _client
          .from('fee_payments')
          .select()
          .gte('payment_date', dateStr)
          .lt('payment_date', nextStr);

      final paymentList =
          payments.map((r) => FeePayment.fromMap(r)).toList();

      double totalCollected = 0;
      double totalConcession = 0;
      double totalLateFee = 0;

      for (final p in paymentList) {
        totalCollected += p.amount;
        totalConcession += p.concession;
        totalLateFee += p.lateFee;
      }

      return DailyCollection(
        date: date,
        totalCollected: totalCollected,
        totalConcession: totalConcession,
        totalLateFee: totalLateFee,
        studentCount: paymentList.length,
        payments: paymentList,
      );
    } catch (e) {
      return DailyCollection(
        date: date,
        totalCollected: 0,
        totalConcession: 0,
        totalLateFee: 0,
        studentCount: 0,
        payments: [],
      );
    }
  }

  // ── Get Payments in Date Range ──────────────────────────────────────────────

  Future<List<FeePayment>> getPaymentsInRange(
      DateTime start, DateTime end) async {
    try {
      final data = await _client
          .from('fee_payments')
          .select()
          .gte('payment_date', DateFormat('yyyy-MM-dd').format(start))
          .lte('payment_date', DateFormat('yyyy-MM-dd').format(end))
          .order('payment_date', ascending: false);
      return data.map((r) => FeePayment.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  // ── Get All Students ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllStudents() async {
    try {
      final data = await _client
          .from('students')
          .select()
          .eq('active', true)
          .order('roll_no');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  // ── Late Fee Calculation ───────────────────────────────────────────────────

  double calculateLateFee(
      double amount, DateTime dueDate, double lateFeePerMonth) {
    if (DateTime.now().isBefore(dueDate)) return 0;
    final monthsLate =
        DateTime.now().difference(dueDate).inDays ~/ 30;
    return monthsLate * lateFeePerMonth;
  }

  // ── Calculate Installment Amount ────────────────────────────────────────────

  double calculateInstallmentAmount(double totalAmount, String plan) {
    switch (plan) {
      case '1':
        return totalAmount;
      case '2':
        return totalAmount / 2;
      case '3':
        return totalAmount / 3;
      default:
        return totalAmount;
    }
  }

  // ── Generate Fees for Class ─────────────────────────────────────────────────

  Future<void> generateFeesForClass({
    required String classId,
    required String academicYear,
    required List<ClassFeeConfig> configs,
    required List<Map<String, dynamic>> students,
    required DateTime dueDate,
  }) async {
    final batch = <Map<String, dynamic>>[];

    // Only the columns that should actually change on a re-generate go in
    // the payload. id/paid_amount/status/concession/late_fee_applied are
    // deliberately left out:
    //  - 'id' omitted so the upsert never overwrites an existing row's
    //    primary key (it only supplies one via the column default on a true
    //    INSERT; on a conflict it's simply not touched).
    //  - paid_amount/status/concession/late_fee_applied omitted so
    //    re-running "Generate Fees" (e.g. after editing a class fee config)
    //    can never reset a student's already-recorded payment progress —
    //    those columns only get their DEFAULT on first insert and are left
    //    alone on every subsequent conflict/update.
    for (final student in students) {
      for (final config in configs) {
        if (config.isEnabled) {
          batch.add({
            'student_id': student['id'],
            'fee_type_id': config.feeTypeId,
            'class_id': classId,
            'academic_year': academicYear,
            'amount': config.customAmount,
            'due_date': dueDate.toIso8601String().substring(0, 10),
          });
        }
      }
    }

    if (batch.isNotEmpty) {
      // No ignoreDuplicates: an existing (student_id, fee_type_id,
      // academic_year) row now gets amount/due_date/class_id UPDATED instead
      // of the call being a silent no-op — this is what actually makes
      // re-generating fees after a config change take effect.
      await _client.from('student_fees').upsert(batch,
          onConflict: 'student_id,fee_type_id,academic_year');
    }
  }

  // ── Fee Summary ─────────────────────────────────────────────────────────────

  Future<FeeSummary> getFeeSummary({
    String? classId,
    required String academicYear,
  }) async {
    try {
      var query = _client
          .from('student_fees')
          .select()
          .eq('academic_year', academicYear);
      if (classId != null) query = query.eq('class_id', classId);

      final data = await query;
      final fees = data.map((r) => StudentFee.fromMap(r)).toList();

      double totalAmount = 0;
      double collectedAmount = 0;
      int overdueCount = 0;
      final uniqueStudents = <String>{};

      for (final fee in fees) {
        totalAmount += fee.amount - fee.concession + fee.lateFeeApplied;
        collectedAmount += fee.paidAmount;
        uniqueStudents.add(fee.studentId);
        if (fee.isOverdue) overdueCount++;
      }

      return FeeSummary(
        totalStudents: uniqueStudents.length,
        totalAmount: totalAmount,
        collectedAmount: collectedAmount,
        pendingAmount: totalAmount - collectedAmount,
        overdueCount: overdueCount,
      );
    } catch (e) {
      return FeeSummary();
    }
  }

  // ── Get all classes with fees ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getClassesWithSummary(
      String academicYear) async {
    try {
      final classes = await _client
          .from('classes')
          .select()
          .eq('academic_year', academicYear);

      final result = <Map<String, dynamic>>[];

      for (final cls in classes) {
        final summary = await getFeeSummary(
          classId: cls['id'] as String,
          academicYear: academicYear,
        );
        result.add({
          ...cls,
          'summary': summary,
        });
      }

      return result;
    } catch (e) {
      return [];
    }
  }
}
