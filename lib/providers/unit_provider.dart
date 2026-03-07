import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/unit.dart';
import '../services/supabase_service.dart';
import 'building_stats_provider.dart';

class UnitNotifier extends StateNotifier<Map<String, List<Unit>>> {
  final SupabaseService _supabaseService;

  UnitNotifier(this._supabaseService) : super({});

  Future<void> loadUnitsForBuilding(String buildingId) async {
    final units = await _supabaseService.getUnits(buildingId);
    state = {...state, buildingId: units};
  }

  Future<void> addUnit(Unit unit, WidgetRef ref) async {
    await _supabaseService.insertUnit(unit);
    await loadUnitsForBuilding(unit.buildingId);
    ref.invalidate(buildingDebtProvider(unit.buildingId));
    ref.invalidate(buildingOccupancyProvider(unit.buildingId));
  }

  Future<void> updateUnit(Unit unit, WidgetRef ref) async {
    await _supabaseService.updateUnit(unit);
    await loadUnitsForBuilding(unit.buildingId);
    ref.invalidate(buildingDebtProvider(unit.buildingId));
    ref.invalidate(unitStatusProvider(unit.id));
    ref.invalidate(buildingOccupancyProvider(unit.buildingId));
  }

  Future<void> deleteUnit(
    String unitId,
    String buildingId,
    WidgetRef ref,
  ) async {
    await _supabaseService.deleteUnit(unitId);
    await loadUnitsForBuilding(buildingId);
    ref.invalidate(buildingDebtProvider(buildingId));
    ref.invalidate(buildingOccupancyProvider(buildingId));
  }
}

final unitProvider =
    StateNotifierProvider<UnitNotifier, Map<String, List<Unit>>>((ref) {
      return UnitNotifier(SupabaseService());
    });
