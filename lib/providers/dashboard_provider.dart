import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

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
  final supabaseService = SupabaseService();
  final now = DateTime.now();

  final stats = await supabaseService.getDashboardStats(now.month, now.year);

  return DashboardStats(
    totalExpected: stats['totalExpected'],
    totalPaid: stats['totalPaid'],
    activeTenants: stats['activeCount'],
  );
});
