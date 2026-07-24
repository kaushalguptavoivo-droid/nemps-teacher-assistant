// Fees Module — Repository
// Handles all fee-related database operations.

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/fee_models.dart';

class FeeRepository {
  FeeRepository(this._client);
  final SupabaseClient _client;
  final _uuid = const Uuid();

  // ── Fee Types ────────────────────────────────────────────────────────────────

  Future<List<FeeType>> getFeeTypes(String academicYear) async {
    try {
      final data = await _client
          .from('fee_types')
          .select()
          .eq('academic_year', academicYear)
          .order('name');
      return data.map((r) => FeeType.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addFeeType({
    required String name,
    required String description,
    required double amount,
    required String frequency,
    required String academicYear,
  }) async {
    final row = {
      'id': _uuid.v4(),
      'name': name,
      'description': description,
      'amount': amount,
      'frequency': frequency,
      'academic_year': academicYear,
      'is_active': true,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _client.from('fee_types').insert(row);
  }

  Future<void> updateFeeType(FeeType feeType) async {
    await _client.from('fee_types').update({
      'name': feeType.name,
      'description': feeType.description,
      'amount': feeType.amount,
      'frequency': feeType.frequency,
      'is_active': feeType.isActive,
    }).eq('id', feeType.id);
  }

  Future<void> deleteFeeType(String id) async {
    await _client.from('fee_types').delete().eq('id', id);
  }

  // ── Class Fee Config ─────────────────────────────────────────────────────────

  Future<List<ClassFeeConfig>> getClassFeeConfigs(
      String classId, String academicYear) async {
    try {
      final data = await _client
          .from('class_fee_configs')
          .select()
          .eq('class_id', classId)
          .eq('academic_year', academicYear);
      return data.map((r) => ClassFeeConfig.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveClassFeeConfig(ClassFeeConfig config) async {
    final existing = await _client
        .from('class_fee_configs')
        .select()
        .eq('class_id', config.classId)
        .eq('fee_type_id', config.feeTypeId)
        .eq('academic_year', config.academicYear)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('class_fee_configs')
          .update(config.toUpdateMap())
          .eq('id', existing['id']);
    } else {
      await _client.from('class_fee_configs').insert({
        'id': _uuid.v4(),
        ...config.toInsertMap(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }
}
