import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/unit.dart';
import '../repositories/app_repository.dart';
import '../services/local_storage_service.dart';
import 'repository_provider.dart';
import 'building_stats_provider.dart';

class UnitNotifier extends StateNotifier<Map<String, List<Unit>>> {
  final AppRepository _repository;

  UnitNotifier(this._repository) : super({});

  Future<void> loadUnitsForBuilding(String buildingId, {bool forceRemote = false}) async {
    final units = await _repository.getUnits(buildingId, forceRemote: forceRemote);
    state = {...state, buildingId: units};
  }

  /// Refresca el estado leyendo solo la caché local (sin pasar por
  /// `AppRepository.getUnits`). Se usa justo después de una mutación local
  /// propia: si esa mutación deja la caché vacía (p. ej. se borró el único
  /// apartamento), `getUnits` recurriría a traer de remoto como respaldo, y
  /// esa lectura remota puede llegar antes de que el borrado en cola termine
  /// de subirse, resucitando en pantalla algo que el usuario acaba de borrar.
  void _refreshFromLocal(String buildingId) {
    state = {...state, buildingId: LocalStorageService.getUnitsForBuilding(buildingId)};
  }

  Future<void> addUnit(Unit unit, WidgetRef ref) async {
    await _repository.addUnit(unit);
    _refreshFromLocal(unit.buildingId);
    ref.invalidate(buildingDebtProvider(unit.buildingId));
    ref.invalidate(buildingOccupancyProvider(unit.buildingId));
  }

  Future<void> updateUnit(Unit unit, WidgetRef ref) async {
    await _repository.updateUnit(unit);
    _refreshFromLocal(unit.buildingId);
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
    _refreshFromLocal(buildingId);
    ref.invalidate(buildingDebtProvider(buildingId));
    ref.invalidate(buildingOccupancyProvider(buildingId));
  }
}

final unitProvider =
    StateNotifierProvider<UnitNotifier, Map<String, List<Unit>>>((ref) {
      final repository = ref.watch(appRepositoryProvider);
      return UnitNotifier(repository);
    });
