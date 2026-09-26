import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/app_repository.dart';
import '../services/supabase_service.dart';
import '../services/sync_manager.dart';

final appRepositoryProvider = Provider<AppRepository>((ref) {
  final syncNotifier = ref.watch(syncProvider.notifier);
  return AppRepository(
    supabaseService: SupabaseService(),
    syncNotifier: syncNotifier,
  );
});
