import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/building.dart';
import '../services/supabase_service.dart';
import 'dashboard_provider.dart';

class BuildingNotifier extends AsyncNotifier<List<Building>> {
  SupabaseService get _supabaseService => SupabaseService();

  @override
  Future<List<Building>> build() async {
    return _supabaseService.getBuildings();
  }

  Future<void> addBuilding(Building building) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _supabaseService.insertBuilding(building);
      return _supabaseService.getBuildings();
    });
  }

  Future<void> deleteBuilding(String buildingId, WidgetRef ref) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _supabaseService.deleteBuilding(buildingId);
      // Invalidar estadísticas globales ya que el inmueble desaparece
      ref.invalidate(dashboardStatsProvider);
      return _supabaseService.getBuildings();
    });
  }
}

final buildingProvider =
    AsyncNotifierProvider<BuildingNotifier, List<Building>>(() {
      return BuildingNotifier();
    });
