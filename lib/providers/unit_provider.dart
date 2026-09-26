import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/unit.dart';
import '../repositories/app_repository.dart';
import 'repository_provider.dart';
import 'building_stats_provider.dart';

class UnitNotifier extends StateNotifier<Map<String, List<Unit>>> {
  final AppRepository _repository;

  UnitNotifier(this._repository) : super({});

  Future<void> loadUnitsForBuilding(String buildingId, {bool forceRemote = false}) async {
    final units = await _repository.getUnits(buildingId, forceRemote: forceRemote);
    state = {...state, buildingId: units};
  }

  Future<void> addUnit(Unit unit, WidgetRef ref) async {
    await _repository.addUnit(unit);
    await loadUnitsForBuilding(unit.buildingId);
    ref.invalidate(buildingDebtProvider(unit.buildingId));
    ref.invalidate(buildingOccupancyProvider(unit.buildingId));
  }

  Future<void> updateUnit(Unit unit, WidgetRef ref) async {
    await _repository.updateUnit(unit);
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
    await _repository.deleteUnit(unitId);
    await loadUnitsForBuilding(buildingId);
    ref.invalidate(buildingDebtProvider(buildingId));
    ref.invalidate(buildingOccupancyProvider(buildingId));
  }
}

final unitProvider =
    StateNotifierProvider<UnitNotifier, Map<String, List<Unit>>>((ref) {
      final repository = ref.watch(appRepositoryProvider);
      return UnitNotifier(repository);
    });
