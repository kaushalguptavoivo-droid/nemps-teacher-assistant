import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

class OfflineQueue {
  final SupabaseClient _client;
  Box<Map>? _queue;

  OfflineQueue(this._client);

  Future<Box<Map>> _getQueue() async {
    if (_queue != null && _queue!.isOpen) return _queue!;
    // Box is already opened in main.dart; just reference it here.
    _queue = Hive.box<Map>('nemps_offline_queue');
    return _queue!;
  }

  Future<void> enqueue(String table, Map<String, dynamic> row) async {
    final queue = await _getQueue();
    final key = '${table}_${DateTime.now().millisecondsSinceEpoch}';
    await queue.put(key, {'table': table, 'data': row});
  }

  /// The natural conflict key for a row, so we can tell whether two queued
  /// entries refer to the *same* underlying row. Without this, replaying an
  /// old queued write after a newer save for the same row could silently
  /// revert it back to the stale value.
  String? _identityKey(String table, Map<String, dynamic> data) {
    switch (table) {
      case 'attendance':
        final studentId = data['student_id'];
        final date = data['date'];
        if (studentId == null || date == null) return null;
        return '$studentId|$date';
      case 'homework_status':
        final homeworkId = data['homework_id'];
        final studentId = data['student_id'];
        if (homeworkId == null || studentId == null) return null;
        return '$homeworkId|$studentId';
      default:
        return null; // no safe natural key — replay as-is, no dedup
    }
  }

  Future<void> flush() async {
    final queue = await _getQueue();
    if (queue.isEmpty) return;

    // Pass 1: for rows we can identify, keep only the most recently queued
    // entry per (table, identity) and drop older duplicates so a stale
    // write can never win over a fresher one queued after it.
    final keys = queue.keys.toList();
    final latestKeyForIdentity = <String, dynamic>{};
    for (final key in keys) {
      final entry = queue.get(key);
      if (entry == null) continue;
      final table = entry['table'] as String;
      final data = Map<String, dynamic>.from(entry['data'] as Map);
      final identity = _identityKey(table, data);
      if (identity == null) continue;
      final compositeKey = '$table::$identity';
      final prevKey = latestKeyForIdentity[compositeKey];
      // Keys embed a millisecond timestamp, so string comparison after the
      // table prefix reflects insertion order — the later key is the
      // more recent write.
      if (prevKey != null) {
        await queue.delete(prevKey);
      }
      latestKeyForIdentity[compositeKey] = key;
    }

    // Pass 2: attempt to sync whatever remains.
    for (final key in queue.keys.toList()) {
      final entry = queue.get(key);
      if (entry == null) continue;
      try {
        final table = entry['table'] as String;
        final data = Map<String, dynamic>.from(entry['data'] as Map);
        final identity = _identityKey(table, data);
        if (table == 'attendance' && identity != null) {
          // Same reasoning as the live save path: target the real unique
          // constraint, not the synthetic id, so a legacy row under a
          // different id can't block this from ever syncing.
          await _client
              .from(table)
              .upsert(data, onConflict: 'student_id,date');
        } else if (table == 'homework_status' && identity != null) {
          await _client
              .from(table)
              .upsert(data, onConflict: 'homework_id,student_id');
        } else {
          await _client.from(table).upsert(data);
        }
        await queue.delete(key); // FIX: was delete(entry) — must delete by key
      } catch (_) {}
    }
  }
}

