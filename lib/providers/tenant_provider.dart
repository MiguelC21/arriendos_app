import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repository_provider.dart';

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
  final repository = ref.watch(appRepositoryProvider);
  final List<dynamic> results = await repository.getActiveTenants();

  return results.map((res) {
    final unit = res['units'];
    final building = unit != null ? unit['buildings'] : null;

    final phone = (res['phone'] ?? res['tenant_phone'] ?? '') as String;

    return TenantInfo(
      name: (res['tenant_name'] ?? '') as String,
      phone: phone,
      unitNumber: unit != null ? (unit['number'] ?? '?') as String : '?',
      unitId: (res['unit_id'] ?? '') as String,
      buildingName: building != null ? (building['name'] ?? '?') as String : '?',
      buildingId: unit != null ? (unit['building_id'] ?? '?') as String : '?',
    );
  }).toList();
});
