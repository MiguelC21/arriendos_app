import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/monthly_payment.dart';
import '../models/abono.dart';
import '../services/database_helper.dart';
import 'dashboard_provider.dart';
import 'building_stats_provider.dart';

class PaymentNotifier extends StateNotifier<AsyncValue<List<MonthlyPayment>>> {
  final DatabaseHelper _dbHelper;
  final String contractId;

  PaymentNotifier(this._dbHelper, this.contractId)
    : super(const AsyncValue.loading()) {
    loadPayments();
  }

  Future<void> loadPayments() async {
    try {
      final payments = await _dbHelper.getPaymentsForContract(contractId);
      if (!mounted) return;
      state = AsyncValue.data(payments);
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> addAbono(
    Abono abono,
    String buildingId,
    String unitId,
    WidgetRef ref,
  ) async {
    await _dbHelper.insertAbono(abono);
    await loadPayments();
    if (!mounted) return;
    _invalidateStats(ref, buildingId, unitId);
  }

  Future<void> applyCascadingPayment({
    required double totalAmount,
    required String method,
    required String buildingId,
    required String unitId,
    required WidgetRef ref,
  }) async {
    await _dbHelper.applyCascadingPayment(
      totalAmount: totalAmount,
      method: method,
      contractId: contractId,
    );

    await loadPayments();
    if (!mounted) return;
    _invalidateStats(ref, buildingId, unitId);
  }

  Future<void> deleteAbono({
    required String abonoId,
    required String buildingId,
    required String unitId,
    required WidgetRef ref,
  }) async {
    await _dbHelper.deleteAbono(abonoId);
    await loadPayments();
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
    StateNotifierProvider.family<
      PaymentNotifier,
      AsyncValue<List<MonthlyPayment>>,
      String
    >((ref, contractId) {
      return PaymentNotifier(DatabaseHelper(), contractId);
    });

final abonosProvider = FutureProvider.family<List<Abono>, String>((
  ref,
  paymentId,
) async {
  return await DatabaseHelper().getAbonosForPayment(paymentId);
});
