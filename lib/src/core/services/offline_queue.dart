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

  Future<void> flush() async {
    final queue = await _getQueue();
    if (queue.isEmpty) return;

    final keys = queue.keys.toList();
    for (final key in keys) {
      final entry = queue.get(key);
      if (entry == null) continue;
      try {
        final table = entry['table'] as String;
        final data = Map<String, dynamic>.from(entry['data'] as Map);
        await _client.from(table).upsert(data);
        await queue.delete(key); // FIX: was delete(entry) — must delete by key
      } catch (_) {}
    }
  }
}
