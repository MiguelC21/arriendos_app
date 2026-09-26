import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/building.dart';
import '../repositories/app_repository.dart';
import 'repository_provider.dart';
import 'dashboard_provider.dart';

class BuildingNotifier extends AsyncNotifier<List<Building>> {
  AppRepository get _repository => ref.read(appRepositoryProvider);

  @override
  Future<List<Building>> build() async {
    return _repository.getBuildings();
  }

  Future<void> addBuilding(Building building) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.addBuilding(building);
      return _repository.getBuildings();
    });
  }

  Future<void> updateBuilding(Building building) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updateBuilding(building);
      return _repository.getBuildings();
    });
  }

  Future<void> deleteBuilding(String buildingId, WidgetRef? refWidget) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteBuilding(buildingId);
      ref.invalidate(dashboardStatsProvider);
      return _repository.getBuildings();
    });
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return _repository.getBuildings(forceRemote: true);
    });
  }
}

final buildingProvider =
    AsyncNotifierProvider<BuildingNotifier, List<Building>>(() {
      return BuildingNotifier();
    });
