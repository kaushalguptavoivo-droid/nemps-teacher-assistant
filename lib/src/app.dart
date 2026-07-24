import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'features/data/providers.dart';
import 'features/presentation/screens.dart';
import 'features/presentation/new_shell_screen.dart';
import 'features/examination/presentation/marks_entry_screen.dart';
import 'features/examination/presentation/result_screen.dart';
import 'features/examination/presentation/report_card_screen.dart';
import 'features/examination/presentation/bulk_print_screen.dart';
import 'features/examination/presentation/promotion_screen.dart';
import 'features/examination/presentation/analytics_screen.dart';
// Feature 1: Attendance Register (new independent module)
import 'features/presentation/attendance_register_screen.dart';

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

class NempsApp extends ConsumerStatefulWidget {
  const NempsApp({super.key});

  @override
  ConsumerState<NempsApp> createState() => _NempsAppState();
}

class _NempsAppState extends ConsumerState<NempsApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
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
          builder: (_, __) => const NewShellScreen(child: DashboardScreen()),
        ),
        GoRoute(
          path: '/class/:id',
          builder: (_, s) => NewShellScreen(
              child: ClassDetailScreen(classId: s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/attendance/:id',
          builder: (_, s) => NewShellScreen(
              child: AttendanceScreen(classId: s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/students/:id',
          builder: (_, s) => NewShellScreen(
              child: StudentsScreen(classId: s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/homework/:id',
          builder: (_, s) => NewShellScreen(
              child: HomeworkScreen(classId: s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/absent/:id',
          builder: (_, s) => NewShellScreen(
              child: AbsentNotifyScreen(classId: s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/reports',
          builder: (_, __) => const NewShellScreen(child: ReportsScreen()),
        ),
        GoRoute(
          path: '/admin',
          builder: (_, __) => const NewShellScreen(child: AdminPanelScreen()),
        ),
        // ── Phase 4: Marks Entry ──────────────────────────────────────────
        GoRoute(
          path: '/exam-marks/:id',
          builder: (_, s) => NewShellScreen(
              child: MarksEntryScreen(classId: s.pathParameters['id']!)),
        ),
        // ── Phase 5: Result Engine ────────────────────────────────────────
        GoRoute(
          path: '/results/:id',
          builder: (_, s) => NewShellScreen(
              child: ResultScreen(classId: s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/report-card/:classId/:studentId',
          builder: (_, s) {
            final args = s.extra as ReportCardArgs;
            return NewShellScreen(
              child: ReportCardScreen(
                classId: s.pathParameters['classId']!,
                studentId: s.pathParameters['studentId']!,
                args: args,
              ),
            );
          },
        ),
        // ── Phase 6: Bulk PDF Print ───────────────────────────────────────
        GoRoute(
          path: '/bulk-print/:classId',
          builder: (_, s) {
            final args = s.extra as BulkPrintArgs;
            return NewShellScreen(
              child: BulkPrintScreen(
                classId: s.pathParameters['classId']!,
                args: args,
              ),
            );
          },
        ),
        // ── Phase 7: Promotion Engine ─────────────────────────────────────
        GoRoute(
          path: '/promotion',
          builder: (_, __) =>
              const NewShellScreen(child: PromotionScreen()),
        ),
        // ── Phase 8: Analytics ────────────────────────────────────────────
        GoRoute(
          path: '/analytics',
          builder: (_, __) =>
              const NewShellScreen(child: AnalyticsScreen()),
        ),
        // ── Feature 1: Attendance Register ───────────────────────────────
        GoRoute(
          path: '/attendance-register/:id',
          builder: (_, s) => NewShellScreen(
              child: AttendanceRegisterScreen(
                  classId: s.pathParameters['id']!)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NEMPS Teacher Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeProvider),
      routerConfig: _router,
    );
  }
}
