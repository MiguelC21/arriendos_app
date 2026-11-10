import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Emite cada cambio de sesión (login, logout, refresco de token, y también
/// el evento inicial con la sesión persistida al abrir la app).
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).onAuthStateChange;
});

/// Resuelve el rol del usuario autenticado actual. Se recalcula cada vez que
/// cambia el estado de auth (incluida la reconexión tras cambiar de entorno).
///
/// Solo depende del id del usuario (vía `select`): eventos repetidos como
/// `tokenRefreshed` o `signedIn` al recuperar el foco no deben reconstruir el
/// provider, o el AuthGate volvería a mostrar el loader cada pocos segundos.
final currentUserRoleProvider = FutureProvider<UserRole>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final streamUserId = ref.watch(
    authStateChangesProvider.select((s) => s.valueOrNull?.session?.user.id),
  );
  final userId = streamUserId ?? authService.currentSession?.user.id;

  if (userId == null) return UserRole.viewer;
  return authService.fetchRole(userId);
});

final canEditProvider = Provider<bool>((ref) {
  return ref.watch(currentUserRoleProvider).valueOrNull?.canEditData ?? false;
});

final isDeveloperProvider = Provider<bool>((ref) {
  return ref.watch(currentUserRoleProvider).valueOrNull?.canManageEnvironment ?? false;
});

final canManageUsersProvider = Provider<bool>((ref) {
  return ref.watch(currentUserRoleProvider).valueOrNull?.canManageUsers ?? false;
});

/// Nombre completo del usuario autenticado actual (para mostrar en la UI en
/// vez del correo). `null` si no tiene nombre guardado o hubo un error de red
/// — en ese caso la UI cae de vuelta al correo.
final currentUserFullNameProvider = FutureProvider<String?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final streamUserId = ref.watch(
    authStateChangesProvider.select((s) => s.valueOrNull?.session?.user.id),
  );
  final userId = streamUserId ?? authService.currentSession?.user.id;
  if (userId == null) return null;

  try {
    final response = await SupabaseService.client
        .from('profiles')
        .select('full_name')
        .eq('id', userId)
        .single();
    return response['full_name'] as String?;
  } catch (_) {
    return null;
  }
});
