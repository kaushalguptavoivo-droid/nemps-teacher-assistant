import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../data/providers.dart';
import '../examination/presentation/admin_exam_tab.dart';

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.class_), text: 'Classes'),
              Tab(icon: Icon(Icons.people), text: 'Students'),
              Tab(icon: Icon(Icons.person), text: 'Teachers'),
              Tab(icon: Icon(Icons.notifications), text: 'Notices'),
              Tab(icon: Icon(Icons.history), text: 'Activity'),
              Tab(icon: Icon(Icons.assignment_rounded), text: 'Exam Mgmt'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const _AdminClassesTab(),
            const _AdminStudentsTab(),
            const _AdminTeachersTab(),
            _NoticeTab(classes: ref.watch(allClassesProvider)),
            const _TeacherActivityTab(),
            const AdminExamTab(),
          ],
        ),
      ),
    );
  }
}

// ── Notices Tab ───────────────────────────────────────────────────────────────

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
          Text('Notice Bhejein',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          widget.classes.when(
            data: (items) => DropdownButtonFormField<String?>(
              value: selectedClassId,
              decoration: const InputDecoration(
                  labelText: 'Audience (class)',
                  prefixIcon: Icon(Icons.group_outlined)),
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
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
                labelText: 'Title', prefixIcon: Icon(Icons.title)),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bodyController,
            decoration: const InputDecoration(
                labelText: 'Message', prefixIcon: Icon(Icons.message_outlined)),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
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
                          setState(() {
                            selectedClassId = null;
                            sending = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Notice bhej diya! ✓'),
                                backgroundColor: AppTheme.infoColor),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => sending = false);
                      }
                    },
              icon: const Icon(Icons.send_rounded),
              label: Text(sending ? 'Sending...' : 'Send Notice'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Activity Tab ──────────────────────────────────────────────────────────────

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
            final color = _activityColor(activity.activityType);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(_activityIcon(activity.activityType),
                      color: color, size: 20),
                ),
                title: Text(
                    activity.activityType.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text(
                    DateFormat('dd MMM yyyy').format(activity.activityDate)),
                trailing: Text('${activity.details}',
                    style: const TextStyle(fontSize: 11)),
              ),
            );
          },
        );
      },
    );
  }

  Color _activityColor(String type) {
    switch (type) {
      case 'attendance_marked': return AppTheme.attendanceColor;
      case 'homework_marked': return AppTheme.homeworkColor;
      case 'whatsapp_sent': return AppTheme.whatsappColor;
      case 'notice_sent': return AppTheme.infoColor;
      default: return Colors.grey;
    }
  }

  IconData _activityIcon(String type) {
    switch (type) {
      case 'attendance_marked': return Icons.fact_check_rounded;
      case 'homework_marked': return Icons.assignment_rounded;
      case 'whatsapp_sent': return Icons.message_rounded;
      case 'notice_sent': return Icons.notifications_rounded;
      default: return Icons.circle;
    }
  }
}

// ── Classes Tab ───────────────────────────────────────────────────────────────

class _AdminClassesTab extends ConsumerStatefulWidget {
  const _AdminClassesTab();
  @override
  ConsumerState<_AdminClassesTab> createState() => _AdminClassesTabState();
}

class _AdminClassesTabState extends ConsumerState<_AdminClassesTab> {
  Future<void> _showClassDialog({ClassRoom? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final sectionCtrl = TextEditingController(text: existing?.section ?? '');
    final yearCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nai Class Banayein' : 'Class Edit Karein'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Class Name (5, 6, 7...)',
                  prefixIcon: Icon(Icons.class_outlined)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sectionCtrl,
              decoration: const InputDecoration(
                  labelText: 'Section (A, B...)',
                  prefixIcon: Icon(Icons.segment)),
            ),
            if (existing == null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: yearCtrl,
                decoration: const InputDecoration(
                    labelText: 'Academic Year (2025-26)',
                    prefixIcon: Icon(Icons.calendar_today)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(existing == null ? 'Banayein' : 'Save')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (nameCtrl.text.trim().isEmpty || sectionCtrl.text.trim().isEmpty) return;
    try {
      await ref.read(repoProvider).saveClass(
            id: existing?.id,
            name: nameCtrl.text,
            section: sectionCtrl.text,
            academicYear: yearCtrl.text,
          );
      ref.invalidate(allClassesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(existing == null ? 'Class ban gayi! ✓' : 'Class update ho gayi!'),
            backgroundColor: AppTheme.attendanceColor));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteClass(ClassRoom c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Class Delete Karein?'),
        content: Text('Class ${c.label} delete karne se saare students bhi hatenge. Pakka?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(repoProvider).deleteClass(c.id);
      ref.invalidate(allClassesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Class delete ho gayi!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(allClassesProvider);
    return Scaffold(
      body: classes.when(
        data: (items) => items.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.class_outlined, size: 64,
                        color: Theme.of(context).colorScheme.outlineVariant),
                    const SizedBox(height: 12),
                    const Text('Koi class nahi.\nNeeche + se add karein.',
                        textAlign: TextAlign.center),
                  ],
                ))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final c = items[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(c.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary)),
                        ),
                      ),
                      title: Text('Class ${c.label}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                            onPressed: () => _showClassDialog(existing: c),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_rounded, color: Colors.red),
                            onPressed: () => _deleteClass(c),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showClassDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Class'),
      ),
    );
  }
}

// ── Students Tab ──────────────────────────────────────────────────────────────

class _AdminStudentsTab extends ConsumerStatefulWidget {
  const _AdminStudentsTab();
  @override
  ConsumerState<_AdminStudentsTab> createState() => _AdminStudentsTabState();
}

class _AdminStudentsTabState extends ConsumerState<_AdminStudentsTab> {
  String? _filterClassId;

  Future<void> _showStudentDialog({Student? existing}) async {
    final allClasses = await ref.read(allClassesProvider.future);
    if (!mounted) return;
    String? classId = existing?.classId.isNotEmpty == true
        ? existing!.classId
        : (_filterClassId ?? allClasses.firstOrNull?.id);
    final nameCtrl = TextEditingController(text: existing?.fullName ?? '');
    final rollCtrl = TextEditingController(text: existing?.rollNo ?? '');
    final fatherCtrl = TextEditingController(text: existing?.parentName ?? '');
    final waCtrl = TextEditingController(text: existing?.whatsapp ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => AlertDialog(
          title: Text(existing == null ? 'Student Add Karein' : 'Student Edit Karein'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: classId,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: allClasses
                      .map((c) => DropdownMenuItem(
                          value: c.id, child: Text('Class ${c.label}')))
                      .toList(),
                  onChanged: (v) => setSt(() => classId = v),
                ),
                const SizedBox(height: 10),
                TextField(controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name')),
                const SizedBox(height: 10),
                TextField(controller: rollCtrl,
                    decoration: const InputDecoration(labelText: 'Roll No')),
                const SizedBox(height: 10),
                TextField(controller: fatherCtrl,
                    decoration: const InputDecoration(labelText: 'Father Name')),
                const SizedBox(height: 10),
                TextField(
                  controller: waCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'WhatsApp Number'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(existing == null ? 'Add' : 'Save')),
          ],
        ),
      ),
    );
    if (confirmed != true || classId == null ||
        nameCtrl.text.trim().isEmpty || rollCtrl.text.trim().isEmpty) return;
    try {
      await ref.read(repoProvider).saveStudent(
            id: existing?.id,
            classId: classId!,
            fullName: nameCtrl.text,
            rollNo: rollCtrl.text,
            fatherName: fatherCtrl.text,
            whatsapp: waCtrl.text,
          );
      ref.invalidate(allStudentsProvider);
      ref.invalidate(studentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(existing == null ? 'Student add ho gaya!' : 'Student update ho gaya!'),
            backgroundColor: AppTheme.attendanceColor));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteStudent(Student s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Student Delete?'),
        content: Text('${s.fullName} ko permanently delete karein?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(repoProvider).deleteStudent(s.id);
      ref.invalidate(allStudentsProvider);
      ref.invalidate(studentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Student delete ho gaya!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _moveStudent(Student s) async {
    final allClasses = await ref.read(allClassesProvider.future);
    if (!mounted) return;
    String? newClassId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => AlertDialog(
          title: Text('${s.fullName} ko Move Karein'),
          content: DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Nai Class'),
            items: allClasses.map((c) => DropdownMenuItem(
                value: c.id, child: Text('Class ${c.label}'))).toList(),
            onChanged: (v) => setSt(() => newClassId = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Move')),
          ],
        ),
      ),
    );
    if (confirmed != true || newClassId == null) return;
    try {
      await ref.read(repoProvider).moveStudentToClass(s.id, newClassId!);
      ref.invalidate(allStudentsProvider);
      ref.invalidate(studentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Student move ho gaya!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allStudents = ref.watch(allStudentsProvider);
    final allClasses = ref.watch(allClassesProvider);
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: allClasses.when(
              data: (classes) => DropdownButtonFormField<String?>(
                value: _filterClassId,
                decoration: const InputDecoration(
                    labelText: 'Class filter', isDense: true),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Saare Students')),
                  ...classes.map((c) => DropdownMenuItem<String?>(
                      value: c.id, child: Text('Class ${c.label}'))),
                ],
                onChanged: (v) => setState(() => _filterClassId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: allStudents.when(
              data: (all) {
                final filtered = _filterClassId == null
                    ? all
                    : all.where((s) => s.classId == _filterClassId).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('Koi student nahi mila.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final s = filtered[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Text(s.rollNo,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        title: Text(s.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Class ${s.classLabel} • ${s.parentName}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') _showStudentDialog(existing: s);
                            if (v == 'move') _moveStudent(s);
                            if (v == 'delete') _deleteStudent(s);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                  leading: Icon(Icons.edit, color: Colors.blue),
                                  title: Text('Edit'), contentPadding: EdgeInsets.zero),
                            ),
                            PopupMenuItem(
                              value: 'move',
                              child: ListTile(
                                  leading: Icon(Icons.swap_horiz, color: Colors.orange),
                                  title: Text('Class Change'), contentPadding: EdgeInsets.zero),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                  leading: Icon(Icons.delete, color: Colors.red),
                                  title: Text('Delete', style: TextStyle(color: Colors.red)),
                                  contentPadding: EdgeInsets.zero),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStudentDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Student'),
      ),
    );
  }
}

// ── Teachers Tab ──────────────────────────────────────────────────────────────

class _AdminTeachersTab extends ConsumerStatefulWidget {
  const _AdminTeachersTab();
  @override
  ConsumerState<_AdminTeachersTab> createState() => _AdminTeachersTabState();
}

class _AdminTeachersTabState extends ConsumerState<_AdminTeachersTab> {
  Future<void> _manageClasses(TeacherProfile teacher) async {
    final allClasses = await ref.read(allClassesProvider.future);
    final assigned =
        await ref.read(repoProvider).getTeacherAssignedClasses(teacher.id);
    if (!mounted) return;
    final assignedIds = assigned.map((c) => c.id).toSet();
    final selected = <String, bool>{
      for (final c in allClasses) c.id: assignedIds.contains(c.id)
    };
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => AlertDialog(
          title: Text('${teacher.fullName} — Classes'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: allClasses.isEmpty
                ? const Center(child: Text('Pehle classes banayein.'))
                : ListView(
                    children: allClasses.map((c) {
                      return CheckboxListTile(
                        value: selected[c.id] ?? false,
                        title: Text('Class ${c.label}'),
                        onChanged: (val) async {
                          setSt(() => selected[c.id] = val ?? false);
                          try {
                            if (val == true) {
                              await ref.read(repoProvider)
                                  .assignTeacherToClass(teacher.id, c.id);
                            } else {
                              await ref.read(repoProvider)
                                  .removeTeacherFromClass(teacher.id, c.id);
                            }
                          } catch (e) {
                            setSt(() => selected[c.id] = !(val ?? false));
                            if (ctx2.mounted) {
                              ScaffoldMessenger.of(ctx2).showSnackBar(
                                  SnackBar(content: Text('Error: $e')));
                            }
                          }
                        },
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                ref.invalidate(teacherAssignedClassesProvider);
                Navigator.pop(ctx);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editProfile(TeacherProfile teacher) async {
    final nameCtrl = TextEditingController(text: teacher.fullName);
    final phoneCtrl = TextEditingController(text: teacher.phone);
    String role = teacher.role == UserRole.admin ? 'admin' : 'teacher';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => AlertDialog(
          title: const Text('Profile Edit Karein'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name')),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (v) => setSt(() => role = v ?? 'teacher'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(repoProvider).updateTeacherProfile(
            id: teacher.id,
            fullName: nameCtrl.text,
            phone: phoneCtrl.text,
            role: role,
          );
      ref.invalidate(allTeachersProvider);
      ref.invalidate(currentUserRoleProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile update ho gayi! ✓'),
                backgroundColor: AppTheme.attendanceColor));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final teachers = ref.watch(allTeachersProvider);
    return teachers.when(
      data: (list) => list.isEmpty
          ? const Center(child: Text('Koi teacher nahi mila.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final t = list[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: t.role == UserRole.admin
                          ? const Color(0xFF7C3AED).withOpacity(0.15)
                          : Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        t.fullName.isNotEmpty ? t.fullName[0].toUpperCase() : '?',
                        style: TextStyle(
                            color: t.role == UserRole.admin
                                ? const Color(0xFF7C3AED)
                                : Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(t.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: t.role == UserRole.admin
                                ? const Color(0xFF7C3AED).withOpacity(0.15)
                                : AppTheme.infoColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(t.roleLabel,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: t.role == UserRole.admin
                                      ? const Color(0xFF7C3AED)
                                      : AppTheme.infoColor)),
                        ),
                        if (t.phone.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(t.phone, style: const TextStyle(fontSize: 12)),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.class_rounded, color: Colors.green),
                          tooltip: 'Classes Assign',
                          onPressed: () => _manageClasses(t),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                          tooltip: 'Edit Profile',
                          onPressed: () => _editProfile(t),
                        ),
                      ],
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
