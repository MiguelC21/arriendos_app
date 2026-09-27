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

    return authState.when(
      data: (state) {
        final session = state.session ?? ref.read(authServiceProvider).currentSession;
        if (session == null) {
          return const LoginScreen();
        }

        final roleAsync = ref.watch(currentUserRoleProvider);
        return roleAsync.when(
          data: (_) => const DashboardScreen(),
          loading: () => const _AuthLoadingScreen(),
          // Si falló la consulta de red, AuthService ya cayó al rol cacheado:
          // seguimos igual hacia el Dashboard con ese rol.
          error: (_, __) => const DashboardScreen(),
        );
      },
      loading: () => const _AuthLoadingScreen(),
      error: (_, __) => const LoginScreen(),
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
