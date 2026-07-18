import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'features/data/providers.dart';
import 'features/presentation/screens.dart';

class NempsApp extends ConsumerWidget {
  const NempsApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      initialLocation: '/dashboard',
      redirect: (context, state) {
        final signedIn = Supabase.instance.client.auth.currentSession != null;
        final publicRoute = state.matchedLocation == '/login' || state.matchedLocation == '/signup';
        if (!signedIn && !publicRoute) return '/login';
        if (signedIn && publicRoute) return '/dashboard';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const ShellScreen(child: DashboardScreen()),
        ),
        GoRoute(
          path: '/class/:id',
          builder: (_, s) => ShellScreen(child: ClassDetailScreen(classId: s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/attendance/:id',
          builder: (_, s) => ShellScreen(child: AttendanceScreen(classId: s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/students/:id',
          builder: (_, s) => ShellScreen(child: StudentsScreen(classId: s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/homework/:id',
          builder: (_, s) => ShellScreen(child: HomeworkScreen(classId: s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/absent/:id',
          builder: (_, s) => ShellScreen(child: AbsentNotifyScreen(classId: s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/reports',
          builder: (_, __) => const ShellScreen(child: ReportsScreen()),
        ),
        GoRoute(
          path: '/admin',
          builder: (_, __) => const ShellScreen(child: AdminPanelScreen()),
        ),
      ],
    );
    return MaterialApp.router(
      title: 'NEMPS Teacher Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeProvider),
      routerConfig: router,
    );
  }
}
