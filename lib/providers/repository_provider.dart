import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/app_repository.dart';
import '../services/supabase_service.dart';
import '../services/sync_manager.dart';

final appRepositoryProvider = Provider<AppRepository>((ref) {
  // `read`, no `watch`: solo necesitamos la instancia del notifier para
  // poder llamarla desde el repositorio. Con `watch`, cualquier provider
  // que dependa de este repositorio (dashboardStatsProvider, etc.) queda
  // formalmente enganchado a syncProvider, y como syncAll() invalida esos
  // mismos providers al terminar, Riverpod lo detecta como una dependencia
  // circular (CircularDependencyError) y aborta la invalidación a mitad
  // de camino.
  final syncNotifier = ref.read(syncProvider.notifier);
  return AppRepository(
    supabaseService: SupabaseService(),
    syncNotifier: syncNotifier,
  );
});
