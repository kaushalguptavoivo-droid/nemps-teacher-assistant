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

    final customAmount = double.tryParse(amountCtrl.text);
    final lateFee = double.tryParse(lateFeeCtrl.text) ?? 0;

    final newConfig = ClassFeeConfig(
      id: config?.id ?? '',
      classId: classId,
      feeTypeId: feeType.id,
      academicYear: academicYear,
      isEnabled: config?.isEnabled ?? true,
      customAmount: customAmount,
      dueDate: dueDate,
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Koi fee records nahi.\nPehle class mein fees generate karein.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
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

      // Record payment
      await ref.read(feeRepoProvider).recordPayment(FeePayment(
        id: '',
        studentFeeId: fee.id,
        studentId: fee.studentId,
        amount: amount,
        paymentDate: paymentDate,
        paymentMethod: paymentMethod,
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

class _FeeReportsContent extends ConsumerWidget {
  const _FeeReportsContent({required this.academicYear});

  final String academicYear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(feeSummaryProvider((
      classId: null,
      academicYear: academicYear,
    )));
    final classesAsync = ref.watch(classesWithFeeSummaryProvider(academicYear));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Summary
          summaryAsync.when(
            data: (summary) => _buildOverallSummary(context, summary),
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (_, __) => const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Error loading summary'),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Class-wise Collection',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // Class-wise breakdown
          classesAsync.when(
            data: (classes) {
              if (classes.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.class_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'Koi class nahi.',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: classes.map((cls) {
                  final summary = cls['summary'] as FeeSummary;
                  return _ClassFeeReportCard(
                    className: '${cls['name']} - ${cls['section']}',
                    summary: summary,
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallSummary(BuildContext context, FeeSummary summary) {
    final percent = summary.collectionPercent;
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Overall Fee Collection ($academicYear)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 20,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(
                  percent >= 80 ? Colors.green :
                  percent >= 50 ? Colors.orange : Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${percent.toStringAsFixed(1)}% Collected',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: percent >= 80 ? Colors.green :
                       percent >= 50 ? Colors.orange : Colors.red,
              ),
            ),
            const SizedBox(height: 20),
            // Stats grid
            Row(
              children: [
                Expanded(child: _reportStat('Total Students', '${summary.totalStudents}')),
                Expanded(child: _reportStat('Total Amount', '₹${_formatAmount(summary.totalAmount)}')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _reportStat('Collected', '₹${_formatAmount(summary.collectedAmount)}', color: Colors.green)),
                Expanded(child: _reportStat('Pending', '₹${_formatAmount(summary.pendingAmount)}', color: Colors.orange)),
              ],
            ),
            const SizedBox(height: 12),
            _reportStat('Overdue Entries', '${summary.overdueCount}', color: Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _reportStat(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: (color ?? Colors.blue).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}

class _ClassFeeReportCard extends StatelessWidget {
  const _ClassFeeReportCard({
    required this.className,
    required this.summary,
  });

  final String className;
  final FeeSummary summary;

  @override
  Widget build(BuildContext context) {
    final percent = summary.collectionPercent;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    className,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: (percent >= 80 ? Colors.green :
                            percent >= 50 ? Colors.orange : Colors.red).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${percent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: percent >= 80 ? Colors.green :
                             percent >= 50 ? Colors.orange : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(
                  percent >= 80 ? Colors.green :
                  percent >= 50 ? Colors.orange : Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniStat('Students', '${summary.totalStudents}'),
                _miniStat('Total', '₹${summary.totalAmount.toStringAsFixed(0)}'),
                _miniStat('Collected', '₹${summary.collectedAmount.toStringAsFixed(0)}', color: Colors.green),
                _miniStat('Pending', '₹${summary.pendingAmount.toStringAsFixed(0)}', color: Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
