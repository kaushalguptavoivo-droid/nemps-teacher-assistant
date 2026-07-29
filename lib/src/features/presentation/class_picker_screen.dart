// Class Picker Screen
//
// Phase 3A fix: "Students", "Attendance", and "Homework" in the bottom nav
// all used to route to '/dashboard' — the same screen — because those
// actions genuinely need a class selected first and there was no dedicated
// landing screen for that. Tapping any of the three looked identical and
// did nothing distinct.
//
// This is a single reusable "pick a class, then go do X" screen. Each nav
// item now gets its own route pointing here with a different action label/
// icon/destination, so the nav is real instead of decorative.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../data/providers.dart';

class ClassPickerScreen extends ConsumerWidget {
  const ClassPickerScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.destinationBuilder,
  });

  /// Screen title shown in the app bar, e.g. "Attendance".
  final String title;

  /// One-line helper text shown above the list, e.g.
  /// "Attendance lene ke liye class chunein".
  final String subtitle;

  final IconData icon;

  /// Given the chosen class id, returns the route to push, e.g.
  /// (id) => '/attendance/$id'.
  final String Function(String classId) destinationBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(classesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(classesProvider),
        child: classes.when(
          data: (rooms) {
            if (rooms.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  Icon(Icons.class_outlined, size: 56, color: Colors.grey),
                  SizedBox(height: 12),
                  Center(
                    child: Text('Koi class nahi mili.',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 12),
                ...rooms.map((room) => Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary.withOpacity(0.12),
                          child: Icon(icon, color: AppTheme.primary),
                        ),
                        title: Text('Class ${room.label}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () =>
                            context.go(destinationBuilder(room.id)),
                      ),
                    )),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}
