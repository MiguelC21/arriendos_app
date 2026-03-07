import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/monthly_payment.dart';
import '../models/abono.dart';
import '../services/supabase_service.dart';
import 'dashboard_provider.dart';
import 'building_stats_provider.dart';

class PaymentNotifier extends StateNotifier<AsyncValue<List<MonthlyPayment>>> {
  final SupabaseService _supabaseService;
  final String contractId;

  PaymentNotifier(this._supabaseService, this.contractId)
    : super(const AsyncValue.loading()) {
    loadPayments();
  }

  Future<void> loadPayments() async {
    try {
      final payments = await _supabaseService.getPayments(contractId);
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
    await _supabaseService.insertAbono(abono);
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
    await _supabaseService.applyCascadingPayment(
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
    await _supabaseService.deleteAbono(abonoId);
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
      return PaymentNotifier(SupabaseService(), contractId);
    });

final abonosProvider = FutureProvider.family<List<Abono>, String>((
  ref,
  paymentId,
) async {
  return await SupabaseService().getAbonosForPayment(paymentId);
});
