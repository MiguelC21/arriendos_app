import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/abono.dart';
import '../models/contract.dart';
import '../models/monthly_payment.dart';
import '../models/unit.dart';
import 'local_storage_service.dart';
import 'supabase_service.dart';
import '../providers/building_provider.dart';
import '../providers/building_stats_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/tenant_provider.dart';

enum SyncConnectionState { online, offline, syncing }

class SyncState {
  final SyncConnectionState connectionState;
  final int pendingCount;
  final String? lastError;
  final DateTime? lastSyncTime;

  const SyncState({
    required this.connectionState,
    required this.pendingCount,
    this.lastError,
    this.lastSyncTime,
  });

  bool get isOnline => connectionState != SyncConnectionState.offline;
  bool get isSyncing => connectionState == SyncConnectionState.syncing;

  SyncState copyWith({
    SyncConnectionState? connectionState,
    int? pendingCount,
    String? lastError,
    DateTime? lastSyncTime,
  }) {
    return SyncState(
      connectionState: connectionState ?? this.connectionState,
      pendingCount: pendingCount ?? this.pendingCount,
      lastError: lastError,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

class SyncNotifier extends StateNotifier<SyncState> {
  final SupabaseService _supabaseService;
  final Ref? _ref;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  RealtimeChannel? _realtimeChannel;
  Timer? _realtimeDebounce;
  bool _isProcessing = false;
  bool _rerunRequested = false;

  static const _realtimeTables = [
    'buildings',
    'units',
    'contracts',
    'monthly_payments',
    'abonos',
  ];

  SyncNotifier(this._supabaseService, {Ref? ref})
      : _ref = ref,
        super(SyncState(
          connectionState: SyncConnectionState.online,
          pendingCount: LocalStorageService.getPendingSyncCount(),
        )) {
    _initConnectivityListener();
    _subscribeToRealtimeChanges();
  }

  /// Escucha cambios en vivo (Supabase Realtime) en las tablas sincronizadas.
  /// Cuando otro dispositivo inserta/actualiza/borra algo, este canal recibe
  /// el evento y dispara una sincronización automática, sin que el usuario
  /// tenga que pulsar "Sincronizar ahora".
  void _subscribeToRealtimeChanges() {
    final channel = SupabaseService.client.channel('sync_changes_${DateTime.now().microsecondsSinceEpoch}');

    for (final table in _realtimeTables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (payload) => _scheduleRealtimeSync(),
      );
    }

    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        debugPrint('⚠️ Realtime: $status $error');
      }
    });
    _realtimeChannel = channel;
  }

  /// Agrupa (debounce) varios eventos que lleguen juntos —p. ej. al borrar un
  /// inmueble completo, que arrastra apartamentos/contratos/pagos en cascada—
  /// en una sola sincronización, en vez de disparar una por cada tabla.
  void _scheduleRealtimeSync() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 800), () {
      syncAll();
    });
  }

  Future<void> _unsubscribeRealtimeChanges() async {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = null;
    final channel = _realtimeChannel;
    _realtimeChannel = null;
    if (channel != null) {
      await channel.unsubscribe();
    }
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final isOffline = results.every((r) => r == ConnectivityResult.none);
      if (isOffline) {
        state = state.copyWith(
          connectionState: SyncConnectionState.offline,
          pendingCount: LocalStorageService.getPendingSyncCount(),
        );
      } else {
        state = state.copyWith(
          connectionState: SyncConnectionState.online,
          pendingCount: LocalStorageService.getPendingSyncCount(),
        );
        // Si vuelve la conexión, procesar inmediatamente la cola pendiente y descargar
        syncAll();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _realtimeDebounce?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  /// Se ejecuta cuando el usuario conmuta de entorno (Local ↔ Producción).
  /// SupabaseService ya apunta al nuevo cliente en este punto, así que hay
  /// que re-suscribir el canal de Realtime a ese cliente nuevo (el anterior
  /// quedaría escuchando al servidor equivocado).
  Future<void> onEnvironmentChanged() async {
    await _unsubscribeRealtimeChanges();
    _subscribeToRealtimeChanges();

    state = state.copyWith(
      pendingCount: LocalStorageService.getPendingSyncCount(),
      lastError: null,
    );
    await syncAll();
  }

  /// Sincroniza todo: primero procesa mutaciones pendientes de subida, luego descarga cambios
  Future<void> syncAll() async {
    if (_isProcessing) {
      // Ya hay una sincronización en curso: pedimos que se repita al terminar
      // para no perder mutaciones encoladas mientras esta pasada estaba en vuelo.
      _rerunRequested = true;
      return;
    }
    _isProcessing = true;

    state = state.copyWith(
      connectionState: SyncConnectionState.syncing,
      pendingCount: LocalStorageService.getPendingSyncCount(),
    );

    try {
      // 1. Subir cambios pendientes locales a Supabase
      await _processPendingQueue();

      // 2. Descargar datos frescos de Supabase a la base local
      await _syncDown();

      state = state.copyWith(
        connectionState: SyncConnectionState.online,
        pendingCount: LocalStorageService.getPendingSyncCount(),
        lastSyncTime: DateTime.now(),
        lastError: null,
      );

      // Notificar a Riverpod para refrescar UI inmediatamente con datos frescos
      _ref?.invalidate(buildingProvider);
      _ref?.invalidate(dashboardStatsProvider);
      _ref?.invalidate(activeTenantsProvider);
      // Estos son FutureProvider.family: invalidar sin argumento recalcula
      // todas sus instancias vivas, para que las tarjetas de ocupación/deuda
      // reflejen lo que la reconciliación acaba de corregir en Hive.
      _ref?.invalidate(buildingOccupancyProvider);
      _ref?.invalidate(buildingDebtProvider);
      _ref?.invalidate(unitStatusProvider);
      _ref?.invalidate(unitDebtProvider);
      // paymentProvider es un StateNotifierProvider.family: a diferencia de
      // los FutureProvider de arriba, solo recarga cuando alguien llama a
      // loadPayments() explícitamente. Sin esta invalidación, una pantalla
      // de pagos ya abierta se queda mostrando el estado/monto viejo (p. ej.
      // "Pendiente") aunque los abonos que lo cambian ya hayan llegado por
      // sync, hasta que el usuario reinicie la app.
      _ref?.invalidate(paymentProvider);
      _ref?.invalidate(abonosProvider);
    } catch (e) {
      debugPrint('Error durante syncAll: $e');
      state = state.copyWith(
        connectionState: SyncConnectionState.online,
        pendingCount: LocalStorageService.getPendingSyncCount(),
        lastError: e.toString(),
      );
    } finally {
      _isProcessing = false;

      if (_rerunRequested) {
        // Llegaron mutaciones nuevas mientras sincronizábamos: repetimos
        // para no dejarlas huérfanas en la cola hasta el próximo disparador.
        _rerunRequested = false;
        unawaited(syncAll());
      }
    }
  }

  /// Procesa la cola de mutaciones acumuladas en modo offline.
  /// Vuelve a leer la cola tras cada pasada para no dejar fuera elementos
  /// que se encolaron mientras esta misma pasada estaba en curso.
  Future<void> _processPendingQueue() async {
    while (true) {
      final queue = LocalStorageService.getPendingSyncQueue();
      if (queue.isEmpty) return;

      debugPrint('🔄 Procesando cola de sincronización (${queue.length} elementos)...');

      bool hadError = false;
      for (var item in queue) {
        final queueId = item['id'] as String;
        final table = item['table'] as String;
        final action = item['action'] as String;
        final data = Map<String, dynamic>.from(item['data'] as Map);

        try {
          await _supabaseService.executeSyncAction(
            table: table,
            action: action,
            data: data,
          );
          // Éxito: eliminar de la cola local
          await LocalStorageService.removeFromSyncQueue(queueId);
        } catch (e) {
          debugPrint('Error procesando item $queueId de tabla $table: $e');
          state = state.copyWith(lastError: e.toString());
          hadError = true;
          // Si hay error, paramos para reintentar luego
          break;
        }
      }

      state = state.copyWith(
        pendingCount: LocalStorageService.getPendingSyncCount(),
      );

      // Si hubo un error nos detenemos por completo (se reintentará con el
      // próximo disparador). Si no, volvemos a leer la cola por si se
      // añadieron elementos nuevos durante esta pasada.
      if (hadError) return;
    }
  }

  /// Descarga todos los registros actuales de Supabase y reconcilia la base
  /// local con esa verdad remota: guarda lo que llega y elimina en cascada
  /// lo que ya no exista remotamente (p. ej. algo borrado desde otro
  /// dispositivo), para que ningún cliente se quede con datos fantasma.
  ///
  /// Trae todo con 5 consultas fijas (una por tabla) en vez de una consulta
  /// por cada edificio/contrato/pago: con pocos edificios eso ya eran 20-30
  /// viajes de red secuenciales, y cada uno pesa por su latencia propia (más
  /// notorio en producción) sin importar cuántos datos traiga. Las 5 salen
  /// en paralelo y la reconciliación agrupa todo en memoria localmente.
  Future<void> _syncDown() async {
    try {
      final buildingsFuture = _supabaseService.getBuildings();
      final unitsFuture = _supabaseService.getAllUnits();
      final contractsFuture = _supabaseService.getAllActiveContracts();
      final paymentsFuture = _supabaseService.getAllPayments();
      final abonosFuture = _supabaseService.getAllAbonos();

      final buildings = await buildingsFuture;
      final allUnits = await unitsFuture;
      final allContracts = await contractsFuture;
      final allPayments = await paymentsFuture;
      final allAbonos = await abonosFuture;

      await LocalStorageService.reconcileBuildings(buildings);

      final unitsByBuilding = _groupBy(allUnits, (Unit u) => u.buildingId);
      final buildingIdByUnitId = {for (var u in allUnits) u.id: u.buildingId};
      final contractsByBuilding = <String, List<Contract>>{};
      for (var c in allContracts) {
        final buildingId = buildingIdByUnitId[c.unitId];
        if (buildingId == null) continue;
        (contractsByBuilding[buildingId] ??= []).add(c);
      }
      final paymentsByContract = _groupBy(allPayments, (MonthlyPayment p) => p.contractId);
      final abonosByPayment = _groupBy(allAbonos, (Abono a) => a.paymentId);

      for (var b in buildings) {
        final units = unitsByBuilding[b.id] ?? const [];
        await LocalStorageService.reconcileUnitsForBuilding(b.id, units);

        final contracts = contractsByBuilding[b.id] ?? const [];
        await LocalStorageService.reconcileContractsForBuilding(b.id, contracts);

        for (var c in contracts) {
          final payments = paymentsByContract[c.id] ?? const [];
          await LocalStorageService.reconcilePaymentsForContract(c.id, payments);

          for (var p in payments) {
            final abonos = abonosByPayment[p.id] ?? const [];
            await LocalStorageService.reconcileAbonosForPayment(p.id, abonos);
            // paid_value/status del monthly_payment remoto puede venir
            // incompleto si otro dispositivo abonó offline sin saber de este
            // abono; se recalcula siempre a partir de los abonos ya
            // reconciliados, que sí son la verdad completa.
            await LocalStorageService.recalculatePaymentStatus(p.id);
          }
        }
      }
      debugPrint('📥 Datos sincronizados y guardados en almacenamiento local.');
    } catch (e) {
      debugPrint('Aviso: no se pudo completar syncDown (posiblemente offline): $e');
    }
  }

  Map<String, List<T>> _groupBy<T>(List<T> items, String Function(T) keyOf) {
    final map = <String, List<T>>{};
    for (var item in items) {
      (map[keyOf(item)] ??= []).add(item);
    }
    return map;
  }

  void notifyLocalMutation() {
    state = state.copyWith(
      pendingCount: LocalStorageService.getPendingSyncCount(),
    );
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(SupabaseService(), ref: ref);
});
