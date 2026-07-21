import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/providers.dart';

class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('NEMPS',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                ref.watch(themeProvider) == ThemeMode.dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                color: Colors.white,
              ),
              tooltip: 'Theme toggle',
              onPressed: () {
                final current = ref.read(themeProvider);
                ref.read(themeProvider.notifier).state =
                    current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
              },
            ),
            IconButton(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              tooltip: 'Sign out',
            ),
          ],
        ),
        body: child,
      );
}
