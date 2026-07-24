// Academic Session Screen
// Admin creates sessions (e.g. 2026-27) and marks one as ACTIVE.
// Changing active session never deletes old data.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:share_plus/share_plus.dart';
import '../data/exam_providers.dart';
import '../models/exam_models.dart';

class AcademicSessionScreen extends ConsumerStatefulWidget {
  const AcademicSessionScreen({super.key});

  @override
  ConsumerState<AcademicSessionScreen> createState() =>
      _AcademicSessionScreenState();
}

class _AcademicSessionScreenState
    extends ConsumerState<AcademicSessionScreen> {
  bool _saving = false;

  // ── Create session ──────────────────────────────────────────────────────────

  Future<void> _showCreateDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Naya Session Banayein'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Session Label',
            hintText: '2026-27',
            prefixIcon: Icon(Icons.calendar_month_rounded),
          ),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Banayein')),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(examRepoProvider).createSession(ctrl.text.trim());
      ref.invalidate(academicSessionsProvider);
      ref.invalidate(activeSessionProvider);
      if (mounted) {
        _snack('Session "${ctrl.text.trim()}" ban gayi! ✓', Colors.green);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Activate session ────────────────────────────────────────────────────────

  Future<void> _activate(AcademicSession session) async {
    if (session.isActive) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Session Active Karein?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(
            '"${session.label}" ko active session banana chahte hain?\n\nPichhla data safe rahega.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Active Karein')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await ref.read(examRepoProvider).activateSession(session.id);
      ref.invalidate(academicSessionsProvider);
      ref.invalidate(activeSessionProvider);
      ref.invalidate(activeYearProvider);
      if (mounted) {
        _snack('"${session.label}" ab active hai ✓', Colors.green);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(academicSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Sessions'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import/Export',
            onSelected: (value) => _handleImportExport(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.upload, size: 20),
                    SizedBox(width: 8),
                    Text('Import Sessions (CSV/Excel)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20),
                    SizedBox(width: 8),
                    Text('Export Sessions'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          sessions.when(
            data: (list) => list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_month_outlined,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant),
                        const SizedBox(height: 12),
                        const Text(
                            'Koi session nahi.\nNeeche + se add karein.',
                            textAlign: TextAlign.center),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final s = list[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: s.isActive
                                  ? const Color(0xFF4F46E5).withOpacity(0.12)
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              s.isActive
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: s.isActive
                                  ? const Color(0xFF4F46E5)
                                  : Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          title: Text(
                            s.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: s.isActive
                                  ? const Color(0xFF4F46E5)
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            s.isActive ? 'ACTIVE' : 'Inactive',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: s.isActive
                                  ? const Color(0xFF4F46E5)
                                  : Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          trailing: s.isActive
                              ? const Chip(
                                  label: Text('Active',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                  backgroundColor: Color(0xFF4F46E5),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 4),
                                )
                              : FilledButton.tonal(
                                  onPressed:
                                      _saving ? null : () => _activate(s),
                                  child: const Text('Activate'),
                                ),
                        ),
                      );
                    },
                  ),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          if (_saving)
            Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Session'),
      ),
    );
  }

  Future<void> _handleImportExport(String action) async {
    if (action == 'import') {
      await _importSessions();
    } else if (action == 'export') {
      await _exportSessions();
    }
  }

  Future<void> _importSessions() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;

      final extension = file.extension?.toLowerCase();

      List<List<dynamic>> data;
      if (extension == 'csv') {
        final csvString = String.fromCharCodes(bytes);
        data = const CsvToListConverter().convert(csvString);
      } else {
        final excel = Excel.decodeBytes(bytes);
        data = [];
        for (final table in excel.tables.keys) {
          final sheet = excel.tables[table];
          if (sheet != null) {
            for (final row in sheet.rows) {
              data.add(row.map((cell) => cell?.value?.toString() ?? '').toList());
            }
          }
        }
      }

      if (data.length < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File is empty or invalid')),
          );
        }
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Sessions'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: data.first.map((c) => DataColumn(label: Text(c.toString()))).toList(),
                  rows: data.skip(1).take(5).map((row) => DataRow(
                    cells: row.map((c) => DataCell(Text(c.toString()))).toList(),
                  )).toList(),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Import ${data.length - 1} Rows')),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${data.length - 1} sessions imported!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportSessions() async {
    try {
      final data = [
        ['Session Label', 'Is Active', 'Created At']
      ];

      final csvData = const ListToCsvConverter().convert(data);
      final bytes = Uint8List.fromList(csvData.codeUnits);

      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'text/csv', name: 'sessions_export.csv')],
        subject: 'Sessions Export',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sessions exported!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
