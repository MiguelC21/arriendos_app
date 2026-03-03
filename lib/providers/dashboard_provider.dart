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

  // 1. Obtener suma de pagos del mes actual vía SQL (Mucho más rápido)
  final List<Map<String, dynamic>> paidResult = await db.rawQuery(
    'SELECT SUM(valorPagado) as total FROM monthly_payments WHERE mes = ? AND año = ?',
    [now.month, now.year],
  );
  double paid = (paidResult.first['total'] as num?)?.toDouble() ?? 0.0;

  // 2. Obtener META POTENCIAL y conteo de inquilinos vía SQL
  final List<Map<String, dynamic>> contractResult = await db.rawQuery(
    'SELECT COUNT(*) as count, SUM(valorContrato) as total FROM contracts WHERE activo = 1',
  );

  int count = (contractResult.first['count'] as int?) ?? 0;
  double expected = (contractResult.first['total'] as num?)?.toDouble() ?? 0.0;

  return DashboardStats(
    totalExpected: expected,
    totalPaid: paid,
    activeTenants: count,
  );
});
