enum UserRole { admin, teacher }
enum AttendanceStatus { present, absent }
enum HomeworkStatus { completed, incomplete, notChecked }
enum FeeStatus { paid, due, overdue }
enum ActivityType { attendanceMarked, homeworkMarked, whatsappSent, noticeSent }

class Student {
  const Student({
    required this.id,
    required this.fullName,
    required this.rollNo,
    required this.className,
    required this.section,
    this.parentName = '',
    this.whatsapp = '',
    this.dob,
    this.feeStatus = FeeStatus.due,
    this.photoUrl,
  });
  final String id, fullName, rollNo, className, section, parentName, whatsapp;
  final DateTime? dob;
  final FeeStatus feeStatus;
  final String? photoUrl;
  String get classLabel => '$className-$section';
  factory Student.fromMap(Map<String, dynamic> m) => Student(
    id: m['id'],
    fullName: m['full_name'],
    rollNo: m['roll_no'],
    className: (m['classes'] as Map<String, dynamic>?)?['name'] ?? m['class_name'] ?? '',
    section: (m['classes'] as Map<String, dynamic>?)?['section'] ?? m['section'] ?? '',
    parentName: m['father_name'] ?? '',
    whatsapp: m['whatsapp'] ?? '',
    dob: m['dob'] != null ? DateTime.parse(m['dob']) : null,
    feeStatus: FeeStatus.values.firstWhere(
      (e) => e.name == (m['fee_status'] ?? 'due'),
      orElse: () => FeeStatus.due,
    ),
  );
}

class ClassRoom {
  const ClassRoom({required this.id, required this.name, required this.section});
  final String id, name, section;
  String get label => '$name-$section';
  factory ClassRoom.fromMap(Map<String, dynamic> m) => ClassRoom(
    id: m['id'],
    name: m['name'],
    section: m['section'],
  );
}

class Homework {
  const Homework({
    required this.id,
    required this.classId,
    required this.subject,
    this.description = '',
    required this.assignedDate,
    this.assignedBy = '',
  });
  final String id, classId, subject, description, assignedBy;
  final DateTime assignedDate;
  factory Homework.fromMap(Map<String, dynamic> m) => Homework(
    id: m['id'],
    classId: m['class_id'],
    subject: m['subject'],
    description: m['description'] ?? '',
    assignedDate: DateTime.parse(m['assigned_date']),
    assignedBy: m['assigned_by'] ?? '',
  );
}

class HomeworkStatusRecord {
  const HomeworkStatusRecord({
    required this.id,
    required this.homeworkId,
    required this.studentId,
    required this.status,
    required this.studentName,
    this.markedBy = '',
  });
  final String id, homeworkId, studentId, status, studentName, markedBy;
  factory HomeworkStatusRecord.fromMap(Map<String, dynamic> m) => HomeworkStatusRecord(
    id: m['id'],
    homeworkId: m['homework_id'],
    studentId: m['student_id'],
    status: m['status'],
    studentName: (m['students'] as Map<String, dynamic>?)?['full_name'] ?? '',
    markedBy: m['marked_by'] ?? '',
  );
}

class Notice {
  const Notice({
    required this.id,
    required this.title,
    required this.body,
    this.audienceClassId = '',
    this.audienceStudentId = '',
    this.createdBy = '',
    required this.createdAt,
  });
  final String id, title, body, audienceClassId, audienceStudentId, createdBy;
  final DateTime createdAt;
  factory Notice.fromMap(Map<String, dynamic> m) => Notice(
    id: m['id'],
    title: m['title'],
    body: m['body'],
    audienceClassId: m['audience_class_id'] ?? '',
    audienceStudentId: m['audience_student_id'] ?? '',
    createdBy: m['created_by'] ?? '',
    createdAt: DateTime.parse(m['created_at']),
  );
}

class TeacherActivity {
  const TeacherActivity({
    required this.id,
    required this.teacherId,
    required this.classId,
    required this.activityType,
    required this.activityDate,
    this.details = const {},
  });
  final String id, teacherId, classId, activityType;
  final DateTime activityDate;
  final Map<String, dynamic> details;
  factory TeacherActivity.fromMap(Map<String, dynamic> m) => TeacherActivity(
    id: m['id'],
    teacherId: m['teacher_id'],
    classId: m['class_id'],
    activityType: m['activity_type'],
    activityDate: DateTime.parse(m['activity_date']),
    details: m['details'] ?? {},
  );
}
