import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_helper.dart';

final buildingDebtProvider = FutureProvider.family<double, String>((
  ref,
  buildingId,
) async {
  return await DatabaseHelper().getBuildingDebt(buildingId);
});

final unitStatusProvider = FutureProvider.family<String, String>((
  ref,
  unitId,
) async {
  final dbHelper = DatabaseHelper();
  final db = await dbHelper.database;

  final contracts = await db.query(
    'contracts',
    where: 'apartamentoId = ? AND activo = 1',
    whereArgs: [unitId],
    limit: 1,
  );

  if (contracts.isEmpty) return 'Disponible';

  final contractId = contracts.first['id'] as String;

  final payments = await db.query(
    'monthly_payments',
    where: 'contratoId = ? AND valorPagado < valorTotal',
    whereArgs: [contractId],
  );

  if (payments.isEmpty) return 'Al Día';

  final now = DateTime.now();
  bool hasMora = false;
  for (var p in payments) {
    if (p['fechaVencimiento'] != null) {
      final dueDate = DateTime.parse(p['fechaVencimiento'] as String);
      if (now.isAfter(dueDate)) {
        hasMora = true;
        break;
      }
    }
  }

  return hasMora ? 'En Mora' : 'Pendiente';
});

final buildingOccupancyProvider =
    FutureProvider.family<Map<String, int>, String>((ref, buildingId) async {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM units WHERE buildingId = ?',
        [buildingId],
      );

      final rentedResult = await db.rawQuery(
        '''
    SELECT COUNT(*) as count 
    FROM units u
    JOIN contracts c ON u.id = c.apartamentoId
    WHERE u.buildingId = ? AND c.activo = 1
  ''',
        [buildingId],
      );

      final total = (totalResult.first['count'] as int?) ?? 0;
      final rented = (rentedResult.first['count'] as int?) ?? 0;

      return {'total': total, 'rented': rented};
    });

final unitDebtProvider = FutureProvider.family<double, String>((
  ref,
  unitId,
) async {
  return await DatabaseHelper().getUnitDebt(unitId);
});
