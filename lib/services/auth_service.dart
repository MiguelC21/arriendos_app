import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_role.dart';
import 'supabase_service.dart';

class AuthService {
  static const String _cachedRolePrefix = 'cached_role_';

  /// Último rol conocido, disponible de forma síncrona para que
  /// `AppRepository` pueda validar permisos sin depender de Riverpod.
  static UserRole _currentRole = UserRole.viewer;
  static UserRole get currentRole => _currentRole;

  SupabaseClient get _client => SupabaseService.client;

  GoTrueClient get _auth => _client.auth;

  Session? get currentSession => _auth.currentSession;
  User? get currentUser => _auth.currentUser;

  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _currentRole = UserRole.viewer;
  }

  /// Cambia la contraseña de la sesión actualmente autenticada.
  Future<void> updatePassword(String newPassword) async {
    await _auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Consulta el rol del usuario en `profiles`. Si no hay red disponible,
  /// cae al último rol cacheado localmente para ese usuario (modo offline).
  Future<UserRole> fetchRole(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();
      final role = UserRole.fromString(response['role'] as String?);
      _currentRole = role;
      await _cacheRole(userId, role);
      return role;
    } catch (e) {
      debugPrint('Aviso: no se pudo obtener el rol remoto ($e). Usando caché.');
      final cached = await _getCachedRole(userId);
      _currentRole = cached;
      return cached;
    }
  }

  Future<void> _cacheRole(String userId, UserRole role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cachedRolePrefix$userId', role.value);
    } catch (_) {}
  }

  Future<UserRole> _getCachedRole(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return UserRole.fromString(prefs.getString('$_cachedRolePrefix$userId'));
    } catch (_) {
      return UserRole.viewer;
    }
  }
}
