import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/models.dart';
import 'school_repository.dart';

final repoProvider = Provider((_) => SchoolRepository(Supabase.instance.client));
final classesProvider = FutureProvider<List<ClassRoom>>((ref) => ref.watch(repoProvider).myClasses());
final studentsProvider = FutureProvider.family<List<Student>, String>((ref, classId) => ref.watch(repoProvider).students(classId));
final themeProvider = StateProvider<ThemeMode>((_) => ThemeMode.system);
