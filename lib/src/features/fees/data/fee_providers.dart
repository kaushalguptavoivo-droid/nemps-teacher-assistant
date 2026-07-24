// Fees Module — Riverpod Providers
// All providers for the Fees Module.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/fee_models.dart';
import 'fee_repository.dart';

// ── Repository Provider ───────────────────────────────────────────────────────

final feeRepoProvider = Provider<FeeRepository>(
  (_) => FeeRepository(Supabase.instance.client),
);

// ── Fee Types ─────────────────────────────────────────────────────────────────

final feeTypesProvider = FutureProvider.family<List<FeeType>, String>(
    (ref, academicYear) async {
  return ref.read(feeRepoProvider).getFeeTypes(academicYear);
});

// ── Class Fee Configs ────────────────────────────────────────────────────────

final classFeeConfigsProvider =
    FutureProvider.family<List<ClassFeeConfig>, ({String classId, String year})>(
        (ref, args) async {
  return ref.read(feeRepoProvider).getClassFeeConfigs(args.classId, args.year);
});
