import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/dashboard_screen.dart';
import '../screens/login_screen.dart';

/// Punto de entrada de la app: muestra `LoginScreen` sin sesión, un loader
/// mientras se resuelve el rol del usuario, y `DashboardScreen` una vez
/// autenticado y con el rol ya cargado (para que el gating de permisos sea
/// correcto desde el primer frame).
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);
    // Un error en el stream (p. ej. falló el refresh de token por falta de
    // red) no significa que no haya sesión: AuthService.currentSession es
    // una lectura local que sigue vigente si Supabase no la invalidó.
    final session = authState.valueOrNull?.session ??
        ref.read(authServiceProvider).currentSession;

    if (session == null) {
      if (authState.isLoading) {
        return const _AuthLoadingScreen();
      }
      return const LoginScreen();
    }

    final roleAsync = ref.watch(currentUserRoleProvider);
    return roleAsync.when(
      // Si ya hay un rol cargado, un recálculo no debe volver al loader.
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: (_) => const DashboardScreen(),
      loading: () => const _AuthLoadingScreen(),
      // Si falló la consulta de red, AuthService ya cayó al rol cacheado:
      // seguimos igual hacia el Dashboard con ese rol.
      error: (_, __) => const DashboardScreen(),
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
