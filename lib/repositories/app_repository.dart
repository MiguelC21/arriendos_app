import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/building.dart';
import '../models/unit.dart';
import '../models/contract.dart';
import '../models/monthly_payment.dart';
import '../models/abono.dart';
import '../services/local_storage_service.dart';
import '../services/supabase_service.dart';
import '../services/sync_manager.dart';

class AppRepository {
  final SupabaseService _supabaseService;
  final SyncNotifier? _syncNotifier;

  AppRepository({
    SupabaseService? supabaseService,
    SyncNotifier? syncNotifier,
  })  : _supabaseService = supabaseService ?? SupabaseService(),
        _syncNotifier = syncNotifier;

  // ==========================================
  // 🏠 BUILDINGS
  // ==========================================
  Future<List<Building>> getBuildings({bool forceRemote = false}) async {
    final localList = LocalStorageService.getAllBuildings();
    if (localList.isNotEmpty && !forceRemote) {
      return localList;
    }

    try {
      final remoteList = await _supabaseService.getBuildings();
      if (remoteList.isNotEmpty) {
        await LocalStorageService.saveBuildingsBatch(remoteList);
        return remoteList;
      }
    } catch (e) {
      debugPrint('Aviso repositorio: Supabase no disponible al listar edificios ($e). Usando local.');
    }
    return localList;
  }

  Future<void> addBuilding(Building building) async {
    // 1. Guardar inmediatamente en local
    await LocalStorageService.saveBuilding(building);

    // 2. Encolar en la lista de sync
    final queueId = const Uuid().v4();
    await LocalStorageService.addToSyncQueue(
      queueId: queueId,
      table: 'buildings',
      action: 'insert',
      data: building.toMap(),
    );

    _syncNotifier?.notifyLocalMutation();
    _triggerSync();
  }

  Future<void> updateBuilding(Building building) async {
    await LocalStorageService.saveBuilding(building);

    final queueId = const Uuid().v4();
    await LocalStorageService.addToSyncQueue(
      queueId: queueId,
      table: 'buildings',
      action: 'update',
      data: building.toMap(),
    );

    _syncNotifier?.notifyLocalMutation();
    _triggerSync();
  }

  Future<void> deleteBuilding(String id) async {
    await LocalStorageService.deleteBuilding(id);

    final queueId = const Uuid().v4();
    await LocalStorageService.addToSyncQueue(
      queueId: queueId,
      table: 'buildings',
      action: 'delete',
      data: {'id': id},
    );

    _syncNotifier?.notifyLocalMutation();
    _triggerSync();
  }

  // ==========================================
  // 🏢 UNITS
  // ==========================================
  Future<List<Unit>> getUnits(String buildingId, {bool forceRemote = false}) async {
    final localUnits = LocalStorageService.getUnitsForBuilding(buildingId);
    if (localUnits.isNotEmpty && !forceRemote) {
      return localUnits;
    }

    try {
      final remoteUnits = await _supabaseService.getUnits(buildingId);
      if (remoteUnits.isNotEmpty) {
        await LocalStorageService.saveUnitsBatch(remoteUnits);
        return remoteUnits;
      }
    } catch (e) {
      debugPrint('Aviso repositorio: Supabase no disponible para unidades ($e). Usando local.');
    }
    return localUnits;
  }

  Future<Unit?> getUnitById(String id) async {
    final local = LocalStorageService.getUnitById(id);
    if (local != null) return local;

    try {
      final remote = await _supabaseService.getUnitById(id);
      if (remote != null) {
        await LocalStorageService.saveUnit(remote);
        return remote;
      }
    } catch (e) {
      debugPrint('Error buscando unidad remota: $e');
    }
    return null;
  }

  Future<void> addUnit(Unit unit) async {
    await LocalStorageService.saveUnit(unit);

    final queueId = const Uuid().v4();
    await LocalStorageService.addToSyncQueue(
      queueId: queueId,
      table: 'units',
      action: 'insert',
      data: unit.toMap(),
    );

    _syncNotifier?.notifyLocalMutation();
    _triggerSync();
  }

  Future<void> updateUnit(Unit unit) async {
    await LocalStorageService.saveUnit(unit);

    final queueId = const Uuid().v4();
    await LocalStorageService.addToSyncQueue(
      queueId: queueId,
      table: 'units',
      action: 'update',
      data: unit.toMap(),
    );

    _syncNotifier?.notifyLocalMutation();
    _triggerSync();
  }

  Future<void> deleteUnit(String id) async {
    await LocalStorageService.deleteUnit(id);

    final queueId = const Uuid().v4();
    await LocalStorageService.addToSyncQueue(
      queueId: queueId,
      table: 'units',
      action: 'delete',
      data: {'id': id},
    );

    _syncNotifier?.notifyLocalMutation();
    _triggerSync();
  }

  // ==========================================
  // 📜 CONTRACTS
  // ==========================================
  Future<Contract?> getActiveContract(String unitId, {bool forceRemote = false}) async {
    final local = LocalStorageService.getActiveContractForUnit(unitId);
    if (local != null && !forceRemote) return local;

    try {
      final remote = await _supabaseService.getActiveContract(unitId);
      if (remote != null) {
        await LocalStorageService.saveContract(remote);
        return remote;
      }
    } catch (e) {
      debugPrint('Aviso contrato: offline ($e).');
    }
    return local;
  }

  Future<List<Contract>> getActiveContractsForBuilding(String buildingId) async {
    final local = LocalStorageService.getActiveContractsForBuilding(buildingId);
    if (local.isNotEmpty) return local;

    try {
      final remote = await _supabaseService.getActiveContractsForBuilding(buildingId);
      if (remote.isNotEmpty) {
        await LocalStorageService.saveContractsBatch(remote);
        return remote;
      }
    } catch (e) {
      debugPrint('Aviso contratos de edificio: offline ($e).');
    }
    return local;
  }

  Future<void> addContract(Contract contract) async {
    await LocalStorageService.saveContract(contract);

    final queueId = const Uuid().v4();
    await LocalStorageService.addToSyncQueue(
      queueId: queueId,
      table: 'contracts',
      action: 'insert',
      data: contract.toMap(),
    );

    _syncNotifier?.notifyLocalMutation();
    _triggerSync();
  }

  Future<void> updateContract(Contract contract) async {
    await LocalStorageService.saveContract(contract);

    final queueId = const Uuid().v4();
    await LocalStorageService.addToSyncQueue(
      queueId: queueId,
      table: 'contracts',
      action: 'update',
      data: contract.toMap(),
    );

    _syncNotifier?.notifyLocalMutation();
    _triggerSync();
  }

  Future<void> terminateContract(String id) async {
    await LocalStorageService.deleteContract(id);

    final queueId = const Uuid().v4();
    await LocalStorageService.addToSyncQueue(
      queueId: queueId,
      table: 'contracts',
      action: 'delete',
      data: {'id': id},
    );

    _syncNotifier?.notifyLocalMutation();
    _triggerSync();
  }

  // ==========================================
  // 💰 PAYMENTS & ABONOS
  // ==========================================
  Future<List<MonthlyPayment>> getPayments(String contractId, {bool forceRemote = false}) async {
    final local = LocalStorageService.getPaymentsForContract(contractId);
    if (local.isNotEmpty && !forceRemote) return local;

    try {
      final remote = await _supabaseService.getPayments(contractId);
      if (remote.isNotEmpty) {
        await LocalStorageService.saveMonthlyPaymentsBatch(remote);
        return remote;
      }
    } catch (e) {
      debugPrint('Aviso pagos: offline ($e).');
    }
    return local;
  }

  Future<void> insertMonthlyPaymentsBatch(List<MonthlyPayment> payments) async {
    if (payments.isEmpty) return;
    await LocalStorageService.saveMonthlyPaymentsBatch(payments);

    for (var p in payments) {
      final queueId = const Uuid().v4();
      await LocalStorageService.addToSyncQueue(
        queueId: queueId,
        table: 'monthly_payments',
        action: 'insert',
        data: p.toMap(),
      );
    }

    _syncNotifier?.notifyLocalMutation();
    _triggerSync();
  }

  Future<List<Abono>> getAbonosForPayment(String paymentId, {bool forceRemote = false}) async {
    final local = LocalStorageService.getAbonosForPayment(paymentId);
    if (local.isNotEmpty && !forceRemote) return local;

    try {
      final remote = await _supabaseService.getAbonosForPayment(paymentId);
      if (remote.isNotEmpty) {
        await LocalStorageService.saveAbonosBatch(remote);
        return remote;
      }
    } catch (e) {
      debugPrint('Aviso abonos: offline ($e).');
    }
    return local;
  }

  Future<void> addAbono(Abono abono) async {
    await LocalStorageService.saveAbono(abono);

    final queueId = const Uuid().v4();
    await LocalStorageService.addToSyncQueue(
      queueId: queueId,
      table: 'abonos',
      action: 'insert',
      data: abono.toMap(),
    );

    // Actualizar también el monthly_payment afectado en la cola
    final updatedPayment = LocalStorageService.getPaymentById(abono.paymentId);
    if (updatedPayment != null) {
      final pQueueId = const Uuid().v4();
      await LocalStorageService.addToSyncQueue(
        queueId: pQueueId,
        table: 'monthly_payments',
        action: 'update',
        data: updatedPayment.toMap(),
      );
    }

    _syncNotifier?.notifyLocalMutation();
    _triggerSync();
  }

  Future<void> deleteAbono(String id) async {
    // Obtener abono antes de borrar para actualizar el pago
    final abonoLocal = LocalStorageService.getAbonosForPayment('')
        .where((a) => a.id == id)
        .firstOrNull;
    final paymentId = abonoLocal?.paymentId;

    await LocalStorageService.deleteAbono(id);

    final queueId = const Uuid().v4();
    await LocalStorageService.addToSyncQueue(
      queueId: queueId,
      table: 'abonos',
      action: 'delete',
      data: {'id': id},
    );

    if (paymentId != null) {
      final updatedPayment = LocalStorageService.getPaymentById(paymentId);
      if (updatedPayment != null) {
        final pQueueId = const Uuid().v4();
        await LocalStorageService.addToSyncQueue(
          queueId: pQueueId,
          table: 'monthly_payments',
          action: 'update',
          data: updatedPayment.toMap(),
        );
      }
    }

    _syncNotifier?.notifyLocalMutation();
    _triggerSync();
  }

  // ==========================================
  // 📊 DASHBOARD & STATUS
  // ==========================================
  Future<Map<String, dynamic>> getDashboardStats(int month, int year) async {
    // Intentar cálculo local primero
    try {
      final allContracts = LocalStorageService.getActiveTenants();
      double totalExpected = 0.0;
      for (var c in allContracts) {
        totalExpected += (c['contract_value'] as num?)?.toDouble() ?? 0.0;
      }

      double totalPaid = 0.0;
      for (var c in allContracts) {
        final contractId = c['id'] as String?;
        if (contractId != null) {
          final payment = LocalStorageService.getPaymentForMonth(contractId, month, year);
          if (payment != null) {
            totalPaid += payment.paidValue;
          }
        }
      }

      if (allContracts.isNotEmpty) {
        return {
          'totalPaid': totalPaid,
          'totalExpected': totalExpected,
          'activeCount': allContracts.length,
        };
      }
    } catch (e) {
      debugPrint('Error calculando stats locales: $e');
    }

    // Fallback a Supabase si la base local está vacía
    try {
      return await _supabaseService.getDashboardStats(month, year);
    } catch (e) {
      return {
        'totalPaid': 0.0,
        'totalExpected': 0.0,
        'activeCount': 0,
      };
    }
  }

  Future<List<dynamic>> getActiveTenants() async {
    final local = LocalStorageService.getActiveTenants();
    if (local.isNotEmpty) return local;

    try {
      return await _supabaseService.getActiveTenants();
    } catch (e) {
      return local;
    }
  }

  Future<double> getBuildingDebt(String buildingId) async {
    final units = LocalStorageService.getUnitsForBuilding(buildingId);
    double debt = 0.0;
    for (var u in units) {
      debt += await getUnitDebt(u.id);
    }
    return debt;
  }

  Future<double> getUnitDebt(String unitId) async {
    final contract = LocalStorageService.getActiveContractForUnit(unitId);
    if (contract == null) return 0.0;

    final payments = LocalStorageService.getPaymentsForContract(contract.id);
    double debt = 0.0;
    for (var p in payments) {
      if (!p.toMap()['is_fully_paid']) {
        debt += (p.totalValue - p.paidValue);
      }
    }
    return debt;
  }

  Future<String> getUnitStatus(String unitId) async {
    final contract = LocalStorageService.getActiveContractForUnit(unitId);
    if (contract == null) return 'Disponible';

    final payments = LocalStorageService.getPaymentsForContract(contract.id);
    final pending = payments.where((p) => p.paidValue < p.totalValue).toList();
    if (pending.isEmpty) return 'Al Día';

    final now = DateTime.now();
    for (var p in pending) {
      if (now.isAfter(p.dueDate)) return 'En Mora';
    }
    return 'Pendiente';
  }

  void _triggerSync() {
    _syncNotifier?.syncAll();
  }
}
