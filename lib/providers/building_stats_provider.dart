import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_helper.dart';

final buildingDebtProvider = FutureProvider.family<double, String>((
  ref,
  buildingId,
) async {
  final dbHelper = DatabaseHelper();
  final db = await dbHelper.database;

  // 1. Obtener todas las unidades del edificio
  final units = await db.query(
    'units',
    where: 'buildingId = ?',
    whereArgs: [buildingId],
  );

  double totalDebt = 0.0;

  for (var unit in units) {
    final unitId = unit['id'] as String;

    // 2. Obtener contrato activo para la unidad
    final contracts = await db.query(
      'contracts',
      where: 'apartamentoId = ? AND activo = 1',
      whereArgs: [unitId],
      limit: 1,
    );

    if (contracts.isNotEmpty) {
      final contractId = contracts.first['id'] as String;

      // 3. Sumar valorTotal - valorPagado de todos los pagos de ese contrato
      final payments = await db.query(
        'monthly_payments',
        where: 'contratoId = ?',
        whereArgs: [contractId],
      );

      for (var p in payments) {
        final total = p['valorTotal'] as double;
        final paid = p['valorPagado'] as double;
        if (total > paid) {
          totalDebt += (total - paid);
        }
      }
    }
  }

  return totalDebt;
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
  final dbHelper = DatabaseHelper();
  final db = await dbHelper.database;

  final contracts = await db.query(
    'contracts',
    where: 'apartamentoId = ? AND activo = 1',
    whereArgs: [unitId],
    limit: 1,
  );

  if (contracts.isEmpty) return 0.0;

  final contractId = contracts.first['id'] as String;

  final payments = await db.query(
    'monthly_payments',
    where: 'contratoId = ?',
    whereArgs: [contractId],
  );

  double debt = 0.0;
  for (var p in payments) {
    final total = p['valorTotal'] as double;
    final paid = p['valorPagado'] as double;
    if (total > paid) {
      debt += (total - paid);
    }
  }

  return debt;
});
