import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repository_provider.dart';

final buildingDebtProvider = FutureProvider.family<double, String>((
  ref,
  buildingId,
) async {
  final repository = ref.watch(appRepositoryProvider);
  return await repository.getBuildingDebt(buildingId);
});

final unitStatusProvider = FutureProvider.family<String, String>((
  ref,
  unitId,
) async {
  final repository = ref.watch(appRepositoryProvider);
  return await repository.getUnitStatus(unitId);
});

final buildingOccupancyProvider =
    FutureProvider.family<Map<String, int>, String>((ref, buildingId) async {
      final repository = ref.watch(appRepositoryProvider);

      // Obtenemos todas las unidades de este edificio
      final units = await repository.getUnits(buildingId);
      final total = units.length;

      // Contamos cuántas tienen contrato activo
      int rented = 0;
      for (var unit in units) {
        final contract = await repository.getActiveContract(unit.id);
        if (contract != null) rented++;
      }

      return {'total': total, 'rented': rented};
    });

final unitDebtProvider = FutureProvider.family<double, String>((
  ref,
  unitId,
) async {
  final repository = ref.watch(appRepositoryProvider);
  return await repository.getUnitDebt(unitId);
});
