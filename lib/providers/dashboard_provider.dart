import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_helper.dart';

class DashboardStats {
  final double totalExpected;
  final double totalPaid;
  final int activeTenants;

  DashboardStats({
    required this.totalExpected,
    required this.totalPaid,
    this.activeTenants = 0,
  });

  double get progress => totalExpected > 0 ? totalPaid / totalExpected : 0.0;
}

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final dbHelper = DatabaseHelper();
  final db = await dbHelper.database;
  final now = DateTime.now();

  // 1. Obtener pagos del mes actual
  final List<Map<String, dynamic>> payments = await db.query(
    'monthly_payments',
    where: 'mes = ? AND año = ?',
    whereArgs: [now.month, now.year],
  );

  double expected = 0.0;
  double paid = 0.0;

  for (var p in payments) {
    expected += p['valorTotal'] as double;
    paid += p['valorPagado'] as double;
  }

  // 2. Obtener inquilinos activos (contratos activos)
  final List<Map<String, dynamic>> contracts = await db.query(
    'contracts',
    where: 'activo = 1',
  );

  return DashboardStats(
    totalExpected: expected,
    totalPaid: paid,
    activeTenants: contracts.length,
  );
});
