import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:csv/csv.dart';
import '../../core/models/models.dart';
import '../../core/services/offline_queue.dart';

// Conditional import: use dart:io on mobile/desktop, stub on web
import 'dart:io' if (dart.library.html) 'package:nemps_teacher_assistant/src/core/stubs/io_stub.dart';

class SchoolRepository {
  SchoolRepository(this._client) : _outbox = OfflineQueue(_client);
  final SupabaseClient _client;
  late final OfflineQueue _outbox;

  String get _uid => _client.auth.currentUser!.id;

  // ── Auth ─────────────────────────────────────────────────────────────────

  Future<UserRole> getCurrentUserRole() async {
    try {
      final data = await _client
          .from('profiles')
          .select('role')
          .eq('id', _uid)
          .single();
      final roleStr = data['role'] as String? ?? 'teacher';
      return roleStr == 'admin' ? UserRole.admin : UserRole.teacher;
    } catch (_) {
      return UserRole.teacher;
    }
  }

  // ── Classes ───────────────────────────────────────────────────────────────

  Future<List<ClassRoom>> myClasses() async {
    try {
      final data = await _client
          .from('teacher_classes')
          .select('classes(id,name,section)')
          .eq('teacher_id', _uid);
      return data.map<ClassRoom>((e) => ClassRoom.fromMap(e['classes'])).toList();
    } catch (e) {
      rethrow;
    }
  }

  // ── Students ──────────────────────────────────────────────────────────────

  Future<List<Student>> students(String classId) async {
    try {
      final data = await _client
          .from('students')
          .select('*, classes(name, section)')
          .eq('class_id', classId)
          .eq('active', true)
          .order('roll_no');
      return data.map<Student>((e) => Student.fromMap(e)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveStudent({
    String? id,
    required String classId,
    required String fullName,
    required String rollNo,
    String fatherName = '',
    String whatsapp = '',
  }) async {
    final row = {
      if (id != null) 'id': id,
      'class_id': classId,
      'full_name': fullName.trim(),
      'roll_no': rollNo.trim(),
      'father_name': fatherName.trim(),
      'whatsapp': whatsapp.trim(),
      'active': true,
    };
    await _client.from('students').upsert(row, onConflict: 'class_id,roll_no');
  }

  Future<void> deactivateStudent(String studentId) async {
    await _client.from('students').update({'active': false}).eq('id', studentId);
  }

  // ── Attendance ────────────────────────────────────────────────────────────

  Future<void> saveAttendance({
    required String classId,
    required String studentId,
    required AttendanceStatus status,
    required DateTime date,
  }) async {
    final row = {
      'id': '${studentId}_${date.toIso8601String().substring(0, 10)}',
      'class_id': classId,
      'student_id': studentId,
      'date': date.toIso8601String().substring(0, 10),
      'status': status.name,
      'marked_by': _uid,
      'marked_at': DateTime.now().toIso8601String(),
    };
    try {
      await _client.from('attendance').upsert(row, onConflict: 'id');
      await _logActivity('attendance_marked', classId, {'students': 1});
    } catch (_) {
      await _outbox.enqueue('attendance', row);
    }
  }

  Future<Map<String, AttendanceStatus>> getAttendanceForDate(
      String classId, DateTime date) async {
    try {
      final data = await _client
          .from('attendance')
          .select('student_id, status')
          .eq('class_id', classId)
          .eq('date', date.toIso8601String().substring(0, 10));
      return {
        for (final row in data)
          row['student_id'] as String: AttendanceStatus.values.firstWhere(
            (e) => e.name == row['status'],
            orElse: () => AttendanceStatus.present,
          )
      };
    } catch (_) {
      return {};
    }
  }

  Future<List<Student>> getAbsentStudents(String classId, DateTime date) async {
    try {
      final attendanceData = await _client
          .from('attendance')
          .select('student_id')
          .eq('class_id', classId)
          .eq('date', date.toIso8601String().substring(0, 10))
          .eq('status', 'absent');
      if (attendanceData.isEmpty) return [];
      final absentIds = attendanceData.map((e) => e['student_id']).toList();
      final allStudents = await students(classId);
      return allStudents.where((s) => absentIds.contains(s.id)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Student>> getPresentStudents(String classId, DateTime date) async {
    try {
      final attendanceData = await _client
          .from('attendance')
          .select('student_id')
          .eq('class_id', classId)
          .eq('date', date.toIso8601String().substring(0, 10))
          .eq('status', 'present');
      if (attendanceData.isEmpty) return [];
      final presentIds = attendanceData.map((e) => e['student_id']).toList();
      final allStudents = await students(classId);
      return allStudents.where((s) => presentIds.contains(s.id)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, int>> getDailyAttendanceCount(
      String classId, DateTime date) async {
    try {
      final dateStr = date.toIso8601String().substring(0, 10);
      final data = await _client
          .from('attendance')
          .select('status')
          .eq('class_id', classId)
          .eq('date', dateStr);
      int present = 0, absent = 0;
      for (var record in data) {
        if (record['status'] == 'present') present++;
        if (record['status'] == 'absent') absent++;
      }
      return {'present': present, 'absent': absent};
    } catch (e) {
      return {'present': 0, 'absent': 0};
    }
  }

  /// Returns true if any attendance records exist for classId on today's date.
  Future<bool> isAttendanceDoneToday(String classId) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final data = await _client
          .from('attendance')
          .select('id')
          .eq('class_id', classId)
          .eq('date', today)
          .limit(1);
      return data.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ── Homework ──────────────────────────────────────────────────────────────

  Future<void> saveHomework({
    required String classId,
    required String subject,
    required String description,
  }) async {
    final row = {
      'class_id': classId,
      'subject': subject,
      'description': description,
      'assigned_date': DateTime.now().toIso8601String().substring(0, 10),
      'assigned_by': _uid,
    };
    try {
      await _client.from('homework').insert(row);
      await _logActivity('homework_marked', classId, {'subject': subject});
    } catch (_) {
      await _outbox.enqueue('homework', row);
    }
  }

  Future<List<Homework>> getHomeworkForClass(String classId) async {
    try {
      final data = await _client
          .from('homework')
          .select()
          .eq('class_id', classId)
          .order('assigned_date', ascending: false)
          .limit(30);
      return data.map<Homework>((e) => Homework.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Homework>> getHomeworkForDate(String classId, DateTime date) async {
    try {
      final data = await _client
          .from('homework')
          .select()
          .eq('class_id', classId)
          .eq('assigned_date', date.toIso8601String().substring(0, 10))
          .order('subject');
      return data.map<Homework>((e) => Homework.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> markHomeworkStatus({
    required String homeworkId,
    required String studentId,
    required String status,
  }) async {
    final row = {
      'homework_id': homeworkId,
      'student_id': studentId,
      'status': status,
      'marked_by': _uid,
      'marked_at': DateTime.now().toIso8601String(),
    };
    try {
      await _client.from('homework_status').upsert(
        row,
        onConflict: 'homework_id,student_id',
      );
    } catch (_) {
      await _outbox.enqueue('homework_status', row);
    }
  }

  Future<List<HomeworkStatusRecord>> getHomeworkStatus(String homeworkId) async {
    try {
      final data = await _client
          .from('homework_status')
          .select('*, students(full_name)')
          .eq('homework_id', homeworkId);
      return data.map<HomeworkStatusRecord>((e) => HomeworkStatusRecord.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Student>> getPendingHomeworkStudents(
      String classId, String homeworkId) async {
    try {
      final statusData = await _client
          .from('homework_status')
          .select('student_id, status')
          .eq('homework_id', homeworkId)
          .inFilter('status', ['incomplete', 'not_checked']);
      final allStudents = await students(classId);
      if (statusData.isEmpty) return allStudents;
      final pendingIds = statusData.map((e) => e['student_id'] as String).toSet();
      return allStudents.where((s) => pendingIds.contains(s.id)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── WhatsApp Notifications Tracking ──────────────────────────────────────

  /// Record that we opened WhatsApp for a student (attendance notification).
  Future<void> markWhatsAppSent({
    required String classId,
    required String studentId,
    required DateTime date,
    required String type, // 'absent' | 'present' | 'homework'
    String? subject,
  }) async {
    try {
      await _client.from('whatsapp_notifications').upsert({
        'class_id': classId,
        'student_id': studentId,
        'notification_date': date.toIso8601String().substring(0, 10),
        'notification_type': type,
        'subject': subject,
        'notified_at': DateTime.now().toIso8601String(),
        'notified_by': _uid,
      }, onConflict: 'student_id,notification_date,notification_type,subject');
      await _logActivity('whatsapp_sent', classId, {'type': type});
    } catch (_) {}
  }

  /// Returns Set of studentIds that have been notified for given date+type.
  Future<Set<String>> getWhatsAppSentStudents({
    required String classId,
    required DateTime date,
    required String type,
    String? subject,
  }) async {
    try {
      var query = _client
          .from('whatsapp_notifications')
          .select('student_id')
          .eq('class_id', classId)
          .eq('notification_date', date.toIso8601String().substring(0, 10))
          .eq('notification_type', type);
      if (subject != null) {
        query = query.eq('subject', subject);
      }
      final data = await query;
      return data.map<String>((e) => e['student_id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  // ── WhatsApp Group Links ──────────────────────────────────────────────────

  Future<String?> getWhatsAppGroupLink(String classId) async {
    try {
      final data = await _client
          .from('class_whatsapp_groups')
          .select('group_link')
          .eq('class_id', classId)
          .maybeSingle();
      return data?['group_link'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveWhatsAppGroupLink(String classId, String groupLink) async {
    try {
      await _client.from('class_whatsapp_groups').upsert({
        'class_id': classId,
        'group_link': groupLink.trim(),
        'updated_by': _uid,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'class_id');
    } catch (e) {
      rethrow;
    }
  }

  // ── Notices ───────────────────────────────────────────────────────────────

  Future<void> createNotice({
    required String title,
    required String body,
    String? audienceClassId,
    String? audienceStudentId,
  }) async {
    final row = {
      'title': title,
      'body': body,
      'audience_class_id': audienceClassId,
      'audience_student_id': audienceStudentId,
      'created_by': _uid,
      'created_at': DateTime.now().toIso8601String(),
    };
    try {
      await _client.from('notices').insert(row);
      await _logActivity('notice_sent', audienceClassId ?? '', {'title': title});
    } catch (_) {
      await _outbox.enqueue('notices', row);
    }
  }

  Future<List<Notice>> getNotices(String classId) async {
    try {
      final data = await _client
          .from('notices')
          .select()
          .or('audience_class_id.eq.$classId,audience_class_id.is.null')
          .order('created_at', ascending: false)
          .limit(20);
      return data.map<Notice>((e) => Notice.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // ── Activity ──────────────────────────────────────────────────────────────

  Future<void> _logActivity(
      String type, String classId, Map<String, dynamic> details) async {
    try {
      await _client.from('teacher_activity').insert({
        'teacher_id': _uid,
        'class_id': classId.isEmpty ? '00000000-0000-0000-0000-000000000000' : classId,
        'activity_type': type,
        'activity_date': DateTime.now().toIso8601String().substring(0, 10),
        'details': details,
      });
    } catch (_) {}
  }

  Future<List<TeacherActivity>> getTeacherActivityLog(String teacherId) async {
    try {
      final data = await _client
          .from('teacher_activity')
          .select()
          .eq('teacher_id', teacherId)
          .order('created_at', ascending: false)
          .limit(50);
      return data.map<TeacherActivity>((e) => TeacherActivity.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // ── CSV Import/Export ─────────────────────────────────────────────────────

  Future<String> exportStudentsToCSV(String classId) async {
    try {
      final studentList = await students(classId);
      List<List<dynamic>> rows = [];
      rows.add(['Roll No', 'Full Name', 'Father Name', 'WhatsApp', 'DOB', 'Fee Status']);
      for (var student in studentList) {
        rows.add([
          student.rollNo,
          student.fullName,
          student.parentName,
          student.whatsapp,
          student.dob?.toString().split(' ')[0] ?? '',
          student.feeStatus.name,
        ]);
      }
      return const ListToCsvConverter().convert(rows);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> importStudentsFromBytes(String classId, Uint8List csvBytes) async {
    try {
      final contents = String.fromCharCodes(csvBytes);
      final rowsAsListOfValues = const CsvToListConverter().convert(contents);
      if (rowsAsListOfValues.isEmpty) return;
      for (int i = 1; i < rowsAsListOfValues.length; i++) {
        final row = rowsAsListOfValues[i];
        if (row.length < 2) continue;
        final studentData = {
          'class_id': classId,
          'roll_no': row[0].toString(),
          'full_name': row[1].toString(),
          'father_name': row.length > 2 ? row[2].toString() : '',
          'whatsapp': row.length > 3 ? row[3].toString() : '',
          'dob': row.length > 4 && row[4].toString().isNotEmpty ? row[4].toString() : null,
          'fee_status': row.length > 5 ? row[5].toString() : 'due',
          'active': true,
        };
        try {
          await _client.from('students').upsert(studentData, onConflict: 'class_id,roll_no');
        } catch (_) {}
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> importStudentsFromCSV(String classId, dynamic csvFile) async {
    if (kIsWeb) throw UnsupportedError('Use importStudentsFromBytes on web');
    final bytes = await (csvFile as File).readAsBytes();
    await importStudentsFromBytes(classId, bytes);
  }

  // ── Admin ─────────────────────────────────────────────────────────────────

  Future<List<ClassRoom>> getAllClasses() async {
    final data = await _client.from('classes').select().order('name');
    return data.map<ClassRoom>((e) => ClassRoom.fromMap(e)).toList();
  }

  Future<void> saveClass({
    String? id,
    required String name,
    required String section,
    String academicYear = '',
  }) async {
    final row = <String, dynamic>{
      'name': name.trim(),
      'section': section.trim(),
      'academic_year': academicYear.trim().isNotEmpty
          ? academicYear.trim()
          : '${DateTime.now().year}-${(DateTime.now().year + 1).toString().substring(2)}',
    };
    if (id != null) {
      await _client.from('classes').update(row).eq('id', id);
    } else {
      await _client.from('classes').insert(row);
    }
  }

  Future<void> deleteClass(String classId) async {
    await _client.from('classes').delete().eq('id', classId);
  }

  Future<List<TeacherProfile>> getAllTeachers() async {
    final data = await _client.from('profiles').select().order('full_name');
    return data.map<TeacherProfile>((e) => TeacherProfile.fromMap(e)).toList();
  }

  Future<void> updateTeacherProfile({
    required String id,
    required String fullName,
    String phone = '',
    String role = 'teacher',
  }) async {
    await _client.from('profiles').update({
      'full_name': fullName.trim(),
      'phone': phone.trim(),
      'role': role,
    }).eq('id', id);
  }

  Future<List<ClassRoom>> getTeacherAssignedClasses(String teacherId) async {
    final data = await _client
        .from('teacher_classes')
        .select('classes(id,name,section)')
        .eq('teacher_id', teacherId);
    return data
        .map<ClassRoom>((e) => ClassRoom.fromMap(e['classes'] as Map<String, dynamic>))
        .toList();
  }

  Future<void> assignTeacherToClass(String teacherId, String classId) async {
    await _client.from('teacher_classes').upsert(
      {'teacher_id': teacherId, 'class_id': classId},
      onConflict: 'teacher_id,class_id',
    );
  }

  Future<void> removeTeacherFromClass(String teacherId, String classId) async {
    await _client
        .from('teacher_classes')
        .delete()
        .eq('teacher_id', teacherId)
        .eq('class_id', classId);
  }

  Future<List<Student>> getAllStudents() async {
    final data = await _client
        .from('students')
        .select('*, classes(name, section)')
        .eq('active', true)
        .order('full_name');
    return data.map<Student>((e) => Student.fromMap(e)).toList();
  }

  Future<void> moveStudentToClass(String studentId, String classId) async {
    await _client.from('students').update({'class_id': classId}).eq('id', studentId);
  }

  Future<void> deleteStudent(String studentId) async {
    await _client.from('students').delete().eq('id', studentId);
  }

  Future<void> sync() => _outbox.flush();
}
