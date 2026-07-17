import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Durable outbox: actions remain on device and replay when a connection returns.
class OfflineQueue {
  OfflineQueue(this._client);
  final SupabaseClient _client;
  Box<Map> get _box => Hive.box<Map>('nemps_offline_queue');
  Future<void> enqueue(String table, Map<String, dynamic> row) async => _box.put(row['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(), {'table': table, 'row': jsonEncode(row)});
  Future<void> flush() async {
    final pending = Map<dynamic, Map>.from(_box.toMap());
    for (final entry in pending.entries) {
      try { await _client.from(entry.value['table'] as String).upsert(jsonDecode(entry.value['row'] as String)); await _box.delete(entry.key); } catch (_) { /* retry later */ }
    }
  }
}
