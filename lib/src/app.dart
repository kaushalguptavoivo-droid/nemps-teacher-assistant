import 'package:flutter/material.dart';
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
// Feature 2: Fee Collection direct access
import 'features/fees/presentation/fee_collection_screen.dart';
// Phase 3A: dedicated class-picker landing screens for nav items that
// previously all pointed at '/dashboard'.
import 'features/presentation/class_picker_screen.dart';
// Phase 3B/3C: dedicated Admin/Fees/Exam screens (replaces nested tabs).
import 'features/presentation/admin_panel_screen.dart';
import 'features/fees/presentation/fee_config_screen.dart';
import 'features/fees/presentation/fees_home_screen.dart';
import 'features/fees/presentation/fee_reports_screen.dart';
import 'features/examination/presentation/admin_exam_tab.dart';

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

// Route builders for ClassPickerScreen (Phase 3A) — kept as top-level
// functions so they're const-constructor-compatible.
String _studentsRoute(String classId) => '/students/$classId';
String _attendanceRoute(String classId) => '/attendance/$classId';
String _homeworkRoute(String classId) => '/homework/$classId';

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
        GoRoute(
          path: '/fee-collection',
          builder: (_, __) =>
              const NewShellScreen(child: FeeCollectionScreen()),
        ),
        // ── Phase 3A: dedicated nav landing screens ─────────────────────
        // "Students" / "Attendance" / "Homework" each need a class picked
        // first — these give each its own real screen instead of all three
        // silently falling back to '/dashboard'.
        GoRoute(
          path: '/students-home',
          builder: (_, __) => const NewShellScreen(
            child: ClassPickerScreen(
              title: 'Students',
              subtitle: 'Students dekhne ke liye class chunein',
              icon: Icons.people_rounded,
              destinationBuilder: _studentsRoute,
            ),
          ),
        ),
        GoRoute(
          path: '/attendance-home',
          builder: (_, __) => const NewShellScreen(
            child: ClassPickerScreen(
              title: 'Attendance',
              subtitle: 'Attendance lene ke liye class chunein',
              icon: Icons.check_circle_rounded,
              destinationBuilder: _attendanceRoute,
            ),
          ),
        ),
        GoRoute(
          path: '/homework-home',
          builder: (_, __) => const NewShellScreen(
            child: ClassPickerScreen(
              title: 'Homework',
              subtitle: 'Homework dene/check karne ke liye class chunein',
              icon: Icons.assignment_rounded,
              destinationBuilder: _homeworkRoute,
            ),
          ),
        ),
        // ── Phase 3B: Admin Panel split into dedicated screens ────────────
        GoRoute(
          path: '/admin/classes',
          builder: (_, __) => const NewShellScreen(child: AdminClassesScreen()),
        ),
        GoRoute(
          path: '/admin/students',
          builder: (_, __) => const NewShellScreen(child: AdminStudentsScreen()),
        ),
        GoRoute(
          path: '/admin/teachers',
          builder: (_, __) => const NewShellScreen(child: AdminTeachersScreen()),
        ),
        GoRoute(
          path: '/admin/notices',
          builder: (_, __) => const NewShellScreen(child: AdminNoticesScreen()),
        ),
        GoRoute(
          path: '/admin/activity',
          builder: (_, __) => const NewShellScreen(child: AdminActivityScreen()),
        ),
        GoRoute(
          path: '/admin/exams',
          builder: (_, __) => NewShellScreen(
            child: Scaffold(
              appBar: AppBar(title: const Text('Exam Management')),
              body: const AdminExamTab(),
            ),
          ),
        ),
        // ── Phase 3C: Fees Management split into dedicated screens ────────
        GoRoute(
          path: '/admin/fees',
          builder: (_, __) => const NewShellScreen(child: FeesHomeScreen()),
        ),
        GoRoute(
          path: '/admin/fees/types',
          builder: (_, __) => const NewShellScreen(child: FeeTypesScreen()),
        ),
        GoRoute(
          path: '/admin/fees/class-config',
          builder: (_, __) => const NewShellScreen(child: ClassFeeConfigScreen()),
        ),
        GoRoute(
          path: '/admin/fees/reports',
          builder: (_, __) => const NewShellScreen(child: FeeReportsScreen()),
        ),
        GoRoute(
          path: '/admin/fees/advanced',
          builder: (_, __) => const NewShellScreen(child: FeeConfigScreen()),
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
