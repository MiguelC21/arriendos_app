import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/building.dart';
import '../services/database_helper.dart';

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
}

final buildingProvider =
    StateNotifierProvider<BuildingNotifier, List<Building>>((ref) {
      return BuildingNotifier(DatabaseHelper());
    });
