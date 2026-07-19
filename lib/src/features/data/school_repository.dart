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

  Future<List<ClassRoom>> myClasses() async {
    try {
      final data = await _client
          .from('teacher_classes')
          .select('classes(id,name,section)')
          .eq('teacher_id', _client.auth.currentUser!.id);
      return data.map<ClassRoom>((e) => ClassRoom.fromMap(e['classes'])).toList();
    } catch (e) {
      rethrow;
    }
  }

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
      'marked_by': _client.auth.currentUser!.id,
      'marked_at': DateTime.now().toIso8601String(),
    };
    try {
      await _client.from('attendance').upsert(
        row,
        onConflict: 'id',          // PK is the composite id field, not a separate unique index
      );
      await _logActivity('attendance_marked', classId, {'students': 1});
    } catch (_) {
      await _outbox.enqueue('attendance', row);
    }
  }

  /// Returns a map of studentId -> AttendanceStatus for the given class and date.
  /// Used to preload the attendance screen when changing dates.
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
      'assigned_by': _client.auth.currentUser!.id,
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
          .limit(10);
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
      'marked_by': _client.auth.currentUser!.id,
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

  /// Returns students with incomplete or not_checked homework for the given homework.
  Future<List<Student>> getPendingHomeworkStudents(
      String classId, String homeworkId) async {
    try {
      final statusData = await _client
          .from('homework_status')
          .select('student_id, status')
          .eq('homework_id', homeworkId)
          .inFilter('status', ['incomplete', 'not_checked']);

      final allStudents = await students(classId);

      if (statusData.isEmpty) {
        // No records at all → everyone is pending (not_checked)
        return allStudents;
      }

      final pendingIds = statusData.map((e) => e['student_id'] as String).toSet();
      return allStudents.where((s) => pendingIds.contains(s.id)).toList();
    } catch (_) {
      return [];
    }
  }

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
      'created_by': _client.auth.currentUser!.id,
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

  Future<void> _logActivity(
      String type, String classId, Map<String, dynamic> details) async {
    try {
      await _client.from('teacher_activity').insert({
        'teacher_id': _client.auth.currentUser!.id,
        'class_id': classId,
        'activity_type': type,
        'activity_date': DateTime.now().toIso8601String().substring(0, 10),
        'details': details,
      });
    } catch (_) {}
  }

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

  /// Import students from CSV bytes (works on both web and mobile).
  Future<void> importStudentsFromBytes(String classId, Uint8List csvBytes) async {
    try {
      final contents = String.fromCharCodes(csvBytes);
      final rowsAsListOfValues =
          const CsvToListConverter().convert(contents);

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
          'dob': row.length > 4 && row[4].toString().isNotEmpty
              ? row[4].toString()
              : null,
          'fee_status': row.length > 5 ? row[5].toString() : 'due',
          'active': true,
        };

        try {
          await _client.from('students').upsert(
            studentData,
            onConflict: 'class_id,roll_no',
          );
        } catch (_) {}
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Legacy mobile-only import using dart:io File. Kept for compatibility;
  /// prefer [importStudentsFromBytes] on all platforms.
  Future<void> importStudentsFromCSV(String classId, dynamic csvFile) async {
    Uint8List bytes;
    if (kIsWeb) {
      throw UnsupportedError('Use importStudentsFromBytes on web');
    }
    bytes = await (csvFile as File).readAsBytes();
    await importStudentsFromBytes(classId, bytes);
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

  Future<void> sync() => _outbox.flush();
}
