import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import '../../core/models/models.dart';
import '../../core/services/offline_queue.dart';

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
        onConflict: 'student_id,date',
      );
      await _logActivity('attendance_marked', classId, {'students': 1});
    } catch (_) {
      await _outbox.enqueue('attendance', row);
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
      final students = await this.students(classId);
      return students.where((s) => absentIds.contains(s.id)).toList();
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

  Future<void> _logActivity(String type, String classId, Map<String, dynamic> details) async {
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
      String csv = const ListToCsvConverter().convert(rows);
      return csv;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> importStudentsFromCSV(String classId, File csvFile) async {
    try {
      final contents = await csvFile.readAsString();
      List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter().convert(contents);
      
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

  Future<Map<String, int>> getDailyAttendanceCount(String classId, DateTime date) async {
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
