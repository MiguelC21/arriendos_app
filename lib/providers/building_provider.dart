import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/building.dart';
import '../services/database_helper.dart';
import 'dashboard_provider.dart';

class BuildingNotifier extends StateNotifier<List<Building>> {
  final DatabaseHelper _dbHelper;

  BuildingNotifier(this._dbHelper) : super([]) {
    loadBuildings();
  }

  Future<void> loadBuildings() async {
    state = await _dbHelper.getBuildings();
  }

  Future<void> addBuilding(Building building) async {
    await _dbHelper.insertBuilding(building);
    await loadBuildings();
  }

  Future<void> deleteBuilding(String buildingId, WidgetRef ref) async {
    await _dbHelper.deleteBuilding(buildingId);
    await loadBuildings();
    // Invalidar estadísticas globales ya que el inmueble desaparece
    ref.invalidate(dashboardStatsProvider);
  }
}

final buildingProvider =
    StateNotifierProvider<BuildingNotifier, List<Building>>((ref) {
      return BuildingNotifier(DatabaseHelper());
    });
