import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/monthly_payment.dart';
import '../models/abono.dart';
import '../services/database_helper.dart';
import 'dashboard_provider.dart';
import 'building_stats_provider.dart';

class PaymentNotifier extends StateNotifier<List<MonthlyPayment>> {
  final DatabaseHelper _dbHelper;

  PaymentNotifier(this._dbHelper) : super([]);

  Future<void> loadPaymentsForContract(String contractId) async {
    final payments = await _dbHelper.getPaymentsForContract(contractId);
    if (!mounted) return;
    state = payments;
  }

  Future<void> addAbono(
    Abono abono,
    String contractId,
    String buildingId,
    String unitId,
    WidgetRef ref,
  ) async {
    await _dbHelper.insertAbono(abono);
    await loadPaymentsForContract(contractId);
    if (!mounted) return;
    _invalidateStats(ref, buildingId, unitId);
  }

  Future<void> applyCascadingPayment({
    required double totalAmount,
    required String method,
    required String contractId,
    required String buildingId,
    required String unitId,
    required WidgetRef ref,
  }) async {
    await _dbHelper.applyCascadingPayment(
      totalAmount: totalAmount,
      method: method,
      contractId: contractId,
    );

    await loadPaymentsForContract(contractId);
    if (!mounted) return;
    _invalidateStats(ref, buildingId, unitId);
  }

  Future<void> deleteAbono({
    required String abonoId,
    required String contractId,
    required String buildingId,
    required String unitId,
    required WidgetRef ref,
  }) async {
    await _dbHelper.deleteAbono(abonoId);
    await loadPaymentsForContract(contractId);
    if (!mounted) return;
    _invalidateStats(ref, buildingId, unitId);
  }

  void _invalidateStats(ref, String buildingId, String unitId) {
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(buildingDebtProvider(buildingId));
    ref.invalidate(unitStatusProvider(unitId));
    ref.invalidate(unitDebtProvider(unitId));
    ref.invalidate(abonosProvider);
  }
}

final paymentProvider =
    StateNotifierProvider<PaymentNotifier, List<MonthlyPayment>>((ref) {
      return PaymentNotifier(DatabaseHelper());
    });

final abonosProvider = FutureProvider.family<List<Abono>, String>((
  ref,
  paymentId,
) async {
  return await DatabaseHelper().getAbonosForPayment(paymentId);
});
