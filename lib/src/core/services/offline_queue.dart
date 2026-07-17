import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

class OfflineQueue {
  final SupabaseClient _client;
  late final Box<Map> _queue;

  OfflineQueue(this._client);

  Future<void> enqueue(String table, Map<String, dynamic> row) async {
    await Hive.openBox<Map>('nemps_offline_queue');
    _queue = Hive.box('nemps_offline_queue');
    final key = '${table}_${DateTime.now().millisecondsSinceEpoch}';
    await _queue.put(key, {'table': table, 'data': row});
  }

  Future<void> flush() async {
    if (_queue.isEmpty) return;
    
    final entries = _queue.values.toList();
    for (var entry in entries) {
      try {
        final table = entry['table'];
        final data = entry['data'];
        await _client.from(table).upsert(data);
        await _queue.delete(entry);
      } catch (_) {}
    }
  }
}
