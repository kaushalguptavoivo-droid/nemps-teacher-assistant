import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' if (dart.library.html) 'package:nemps_teacher_assistant/src/core/stubs/io_stub.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/models/models.dart';
import '../data/providers.dart';
import '../../core/theme/app_theme.dart';

class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key, required this.classId});
  final String classId;

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  Future<void> _showStudentDialog({Student? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.fullName ?? '');
    final rollCtrl = TextEditingController(text: existing?.rollNo ?? '');
    final fatherCtrl = TextEditingController(text: existing?.parentName ?? '');
    final waCtrl = TextEditingController(text: existing?.whatsapp ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Student Add Karein' : 'Student Edit Karein'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: rollCtrl,
                decoration: const InputDecoration(
                    labelText: 'Roll No', prefixIcon: Icon(Icons.numbers)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: fatherCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Father Name', prefixIcon: Icon(Icons.family_restroom)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: waCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'WhatsApp (10 digit)',
                    prefixIcon: Icon(Icons.phone_outlined)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(existing == null ? 'Add' : 'Save')),
        ],
      ),
    );

    if (confirmed != true || nameCtrl.text.trim().isEmpty || rollCtrl.text.trim().isEmpty) return;
    try {
      await ref.read(repoProvider).saveStudent(
            id: existing?.id,
            classId: widget.classId,
            fullName: nameCtrl.text,
            rollNo: rollCtrl.text,
            fatherName: fatherCtrl.text,
            whatsapp: waCtrl.text,
          );
      ref.invalidate(studentsProvider(widget.classId));
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

  Future<void> _deleteStudent(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Student Hatayein?'),
        content: Text('${student.fullName} ko class se remove karein?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.absentColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(repoProvider).deactivateStudent(student.id);
      ref.invalidate(studentsProvider(widget.classId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Student remove ho gaya!'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _importStudents() async {
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
      await ref.read(repoProvider).importStudentsFromBytes(widget.classId, bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Students import ho gaye!'), backgroundColor: AppTheme.attendanceColor));
        ref.invalidate(studentsProvider(widget.classId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Import error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _exportStudents() async {
    try {
      final csv = await ref.read(repoProvider).exportStudentsToCSV(widget.classId);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Export CSV'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: SingleChildScrollView(
              child: SelectableText(csv,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(studentsProvider(widget.classId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Students'),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            itemBuilder: (context) => [
              PopupMenuItem(
                  child: const ListTile(
                      leading: Icon(Icons.upload_file), title: Text('Import CSV'), contentPadding: EdgeInsets.zero),
                  onTap: _importStudents),
              PopupMenuItem(
                  child: const ListTile(
                      leading: Icon(Icons.download), title: Text('Export CSV'), contentPadding: EdgeInsets.zero),
                  onTap: _exportStudents),
            ],
          ),
        ],
      ),
      body: students.when(
        data: (items) => items.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline, size: 64,
                        color: Theme.of(context).colorScheme.outlineVariant),
                    const SizedBox(height: 12),
                    Text('Koi student nahi.\nNeeche + se add karein.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                itemCount: items.length,
                itemBuilder: (_, index) {
                  final s = items[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Text(s.rollNo,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold)),
                      ),
                      title: Text(s.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.parentName.isNotEmpty
                              ? '👨 ${s.parentName}'
                              : 'Father name nahi'),
                          if (s.whatsapp.isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.phone, size: 12, color: AppTheme.whatsappColor),
                                const SizedBox(width: 4),
                                Text(s.whatsapp,
                                    style: const TextStyle(
                                        fontSize: 12, color: AppTheme.whatsappColor)),
                              ],
                            ),
                        ],
                      ),
                      isThreeLine: s.whatsapp.isNotEmpty,
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') _showStudentDialog(existing: s);
                          if (v == 'delete') _deleteStudent(s);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                                leading: Icon(Icons.edit, color: Colors.blue),
                                title: Text('Edit'),
                                contentPadding: EdgeInsets.zero),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                                leading: Icon(Icons.person_remove, color: Colors.red),
                                title: Text('Remove', style: TextStyle(color: Colors.red)),
                                contentPadding: EdgeInsets.zero),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        error: (_, __) =>
            const Center(child: Text('Students unavailable offline')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStudentDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Student'),
      ),
    );
  }
}
