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

  // 1. Obtener pagos del mes actual (para saber cuánto se ha pagado hoy)
  final List<Map<String, dynamic>> payments = await db.query(
    'monthly_payments',
    where: 'mes = ? AND año = ?',
    whereArgs: [now.month, now.year],
  );

  double paid = 0.0;
  for (var p in payments) {
    paid += (p['valorPagado'] as num?)?.toDouble() ?? 0.0;
  }

  // 2. Obtener todos los contratos activos para calcular la META POTENCIAL
  final List<Map<String, dynamic>> contracts = await db.query(
    'contracts',
    where: 'activo = 1',
  );

  double expected = 0.0;
  for (var c in contracts) {
    // La columna correcta es 'valorContrato'
    expected += (c['valorContrato'] as num?)?.toDouble() ?? 0.0;
  }

  return DashboardStats(
    totalExpected: expected,
    totalPaid: paid,
    activeTenants: contracts.length,
  );
});
