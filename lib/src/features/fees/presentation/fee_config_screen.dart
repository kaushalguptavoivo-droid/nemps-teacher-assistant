// Fee Configuration Screen
// Admin manages fee types and class-wise fee configuration.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    _tabController = TabController(length: 2, vsync: this);
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.category), text: 'Fee Types'),
            Tab(icon: Icon(Icons.settings), text: 'Class Config'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _FeeTypesTab(),
          _ClassFeeConfigTab(),
        ],
      ),
    );
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
