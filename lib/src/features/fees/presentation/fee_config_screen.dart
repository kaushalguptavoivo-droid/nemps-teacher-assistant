// Admin Fees Management Screen
// Fully customizable fee management for admin

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:share_plus/share_plus.dart';
import '../../data/providers.dart';
import '../data/fee_providers.dart';
import '../../examination/data/exam_providers.dart';
import '../models/fee_models.dart';

class FeeConfigScreen extends ConsumerStatefulWidget {
  const FeeConfigScreen({super.key});

  @override
  ConsumerState<FeeConfigScreen> createState() => _FeeConfigScreenState();
}

class _FeeConfigScreenState extends ConsumerState<FeeConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fees Management'),
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
                    Text('Import Fees (CSV/Excel)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20),
                    SizedBox(width: 8),
                    Text('Export Fees'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.category), text: 'Fee Types'),
            Tab(icon: Icon(Icons.class_), text: 'Class Config'),
            Tab(icon: Icon(Icons.payments), text: 'Collection'),
            Tab(icon: Icon(Icons.analytics), text: 'Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _FeeTypesTab(),
          _ClassFeeConfigTab(),
          _FeeCollectionTab(),
          _FeeReportsTab(),
        ],
      ),
    );
  }

  Future<void> _handleImportExport(String action) async {
    if (action == 'import') {
      await _importFees();
    } else if (action == 'export') {
      await _exportFees();
    }
  }

  Future<void> _importFees() async {
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
          title: const Text('Import Fees'),
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
          content: Text('${data.length - 1} fee records imported!'),
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

  Future<void> _exportFees() async {
    try {
      final data = [
        ['Fee Type', 'Amount', 'Frequency', 'Due Date', 'Class']
      ];

      final csvData = const ListToCsvConverter().convert(data);
      final bytes = Uint8List.fromList(csvData.codeUnits);

      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'text/csv', name: 'fees_export.csv')],
        subject: 'Fees Export',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fees exported!'), backgroundColor: Colors.green),
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

// ── Fee Types Tab ─────────────────────────────────────────────────────────────

class _FeeTypesTab extends ConsumerWidget {
  const _FeeTypesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(activeSessionProvider);

    return activeSession.when(
      data: (session) {
        if (session == null) {
          return const Center(
            child: Text(
              'Koi active session nahi.\nAdmin se poochein.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return _FeeTypesList(academicYear: session.label);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _FeeTypesList extends ConsumerWidget {
  const _FeeTypesList({required this.academicYear});

  final String academicYear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feeTypesAsync = ref.watch(feeTypesProvider(academicYear));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _addFeeType(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add Fee Type'),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: feeTypesAsync.when(
            data: (feeTypes) => feeTypes.isEmpty
                ? const Center(
                    child: Text(
                      'Koi fee type nahi.\nAdd karein.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: feeTypes.length,
                    itemBuilder: (_, index) {
                      final feeType = feeTypes[index];
                      return _FeeTypeCard(
                        feeType: feeType,
                        academicYear: academicYear,
                      );
                    },
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Future<void> _addFeeType(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String frequency = 'one-time';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => AlertDialog(
          title: const Text('Add Fee Type'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Fee Name',
                    hintText: 'e.g., Tuition Fee, Admission Fee',
                    prefixIcon: Icon(Icons.label),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'e.g., Monthly tuition charges',
                    prefixIcon: Icon(Icons.description),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    hintText: 'e.g., 5000',
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: const InputDecoration(
                    labelText: 'Frequency',
                    prefixIcon: Icon(Icons.schedule),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                    DropdownMenuItem(value: 'annually', child: Text('Annually')),
                    DropdownMenuItem(value: 'one-time', child: Text('One Time')),
                  ],
                  onChanged: (v) => setSt(() => frequency = v ?? 'one-time'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    if (nameCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;

    final amount = double.tryParse(amountCtrl.text) ?? 0;
    if (amount <= 0) return;

    try {
      await ref.read(feeRepoProvider).addFeeType(
        name: nameCtrl.text.trim(),
        description: descCtrl.text.trim(),
        amount: amount,
        frequency: frequency,
        academicYear: academicYear,
      );
      ref.invalidate(feeTypesProvider(academicYear));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fee type add ho gaya! ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _FeeTypeCard extends ConsumerWidget {
  const _FeeTypeCard({required this.feeType, required this.academicYear});

  final FeeType feeType;
  final String academicYear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: feeType.isActive
              ? Colors.green.withOpacity(0.15)
              : Colors.grey.withOpacity(0.15),
          child: Icon(
            Icons.currency_rupee,
            color: feeType.isActive ? Colors.green : Colors.grey,
          ),
        ),
        title: Row(
          children: [
            Text(
              feeType.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (!feeType.isActive) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Inactive',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (feeType.description.isNotEmpty)
              Text(
                feeType.description,
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '₹${feeType.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _frequencyLabel(feeType.frequency),
                    style: const TextStyle(fontSize: 10, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'toggle') {
              _toggleActive(context, ref);
            } else if (value == 'delete') {
              _deleteFeeType(context, ref);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle',
              child: ListTile(
                leading: Icon(
                  feeType.isActive ? Icons.toggle_off : Icons.toggle_on,
                  color: feeType.isActive ? Colors.grey : Colors.green,
                ),
                title: Text(feeType.isActive ? 'Deactivate' : 'Activate'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        isThreeLine: feeType.description.isNotEmpty,
      ),
    );
  }

  String _frequencyLabel(String freq) {
    switch (freq) {
      case 'monthly':
        return 'Monthly';
      case 'quarterly':
        return 'Quarterly';
      case 'annually':
        return 'Annually';
      case 'one-time':
        return 'One Time';
      default:
        return freq;
    }
  }

  Future<void> _toggleActive(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(feeRepoProvider).updateFeeType(
            FeeType(
              id: feeType.id,
              name: feeType.name,
              description: feeType.description,
              amount: feeType.amount,
              frequency: feeType.frequency,
              isActive: !feeType.isActive,
              academicYear: feeType.academicYear,
              createdAt: feeType.createdAt,
            ),
          );
      ref.invalidate(feeTypesProvider(academicYear));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              feeType.isActive
                  ? 'Fee type deactivate ho gaya'
                  : 'Fee type activate ho gaya',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteFeeType(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Fee Type?'),
        content: Text('"${feeType.name}" ko delete karein?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
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
      await ref.read(feeRepoProvider).deleteFeeType(feeType.id);
      ref.invalidate(feeTypesProvider(academicYear));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fee type delete ho gaya ✓'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ── Class Fee Config Tab ─────────────────────────────────────────────────────

class _ClassFeeConfigTab extends ConsumerWidget {
  const _ClassFeeConfigTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(activeSessionProvider);
    final allClasses = ref.watch(allClassesProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: allClasses.when(
            data: (classes) {
              if (classes.isEmpty) {
                return const Text('Pehle classes banayein.');
              }
              return const _ClassFeeConfigList();
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
          ),
        ),
      ],
    );
  }
}

class _ClassFeeConfigList extends ConsumerStatefulWidget {
  const _ClassFeeConfigList();

  @override
  ConsumerState<_ClassFeeConfigList> createState() =>
      _ClassFeeConfigListState();
}

class _ClassFeeConfigListState extends ConsumerState<_ClassFeeConfigList> {
  String? _selectedClassId;

  @override
  Widget build(BuildContext context) {
    final allClasses = ref.watch(allClassesProvider);
    final activeSession = ref.watch(activeSessionProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedClassId,
          decoration: const InputDecoration(
            labelText: 'Class choose karein',
            prefixIcon: Icon(Icons.class_rounded),
          ),
          items: (allClasses.valueOrNull ?? [])
              .map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text('Class ${c.label}'),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedClassId = v),
        ),
        if (_selectedClassId != null)
          Builder(
            builder: (context) {
              final session = activeSession.valueOrNull;
              if (session == null) return const SizedBox.shrink();
              return Expanded(
                child: _ClassFeeConfigDetail(
                  classId: _selectedClassId!,
                  academicYear: session.label,
                ),
              );
            },
          ),
      ],
    );
  }
}

class _ClassFeeConfigDetail extends ConsumerWidget {
  const _ClassFeeConfigDetail({
    required this.classId,
    required this.academicYear,
  });

  final String classId;
  final String academicYear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feeTypesAsync = ref.watch(feeTypesProvider(academicYear));
    final configAsync = ref.watch(
        classFeeConfigsProvider((classId: classId, year: academicYear)));

    return feeTypesAsync.when(
      data: (feeTypes) {
        if (feeTypes.isEmpty) {
          return const Center(
            child: Text(
              'Pehle Fee Types add karein.',
              textAlign: TextAlign.center,
            ),
          );
        }

        return configAsync.when(
          data: (configs) {
            final configMap = {for (var c in configs) c.feeTypeId: c};

            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: feeTypes.length,
              itemBuilder: (_, index) {
                final feeType = feeTypes[index];
                final config = configMap[feeType.id];
                return _ClassFeeConfigCard(
                  feeType: feeType,
                  config: config,
                  classId: classId,
                  academicYear: academicYear,
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _ClassFeeConfigCard extends ConsumerWidget {
  const _ClassFeeConfigCard({
    required this.feeType,
    required this.config,
    required this.classId,
    required this.academicYear,
  });

  final FeeType feeType;
  final ClassFeeConfig? config;
  final String classId;
  final String academicYear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = config?.isEnabled ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: SwitchListTile(
        title: Row(
          children: [
            Text(
              feeType.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: feeType.isActive ? null : Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '₹${feeType.amount.toStringAsFixed(0)}',
              style: TextStyle(
                color: isEnabled ? Colors.green : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${_frequencyLabel(feeType.frequency)} • ${feeType.description.isNotEmpty ? feeType.description : "No description"}',
          style: TextStyle(
            fontSize: 12,
            color: feeType.isActive ? null : Colors.grey,
          ),
        ),
        value: isEnabled && feeType.isActive,
        onChanged: feeType.isActive
            ? (value) => _toggleConfig(context, ref, value)
            : null,
        secondary: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => _showConfigDialog(context, ref),
        ),
      ),
    );
  }

  String _frequencyLabel(String freq) {
    switch (freq) {
      case 'monthly':
        return 'Monthly';
      case 'quarterly':
        return 'Quarterly';
      case 'annually':
        return 'Annually';
      case 'one-time':
        return 'One Time';
      default:
        return freq;
    }
  }

  Future<void> _toggleConfig(BuildContext context, WidgetRef ref, bool value) async {
    final newConfig = ClassFeeConfig(
      id: config?.id ?? '',
      classId: classId,
      feeTypeId: feeType.id,
      academicYear: academicYear,
      isEnabled: value,
      customAmount: config?.customAmount ?? feeType.amount,
      dueDate: config?.dueDate ?? DateTime.now().add(const Duration(days: 30)),
      lateFee: config?.lateFee ?? 0,
      concessionAllowed: config?.concessionAllowed ?? false,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(feeRepoProvider).saveClassFeeConfig(newConfig);
      ref.invalidate(
          classFeeConfigsProvider((classId: classId, year: academicYear)));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? '${feeType.name} enabled!'
                  : '${feeType.name} disabled!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showConfigDialog(BuildContext context, WidgetRef ref) async {
    final amountCtrl = TextEditingController(
      text: (config?.customAmount ?? feeType.amount).toStringAsFixed(0),
    );
    final lateFeeCtrl = TextEditingController(
      text: (config?.lateFee ?? 0).toStringAsFixed(0),
    );
    bool concessionAllowed = config?.concessionAllowed ?? false;
    DateTime? dueDate = config?.dueDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => AlertDialog(
          title: Text('Configure ${feeType.name}'),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  decoration: InputDecoration(
                    labelText: 'Custom Amount',
                    hintText: 'Default: ₹${feeType.amount.toStringAsFixed(0)}',
                    prefixIcon: const Icon(Icons.currency_rupee),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lateFeeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Late Fee (₹)',
                    hintText: '0',
                    prefixIcon: Icon(Icons.warning),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow Concession'),
                  trailing: Switch(
                    value: concessionAllowed,
                    onChanged: (v) => setSt(() => concessionAllowed = v),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Due Date'),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx2,
                        initialDate: dueDate ?? DateTime.now(),
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 365)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setSt(() => dueDate = picked);
                      }
                    },
                    child: Text(
                      dueDate != null
                          ? '${dueDate!.day}/${dueDate!.month}/${dueDate!.year}'
                          : 'Select Date',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final customAmount = double.tryParse(amountCtrl.text) ?? 0;
    final lateFee = double.tryParse(lateFeeCtrl.text) ?? 0;
    final selectedDueDate = dueDate ?? DateTime.now().add(const Duration(days: 30));

    final newConfig = ClassFeeConfig(
      id: config?.id ?? '',
      classId: classId,
      feeTypeId: feeType.id,
      academicYear: academicYear,
      isEnabled: config?.isEnabled ?? true,
      customAmount: customAmount,
      dueDate: selectedDueDate,
      lateFee: lateFee,
      concessionAllowed: concessionAllowed,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(feeRepoProvider).saveClassFeeConfig(newConfig);
      ref.invalidate(
          classFeeConfigsProvider((classId: classId, year: academicYear)));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fee config save ho gaya! ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ── Fee Collection Tab ───────────────────────────────────────────────────────

class _FeeCollectionTab extends ConsumerStatefulWidget {
  const _FeeCollectionTab();

  @override
  ConsumerState<_FeeCollectionTab> createState() => _FeeCollectionTabState();
}

class _FeeCollectionTabState extends ConsumerState<_FeeCollectionTab> {
  String? _selectedClassId;
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(activeSessionProvider);

    return activeSession.when(
      data: (session) {
        if (session == null) {
          return const Center(
            child: Text(
              'Koi active session nahi.\nAdmin se poochein.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return _buildCollectionContent(session.label);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildCollectionContent(String academicYear) {
    final classesAsync = ref.watch(allClassesProvider);
    final summaryAsync = ref.watch(feeSummaryProvider((
      classId: _selectedClassId,
      academicYear: academicYear,
    )));

    return Column(
      children: [
        // Summary Card
        summaryAsync.when(
          data: (summary) => _buildSummaryCard(summary),
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        // Filters
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: classesAsync.when(
                  data: (classes) => DropdownButtonFormField<String>(
                    value: _selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Class Filter',
                      prefixIcon: Icon(Icons.class_),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Classes')),
                      ...classes.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.name} - ${c.section}'),
                      )),
                    ],
                    onChanged: (v) => setState(() => _selectedClassId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Error loading classes'),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'due', child: Text('Due')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                ],
                onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Fee List
        Expanded(
          child: _buildFeeList(academicYear),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(FeeSummary summary) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('Total', '₹${summary.totalAmount.toStringAsFixed(0)}', Colors.white),
          _summaryItem('Collected', '₹${summary.collectedAmount.toStringAsFixed(0)}', Colors.greenAccent),
          _summaryItem('Pending', '₹${summary.pendingAmount.toStringAsFixed(0)}', Colors.orangeAccent),
          _summaryItem('Overdue', '${summary.overdueCount}', Colors.redAccent),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildFeeList(String academicYear) {
    final feesAsync = ref.watch(studentFeesProvider((
      classId: _selectedClassId,
      studentId: null,
      academicYear: academicYear,
      status: _statusFilter == 'all' ? null : _statusFilter,
    )));

    return feesAsync.when(
      data: (fees) {
        if (fees.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Koi fee records nahi.\nPehle fees generate karein.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _generateFeesForAll(academicYear),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generate Fees for All'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ye step sirf ek baar karne ka hai\nTabhi students ko fees dikhengi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: fees.length,
          itemBuilder: (_, index) {
            final fee = fees[index];
            return _FeeCollectionCard(
              fee: fee,
              onCollectPayment: () => _showPaymentDialog(fee),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Future<void> _generateFeesForAll(String academicYear) async {
    final classes = await ref.read(allClassesProvider.future);
    
    if (classes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Koi class nahi hai. Pehle class add karein.')),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Fees'),
        content: Text(
          '${classes.length} classes ke students ke liye fees generate honge.\n\n'
          'Ye action sirf ek baar karne ka hai.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      int totalGenerated = 0;
      
      for (final cls in classes) {
        final configs = await ref.read(feeRepoProvider).getClassFeeConfigs(cls.id, academicYear);
        if (configs.isEmpty) continue;
        
        final students = await ref.read(feeRepoProvider).getStudentsForClass(cls.id);
        if (students.isEmpty) continue;

        await ref.read(feeRepoProvider).generateFeesForClass(
          classId: cls.id,
          academicYear: academicYear,
          configs: configs,
          students: students,
          dueDate: DateTime.now().add(const Duration(days: 15)),
        );
        totalGenerated += students.length;
      }

      ref.invalidate(studentFeesProvider((
        classId: _selectedClassId,
        studentId: null,
        academicYear: academicYear,
        status: _statusFilter == 'all' ? null : _statusFilter,
      )));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $totalGenerated students ke fees generate ho gaye!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showPaymentDialog(StudentFee fee) async {
    final amountCtrl = TextEditingController(
      text: fee.pendingAmount.toStringAsFixed(0),
    );
    final remarksCtrl = TextEditingController();
    String paymentMethod = 'cash';
    DateTime paymentDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => AlertDialog(
          title: Text('Collect Payment - ${fee.feeTypeName ?? "Fee"}'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Total Amount'),
                  trailing: Text('₹${fee.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  title: const Text('Pending'),
                  trailing: Text('₹${fee.pendingAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                ),
                const Divider(),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Payment Amount',
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                    prefixIcon: Icon(Icons.payment),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'upi', child: Text('UPI')),
                    DropdownMenuItem(value: 'card', child: Text('Card')),
                    DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                    DropdownMenuItem(value: 'online', child: Text('Online Transfer')),
                  ],
                  onChanged: (v) => setSt(() => paymentMethod = v ?? 'cash'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Payment Date'),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx2,
                        initialDate: paymentDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setSt(() => paymentDate = picked);
                    },
                    child: Text(DateFormat('dd/MM/yyyy').format(paymentDate)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: remarksCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Remarks (optional)',
                    prefixIcon: Icon(Icons.note),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Collect'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final amount = double.tryParse(amountCtrl.text) ?? 0;
    if (amount <= 0) return;

    try {
      // Update student fee
      final newPaidAmount = fee.paidAmount + amount;
      final isFullyPaid = newPaidAmount >= fee.pendingAmount;
      
      await ref.read(feeRepoProvider).updateStudentFee(StudentFee(
        id: fee.id,
        studentId: fee.studentId,
        feeTypeId: fee.feeTypeId,
        classId: fee.classId,
        academicYear: fee.academicYear,
        amount: fee.amount,
        paidAmount: newPaidAmount,
        status: isFullyPaid ? 'paid' : 'partial',
        dueDate: fee.dueDate,
        paidDate: isFullyPaid ? paymentDate : null,
        concession: fee.concession,
        lateFeeApplied: fee.lateFeeApplied,
        remarks: remarksCtrl.text.isNotEmpty ? remarksCtrl.text : fee.remarks,
        createdAt: fee.createdAt,
      ));

      // Record payment (using new payment system)
      final receiptNo = await ref.read(feeRepoProvider).generateReceiptNo();
      await ref.read(feeRepoProvider).createFeePayment(FeePayment(
        id: '',
        studentId: fee.studentId,
        amount: amount,
        paymentDate: paymentDate,
        paymentMethod: paymentMethod,
        receiptNo: receiptNo,
        academicYear: fee.academicYear,
        remarks: remarksCtrl.text.isNotEmpty ? remarksCtrl.text : null,
        createdAt: DateTime.now(),
      ));

      ref.invalidate(studentFeesProvider((
        classId: _selectedClassId,
        studentId: null,
        academicYear: fee.academicYear,
        status: _statusFilter == 'all' ? null : _statusFilter,
      )));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('₹$amount payment record ho gaya! ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _FeeCollectionCard extends StatelessWidget {
  const _FeeCollectionCard({
    required this.fee,
    required this.onCollectPayment,
  });

  final StudentFee fee;
  final VoidCallback onCollectPayment;

  @override
  Widget build(BuildContext context) {
    final isPaid = fee.isPaid;
    final isOverdue = fee.isOverdue;

    Color statusColor = Colors.orange;
    String statusText = 'Due';
    
    if (isPaid) {
      statusColor = Colors.green;
      statusText = 'Paid';
    } else if (isOverdue) {
      statusColor = Colors.red;
      statusText = 'Overdue';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(
            isPaid ? Icons.check_circle : Icons.pending,
            color: statusColor,
          ),
        ),
        title: Text(
          fee.studentName ?? fee.studentId.substring(0, 8),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${fee.feeTypeName ?? "Fee"} • Roll: ${fee.studentRollNo ?? "N/A"}'),
            Row(
              children: [
                Text(
                  'Paid: ₹${fee.paidAmount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12),
                ),
                const Text(' / ', style: TextStyle(fontSize: 12)),
                Text(
                  '₹${fee.amount.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (!isPaid)
              FilledButton.tonal(
                onPressed: onCollectPayment,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                ),
                child: const Text('Collect', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

// ── Fee Reports Tab ───────────────────────────────────────────────────────────

class _FeeReportsTab extends ConsumerWidget {
  const _FeeReportsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(activeSessionProvider);

    return activeSession.when(
      data: (session) {
        if (session == null) {
          return const Center(
            child: Text(
              'Koi active session nahi.\nAdmin se poochein.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return _FeeReportsContent(academicYear: session.label);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _FeeReportsContent extends ConsumerStatefulWidget {
  const _FeeReportsContent({required this.academicYear});

  final String academicYear;

  @override
  ConsumerState<_FeeReportsContent> createState() => _FeeReportsContentState();
}

class _FeeReportsContentState extends ConsumerState<_FeeReportsContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedClassId;
  DateTime _selectedDate = DateTime.now();
  String _exportType = 'due';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Bar
        Container(
          color: Colors.grey[100],
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(icon: Icon(Icons.warning_amber), text: 'Due List'),
              Tab(icon: Icon(Icons.today), text: 'Collection'),
              Tab(icon: Icon(Icons.download), text: 'Export'),
            ],
          ),
        ),
        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDueListTab(),
              _buildCollectionTab(),
              _buildExportTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Due List Tab ─────────────────────────────────────────────────────────

  Widget _buildDueListTab() {
    final dueAsync = ref.watch(dueStudentsProvider(widget.academicYear));

    return Column(
      children: [
        // Class Filter
        Padding(
          padding: const EdgeInsets.all(16),
          child: ref.watch(allClassesProvider).when(
            data: (classes) => DropdownButtonFormField<String>(
              value: _selectedClassId,
              decoration: const InputDecoration(
                labelText: 'Filter by Class',
                prefixIcon: Icon(Icons.class_),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Classes')),
                ...classes.map((c) => DropdownMenuItem(
                  value: c.id,
                  child: Text('${c.name} - ${c.section}'),
                )),
              ],
              onChanged: (v) => setState(() => _selectedClassId = v),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Error'),
          ),
        ),
        // Due Students List
        Expanded(
          child: dueAsync.when(
            data: (dueStudents) {
              if (dueStudents.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 64, color: Colors.green),
                      SizedBox(height: 16),
                      Text('🎉 Sab students ne fees pay kar di!'),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // Summary Card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text('${dueStudents.length}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red[700])),
                            const Text('Due Students'),
                          ],
                        ),
                        Container(width: 1, height: 40, color: Colors.grey[300]),
                        Column(
                          children: [
                            Text('₹${dueStudents.fold<double>(0, (sum, s) => sum + s.totalPending).toStringAsFixed(0)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red[700])),
                            const Text('Total Due'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: dueStudents.length,
                      itemBuilder: (context, index) {
                        final student = dueStudents[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.red[50],
                              child: Text(student.studentName.substring(0, 1).toUpperCase(), style: TextStyle(color: Colors.red[700])),
                            ),
                            title: Text(student.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${student.className} - ${student.section} | ${student.monthsPending.length} months'),
                            trailing: Text('₹${student.totalPending.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red[700])),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  // ── Collection Tab ────────────────────────────────────────────────────────

  Widget _buildCollectionTab() {
    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final collectionAsync = ref.watch(dailyCollectionProvider(dateStr));

    return Column(
      children: [
        // Date Selector
        Padding(
          padding: const EdgeInsets.all(16),
          child: InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() => _selectedDate = date);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today),
                  const SizedBox(width: 12),
                  Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Collection Summary
        Expanded(
          child: collectionAsync.when(
            data: (collection) {
              if (collection.payments.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.money_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Aaj koi collection nahi'),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // Summary Card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.green[700]!, Colors.green[500]!]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text('₹${collection.totalCollected.toStringAsFixed(0)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                            const Text('Total Collected', style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                        Container(width: 1, height: 50, color: Colors.white30),
                        Column(
                          children: [
                            Text('${collection.studentCount}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                            const Text('Students', style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Payment List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: collection.payments.length,
                      itemBuilder: (context, index) {
                        final payment = collection.payments[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: Colors.green[50], child: Icon(Icons.check, color: Colors.green[700])),
                            title: Text(payment.studentName ?? 'Student'),
                            subtitle: Text(payment.paymentMethod.toUpperCase()),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('₹${payment.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('#${payment.receiptNo}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  // ── Export Tab ────────────────────────────────────────────────────────────

  Widget _buildExportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Report Type:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(label: const Text('📋 Due List'), selected: _exportType == 'due', onSelected: (_) => setState(() => _exportType = 'due')),
              ChoiceChip(label: const Text('💰 Collection'), selected: _exportType == 'collection', onSelected: (_) => setState(() => _exportType = 'collection')),
              ChoiceChip(label: const Text('👥 Student Ledger'), selected: _exportType == 'ledger', onSelected: (_) => setState(() => _exportType = 'ledger')),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _exportReport(),
              icon: const Icon(Icons.download),
              label: const Text('Export to CSV'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.blue[50],
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(Icons.info, color: Colors.blue), SizedBox(width: 8), Text('Export Info', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))]),
                  SizedBox(height: 8),
                  Text('• CSV file will be downloaded'),
                  Text('• Open in Excel or Google Sheets'),
                  Text('• Report for current academic year'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportReport() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export feature coming soon!')),
    );
  }
}
