import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

class TenantInfo {
  final String name;
  final String phone;
  final String unitNumber;
  final String buildingName;
  final String unitId;
  final String buildingId;

  TenantInfo({
    required this.name,
    required this.phone,
    required this.unitNumber,
    required this.buildingName,
    required this.unitId,
    required this.buildingId,
  });
}

final activeTenantsProvider = FutureProvider<List<TenantInfo>>((ref) async {
  final supabaseService = SupabaseService();
  final List<dynamic> results = await supabaseService.getActiveTenants();

  return results.map((res) {
    // Supabase devuelve el join como objetos anidados
    final unit = res['units'];
    final building = unit != null ? unit['buildings'] : null;

    return TenantInfo(
      name: res['tenant_name'] as String,
      phone: res['tenant_phone'] as String? ?? '',
      unitNumber: unit != null ? unit['number'] as String : '?',
      unitId: res['unit_id'] as String,
      buildingName: building != null ? building['name'] as String : '?',
      buildingId: unit != null ? unit['building_id'] as String : '?',
    );
  }).toList();
});
