import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_storage_service.dart';
import 'supabase_service.dart';
import '../providers/building_provider.dart';
import '../providers/building_stats_provider.dart';
import '../providers/dashboard_provider.dart';
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
  bool _isProcessing = false;
  bool _rerunRequested = false;

  SyncNotifier(this._supabaseService, {Ref? ref})
      : _ref = ref,
        super(SyncState(
          connectionState: SyncConnectionState.online,
          pendingCount: LocalStorageService.getPendingSyncCount(),
        )) {
    _initConnectivityListener();
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
    super.dispose();
  }

  /// Se ejecuta cuando el usuario conmuta de entorno
  Future<void> onEnvironmentChanged() async {
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
  Future<void> _syncDown() async {
    try {
      final buildings = await _supabaseService.getBuildings();
      await LocalStorageService.reconcileBuildings(buildings);

      for (var b in buildings) {
        final units = await _supabaseService.getUnits(b.id);
        await LocalStorageService.reconcileUnitsForBuilding(b.id, units);

        final contracts = await _supabaseService.getActiveContractsForBuilding(b.id);
        await LocalStorageService.reconcileContractsForBuilding(b.id, contracts);

        for (var c in contracts) {
          final payments = await _supabaseService.getPayments(c.id);
          await LocalStorageService.reconcilePaymentsForContract(c.id, payments);

          for (var p in payments) {
            final abonos = await _supabaseService.getAbonosForPayment(p.id);
            await LocalStorageService.reconcileAbonosForPayment(p.id, abonos);
          }
        }
      }
      debugPrint('📥 Datos sincronizados y guardados en almacenamiento local.');
    } catch (e) {
      debugPrint('Aviso: no se pudo completar syncDown (posiblemente offline): $e');
    }
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
