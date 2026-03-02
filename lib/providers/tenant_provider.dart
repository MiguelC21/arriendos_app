import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_helper.dart';

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
  final dbHelper = DatabaseHelper();
  final db = await dbHelper.database;

  final List<Map<String, dynamic>> results = await db.rawQuery('''
    SELECT 
      c.nombreInquilino as name,
      c.telefono as phone,
      u.numero as unitNumber,
      u.id as unitId,
      b.name as buildingName,
      b.id as buildingId
    FROM contracts c
    JOIN units u ON c.apartamentoId = u.id
    JOIN buildings b ON u.buildingId = b.id
    WHERE c.activo = 1
    ORDER BY b.name, u.numero
  ''');

  return results
      .map(
        (res) => TenantInfo(
          name: res['name'] as String,
          phone: res['phone'] as String,
          unitNumber: res['unitNumber'] as String,
          buildingName: res['buildingName'] as String,
          unitId: res['unitId'] as String,
          buildingId: res['buildingId'] as String,
        ),
      )
      .toList();
});
