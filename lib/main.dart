import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/core/config/app_config.dart';
import 'src/core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // HiveAesCipher is NOT supported on web (Hive uses IndexedDB on web).
  // flutter_secure_storage on web uses localStorage; encryption unsupported,
  // so we open the box without a cipher on web.
  if (!kIsWeb) {
    const secureStorage = FlutterSecureStorage();
    var key = await secureStorage.read(key: 'nemps_hive_aes_key');
    if (key == null) {
      final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
      key = base64UrlEncode(bytes);
      await secureStorage.write(key: 'nemps_hive_aes_key', value: key);
    }
    await Hive.openBox<Map>(
      'nemps_offline_queue',
      encryptionCipher:
          HiveAesCipher(Uint8List.fromList(base64Url.decode(key))),
    );
  } else {
    // Web: open box without encryption (Hive uses IndexedDB, no AES support)
    await Hive.openBox<Map>('nemps_offline_queue');
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
    // Persist session so teachers don't have to login every time
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
    ),
  );

  // Initialize local notifications & schedule daily reminders
  await NotificationService.init();
  // Only schedule if a user is already logged in (session persisted)
  if (Supabase.instance.client.auth.currentSession != null) {
    unawaited(NotificationService.scheduleDailyAttendanceReminder());
    unawaited(NotificationService.scheduleDailyHomeworkReminder());
  }

  runApp(const ProviderScope(child: NempsApp()));
}

// ignore: unused_element
void unawaited(Future<void> f) {}
