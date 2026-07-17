import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../../core/models/models.dart';
import '../data/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
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
                Icon(Icons.school_rounded, size: 52, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text('NEMPS Teacher Assistant', style: Theme.of(context).textTheme.headlineSmall),
                const Text('New Era Modern Public School, Vrindavan'),
                const SizedBox(height: 32),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'School email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: busy ? null : _signIn,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  icon: busy
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
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

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    fullName.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (email.text.isEmpty || password.text.isEmpty || fullName.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    if (password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
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
        const SnackBar(content: Text('Account created! Please check your email to verify.')),
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
                Text('Join NEMPS', style: Theme.of(context).textTheme.headlineSmall),
                const Text('Create your teacher account'),
                const SizedBox(height: 24),
                TextField(
                  controller: fullName,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'School Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    helperText: 'At least 6 characters',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number (optional)'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Checkbox(
                      value: agreeTerms,
                      onChanged: (v) => setState(() => agreeTerms = v ?? false),
                    ),
                    const Expanded(
                      child: Text('I agree to the terms & conditions'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: (busy || !agreeTerms) ? null : _signUp,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  icon: busy
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.person_add),
                  label: Text(busy ? 'Creating account...' : 'Sign Up'),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Already have an account? Sign in'),
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

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('NEMPS'),
      actions: [
        IconButton(
          icon: const Icon(Icons.dark_mode_outlined),
          onPressed: () => showModalBottomSheet(
            context: context,
            builder: (_) => const ListTile(title: Text('Appearance'), subtitle: Text('Follow system')),
          ),
        ),
        IconButton(
          onPressed: () => Supabase.instance.client.auth.signOut(),
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: child,
  );
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(classesProvider);
    final isAdmin = Supabase.instance.client.auth.currentUser?.userMetadata?['role'] == 'admin';

    return RefreshIndicator(
      onRefresh: () => ref.read(repoProvider).sync(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Good morning', style: Theme.of(context).textTheme.headlineSmall),
          const Text('Finish today\'s work in a few taps.'),
          const SizedBox(height: 20),
          const SizedBox(height: 24),
          Text('My classes', style: Theme.of(context).textTheme.titleLarge),
          classes.when(
            data: (items) => Column(
              children: items
                  .map((room) => Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text(room.name)),
                      title: Text('Class ${room.label}'),
                      subtitle: const Text('Tap to manage'),
                      onTap: () => context.go('/class/${room.id}'),
                    ),
                  ))
                  .toList(),
            ),
            error: (error, stackTrace) => const Text('Could not load classes. Pull down to sync.'),
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          const SizedBox(height: 20),
          Text('Quick actions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: classes.valueOrNull?.isNotEmpty == true
                ? () => context.go('/attendance/${classes.value!.first.id}')
                : null,
            icon: const Icon(Icons.fact_check),
            label: const Text('Mark Attendance'),
          ),
          if (isAdmin) ...[const SizedBox(height: 8)],
          if (isAdmin)
            FilledButton.icon(
              onPressed: () => context.go('/admin'),
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Admin Panel'),
            ),
        ],
      ),
    );
  }
}

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
                child: const Text('Import Students'),
                onTap: () => _importStudents(context, ref, classId),
              ),
              PopupMenuItem(
                child: const Text('Export Students'),
                onTap: () => _exportStudents(context, ref, classId),
              ),
            ],
          ),
        ],
      ),
      body: students.when(
        data: (items) => ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (_, index) {
            final student = items[index];
            return Card(
              child: ListTile(
                title: Text(student.fullName),
                subtitle: Text('Roll No: ${student.rollNo}'),
                leading: CircleAvatar(child: Text(student.rollNo)),
              ),
            );
          },
        ),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _importStudents(BuildContext context, WidgetRef ref, String classId) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
      if (result == null) return;

      await ref.read(repoProvider).importStudentsFromCSV(classId, File(result.files.single.path!));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Students imported successfully')));
        ref.invalidate(studentsProvider(classId));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _exportStudents(BuildContext context, WidgetRef ref, String classId) async {
    try {
      final csv = await ref.read(repoProvider).exportStudentsToCSV(classId);
      final now = DateTime.now();
      final filename = 'students_${classId}_${DateFormat('yyyy-MM-dd').format(now)}.csv';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV ready: $filename\n$csv')));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class StudentsScreen extends ConsumerWidget {
  const StudentsScreen({super.key, required this.classId});
  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentsProvider(classId));
    return students.when(
      data: (items) => ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (_, index) {
          final student = items[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(student.rollNo)),
              title: Text(student.fullName),
              subtitle: Text(student.parentName),
            ),
          );
        },
      ),
      error: (error, stackTrace) => const Center(child: Text('Students unavailable offline')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key, required this.classId});
  final String classId;
  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  final statuses = <String, AttendanceStatus>{};
  DateTime selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(studentsProvider(widget.classId));
    final count = ref.watch(dailyAttendanceCountProvider((widget.classId, selectedDate)));

    return Scaffold(
      body: students.when(
        data: (items) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Attendance - ${DateFormat('dd MMM yyyy').format(selectedDate)}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      count.when(
                        data: (data) => Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Present: ${data['present'] ?? 0}', style: const TextStyle(color: Colors.green)),
                            Text('Absent: ${data['absent'] ?? 0}', style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Change Date'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, index) {
                  final student = items[index];
                  final status = statuses[student.id] ?? AttendanceStatus.present;
                  return ListTile(
                    leading: CircleAvatar(child: Text(student.rollNo)),
                    title: Text(student.fullName),
                    trailing: SegmentedButton<AttendanceStatus>(
                      segments: const [
                        ButtonSegment(label: Text('P'), value: AttendanceStatus.present),
                        ButtonSegment(label: Text('A'), value: AttendanceStatus.absent),
                      ],
                      selected: {status},
                      onSelectionChanged: (s) => setState(() => statuses[student.id] = s.first),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () async {
                  for (final student in items) {
                    await ref.read(repoProvider).saveAttendance(
                      classId: widget.classId,
                      studentId: student.id,
                      status: statuses[student.id] ?? AttendanceStatus.present,
                      date: selectedDate,
                    );
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance saved')));
                    ref.invalidate(dailyAttendanceCountProvider);
                  }
                },
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: const Text('Save Attendance'),
              ),
            ),
          ],
        ),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class HomeworkScreen extends ConsumerStatefulWidget {
  const HomeworkScreen({super.key, required this.classId});
  final String classId;
  @override
  ConsumerState<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends ConsumerState<HomeworkScreen> {
  String? selectedSubject;
  String? selectedHomeworkId;
  final subjects = ['Math', 'English', 'Hindi', 'Science', 'Social Studies'];
  final descController = TextEditingController();

  @override
  void dispose() {
    descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homework = ref.watch(homeworkProvider(widget.classId));
    final students = ref.watch(studentsProvider(widget.classId));

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assign Homework', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  value: selectedSubject,
                  hint: const Text('Select Subject'),
                  isExpanded: true,
                  items: subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (value) => setState(() => selectedSubject = value),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                FilledButton(
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Homework assigned')));
                      ref.invalidate(homeworkProvider(widget.classId));
                    }
                  },
                  child: const Text('Assign Homework'),
                ),
              ],
            ),
          ),
          Expanded(
            child: homework.when(
              data: (items) => items.isEmpty
                  ? const Center(child: Text('No homework assigned'))
                  : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      final hw = items[index];
                      return Card(
                        child: ListTile(
                          title: Text(hw.subject),
                          subtitle: Text(hw.description),
                          trailing: FilledButton(
                            onPressed: () => _markHomework(context, ref, hw.id),
                            child: const Text('Mark Status'),
                          ),
                        ),
                      );
                    },
                  ),
              error: (error, stackTrace) => Center(child: Text('Error: $error')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }

  void _markHomework(BuildContext context, WidgetRef ref, String homeworkId) {
    showDialog(
      context: context,
      builder: (context) => HomeworkMarkDialog(
        homeworkId: homeworkId,
        classId: widget.classId,
        ref: ref,
      ),
    );
  }
}

class HomeworkMarkDialog extends ConsumerStatefulWidget {
  const HomeworkMarkDialog({
    super.key,
    required this.homeworkId,
    required this.classId,
    required this.ref,
  });
  final String homeworkId, classId;
  final WidgetRef ref;

  @override
  ConsumerState<HomeworkMarkDialog> createState() => _HomeworkMarkDialogState();
}

class _HomeworkMarkDialogState extends ConsumerState<HomeworkMarkDialog> {
  final statuses = <String, String>{};

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(studentsProvider(widget.classId));
    final hwStatus = ref.watch(homeworkStatusProvider(widget.homeworkId));

    return AlertDialog(
      title: const Text('Mark Homework Status'),
      content: SizedBox(
        width: double.maxFinite,
        child: students.when(
          data: (items) => ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, index) {
              final student = items[index];
              final status = statuses[student.id] ?? 'not_checked';
              return ListTile(
                title: Text(student.fullName),
                trailing: DropdownButton<String>(
                  value: status,
                  items: [
                    const DropdownMenuItem(value: 'completed', child: Text('✓ Done')),
                    const DropdownMenuItem(value: 'incomplete', child: Text('✗ Incomplete')),
                    const DropdownMenuItem(value: 'not_checked', child: Text('? Not Checked')),
                  ].toList(),
                  onChanged: (value) => setState(() => statuses[student.id] = value ?? 'not_checked'),
                ),
              );
            },
          ),
          loading: () => const CircularProgressIndicator(),
          error: (e, st) => Text('Error: $e'),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            for (final entry in statuses.entries) {
              await ref.read(repoProvider).markHomeworkStatus(
                homeworkId: widget.homeworkId,
                studentId: entry.key,
                status: entry.value,
              );
            }
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Homework marked')));
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class AbsentNotifyScreen extends ConsumerWidget {
  const AbsentNotifyScreen({super.key, required this.classId});
  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final absent = ref.watch(absentStudentsProvider((classId, DateTime.now())));

    return Scaffold(
      appBar: AppBar(title: const Text('Send Absent Notification')),
      body: absent.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('No absent students'))
            : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (_, index) {
                final student = items[index];
                return Card(
                  child: ListTile(
                    title: Text(student.fullName),
                    subtitle: Text(student.whatsapp),
                    trailing: FilledButton.icon(
                      onPressed: student.whatsapp.isEmpty
                          ? null
                          : () => _sendWhatsApp(
                            context,
                            student.whatsapp,
                            '${student.fullName} is marked absent today. Please contact the school.',
                          ),
                      icon: const Icon(Icons.message),
                      label: const Text('Send'),
                    ),
                  ),
                );
              },
            ),
        error: (e, st) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _sendWhatsApp(BuildContext context, String phone, String message) async {
    final uri = Uri.parse('https://wa.me/${phone.replaceAll(RegExp(r'[^0-9]'), '')}?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

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
            Tab(text: 'Teacher Activity'),
            Tab(text: 'Students'),
          ]),
        ),
        body: TabBarView(
          children: [
            _NoticeTab(classes: classes),
            _TeacherActivityTab(),
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

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Send Notice', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          widget.classes.when(
            data: (items) => DropdownButton<String?>(
              value: selectedClassId,
              hint: const Text('Select Class (optional)'),
              isExpanded: true,
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Classes'),
                ),
                ...items.map<DropdownMenuItem<String?>>(
                  (c) => DropdownMenuItem<String?>(
                    value: c.id,
                    child: Text('Class ${c.label}'),
                  ),
                ),
              ],
              onChanged: (String? value) {
                setState(() => selectedClassId = value);
              },
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, st) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bodyController,
            decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: titleController.text.isEmpty
                ? null
                : () async {
              await ref.read(repoProvider).createNotice(
                title: titleController.text,
                body: bodyController.text,
                audienceClassId: selectedClassId,
              );
              if (mounted) {
                titleController.clear();
                bodyController.clear();
                setState(() => selectedClassId = null);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notice sent')));
              }
            },
            child: const Text('Send Notice'),
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
    if (currentUser == null) return const Center(child: Text('No user'));

    return FutureBuilder<List<TeacherActivity>>(
      future: ref.read(repoProvider).getTeacherActivityLog(currentUser.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final activities = snapshot.data ?? [];

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: activities.length,
          itemBuilder: (_, index) {
            final activity = activities[index];
            return Card(
              child: ListTile(
                title: Text(activity.activityType.replaceAll('_', ' ').toUpperCase()),
                subtitle: Text(DateFormat('dd MMM yyyy HH:mm').format(activity.activityDate)),
                trailing: Text('${activity.details}'),
              ),
            );
          },
        );
      },
    );
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
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Class ${classroom.label}'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: ref.watch(studentsProvider(classroom.id)).when(
                      data: (students) => ListView.builder(
                        itemCount: students.length,
                        itemBuilder: (_, idx) => ListTile(
                          title: Text(students[idx].fullName),
                          subtitle: Text(students[idx].parentName),
                        ),
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (e, st) => Text('Error: $e'),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('Reports', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 20),
      const Card(child: ListTile(title: Text('Attendance Report'), subtitle: Text('View daily attendance'))),
      const SizedBox(height: 8),
      const Card(child: ListTile(title: Text('Homework Report'), subtitle: Text('Track homework completion'))),
    ],
  );
}
