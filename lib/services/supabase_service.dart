import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/environment_config.dart';
import '../models/building.dart';
import '../models/unit.dart';
import '../models/contract.dart';
import '../models/monthly_payment.dart';
import '../models/abono.dart';

class SupabaseService {
  /// Usa el cliente de `Supabase.instance` (inicializado en main.dart) en vez
  /// de crear uno manual: solo ese cliente persiste y recupera la sesión de
  /// autenticación entre reinicios de la app (necesario para los roles de
  /// usuario). Cambiar de entorno recrea esta instancia global apuntando al
  /// nuevo endpoint.
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> switchEnvironment() async {
    await Supabase.instance.dispose();
    await Supabase.initialize(
      url: EnvironmentConfig.currentUrl,
      anonKey: EnvironmentConfig.currentAnonKey,
    );
    debugPrint('⚡ SupabaseService conmutó al endpoint: ${EnvironmentConfig.currentUrl}');
  }

  SupabaseClient get _client => client;

  // 🏠 BUILDINGS
  Future<List<Building>> getBuildings() async {
    final response = await _client
        .from('buildings')
        .select()
        .order('name', ascending: true);
    return (response as List).map((m) => Building.fromMap(m)).toList();
  }

  Future<void> insertBuilding(Building building) async {
    await _client.from('buildings').insert(building.toMap());
  }

  Future<void> updateBuilding(Building building) async {
    await _client
        .from('buildings')
        .update(building.toMap())
        .eq('id', building.id);
  }

  Future<void> deleteBuilding(String id) async {
    await _client.from('buildings').delete().eq('id', id);
  }

  // 🏢 UNITS
  Future<List<Unit>> getUnits(String buildingId) async {
    final response = await _client
        .from('units')
        .select()
        .eq('building_id', buildingId)
        .order('number', ascending: true);
    return (response as List).map((m) => Unit.fromMap(m)).toList();
  }

  /// Trae TODAS las unidades en una sola consulta (usado por la sincronización
  /// completa, para no hacer una consulta por cada edificio).
  Future<List<Unit>> getAllUnits() async {
    final response = await _client
        .from('units')
        .select()
        .order('number', ascending: true);
    return (response as List).map((m) => Unit.fromMap(m)).toList();
  }

  Future<void> insertUnit(Unit unit) async {
    await _client.from('units').insert(unit.toMap());
  }

  Future<Unit?> getUnitById(String id) async {
    final response = await _client
        .from('units')
        .select()
        .eq('id', id)
        .maybeSingle();
    return response != null ? Unit.fromMap(response) : null;
  }

  Future<void> updateUnit(Unit unit) async {
    await _client.from('units').upsert(unit.toMap());
  }

  Future<void> deleteUnit(String id) async {
    await _client.from('units').delete().eq('id', id);
  }

  // 📜 CONTRACTS
  Future<Contract?> getActiveContract(String unitId) async {
    final response = await _client
        .from('contracts')
        .select()
        .eq('unit_id', unitId)
        .eq('active', true)
        .maybeSingle();

    if (response == null) return null;
    return Contract.fromMap(response);
  }

  Future<List<Contract>> getActiveContractsForBuilding(
    String buildingId,
  ) async {
    final response = await _client
        .from('contracts')
        .select('*, units!inner(*)')
        .eq('units.building_id', buildingId)
        .eq('active', true);

    return (response as List).map((m) => Contract.fromMap(m)).toList();
  }

  /// Trae TODOS los contratos activos en una sola consulta (usado por la
  /// sincronización completa, para no hacer una consulta por cada edificio).
  Future<List<Contract>> getAllActiveContracts() async {
    final response = await _client
        .from('contracts')
        .select()
        .eq('active', true);

    return (response as List).map((m) => Contract.fromMap(m)).toList();
  }

  Future<void> insertContract(Contract contract) async {
    await _client.from('contracts').insert(contract.toMap());
  }

  Future<void> terminateContract(String id) async {
    await _client.from('contracts').delete().eq('id', id);
  }

  Future<void> updateContract(Contract contract) async {
    await _client.from('contracts').upsert(contract.toMap());
  }

  // 💰 PAYMENTS & ABONOS
  Future<List<MonthlyPayment>> getPayments(String contractId) async {
    final response = await _client
        .from('monthly_payments')
        .select()
        .eq('contract_id', contractId)
        .order('year', ascending: false)
        .order('month', ascending: false);
    return (response as List).map((m) => MonthlyPayment.fromMap(m)).toList();
  }

  /// Trae TODOS los pagos mensuales en una sola consulta (usado por la
  /// sincronización completa, para no hacer una consulta por cada contrato).
  Future<List<MonthlyPayment>> getAllPayments() async {
    final response = await _client
        .from('monthly_payments')
        .select()
        .order('year', ascending: false)
        .order('month', ascending: false);
    return (response as List).map((m) => MonthlyPayment.fromMap(m)).toList();
  }

  Future<void> insertMonthlyPaymentsBatch(List<MonthlyPayment> payments) async {
    if (payments.isEmpty) return;
    try {
      final maps = payments.map((p) => p.toMap()).toList();
      await _client.from('monthly_payments').insert(maps);
    } catch (e) {
      // Ignorar error de clave foránea (23503) - el contrato fue eliminado
      if (e is PostgrestException && e.code == '23503') {
        debugPrint('Ignorando inserción de pagos para contrato inexistente.');
        return;
      }
      debugPrint('Error en insertMonthlyPaymentsBatch: $e');
      rethrow;
    }
  }

  Future<void> insertAbono(Abono abono) async {
    await _client.from('abonos').insert(abono.toMap());
    // Importante: El trigger en Supabase o una actualización manual debería manejar is_fully_paid
    // Por ahora lo simplificamos actualizando el pago mensual asociado
    await _updatePaymentPaidValue(abono.paymentId);
  }

  Future<void> _updatePaymentPaidValue(String paymentId) async {
    final abonosResponse = await _client
        .from('abonos')
        .select('amount')
        .eq('payment_id', paymentId);

    double totalPaid = 0.0;
    for (var row in abonosResponse as List) {
      totalPaid += (row['amount'] as num?)?.toDouble() ?? 0.0;
    }

    final paymentResponse = await _client
        .from('monthly_payments')
        .select('total_value')
        .eq('id', paymentId)
        .single();

    final totalValue = (paymentResponse['total_value'] as num).toDouble();

    String status = 'pendiente';
    // Usamos una pequeña tolerancia para evitar problemas con decimales
    if (totalPaid >= (totalValue - 0.1)) {
      status = 'pagado';
    } else if (totalPaid > 0.1) {
      status = 'parcial';
    }

    await _client
        .from('monthly_payments')
        .update({
          'paid_value': totalPaid,
          'is_fully_paid': totalPaid >= totalValue,
          'status': status,
        })
        .eq('id', paymentId);
  }

  Future<List<Abono>> getAbonosForPayment(String paymentId) async {
    final response = await _client
        .from('abonos')
        .select()
        .eq('payment_id', paymentId)
        .order('date', ascending: false);
    return (response as List).map((m) => Abono.fromMap(m)).toList();
  }

  /// Trae TODOS los abonos en una sola consulta (usado por la sincronización
  /// completa, para no hacer una consulta por cada pago mensual).
  Future<List<Abono>> getAllAbonos() async {
    final response = await _client
        .from('abonos')
        .select()
        .order('date', ascending: false);
    return (response as List).map((m) => Abono.fromMap(m)).toList();
  }

  Future<void> deleteAbono(String id) async {
    // Primero obtenemos el id del pago para actualizarlo después
    final abono = await _client
        .from('abonos')
        .select('payment_id')
        .eq('id', id)
        .single();
    final paymentId = abono['payment_id'];

    await _client.from('abonos').delete().eq('id', id);
    await _updatePaymentPaidValue(paymentId);
  }

  Future<void> applyCascadingPayment({
    required double totalAmount,
    required String method,
    required String contractId,
  }) async {
    // Esta es una operación compleja. Buscamos pagos pendientes ordenados por fecha
    final payments = await _client
        .from('monthly_payments')
        .select()
        .eq('contract_id', contractId)
        .eq('is_fully_paid', false)
        .order('year', ascending: true)
        .order('month', ascending: true);

    double remainingAmount = totalAmount;

    for (var payMap in payments as List) {
      if (remainingAmount <= 0) break;

      final paymentId = payMap['id'];
      final totalValue = (payMap['total_value'] as num).toDouble();
      final currentPaid = (payMap['paid_value'] as num?)?.toDouble() ?? 0.0;
      final pendingForThisMonth = totalValue - currentPaid;

      final amountToApply = remainingAmount >= pendingForThisMonth
          ? pendingForThisMonth
          : remainingAmount;

      await insertAbono(
        Abono(
          paymentId: paymentId,
          amount: amountToApply,
          date: DateTime.now(),
          note: 'Pago en cascada ($method)',
        ),
      );

      remainingAmount -= amountToApply;
    }
  }

  // 📊 DEBT & STATUS
  Future<double> getBuildingDebt(String buildingId) async {
    // Obtenemos todas las unidades del edificio
    final units = await _client
        .from('units')
        .select('id')
        .eq('building_id', buildingId);

    double totalDebt = 0.0;
    for (var unit in units as List) {
      totalDebt += await getUnitDebt(unit['id']);
    }
    return totalDebt;
  }

  Future<double> getUnitDebt(String unitId) async {
    final contract = await getActiveContract(unitId);
    if (contract == null) return 0.0;

    final payments = await _client
        .from('monthly_payments')
        .select('total_value, paid_value')
        .eq('contract_id', contract.id)
        .eq('is_fully_paid', false);

    double debt = 0.0;
    for (var pay in payments as List) {
      final total = (pay['total_value'] as num).toDouble();
      final paid = (pay['paid_value'] as num?)?.toDouble() ?? 0.0;
      debt += (total - paid);
    }
    return debt;
  }

  Future<String> getUnitStatus(String unitId) async {
    final contract = await getActiveContract(unitId);
    if (contract == null) return 'Disponible';

    final pendingPayments = await _client
        .from('monthly_payments')
        .select('due_date')
        .eq('contract_id', contract.id)
        .eq('is_fully_paid', false);

    if ((pendingPayments as List).isEmpty) return 'Al Día';

    final now = DateTime.now();
    bool hasMora = false;
    for (var p in pendingPayments) {
      if (p['due_date'] != null) {
        final dueDate = DateTime.parse(p['due_date'] as String);
        if (now.isAfter(dueDate)) {
          hasMora = true;
          break;
        }
      }
    }

    return hasMora ? 'En Mora' : 'Pendiente';
  }

  Future<List<dynamic>> getActiveTenants() async {
    final response = await _client
        .from('contracts')
        .select('*, units(*, buildings(*))')
        .eq('active', true)
        .order('unit_id', ascending: true);

    return response as List<dynamic>;
  }

  Future<MonthlyPayment?> getPaymentForMonth(
    String contractId,
    int month,
    int year,
  ) async {
    final response = await _client
        .from('monthly_payments')
        .select()
        .eq('contract_id', contractId)
        .eq('month', month)
        .eq('year', year)
        .maybeSingle();

    if (response == null) return null;
    return MonthlyPayment.fromMap(response);
  }

  Future<void> insertMonthlyPayment(MonthlyPayment payment) async {
    await _client.from('monthly_payments').insert(payment.toMap());
  }

  // 📊 DASHBOARD STATS
  Future<Map<String, dynamic>> getDashboardStats(int month, int year) async {
    // 1. Suma de pagos realizados este mes
    final paymentsResponse = await _client
        .from('monthly_payments')
        .select('paid_value')
        .eq('month', month)
        .eq('year', year);

    double totalPaid = 0.0;
    for (var row in paymentsResponse as List) {
      totalPaid += (row['paid_value'] as num?)?.toDouble() ?? 0.0;
    }

    // 2. Meta potencial y contratos activos
    final contractsResponse = await _client
        .from('contracts')
        .select('contract_value')
        .eq('active', true);

    double totalExpected = 0.0;
    int activeCount = 0;
    final list = contractsResponse as List;
    activeCount = list.length;
    for (var row in list) {
      totalExpected += (row['contract_value'] as num?)?.toDouble() ?? 0.0;
    }

    return {
      'totalPaid': totalPaid,
      'totalExpected': totalExpected,
      'activeCount': activeCount,
    };
  }

  // 🔄 SYNC QUEUE EXECUTION
  Future<void> executeSyncAction({
    required String table,
    required String action,
    required Map<String, dynamic> data,
  }) async {
    final id = data['id'];
    switch (action.toLowerCase()) {
      case 'insert':
      case 'upsert':
        await _client.from(table).upsert(data);
        break;
      case 'update':
        if (id != null) {
          await _client.from(table).update(data).eq('id', id);
        }
        break;
      case 'delete':
        if (id != null) {
          await _client.from(table).delete().eq('id', id);
        }
        break;
      default:
        debugPrint('Acción de sincronización desconocida: $action');
    }
  }
}

