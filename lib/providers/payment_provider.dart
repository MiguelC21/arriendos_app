import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/monthly_payment.dart';
import '../models/abono.dart';
import '../models/contract.dart';
import '../repositories/app_repository.dart';
import '../services/advance_payment_planner.dart';
import 'repository_provider.dart';
import 'dashboard_provider.dart';
import 'building_stats_provider.dart';

class PaymentNotifier extends StateNotifier<AsyncValue<List<MonthlyPayment>>> {
  final AppRepository _repository;
  final String contractId;

  /// Se llama cada vez que los pagos terminan de cargarse. Sirve para que los
  /// estados/deudas derivados (que leen la caché local) se recalculen: si se
  /// calcularon antes de que llegaran los pagos (p. ej. caché local vacía),
  /// quedaban desactualizados, por ejemplo mostrando "Al Día" con un
  /// adelanto ya registrado.
  final void Function()? _onLoaded;

  PaymentNotifier(this._repository, this.contractId, {void Function()? onLoaded})
      : _onLoaded = onLoaded,
        super(const AsyncValue.loading()) {
    loadPayments();
  }

  Future<void> loadPayments({bool forceRemote = false}) async {
    try {
      final payments = await _repository.getPayments(contractId, forceRemote: forceRemote);
      if (!mounted) return;
      state = AsyncValue.data(payments);
      _onLoaded?.call();
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
    Contract? contract,
    int advanceMonths = 0,
  }) async {
    // Aplicar pago en cascada de forma local-first. Si se pide adelanto, el
    // sobrante después de cubrir la deuda se reparte sobre meses futuros, que
    // se crean solo cuando les llega dinero.
    final payments = await _repository.getPayments(contractId);
    final plan = AdvancePaymentPlanner.plan(
      contract: contract,
      existing: payments,
      amount: totalAmount,
      advanceMonths: advanceMonths,
    );

    // Los meses nuevos se encolan primero para que, al sincronizar, existan
    // en el servidor antes de recibir sus abonos.
    final newPayments = plan.newPayments;
    if (newPayments.isNotEmpty) {
      await _repository.insertMonthlyPaymentsBatch(newPayments);
    }

    final now = DateTime.now();
    for (final a in plan.applications) {
      await _repository.addAbono(
        Abono(
          paymentId: a.payment.id,
          amount: a.amount,
          date: now,
          note: a.payment.isAdvanceAt(now)
              ? 'Adelanto ($method)'
              : 'Pago en cascada ($method)',
        ),
      );
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
      return PaymentNotifier(
        repository,
        contractId,
        onLoaded: () {
          ref.invalidate(unitStatusProvider);
          ref.invalidate(unitDebtProvider);
        },
      );
    });

final abonosProvider = FutureProvider.family<List<Abono>, String>((
  ref,
  paymentId,
) async {
  final repository = ref.watch(appRepositoryProvider);
  return await repository.getAbonosForPayment(paymentId);
});
