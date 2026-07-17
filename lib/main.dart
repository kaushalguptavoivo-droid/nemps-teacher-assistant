import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  const secureStorage = FlutterSecureStorage();
  var key = await secureStorage.read(key: 'nemps_hive_aes_key');
  if (key == null) {
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    key = base64UrlEncode(bytes);
    await secureStorage.write(key: 'nemps_hive_aes_key', value: key);
  }
  await Hive.openBox<Map>('nemps_offline_queue', encryptionCipher: HiveAesCipher(Uint8List.fromList(base64Url.decode(key))));
  await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseAnonKey);
  runApp(const ProviderScope(child: NempsApp()));
}
