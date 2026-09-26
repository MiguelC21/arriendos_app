import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repository_provider.dart';

class DashboardStats {
  final double totalExpected;
  final double totalPaid;
  final int activeTenants;

  DashboardStats({
    required this.totalExpected,
    required this.totalPaid,
    this.activeTenants = 0,
  });

  double get progress => totalExpected > 0 ? (totalPaid / totalExpected).clamp(0.0, 1.0) : 0.0;
  double get pendingDebt => (totalExpected - totalPaid) > 0 ? (totalExpected - totalPaid) : 0.0;
  int get occupancyRatePercentage => activeTenants > 0 ? 100 : 0;
}

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final repository = ref.watch(appRepositoryProvider);
  final now = DateTime.now();

  final stats = await repository.getDashboardStats(now.month, now.year);

  return DashboardStats(
    totalExpected: (stats['totalExpected'] as num?)?.toDouble() ?? 0.0,
    totalPaid: (stats['totalPaid'] as num?)?.toDouble() ?? 0.0,
    activeTenants: (stats['activeCount'] as num?)?.toInt() ?? 0,
  );
});
