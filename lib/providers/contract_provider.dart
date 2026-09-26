import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contract.dart';
import '../models/monthly_payment.dart';
import '../repositories/app_repository.dart';
import 'repository_provider.dart';
import 'building_stats_provider.dart';
import 'dashboard_provider.dart';
import 'tenant_provider.dart';
import 'payment_provider.dart';

class ContractNotifier extends StateNotifier<Map<String, Contract?>> {
  final AppRepository _repository;
  final Set<String> _processingContracts = {};

  ContractNotifier(this._repository) : super({});

  Future<void> loadActiveContractForUnit(String unitId, {bool forceRemote = false}) async {
    final contract = await _repository.getActiveContract(unitId, forceRemote: forceRemote);
    if (!mounted) return;
    state = {...state, unitId: contract};

    if (contract != null) {
      await _checkAndGenerateMonthlyPayment(contract);
    }
  }

  Future<void> loadActiveContractsForBuilding(String buildingId) async {
    final contracts = await _repository.getActiveContractsForBuilding(buildingId);
    if (!mounted) return;

    final Map<String, Contract?> newEntries = {};
    for (var contract in contracts) {
      newEntries[contract.unitId] = contract;
    }

    state = {...state, ...newEntries};

    for (var contract in contracts) {
      _checkAndGenerateMonthlyPayment(contract);
    }
  }

  Future<void> addContract(
    Contract contract,
    String buildingId,
    WidgetRef ref,
  ) async {
    await _repository.addContract(contract);
    await loadActiveContractForUnit(contract.unitId);
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(activeTenantsProvider);
    ref.invalidate(buildingOccupancyProvider(buildingId));
    ref.invalidate(unitDebtProvider(contract.unitId));
    ref.invalidate(unitStatusProvider(contract.unitId));
    ref.invalidate(buildingDebtProvider(buildingId));
    ref.invalidate(paymentProvider);
  }

  Future<void> terminateContract(
    String contractId,
    String unitId,
    String buildingId,
    WidgetRef ref,
  ) async {
    await _repository.terminateContract(contractId);
    if (!mounted) return;
    state = {...state, unitId: null};

    ref.invalidate(buildingDebtProvider(buildingId));
    ref.invalidate(unitStatusProvider(unitId));
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(activeTenantsProvider);
    ref.invalidate(buildingOccupancyProvider(buildingId));
    ref.invalidate(unitDebtProvider(unitId));
  }

  Future<void> updateContract(Contract contract, WidgetRef ref) async {
    await _repository.updateContract(contract);
    if (!mounted) return;
    state = {...state, contract.unitId: contract};
    ref.invalidate(activeTenantsProvider);
  }

  Future<void> _checkAndGenerateMonthlyPayment(Contract contract) async {
    if (_processingContracts.contains(contract.id)) return;
    _processingContracts.add(contract.id);

    try {
      final now = DateTime.now();

      final existingPayments = await _repository.getPayments(contract.id);
      final Set<String> existingKeys = existingPayments
          .map((p) => '${p.month}-${p.year}')
          .toSet();

      List<MonthlyPayment> paymentsToInsert = [];
      DateTime checkDate = DateTime(
        contract.startDate.year,
        contract.startDate.month,
      );

      while (checkDate.isBefore(now) ||
          (checkDate.year == now.year && checkDate.month == now.month)) {
        final key = '${checkDate.month}-${checkDate.year}';

        if (!existingKeys.contains(key)) {
          int generationDay = contract.startDate.day;
          int lastDayOfCheckMonth = DateTime(
            checkDate.year,
            checkDate.month + 1,
            0,
          ).day;
          if (generationDay > lastDayOfCheckMonth) {
            generationDay = lastDayOfCheckMonth;
          }

          if (checkDate.year == now.year && checkDate.month == now.month) {
            if (now.day < generationDay) {
              break;
            }
          }

          final dueDateDay =
              contract.startDate.day >
                      DateTime(checkDate.year, checkDate.month + 2, 0).day
                  ? DateTime(checkDate.year, checkDate.month + 2, 0).day
                  : contract.startDate.day;

          final dueDate = DateTime(
            checkDate.year,
            checkDate.month + 1,
            dueDateDay,
          );

          paymentsToInsert.add(
            MonthlyPayment(
              contractId: contract.id,
              month: checkDate.month,
              year: checkDate.year,
              totalValue: contract.contractValue,
              dueDate: dueDate,
              status: PaymentStatus.pendiente,
            ),
          );
        }
        checkDate = DateTime(checkDate.year, checkDate.month + 1);
      }
      if (paymentsToInsert.isNotEmpty) {
        debugPrint('Insertando ${paymentsToInsert.length} pagos mensuales...');
        await _repository.insertMonthlyPaymentsBatch(paymentsToInsert);
      }
    } finally {
      _processingContracts.remove(contract.id);
    }
  }
}

final contractProvider =
    StateNotifierProvider<ContractNotifier, Map<String, Contract?>>((ref) {
      final repository = ref.watch(appRepositoryProvider);
      return ContractNotifier(repository);
    });
