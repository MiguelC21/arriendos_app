import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../models/building.dart';
import '../models/unit.dart';
import '../models/contract.dart';
import '../models/monthly_payment.dart';
import '../models/abono.dart';

import '../config/environment_config.dart';

class LocalStorageService {
  static String _boxName(String name, AppEnvironment env) => '${env.name}_$name';

  static late Box _buildingsBox;
  static late Box _unitsBox;
  static late Box _contractsBox;
  static late Box _paymentsBox;
  static late Box _abonosBox;
  static late Box _syncQueueBox;

  static bool _isInitialized = false;

  /// Conmuta las cajas de almacenamiento al entorno seleccionado
  static Future<void> switchEnvironment(AppEnvironment env) async {
    _buildingsBox = await Hive.openBox(_boxName('buildings_box', env));
    _unitsBox = await Hive.openBox(_boxName('units_box', env));
    _contractsBox = await Hive.openBox(_boxName('contracts_box', env));
    _paymentsBox = await Hive.openBox(_boxName('payments_box', env));
    _abonosBox = await Hive.openBox(_boxName('abonos_box', env));
    _syncQueueBox = await Hive.openBox(_boxName('sync_queue_box', env));
    debugPrint('📦 LocalStorageService conmutó a almacenamiento de entorno: ${env.name}');
  }

  /// Inicializa Hive y abre todas las cajas del entorno actual
  static Future<void> initialize() async {
    if (_isInitialized) return;

    await Hive.initFlutter();
    await switchEnvironment(EnvironmentConfig.current);

    _isInitialized = true;
    debugPrint('📦 LocalStorageService inicializado correctamente con Hive CE.');
  }

  // ==========================================
  // 🏠 BUILDINGS
  // ==========================================
  static List<Building> getAllBuildings() {
    final list = <Building>[];
    for (var key in _buildingsBox.keys) {
      final raw = _buildingsBox.get(key);
      if (raw != null) {
        try {
          final map = Map<String, dynamic>.from(raw as Map);
          list.add(Building.fromMap(map));
        } catch (e) {
          debugPrint('Error parseando edificio local: $e');
        }
      }
    }
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  static Future<void> saveBuilding(Building building) async {
    await _buildingsBox.put(building.id, building.toMap());
  }

  static Future<void> saveBuildingsBatch(List<Building> buildings) async {
    final map = {for (var b in buildings) b.id: b.toMap()};
    await _buildingsBox.putAll(map);
  }

  static Future<void> deleteBuilding(String id) async {
    await _buildingsBox.delete(id);
    // Eliminar también las unidades locales asociadas
    final units = getUnitsForBuilding(id);
    for (var u in units) {
      await deleteUnit(u.id);
    }
  }

  /// IDs con una mutación local aún pendiente de subir: nunca se podan por
  /// reconciliación, para no borrar algo que este mismo dispositivo creó y
  /// todavía no ha logrado subir al servidor.
  static Set<String> _pendingMutationIds() {
    return getPendingSyncQueue()
        .map((item) => (item['data'] as Map?)?['id'])
        .whereType<String>()
        .toSet();
  }

  /// Reconcilia el directorio de inmuebles con la verdad remota: guarda los
  /// que llegan y elimina en cascada (local) los que ya no existen en el
  /// servidor (p. ej. borrados desde otro dispositivo). Si esto llegara a
  /// podar de más por una respuesta remota espuria, la propia lógica de
  /// lectura (`AppRepository.getBuildings`: caché vacía → reintenta remoto)
  /// se autocorrige en la siguiente consulta.
  static Future<void> reconcileBuildings(List<Building> remoteBuildings) async {
    final local = getAllBuildings();
    final protectedIds = _pendingMutationIds();
    final remoteIds = remoteBuildings.map((b) => b.id).toSet();
    for (var b in local) {
      if (!remoteIds.contains(b.id) && !protectedIds.contains(b.id)) {
        await deleteBuilding(b.id);
      }
    }
    await saveBuildingsBatch(remoteBuildings);
  }

  // ==========================================
  // 🏢 UNITS
  // ==========================================
  static List<Unit> getUnitsForBuilding(String buildingId) {
    final list = <Unit>[];
    for (var key in _unitsBox.keys) {
      final raw = _unitsBox.get(key);
      if (raw != null) {
        try {
          final map = Map<String, dynamic>.from(raw as Map);
          if (map['building_id'] == buildingId) {
            list.add(Unit.fromMap(map));
          }
        } catch (e) {
          debugPrint('Error parseando unidad local: $e');
        }
      }
    }
    list.sort((a, b) => a.number.compareTo(b.number));
    return list;
  }

  static Unit? getUnitById(String id) {
    final raw = _unitsBox.get(id);
    if (raw == null) return null;
    return Unit.fromMap(Map<String, dynamic>.from(raw as Map));
  }

  static Future<void> saveUnit(Unit unit) async {
    await _unitsBox.put(unit.id, unit.toMap());
  }

  static Future<void> saveUnitsBatch(List<Unit> units) async {
    final map = {for (var u in units) u.id: u.toMap()};
    await _unitsBox.putAll(map);
  }

  static Future<void> deleteUnit(String id) async {
    // Réplica local del ON DELETE CASCADE remoto: al borrar la unidad,
    // se arrastra su contrato y los pagos/abonos asociados.
    final contract = getActiveContractForUnit(id);
    if (contract != null) {
      await _deleteContractCascade(contract.id);
    }
    await _unitsBox.delete(id);
  }

  /// Reconcilia los apartamentos de un inmueble con la verdad remota.
  static Future<void> reconcileUnitsForBuilding(String buildingId, List<Unit> remoteUnits) async {
    final local = getUnitsForBuilding(buildingId);
    final protectedIds = _pendingMutationIds();
    final remoteIds = remoteUnits.map((u) => u.id).toSet();
    for (var u in local) {
      if (!remoteIds.contains(u.id) && !protectedIds.contains(u.id)) {
        await deleteUnit(u.id);
      }
    }
    await saveUnitsBatch(remoteUnits);
  }

  // ==========================================
  // 📜 CONTRACTS
  // ==========================================
  static Contract? getActiveContractForUnit(String unitId) {
    for (var key in _contractsBox.keys) {
      final raw = _contractsBox.get(key);
      if (raw != null) {
        try {
          final map = Map<String, dynamic>.from(raw as Map);
          if (map['unit_id'] == unitId && (map['active'] == true || map['active'] == 1)) {
            return Contract.fromMap(map);
          }
        } catch (e) {
          debugPrint('Error parseando contrato local: $e');
        }
      }
    }
    return null;
  }

  static List<Contract> getActiveContractsForBuilding(String buildingId) {
    final units = getUnitsForBuilding(buildingId);
    final unitIds = units.map((u) => u.id).toSet();
    final list = <Contract>[];

    for (var key in _contractsBox.keys) {
      final raw = _contractsBox.get(key);
      if (raw != null) {
        try {
          final map = Map<String, dynamic>.from(raw as Map);
          if (unitIds.contains(map['unit_id']) &&
              (map['active'] == true || map['active'] == 1)) {
            list.add(Contract.fromMap(map));
          }
        } catch (e) {
          debugPrint('Error al obtener contrato de edificio: $e');
        }
      }
    }
    return list;
  }

  static List<Map<String, dynamic>> getActiveTenants() {
    final list = <Map<String, dynamic>>[];
    for (var key in _contractsBox.keys) {
      final raw = _contractsBox.get(key);
      if (raw != null) {
        try {
          final map = Map<String, dynamic>.from(raw as Map);
          if (map['active'] == true || map['active'] == 1) {
            final unit = getUnitById(map['unit_id'] ?? '');
            Building? building;
            if (unit != null) {
              final rawB = _buildingsBox.get(unit.buildingId);
              if (rawB != null) {
                building = Building.fromMap(Map<String, dynamic>.from(rawB as Map));
              }
            }
            final contractCopy = Map<String, dynamic>.from(map);
            if (unit != null) {
              final unitMap = unit.toMap();
              if (building != null) {
                unitMap['buildings'] = building.toMap();
              }
              contractCopy['units'] = unitMap;
            }
            list.add(contractCopy);
          }
        } catch (e) {
          debugPrint('Error obteniendo inquilinos activos local: $e');
        }
      }
    }
    return list;
  }

  static Future<void> saveContract(Contract contract) async {
    await _contractsBox.put(contract.id, contract.toMap());
  }

  static Future<void> saveContractsBatch(List<Contract> contracts) async {
    final map = {for (var c in contracts) c.id: c.toMap()};
    await _contractsBox.putAll(map);
  }

  static Future<void> deleteContract(String id) async {
    await _contractsBox.delete(id);
  }

  static Future<void> _deleteContractCascade(String contractId) async {
    final payments = getPaymentsForContract(contractId);
    for (var p in payments) {
      for (var a in getAbonosForPayment(p.id)) {
        await _abonosBox.delete(a.id);
      }
      await _paymentsBox.delete(p.id);
    }
    await _contractsBox.delete(contractId);
  }

  /// Reconcilia los contratos activos de un inmueble con la verdad remota
  /// (p. ej. un contrato finalizado en otro dispositivo debe desaparecer
  /// aquí también, arrastrando sus pagos y abonos).
  static Future<void> reconcileContractsForBuilding(
    String buildingId,
    List<Contract> remoteContracts,
  ) async {
    final local = getActiveContractsForBuilding(buildingId);
    final protectedIds = _pendingMutationIds();
    final remoteIds = remoteContracts.map((c) => c.id).toSet();
    for (var c in local) {
      if (!remoteIds.contains(c.id) && !protectedIds.contains(c.id)) {
        await _deleteContractCascade(c.id);
      }
    }
    await saveContractsBatch(remoteContracts);
  }

  // ==========================================
  // 💰 MONTHLY PAYMENTS
  // ==========================================
  static List<MonthlyPayment> getPaymentsForContract(String contractId) {
    final list = <MonthlyPayment>[];
    for (var key in _paymentsBox.keys) {
      final raw = _paymentsBox.get(key);
      if (raw != null) {
        try {
          final map = Map<String, dynamic>.from(raw as Map);
          if (map['contract_id'] == contractId) {
            list.add(MonthlyPayment.fromMap(map));
          }
        } catch (e) {
          debugPrint('Error parseando pago mensual local: $e');
        }
      }
    }
    list.sort((a, b) {
      final yearCmp = b.year.compareTo(a.year);
      if (yearCmp != 0) return yearCmp;
      return b.month.compareTo(a.month);
    });
    return list;
  }

  static MonthlyPayment? getPaymentById(String id) {
    final raw = _paymentsBox.get(id);
    if (raw == null) return null;
    return MonthlyPayment.fromMap(Map<String, dynamic>.from(raw as Map));
  }

  static MonthlyPayment? getPaymentForMonth(String contractId, int month, int year) {
    for (var key in _paymentsBox.keys) {
      final raw = _paymentsBox.get(key);
      if (raw != null) {
        try {
          final map = Map<String, dynamic>.from(raw as Map);
          if (map['contract_id'] == contractId &&
              map['month'] == month &&
              map['year'] == year) {
            return MonthlyPayment.fromMap(map);
          }
        } catch (e) {
          debugPrint('Error buscando pago de mes local: $e');
        }
      }
    }
    return null;
  }

  static Future<void> saveMonthlyPayment(MonthlyPayment payment) async {
    await _paymentsBox.put(payment.id, payment.toMap());
  }

  static Future<void> saveMonthlyPaymentsBatch(List<MonthlyPayment> payments) async {
    final map = {for (var p in payments) p.id: p.toMap()};
    await _paymentsBox.putAll(map);
  }

  /// Reconcilia los pagos mensuales de un contrato con la verdad remota.
  static Future<void> reconcilePaymentsForContract(
    String contractId,
    List<MonthlyPayment> remotePayments,
  ) async {
    final local = getPaymentsForContract(contractId);
    final protectedIds = _pendingMutationIds();
    final remoteIds = remotePayments.map((p) => p.id).toSet();
    for (var p in local) {
      if (!remoteIds.contains(p.id) && !protectedIds.contains(p.id)) {
        for (var a in getAbonosForPayment(p.id)) {
          await _abonosBox.delete(a.id);
        }
        await _paymentsBox.delete(p.id);
      }
    }
    await saveMonthlyPaymentsBatch(remotePayments);
  }

  // ==========================================
  // 💵 ABONOS
  // ==========================================
  static List<Abono> getAbonosForPayment(String paymentId) {
    final list = <Abono>[];
    for (var key in _abonosBox.keys) {
      final raw = _abonosBox.get(key);
      if (raw != null) {
        try {
          final map = Map<String, dynamic>.from(raw as Map);
          if (map['payment_id'] == paymentId) {
            list.add(Abono.fromMap(map));
          }
        } catch (e) {
          debugPrint('Error parseando abono local: $e');
        }
      }
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  static Future<void> saveAbono(Abono abono) async {
    await _abonosBox.put(abono.id, abono.toMap());
    // Recalcular saldo del pago mensual
    await _recalculatePaymentStatus(abono.paymentId);
  }

  static Future<void> saveAbonosBatch(List<Abono> abonos) async {
    final map = {for (var a in abonos) a.id: a.toMap()};
    await _abonosBox.putAll(map);
  }

  /// Reconcilia los abonos de un pago mensual con la verdad remota.
  static Future<void> reconcileAbonosForPayment(
    String paymentId,
    List<Abono> remoteAbonos,
  ) async {
    final local = getAbonosForPayment(paymentId);
    final protectedIds = _pendingMutationIds();
    final remoteIds = remoteAbonos.map((a) => a.id).toSet();
    for (var a in local) {
      if (!remoteIds.contains(a.id) && !protectedIds.contains(a.id)) {
        await _abonosBox.delete(a.id);
      }
    }
    await saveAbonosBatch(remoteAbonos);
  }

  static Future<void> deleteAbono(String id) async {
    final raw = _abonosBox.get(id);
    if (raw != null) {
      final map = Map<String, dynamic>.from(raw as Map);
      final paymentId = map['payment_id'];
      await _abonosBox.delete(id);
      if (paymentId != null) {
        await _recalculatePaymentStatus(paymentId);
      }
    }
  }

  static Future<void> _recalculatePaymentStatus(String paymentId) async {
    final payment = getPaymentById(paymentId);
    if (payment == null) return;

    final abonos = getAbonosForPayment(paymentId);
    double totalPaid = 0.0;
    for (var a in abonos) {
      totalPaid += a.amount;
    }

    PaymentStatus status = PaymentStatus.pendiente;
    if (totalPaid >= (payment.totalValue - 0.1)) {
      status = PaymentStatus.pagado;
    } else if (totalPaid > 0.1) {
      status = PaymentStatus.parcial;
    }

    final updated = MonthlyPayment(
      id: payment.id,
      contractId: payment.contractId,
      month: payment.month,
      year: payment.year,
      totalValue: payment.totalValue,
      paidValue: totalPaid,
      dueDate: payment.dueDate,
      status: status,
      createdAt: payment.createdAt,
    );

    await saveMonthlyPayment(updated);
  }

  // ==========================================
  // ⚡ SYNC QUEUE (Cola de mutaciones offline)
  // ==========================================
  static List<Map<String, dynamic>> getPendingSyncQueue() {
    final list = <Map<String, dynamic>>[];
    for (var key in _syncQueueBox.keys) {
      final raw = _syncQueueBox.get(key);
      if (raw != null) {
        list.add(Map<String, dynamic>.from(raw as Map));
      }
    }
    // Ordenar por fecha de creación ascendente (FIFO)
    list.sort((a, b) {
      final aDate = a['created_at'] != null ? DateTime.parse(a['created_at']) : DateTime.now();
      final bDate = b['created_at'] != null ? DateTime.parse(b['created_at']) : DateTime.now();
      return aDate.compareTo(bDate);
    });
    return list;
  }

  static Future<void> addToSyncQueue({
    required String queueId,
    required String table,
    required String action, // 'insert', 'update', 'delete'
    required Map<String, dynamic> data,
  }) async {
    final item = {
      'id': queueId,
      'table': table,
      'action': action,
      'data': data,
      'created_at': DateTime.now().toIso8601String(),
      'retries': 0,
    };
    await _syncQueueBox.put(queueId, item);
  }

  static Future<void> removeFromSyncQueue(String queueId) async {
    await _syncQueueBox.delete(queueId);
  }

  static int getPendingSyncCount() {
    return _syncQueueBox.length;
  }

  static Future<void> clearAllLocalData() async {
    await _buildingsBox.clear();
    await _unitsBox.clear();
    await _contractsBox.clear();
    await _paymentsBox.clear();
    await _abonosBox.clear();
    await _syncQueueBox.clear();
  }
}
