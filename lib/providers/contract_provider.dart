import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contract.dart';
import '../models/monthly_payment.dart';
import '../services/database_helper.dart';
import 'building_stats_provider.dart';
import 'dashboard_provider.dart';
import 'tenant_provider.dart';
import 'payment_provider.dart';

class ContractNotifier extends StateNotifier<Map<String, Contract?>> {
  final DatabaseHelper _dbHelper;

  ContractNotifier(this._dbHelper) : super({});

  Future<void> loadActiveContractForUnit(String unitId) async {
    final contract = await _dbHelper.getActiveContractForUnit(unitId);
    if (!mounted) return;
    state = {...state, unitId: contract};

    if (contract != null) {
      await _checkAndGenerateMonthlyPayment(contract);
    }
  }

  Future<void> addContract(
    Contract contract,
    String buildingId,
    WidgetRef ref,
  ) async {
    await _dbHelper.insertContract(contract);
    await loadActiveContractForUnit(contract.unitId);
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(activeTenantsProvider);
    ref.invalidate(buildingOccupancyProvider(buildingId));
    ref.invalidate(unitDebtProvider(contract.unitId));
    ref.invalidate(unitStatusProvider(contract.unitId));
    ref.invalidate(buildingDebtProvider(buildingId));
    // Importante: invalidar la lista de pagos para que el primer cobro generado aparezca
    ref.invalidate(paymentProvider);
  }

  Future<void> terminateContract(
    String contractId,
    String unitId,
    String buildingId,
    WidgetRef ref,
  ) async {
    await _dbHelper.terminateContract(contractId);
    if (!mounted) return;
    state = {...state, unitId: null};

    // Invalidar para que la UI se refresque y el apto salga como Disponible
    ref.invalidate(buildingDebtProvider(buildingId));
    ref.invalidate(unitStatusProvider(unitId));
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(activeTenantsProvider);
    ref.invalidate(buildingOccupancyProvider(buildingId));
    ref.invalidate(unitDebtProvider(unitId));
  }

  Future<void> updateContract(Contract contract, WidgetRef ref) async {
    await _dbHelper.updateContract(contract);
    if (!mounted) return;
    state = {...state, contract.unitId: contract};
    ref.invalidate(activeTenantsProvider);
  }

  Future<void> _checkAndGenerateMonthlyPayment(Contract contract) async {
    final now = DateTime.now();

    // Empezamos desde el mes de inicio del contrato
    DateTime checkDate = DateTime(
      contract.startDate.year,
      contract.startDate.month,
    );

    // Mientras la fecha que revisamos no sea futura al mes actual
    while (checkDate.isBefore(now) ||
        (checkDate.year == now.year && checkDate.month == now.month)) {
      // Un pago de un mes X se genera si ya llegamos al día pactado en ese mes
      // Si el contrato empezó un 31 y el mes tiene 28, usamos el 28.
      final lastDayOfMonth = DateTime(
        checkDate.year,
        checkDate.month + 1,
        0,
      ).day;
      final dayToUse = contract.startDate.day > lastDayOfMonth
          ? lastDayOfMonth
          : contract.startDate.day;

      final generationDate = DateTime(
        checkDate.year,
        checkDate.month,
        dayToUse,
      );

      if (now.isAfter(generationDate) || now.isAtSameMomentAs(generationDate)) {
        final existingPayment = await _dbHelper.getPaymentForMonth(
          contract.id,
          checkDate.month,
          checkDate.year,
        );

        if (existingPayment == null) {
          // La fecha límite es el mismo día del SIGUIENTE mes (pago a mes vencido)
          final lastDayOfNextMonth = DateTime(
            checkDate.year,
            checkDate.month + 2,
            0,
          ).day;
          final dayToUseNext = contract.startDate.day > lastDayOfNextMonth
              ? lastDayOfNextMonth
              : contract.startDate.day;

          final dueDate = DateTime(
            checkDate.year,
            checkDate.month + 1,
            dayToUseNext,
          );

          final payment = MonthlyPayment(
            contractId: contract.id,
            month: checkDate.month,
            year: checkDate.year,
            totalValue: contract.contractValue,
            dueDate: dueDate,
            status: PaymentStatus.pendiente,
          );
          await _dbHelper.insertMonthlyPayment(payment);
        }
      }

      // Siguiente mes para la comprobación
      checkDate = DateTime(checkDate.year, checkDate.month + 1);
    }
  }
}

final contractProvider =
    StateNotifierProvider<ContractNotifier, Map<String, Contract?>>((ref) {
      return ContractNotifier(DatabaseHelper());
    });
