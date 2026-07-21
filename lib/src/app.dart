import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'features/data/providers.dart';
import 'features/presentation/screens.dart';
import 'features/examination/presentation/marks_entry_screen.dart';
import 'features/examination/presentation/result_screen.dart';
import 'features/examination/presentation/report_card_screen.dart';

/// Notifier that GoRouter listens to for auth state changes.
/// This ensures the router re-evaluates redirects when Supabase restores
/// a persisted session — fixing the "bar bar login" issue.
class _AuthNotifier extends ValueNotifier<User?> {
  _AuthNotifier()
      : super(Supabase.instance.client.auth.currentUser) {
    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      value = event.session?.user;
      // Schedule daily reminders when user signs in
      if (event.event == AuthChangeEvent.signedIn) {
        NotificationService.scheduleDailyAttendanceReminder();
        NotificationService.scheduleDailyHomeworkReminder();
      }
    });
  }
}

final _authNotifier = _AuthNotifier();

class NempsApp extends ConsumerWidget {
  const NempsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      initialLocation: '/dashboard',
      refreshListenable: _authNotifier,
      redirect: (context, state) {
        final signedIn = _authNotifier.value != null;
        final publicRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/signup';
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
          builder: (_, s) => ShellScreen(
              child: ClassDetailScreen(classId: s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/attendance/:id',
          builder: (_, s) => ShellScreen(
              child: AttendanceScreen(classId: s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/students/:id',
          builder: (_, s) => ShellScreen(
              child: StudentsScreen(classId: s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/homework/:id',
          builder: (_, s) => ShellScreen(
              child: HomeworkScreen(classId: s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/absent/:id',
          builder: (_, s) => ShellScreen(
              child: AbsentNotifyScreen(classId: s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/reports',
          builder: (_, __) => const ShellScreen(child: ReportsScreen()),
        ),
        GoRoute(
          path: '/admin',
          builder: (_, __) => const ShellScreen(child: AdminPanelScreen()),
        ),
        // ── Phase 4: Marks Entry ──────────────────────────────────────────
        GoRoute(
          path: '/exam-marks/:id',
          builder: (_, s) => ShellScreen(
              child: MarksEntryScreen(classId: s.pathParameters['id']!)),
        ),
        // ── Phase 5: Result Engine ────────────────────────────────────────
        GoRoute(
          path: '/results/:id',
          builder: (_, s) => ShellScreen(
              child: ResultScreen(classId: s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/report-card/:classId/:studentId',
          builder: (_, s) {
            final args = s.extra as ReportCardArgs;
            return ShellScreen(
              child: ReportCardScreen(
                classId: s.pathParameters['classId']!,
                studentId: s.pathParameters['studentId']!,
                args: args,
              ),
            );
          },
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
