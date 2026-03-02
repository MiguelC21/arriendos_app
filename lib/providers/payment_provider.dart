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
    state = await _dbHelper.getPaymentsForContract(contractId);
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
    // 1. Obtener pagos pendientes ordenados por antigüedad (mes/año)
    final allPayments = await _dbHelper.getPaymentsForContract(contractId);
    // Filtrar solo los que deben dinero y ordenar ASC (antiguos primero)
    final pendingPayments = allPayments
        .where((p) => p.paidValue < p.totalValue)
        .toList()
        .reversed
        .toList();

    double remainingMoney = totalAmount;

    for (var payment in pendingPayments) {
      if (remainingMoney <= 0) break;

      double debt = payment.totalValue - payment.paidValue;
      double amountToApply = remainingMoney >= debt ? debt : remainingMoney;

      final abono = Abono(
        paymentId: payment.id,
        value: amountToApply,
        date: DateTime.now(),
        method: method,
      );

      await _dbHelper.insertAbono(abono);
      remainingMoney -= amountToApply;
    }

    // 2. Recargar estado e invalidar providers
    await loadPaymentsForContract(contractId);
    _invalidateStats(ref, buildingId, unitId);
  }

  void _invalidateStats(WidgetRef ref, String buildingId, String unitId) {
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(buildingDebtProvider(buildingId));
    ref.invalidate(unitStatusProvider(unitId));
  }
}

final paymentProvider =
    StateNotifierProvider<PaymentNotifier, List<MonthlyPayment>>((ref) {
      return PaymentNotifier(DatabaseHelper());
    });
