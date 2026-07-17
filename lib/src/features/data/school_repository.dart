import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/models.dart';
import '../../core/services/offline_queue.dart';

class SchoolRepository {
  SchoolRepository(this._client) : _outbox = OfflineQueue(_client);
  final SupabaseClient _client;
  late final OfflineQueue _outbox;

  Future<List<ClassRoom>> myClasses() async => (await _client.from('teacher_classes').select('classes(id,name,section)').eq('teacher_id', _client.auth.currentUser!.id)).map((e) => ClassRoom.fromMap(e['classes'])).toList();
  Future<List<Student>> students(String classId) async => (await _client.from('students').select().eq('class_id', classId).eq('active', true).order('roll_no')).map(Student.fromMap).toList();
  Future<void> saveAttendance({required String classId, required String studentId, required AttendanceStatus status, required DateTime date}) async {
    final row = {'id': '${studentId}_${date.toIso8601String().substring(0,10)}', 'class_id': classId, 'student_id': studentId, 'date': date.toIso8601String().substring(0,10), 'status': status.name, 'marked_by': _client.auth.currentUser!.id};
    try { await _client.from('attendance').upsert(row, onConflict: 'student_id,date'); } catch (_) { await _outbox.enqueue('attendance', row); }
  }
  Future<void> saveHomework(Map<String,dynamic> row) async { try { await _client.from('homework').upsert(row); } catch (_) { await _outbox.enqueue('homework', row); } }
  Future<void> sync() => _outbox.flush();
}
