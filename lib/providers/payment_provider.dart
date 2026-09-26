import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/monthly_payment.dart';
import '../models/abono.dart';
import '../repositories/app_repository.dart';
import 'repository_provider.dart';
import 'dashboard_provider.dart';
import 'building_stats_provider.dart';

class PaymentNotifier extends StateNotifier<AsyncValue<List<MonthlyPayment>>> {
  final AppRepository _repository;
  final String contractId;

  PaymentNotifier(this._repository, this.contractId)
      : super(const AsyncValue.loading()) {
    loadPayments();
  }

  Future<void> loadPayments({bool forceRemote = false}) async {
    try {
      final payments = await _repository.getPayments(contractId, forceRemote: forceRemote);
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
    await _repository.addAbono(abono);
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
    // Aplicar pago en cascada de forma local-first
    final payments = await _repository.getPayments(contractId);
    final pendingPayments = payments
        .where((p) => p.paidValue < p.totalValue)
        .toList();

    // Ordenar ascendente por año y mes
    pendingPayments.sort((a, b) {
      final y = a.year.compareTo(b.year);
      if (y != 0) return y;
      return a.month.compareTo(b.month);
    });

    double remaining = totalAmount;
    for (var p in pendingPayments) {
      if (remaining <= 0) break;
      final pendingAmount = p.totalValue - p.paidValue;
      final toApply = remaining >= pendingAmount ? pendingAmount : remaining;

      await _repository.addAbono(
        Abono(
          paymentId: p.id,
          amount: toApply,
          date: DateTime.now(),
          note: 'Pago en cascada ($method)',
        ),
      );

      remaining -= toApply;
    }

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
    await _repository.deleteAbono(abonoId);
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
      final repository = ref.watch(appRepositoryProvider);
      return PaymentNotifier(repository, contractId);
    });

final abonosProvider = FutureProvider.family<List<Abono>, String>((
  ref,
  paymentId,
) async {
  final repository = ref.watch(appRepositoryProvider);
  return await repository.getAbonosForPayment(paymentId);
});
