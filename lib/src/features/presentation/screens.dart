import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' if (dart.library.html) 'package:nemps_teacher_assistant/src/core/stubs/io_stub.dart';

import '../../core/models/models.dart';
import '../data/providers.dart';

// ---------------------------------------------------------------------------
// Login
// ---------------------------------------------------------------------------

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  bool obscure = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );
      if (!mounted) return;
      context.go('/dashboard');
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.school_rounded,
                        size: 52,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('NEMPS Teacher Assistant',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const Text('New Era Modern Public School, Vrindavan'),
                    const SizedBox(height: 32),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          const InputDecoration(labelText: 'School email'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: password,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(obscure
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => obscure = !obscure),
                        ),
                      ),
                      onSubmitted: (_) => busy ? null : _signIn(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: busy ? null : _signIn,
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52)),
                      icon: busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.login),
                      label: Text(busy ? 'Signing in...' : 'Sign in'),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/signup'),
                        child: const Text('Create new account'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Signup
// ---------------------------------------------------------------------------

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final fullName = TextEditingController();
  final phone = TextEditingController();
  bool busy = false;
  bool agreeTerms = false;
  bool obscure = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    fullName.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (email.text.isEmpty ||
        password.text.isEmpty ||
        fullName.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }
    if (password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password must be at least 6 characters')),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await Supabase.instance.client.auth.signUp(
        email: email.text.trim(),
        password: password.text,
        data: {
          'full_name': fullName.text,
          'phone': phone.text,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Account created! Please check your email to verify.')),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) context.go('/login');
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create Account')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Join NEMPS',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const Text('Create your teacher account'),
                    const SizedBox(height: 24),
                    TextField(
                      controller: fullName,
                      decoration:
                          const InputDecoration(labelText: 'Full Name *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          const InputDecoration(labelText: 'School Email *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: password,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Password *',
                        helperText: 'At least 6 characters',
                        suffixIcon: IconButton(
                          icon: Icon(obscure
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => obscure = !obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                          labelText: 'Phone Number (optional)'),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Checkbox(
                          value: agreeTerms,
                          onChanged: (v) =>
                              setState(() => agreeTerms = v ?? false),
                        ),
                        const Expanded(
                          child:
                              Text('I agree to the terms & conditions'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: (busy || !agreeTerms) ? null : _signUp,
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52)),
                      icon: busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.person_add),
                      label:
                          Text(busy ? 'Creating account...' : 'Sign Up'),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text(
                            'Already have an account? Sign in'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Shell (AppBar + logout)
// ---------------------------------------------------------------------------

class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(
          title: const Text('NEMPS'),
          actions: [
            IconButton(
              icon: const Icon(Icons.brightness_6_outlined),
              tooltip: 'Toggle theme',
              onPressed: () {
                final current = ref.read(themeProvider);
                ref.read(themeProvider.notifier).state =
                    current == ThemeMode.dark
                        ? ThemeMode.light
                        : ThemeMode.dark;
              },
            ),
            IconButton(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
            ),
          ],
        ),
        body: child,
      );
}

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(classesProvider);
    final roleAsync = ref.watch(currentUserRoleProvider);
    final isAdmin = roleAsync.valueOrNull == UserRole.admin;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return RefreshIndicator(
      onRefresh: () => ref.read(repoProvider).sync(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(greeting,
              style: Theme.of(context).textTheme.headlineSmall),
          const Text('Finish today\'s work in a few taps.'),
          const SizedBox(height: 20),
          Text('My classes',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          classes.when(
            data: (items) => items.isEmpty
                ? const Card(
                    child: ListTile(
                        title: Text(
                            'No classes assigned yet. Ask your admin.')))
                : Column(
                    children: items
                        .map((room) => Card(
                              child: ListTile(
                                leading:
                                    CircleAvatar(child: Text(room.name)),
                                title: Text('Class ${room.label}'),
                                subtitle: const Text('Tap to manage'),
                                onTap: () =>
                                    context.go('/class/${room.id}'),
                              ),
                            ))
                        .toList(),
                  ),
            error: (error, _) => Card(
              child: ListTile(
                leading: const Icon(Icons.wifi_off, color: Colors.orange),
                title: const Text('Could not load classes'),
                subtitle: const Text('Pull down to retry'),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(classesProvider),
                ),
              ),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          const SizedBox(height: 20),
          Text('Quick actions',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: classes.valueOrNull?.isNotEmpty == true
                ? () => context.go(
                    '/attendance/${classes.value!.first.id}')
                : null,
            icon: const Icon(Icons.fact_check),
            label: const Text('Mark Attendance'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => context.go('/reports'),
            icon: const Icon(Icons.bar_chart),
            label: const Text('Reports'),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => context.go('/admin'),
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Admin Panel'),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Class Detail
// ---------------------------------------------------------------------------

class ClassDetailScreen extends ConsumerWidget {
  const ClassDetailScreen({super.key, required this.classId});
  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentsProvider(classId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Details'),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Import Students (CSV)'),
                onTap: () => _importStudents(context, ref, classId),
              ),
              PopupMenuItem(
                child: const Text('Export Students (CSV)'),
                onTap: () => _exportStudents(context, ref, classId),
              ),
            ],
          ),
        ],
      ),
      body: students.when(
        data: (items) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                  onPressed: () =>
                      context.go('/attendance/$classId'),
                  icon: const Icon(Icons.fact_check),
                  label: const Text('Attendance')),
              FilledButton.tonalIcon(
                  onPressed: () =>
                      context.go('/homework/$classId'),
                  icon: const Icon(Icons.assignment),
                  label: const Text('Homework')),
              FilledButton.tonalIcon(
                  onPressed: () => context.go('/absent/$classId'),
                  icon: const Icon(Icons.message),
                  label: const Text('WhatsApp')),
              FilledButton.tonalIcon(
                  onPressed: () =>
                      context.go('/students/$classId'),
                  icon: const Icon(Icons.people),
                  label: const Text('Students')),
            ]),
            const SizedBox(height: 16),
            Text('Students (${items.length})',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...items.map((student) => Card(
                  child: ListTile(
                    title: Text(student.fullName),
                    subtitle: Text(
                        'Roll: ${student.rollNo}  |  ${student.parentName}'),
                    leading: CircleAvatar(
                        child: Text(student.rollNo)),
                    trailing: student.whatsapp.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.message,
                                color: Colors.green),
                            tooltip: 'WhatsApp parent',
                            onPressed: () => _openWhatsApp(
                                context,
                                student.whatsapp,
                                'Namaste, ${student.parentName} ji! Aapke bache ${student.fullName} ke baare mein baat karni thi.'),
                          )
                        : null,
                  ),
                )),
          ],
        ),
        error: (error, _) =>
            Center(child: Text('Error loading class: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _importStudents(
      BuildContext context, WidgetRef ref, String classId) async {
    try {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
      if (result == null) return;

      Uint8List bytes;
      if (kIsWeb) {
        bytes = result.files.single.bytes!;
      } else {
        bytes = await File(result.files.single.path!).readAsBytes();
      }

      await ref
          .read(repoProvider)
          .importStudentsFromBytes(classId, bytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Students imported successfully')));
        ref.invalidate(studentsProvider(classId));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Import error: $e')));
      }
    }
  }

  Future<void> _exportStudents(
      BuildContext context, WidgetRef ref, String classId) async {
    try {
      final csv = await ref.read(repoProvider).exportStudentsToCSV(classId);
      // Show a dialog with the CSV content so the user can copy it
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Export: copy CSV below'),
            content: SingleChildScrollView(
              child: SelectableText(csv,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close')),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export error: $e')));
      }
    }
  }

  Future<void> _openWhatsApp(
      BuildContext context, String phone, String message) async {
    final uri = Uri.parse(
        'https://wa.me/${phone.replaceAll(RegExp(r'[^0-9]'), '')}?text=${Uri.encodeComponent(message)}');
    final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Could not open WhatsApp. Check the number.')));
    }
  }
}

// ---------------------------------------------------------------------------
// Students
// ---------------------------------------------------------------------------

class StudentsScreen extends ConsumerWidget {
  const StudentsScreen({super.key, required this.classId});
  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentsProvider(classId));
    return Scaffold(
      appBar: AppBar(title: const Text('Students')),
      body: students.when(
        data: (items) => ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (_, index) {
            final student = items[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(student.rollNo)),
                title: Text(student.fullName),
                subtitle: Text(
                    '${student.parentName}  |  ${student.whatsapp}'),
              ),
            );
          },
        ),
        error: (_, __) =>
            const Center(child: Text('Students unavailable offline')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Attendance
// ---------------------------------------------------------------------------

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key, required this.classId});
  final String classId;

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  final statuses = <String, AttendanceStatus>{};
  DateTime selectedDate = DateTime.now();
  bool saving = false;
  bool loadingExisting = false;

  @override
  void initState() {
    super.initState();
    _loadExistingAttendance();
  }

  Future<void> _loadExistingAttendance() async {
    if (!mounted) return;
    setState(() => loadingExisting = true);
    final existing = await ref
        .read(repoProvider)
        .getAttendanceForDate(widget.classId, selectedDate);
    if (!mounted) return;
    setState(() {
      statuses
        ..clear()
        ..addAll(existing);
      loadingExisting = false;
    });
  }

  Future<void> _changeDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
      await _loadExistingAttendance();
      ref.invalidate(dailyAttendanceCountProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(studentsProvider(widget.classId));
    final count = ref.watch(
        dailyAttendanceCountProvider((widget.classId, selectedDate)));

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: students.when(
        data: (items) => Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('dd MMM yyyy, EEEE')
                                  .format(selectedDate),
                              style:
                                  Theme.of(context).textTheme.titleMedium,
                            ),
                            count.when(
                              data: (data) => Text(
                                'Present: ${data['present'] ?? 0}  |  Absent: ${data['absent'] ?? 0}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall,
                              ),
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _changeDate,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: const Text('Change Date'),
                      ),
                    ],
                  ),
                  if (loadingExisting)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Mark all row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Expanded(
                      child: Text('Mark all as:',
                          style: TextStyle(fontSize: 13))),
                  TextButton(
                    onPressed: () => setState(() {
                      for (final s in items) {
                        statuses[s.id] = AttendanceStatus.present;
                      }
                    }),
                    child: const Text('All Present'),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => setState(() {
                      for (final s in items) {
                        statuses[s.id] = AttendanceStatus.absent;
                      }
                    }),
                    child: const Text('All Absent'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Student list
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, index) {
                  final student = items[index];
                  final status = statuses[student.id] ??
                      AttendanceStatus.present;
                  return ListTile(
                    leading: CircleAvatar(child: Text(student.rollNo)),
                    title: Text(student.fullName),
                    subtitle: Text(student.parentName,
                        style: const TextStyle(fontSize: 12)),
                    trailing: SegmentedButton<AttendanceStatus>(
                      segments: const [
                        ButtonSegment(
                            label: Text('P'),
                            value: AttendanceStatus.present,
                            icon: Icon(Icons.check, size: 14)),
                        ButtonSegment(
                            label: Text('A'),
                            value: AttendanceStatus.absent,
                            icon: Icon(Icons.close, size: 14)),
                      ],
                      selected: {status},
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor:
                            status == AttendanceStatus.absent
                                ? Colors.red.shade100
                                : Colors.green.shade100,
                      ),
                      onSelectionChanged: (s) =>
                          setState(() => statuses[student.id] = s.first),
                    ),
                  );
                },
              ),
            ),
            // Save button
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        setState(() => saving = true);
                        try {
                          for (final student in items) {
                            await ref.read(repoProvider).saveAttendance(
                                  classId: widget.classId,
                                  studentId: student.id,
                                  status: statuses[student.id] ??
                                      AttendanceStatus.present,
                                  date: selectedDate,
                                );
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Attendance saved!')));
                            ref.invalidate(dailyAttendanceCountProvider);
                          }
                        } finally {
                          if (mounted) setState(() => saving = false);
                        }
                      },
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                icon: saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(saving ? 'Saving...' : 'Save Attendance'),
              ),
            ),
          ],
        ),
        error: (error, _) =>
            Center(child: Text('Error loading students: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Homework
// ---------------------------------------------------------------------------

class HomeworkScreen extends ConsumerStatefulWidget {
  const HomeworkScreen({super.key, required this.classId});
  final String classId;

  @override
  ConsumerState<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends ConsumerState<HomeworkScreen> {
  String? selectedSubject;
  final subjects = [
    'Math',
    'English',
    'Hindi',
    'Science',
    'Social Studies'
  ];
  final descController = TextEditingController();

  @override
  void dispose() {
    descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homework = ref.watch(homeworkProvider(widget.classId));
    final isAfter1PM = DateTime.now().hour >= 13;

    return Scaffold(
      appBar: AppBar(title: const Text('Homework')),
      body: Column(
        children: [
          // Assign new homework
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assign Homework',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedSubject,
                  decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder()),
                  items: subjects
                      .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => selectedSubject = value),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: selectedSubject == null
                      ? null
                      : () async {
                          await ref.read(repoProvider).saveHomework(
                                classId: widget.classId,
                                subject: selectedSubject!,
                                description: descController.text,
                              );
                          if (mounted) {
                            descController.clear();
                            setState(() => selectedSubject = null);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Homework assigned')));
                            ref.invalidate(
                                homeworkProvider(widget.classId));
                          }
                        },
                  icon: const Icon(Icons.add),
                  label: const Text('Assign Homework'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Homework list
          Expanded(
            child: homework.when(
              data: (items) => items.isEmpty
                  ? const Center(child: Text('No homework assigned yet'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      itemBuilder: (_, index) {
                        final hw = items[index];
                        return Card(
                          child: Column(
                            children: [
                              ListTile(
                                title: Text(hw.subject,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  '${hw.description}\n${DateFormat('dd MMM yyyy').format(hw.assignedDate)}',
                                ),
                                isThreeLine: true,
                              ),
                              OverflowBar(
                                padding: const EdgeInsets.fromLTRB(
                                    8, 0, 8, 8),
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _markHomework(
                                        context, hw.id),
                                    icon: const Icon(Icons.edit_note,
                                        size: 18),
                                    label: const Text('Mark Status'),
                                  ),
                                  TextButton.icon(
                                    onPressed: isAfter1PM
                                        ? () =>
                                            _sendPendingWhatsApp(
                                                context, hw.id, hw.subject)
                                        : null,
                                    icon: Icon(
                                      Icons.message,
                                      size: 18,
                                      color: isAfter1PM
                                          ? Colors.green
                                          : null,
                                    ),
                                    label: Text(
                                      isAfter1PM
                                          ? 'WhatsApp Pending'
                                          : 'WhatsApp (after 1 PM)',
                                      style: TextStyle(
                                        color: isAfter1PM
                                            ? Colors.green
                                            : Theme.of(context)
                                                .disabledColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              error: (error, _) =>
                  Center(child: Text('Error: $error')),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }

  void _markHomework(BuildContext context, String homeworkId) {
    showDialog(
      context: context,
      builder: (_) => HomeworkMarkDialog(
        homeworkId: homeworkId,
        classId: widget.classId,
      ),
    );
  }

  /// Opens WhatsApp for each student with pending homework, one by one.
  /// Only available after 1 PM.
  Future<void> _sendPendingWhatsApp(
      BuildContext context, String homeworkId, String subject) async {
    final pending = await ref
        .read(repoProvider)
        .getPendingHomeworkStudents(widget.classId, homeworkId);

    if (!mounted) return;

    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pending students!')));
      return;
    }

    // Show list and send one by one with confirmation
    showDialog(
      context: context,
      builder: (ctx) => _PendingWhatsAppDialog(
        students: pending,
        subject: subject,
      ),
    );
  }
}

/// Dialog that sends WhatsApp messages one at a time for pending students.
class _PendingWhatsAppDialog extends StatefulWidget {
  const _PendingWhatsAppDialog({
    required this.students,
    required this.subject,
  });
  final List<Student> students;
  final String subject;

  @override
  State<_PendingWhatsAppDialog> createState() =>
      _PendingWhatsAppDialogState();
}

class _PendingWhatsAppDialogState extends State<_PendingWhatsAppDialog> {
  int currentIndex = 0;

  Student get current => widget.students[currentIndex];
  bool get isLast => currentIndex == widget.students.length - 1;

  Future<void> _sendAndAdvance() async {
    if (current.whatsapp.isEmpty) {
      _advance();
      return;
    }
    final msg =
        'Namaste ${current.parentName.isNotEmpty ? current.parentName : "Madam/Sir"}! '
        'Aapke bache *${current.fullName}* ka aaj ka *${widget.subject}* homework pending hai. '
        'Kripya aaj raat complete karwayein. NEMPS School.';
    final uri = Uri.parse(
        'https://wa.me/${current.whatsapp.replaceAll(RegExp(r"[^0-9]"), "")}?text=${Uri.encodeComponent(msg)}');
    await launchUrl(uri, mode: LaunchMode.platformDefault);
    _advance();
  }

  void _advance() {
    if (isLast) {
      Navigator.pop(context);
    } else {
      setState(() => currentIndex++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          'Pending: ${currentIndex + 1} of ${widget.students.length}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(current.fullName,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text('Parent: ${current.parentName}'),
          Text(
              'WhatsApp: ${current.whatsapp.isNotEmpty ? current.whatsapp : "—Not set—"}'),
          const SizedBox(height: 16),
          if (current.whatsapp.isEmpty)
            const Text(
                '(No WhatsApp number — will skip this student)',
                style: TextStyle(color: Colors.orange)),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        TextButton(
            onPressed: _advance,
            child: Text(isLast ? 'Skip & Done' : 'Skip')),
        FilledButton.icon(
          onPressed:
              current.whatsapp.isNotEmpty ? _sendAndAdvance : null,
          icon: const Icon(Icons.message, size: 18),
          label: Text(isLast ? 'Send & Done' : 'Send & Next'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Homework Mark Dialog  (FIX: no longer takes ref as constructor param)
// ---------------------------------------------------------------------------

class HomeworkMarkDialog extends ConsumerStatefulWidget {
  const HomeworkMarkDialog({
    super.key,
    required this.homeworkId,
    required this.classId,
  });
  final String homeworkId, classId;

  @override
  ConsumerState<HomeworkMarkDialog> createState() =>
      _HomeworkMarkDialogState();
}

class _HomeworkMarkDialogState extends ConsumerState<HomeworkMarkDialog> {
  final statuses = <String, String>{};
  bool saving = false;
  bool loadingStatuses = true;

  @override
  void initState() {
    super.initState();
    _preloadStatuses();
  }

  Future<void> _preloadStatuses() async {
    try {
      final existing =
          await ref.read(repoProvider).getHomeworkStatus(widget.homeworkId);
      if (!mounted) return;
      setState(() {
        for (final record in existing) {
          statuses[record.studentId] = record.status;
        }
        loadingStatuses = false;
      });
    } catch (_) {
      if (mounted) setState(() => loadingStatuses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(studentsProvider(widget.classId));

    return AlertDialog(
      title: const Text('Mark Homework Status'),
      content: SizedBox(
        width: double.maxFinite,
        child: students.when(
          data: (items) => loadingStatuses
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, index) {
              final student = items[index];
              final status = statuses[student.id] ?? 'not_checked';
              return ListTile(
                title: Text(student.fullName),
                trailing: DropdownButton<String>(
                  value: status,
                  items: const [
                    DropdownMenuItem(
                        value: 'completed', child: Text('Done')),
                    DropdownMenuItem(
                        value: 'incomplete',
                        child: Text('Incomplete')),
                    DropdownMenuItem(
                        value: 'not_checked',
                        child: Text('Not Checked')),
                  ],
                  onChanged: (value) => setState(
                      () => statuses[student.id] = value ?? 'not_checked'),
                ),
              );
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  setState(() => saving = true);
                  try {
                    for (final entry in statuses.entries) {
                      await ref.read(repoProvider).markHomeworkStatus(
                            homeworkId: widget.homeworkId,
                            studentId: entry.key,
                            status: entry.value,
                          );
                    }
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Homework status saved')));
                    }
                  } finally {
                    if (mounted) setState(() => saving = false);
                  }
                },
          child: Text(saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Absent Notify (WhatsApp) — day-wise with absent/present tabs
// ---------------------------------------------------------------------------

class AbsentNotifyScreen extends ConsumerStatefulWidget {
  const AbsentNotifyScreen({super.key, required this.classId});
  final String classId;

  @override
  ConsumerState<AbsentNotifyScreen> createState() =>
      _AbsentNotifyScreenState();
}

class _AbsentNotifyScreenState extends ConsumerState<AbsentNotifyScreen>
    with SingleTickerProviderStateMixin {
  DateTime selectedDate = DateTime.now();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
      ref.invalidate(absentStudentsProvider);
      ref.invalidate(presentStudentsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final absent = ref.watch(
        absentStudentsProvider((widget.classId, selectedDate)));
    final present = ref.watch(
        presentStudentsProvider((widget.classId, selectedDate)));
    final dateStr = DateFormat('dd MMM yyyy').format(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp Notifications'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Absent'),
            Tab(text: 'Present'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date picker row
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Date: $dateStr',
                          style: Theme.of(context).textTheme.titleMedium),
                      absent.when(
                        data: (a) => present.when(
                          data: (p) => Text(
                            'Absent: ${a.length}  |  Present: ${p.length}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: const Text('Change Date'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Absent tab
                absent.when(
                  data: (items) => _buildStudentList(
                    context,
                    items,
                    isAbsent: true,
                    dateStr: dateStr,
                  ),
                  error: (e, _) =>
                      Center(child: Text('Error: $e')),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),
                // Present tab
                present.when(
                  data: (items) => _buildStudentList(
                    context,
                    items,
                    isAbsent: false,
                    dateStr: dateStr,
                  ),
                  error: (e, _) =>
                      Center(child: Text('Error: $e')),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList(
    BuildContext context,
    List<Student> items, {
    required bool isAbsent,
    required String dateStr,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isAbsent ? Icons.check_circle : Icons.person_off,
                size: 48,
                color: isAbsent ? Colors.green : Colors.grey),
            const SizedBox(height: 12),
            Text(
              isAbsent
                  ? 'No absent students on $dateStr'
                  : 'No present students marked on $dateStr',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: FilledButton.icon(
            onPressed: () => _sendAllOneByOne(context, items, isAbsent, dateStr),
            icon: const Icon(Icons.send),
            label: Text(
                'Send to All ${isAbsent ? "Absent" : "Present"} (${items.length})'),
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44)),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (_, index) {
              final student = items[index];
              final msg = _buildMessage(student, isAbsent, dateStr);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isAbsent
                        ? Colors.red.shade100
                        : Colors.green.shade100,
                    child: Icon(
                      isAbsent ? Icons.close : Icons.check,
                      color: isAbsent ? Colors.red : Colors.green,
                    ),
                  ),
                  title: Text(student.fullName),
                  subtitle: Text(
                      '${student.parentName}  |  ${student.whatsapp.isNotEmpty ? student.whatsapp : "No number"}'),
                  trailing: FilledButton.tonalIcon(
                    onPressed: student.whatsapp.isEmpty
                        ? null
                        : () => _sendWhatsApp(
                            context, student.whatsapp, msg),
                    icon: const Icon(Icons.message, size: 18),
                    label: const Text('Send'),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _buildMessage(Student student, bool isAbsent, String dateStr) {
    final parentName = student.parentName.isNotEmpty
        ? student.parentName
        : 'Madam/Sir';
    if (isAbsent) {
      return 'Namaste $parentName ji! '
          'Aapke bache *${student.fullName}* aaj $dateStr school mein *absent* hain. '
          'Agar koi karan hai to school se sampark karein. '
          '— NEMPS School, Vrindavan';
    } else {
      return 'Namaste $parentName ji! '
          'Aapke bache *${student.fullName}* aaj $dateStr school mein *present* hain. '
          'Dhanyawaad! — NEMPS School, Vrindavan';
    }
  }

  void _sendAllOneByOne(BuildContext context, List<Student> students,
      bool isAbsent, String dateStr) {
    showDialog(
      context: context,
      builder: (_) => _BulkWhatsAppDialog(
        students: students,
        isAbsent: isAbsent,
        dateStr: dateStr,
      ),
    );
  }

  Future<void> _sendWhatsApp(
      BuildContext context, String phone, String message) async {
    final uri = Uri.parse(
        'https://wa.me/${phone.replaceAll(RegExp(r"[^0-9]"), "")}?text=${Uri.encodeComponent(message)}');
    final opened =
        await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Could not open WhatsApp. Check the number.')));
    }
  }
}

/// Dialog that sends WhatsApp one by one for absent/present list.
class _BulkWhatsAppDialog extends StatefulWidget {
  const _BulkWhatsAppDialog({
    required this.students,
    required this.isAbsent,
    required this.dateStr,
  });
  final List<Student> students;
  final bool isAbsent;
  final String dateStr;

  @override
  State<_BulkWhatsAppDialog> createState() =>
      _BulkWhatsAppDialogState();
}

class _BulkWhatsAppDialogState extends State<_BulkWhatsAppDialog> {
  int currentIndex = 0;

  Student get current => widget.students[currentIndex];
  bool get isLast => currentIndex == widget.students.length - 1;

  String get message {
    final parentName = current.parentName.isNotEmpty
        ? current.parentName
        : 'Madam/Sir';
    if (widget.isAbsent) {
      return 'Namaste $parentName ji! '
          'Aapke bache *${current.fullName}* aaj ${widget.dateStr} school mein *absent* hain. '
          'Agar koi karan hai to school se sampark karein. '
          '— NEMPS School, Vrindavan';
    } else {
      return 'Namaste $parentName ji! '
          'Aapke bache *${current.fullName}* aaj ${widget.dateStr} school mein *present* hain. '
          'Dhanyawaad! — NEMPS School, Vrindavan';
    }
  }

  Future<void> _sendAndAdvance() async {
    if (current.whatsapp.isEmpty) {
      _advance();
      return;
    }
    final uri = Uri.parse(
        'https://wa.me/${current.whatsapp.replaceAll(RegExp(r"[^0-9]"), "")}?text=${Uri.encodeComponent(message)}');
    await launchUrl(uri, mode: LaunchMode.platformDefault);
    _advance();
  }

  void _advance() {
    if (isLast) {
      Navigator.pop(context);
    } else {
      setState(() => currentIndex++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.isAbsent ? Icons.close : Icons.check,
            color: widget.isAbsent ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 8),
          Text(
              '${currentIndex + 1} of ${widget.students.length}'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(current.fullName,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text('Parent: ${current.parentName}'),
          Text(
              'WhatsApp: ${current.whatsapp.isNotEmpty ? current.whatsapp : "—Not set—"}'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(message, style: const TextStyle(fontSize: 13)),
          ),
          if (current.whatsapp.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No WhatsApp number — will skip',
                  style: TextStyle(color: Colors.orange)),
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        TextButton(
            onPressed: _advance,
            child: Text(isLast ? 'Skip & Done' : 'Skip')),
        FilledButton.icon(
          onPressed:
              current.whatsapp.isNotEmpty ? _sendAndAdvance : _advance,
          icon: const Icon(Icons.message, size: 18),
          label: Text(current.whatsapp.isEmpty
              ? 'Skip (No number)'
              : isLast
                  ? 'Send & Done'
                  : 'Send & Next'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Admin Panel
// ---------------------------------------------------------------------------

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(classesProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Notices'),
            Tab(text: 'Activity'),
            Tab(text: 'Students'),
          ]),
        ),
        body: TabBarView(
          children: [
            _NoticeTab(classes: classes),
            const _TeacherActivityTab(),
            _StudentsTab(classes: classes),
          ],
        ),
      ),
    );
  }
}

class _NoticeTab extends ConsumerStatefulWidget {
  const _NoticeTab({required this.classes});
  final AsyncValue<List<ClassRoom>> classes;

  @override
  ConsumerState<_NoticeTab> createState() => _NoticeTabState();
}

class _NoticeTabState extends ConsumerState<_NoticeTab> {
  String? selectedClassId;
  final titleController = TextEditingController();
  final bodyController = TextEditingController();
  bool sending = false;

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Send Notice',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          widget.classes.when(
            data: (items) => DropdownButtonFormField<String?>(
              value: selectedClassId,
              decoration: const InputDecoration(
                  labelText: 'Audience',
                  border: OutlineInputBorder()),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                    value: null, child: Text('All Classes')),
                ...items.map<DropdownMenuItem<String?>>(
                  (c) => DropdownMenuItem<String?>(
                      value: c.id, child: Text('Class ${c.label}')),
                ),
              ],
              onChanged: (v) => setState(() => selectedClassId = v),
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
                labelText: 'Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bodyController,
            decoration: const InputDecoration(
                labelText: 'Message', border: OutlineInputBorder()),
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: (sending || titleController.text.isEmpty)
                ? null
                : () async {
                    setState(() => sending = true);
                    try {
                      await ref.read(repoProvider).createNotice(
                            title: titleController.text,
                            body: bodyController.text,
                            audienceClassId: selectedClassId,
                          );
                      if (mounted) {
                        titleController.clear();
                        bodyController.clear();
                        setState(() => selectedClassId = null);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Notice sent!')));
                      }
                    } finally {
                      if (mounted) setState(() => sending = false);
                    }
                  },
            icon: const Icon(Icons.send),
            label: Text(sending ? 'Sending...' : 'Send Notice'),
          ),
        ],
      ),
    );
  }
}

class _TeacherActivityTab extends ConsumerWidget {
  const _TeacherActivityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return const Center(child: Text('Not signed in'));

    return FutureBuilder<List<TeacherActivity>>(
      future: ref.read(repoProvider).getTeacherActivityLog(currentUser.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError)
          return Center(child: Text('Error: ${snapshot.error}'));
        final activities = snapshot.data ?? [];
        if (activities.isEmpty) {
          return const Center(child: Text('No activity yet'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: activities.length,
          itemBuilder: (_, index) {
            final activity = activities[index];
            return Card(
              child: ListTile(
                leading: Icon(_activityIcon(activity.activityType)),
                title: Text(
                    activity.activityType.replaceAll('_', ' ').toUpperCase(),
                    style:
                        const TextStyle(fontSize: 13)),
                subtitle: Text(DateFormat('dd MMM yyyy')
                    .format(activity.activityDate)),
                trailing: Text('${activity.details}',
                    style: const TextStyle(fontSize: 11)),
              ),
            );
          },
        );
      },
    );
  }

  IconData _activityIcon(String type) {
    switch (type) {
      case 'attendance_marked':
        return Icons.fact_check;
      case 'homework_marked':
        return Icons.assignment;
      case 'whatsapp_sent':
        return Icons.message;
      case 'notice_sent':
        return Icons.notifications;
      default:
        return Icons.circle;
    }
  }
}

class _StudentsTab extends ConsumerWidget {
  const _StudentsTab({required this.classes});
  final AsyncValue<List<ClassRoom>> classes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return classes.when(
      data: (items) => ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (_, index) {
          final classroom = items[index];
          return Card(
            child: ListTile(
              title: Text('Class ${classroom.label}'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text('Class ${classroom.label} Students'),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: 300,
                    child: ref
                        .watch(studentsProvider(classroom.id))
                        .when(
                          data: (students) => ListView.builder(
                            itemCount: students.length,
                            itemBuilder: (_, idx) => ListTile(
                              leading: CircleAvatar(
                                  child: Text(students[idx].rollNo)),
                              title: Text(students[idx].fullName),
                              subtitle:
                                  Text(students[idx].parentName),
                            ),
                          ),
                          loading: () => const Center(
                              child: CircularProgressIndicator()),
                          error: (e, _) => Text('Error: $e'),
                        ),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close')),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ---------------------------------------------------------------------------
// Reports
// ---------------------------------------------------------------------------

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Reports')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Reports',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            const Card(
              child: ListTile(
                leading: Icon(Icons.bar_chart),
                title: Text('Attendance Report'),
                subtitle: Text('View daily/monthly attendance'),
              ),
            ),
            const SizedBox(height: 8),
            const Card(
              child: ListTile(
                leading: Icon(Icons.assignment_turned_in),
                title: Text('Homework Report'),
                subtitle: Text('Track homework completion rates'),
              ),
            ),
          ],
        ),
      );
}
