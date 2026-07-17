enum UserRole { admin, teacher }
enum AttendanceStatus { present, absent }
enum HomeworkStatus { completed, pending, notChecked }
enum FeeStatus { paid, due, overdue }

class Student {
  const Student({required this.id, required this.fullName, required this.rollNo, required this.className, required this.section, this.parentName = '', this.whatsapp = '', this.dob, this.feeStatus = FeeStatus.due, this.photoUrl});
  final String id, fullName, rollNo, className, section, parentName, whatsapp;
  final DateTime? dob;
  final FeeStatus feeStatus;
  final String? photoUrl;
  String get classLabel => '$className-$section';
  factory Student.fromMap(Map<String, dynamic> m) => Student(id: m['id'], fullName: m['full_name'], rollNo: m['roll_no'], className: m['class_name'], section: m['section'], parentName: m['father_name'] ?? '', whatsapp: m['whatsapp'] ?? '', dob: m['dob'] == null ? null : DateTime.parse(m['dob']), feeStatus: FeeStatus.values.byName(m['fee_status'] ?? 'due'), photoUrl: m['photo_url']);
}

class ClassRoom {
  const ClassRoom({required this.id, required this.name, required this.section});
  final String id, name, section;
  String get label => '$name-$section';
  factory ClassRoom.fromMap(Map<String,dynamic> m) => ClassRoom(id: m['id'], name: m['name'], section: m['section']);
}
