import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/unit.dart';
import '../services/database_helper.dart';
import 'building_stats_provider.dart';

class UnitNotifier extends StateNotifier<Map<String, List<Unit>>> {
  final DatabaseHelper _dbHelper;

  UnitNotifier(this._dbHelper) : super({});

  Future<void> loadUnitsForBuilding(String buildingId) async {
    final units = await _dbHelper.getUnitsForBuilding(buildingId);
    state = {...state, buildingId: units};
  }

  Future<void> addUnit(Unit unit, WidgetRef ref) async {
    await _dbHelper.insertUnit(unit);
    await loadUnitsForBuilding(unit.buildingId);
    ref.invalidate(buildingDebtProvider(unit.buildingId));
  }

  Future<void> updateUnit(Unit unit, WidgetRef ref) async {
    await _dbHelper.updateUnit(unit);
    await loadUnitsForBuilding(unit.buildingId);
    ref.invalidate(buildingDebtProvider(unit.buildingId));
    ref.invalidate(unitStatusProvider(unit.id));
  }

  Future<void> deleteUnit(
    String unitId,
    String buildingId,
    WidgetRef ref,
  ) async {
    await _dbHelper.deleteUnit(unitId);
    await loadUnitsForBuilding(buildingId);
    ref.invalidate(buildingDebtProvider(buildingId));
  }
}

final unitProvider =
    StateNotifierProvider<UnitNotifier, Map<String, List<Unit>>>((ref) {
      return UnitNotifier(DatabaseHelper());
    });
