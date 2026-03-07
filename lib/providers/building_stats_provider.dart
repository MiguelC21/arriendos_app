import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

final buildingDebtProvider = FutureProvider.family<double, String>((
  ref,
  buildingId,
) async {
  return await SupabaseService().getBuildingDebt(buildingId);
});

final unitStatusProvider = FutureProvider.family<String, String>((
  ref,
  unitId,
) async {
  return await SupabaseService().getUnitStatus(unitId);
});

final buildingOccupancyProvider =
    FutureProvider.family<Map<String, int>, String>((ref, buildingId) async {
      final supabaseService = SupabaseService();

      // Obtenemos todas las unidades de este edificio
      final units = await supabaseService.getUnits(buildingId);
      final total = units.length;

      // Contamos cuántas tienen contrato activo
      int rented = 0;
      for (var unit in units) {
        final contract = await supabaseService.getActiveContract(unit.id);
        if (contract != null) rented++;
      }

      return {'total': total, 'rented': rented};
    });

final unitDebtProvider = FutureProvider.family<double, String>((
  ref,
  unitId,
) async {
  return await SupabaseService().getUnitDebt(unitId);
});
