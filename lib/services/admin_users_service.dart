import '../models/user_role.dart';
import 'supabase_service.dart';

class ProfileSummary {
  final String id;
  final String email;
  final String? fullName;
  final UserRole role;

  ProfileSummary({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
  });

  /// Nombre a mostrar: el nombre completo si existe, si no el correo.
  String get displayName => (fullName != null && fullName!.trim().isNotEmpty) ? fullName! : email;

  factory ProfileSummary.fromMap(Map<String, dynamic> map) {
    return ProfileSummary(
      id: map['id'] as String,
      email: (map['email'] as String?) ?? '(sin correo)',
      fullName: map['full_name'] as String?,
      role: UserRole.fromString(map['role'] as String?),
    );
  }
}

/// Operaciones de gestión de usuarios reservadas a Admin/Developer.
/// Crear cuentas y resetear contraseñas de terceros requiere la
/// `service_role key`, por eso pasan por la Edge Function `admin-users`
/// en vez de llamarse directo desde el cliente.
class AdminUsersService {
  Future<List<ProfileSummary>> listProfiles() async {
    final response = await SupabaseService.client
        .from('profiles')
        .select('id, email, full_name, role')
        .order('email', ascending: true);
    return (response as List)
        .map((m) => ProfileSummary.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<void> createUser({
    required String email,
    required String password,
    required UserRole role,
    String? fullName,
  }) async {
    final response = await SupabaseService.client.functions.invoke(
      'admin-users',
      body: {
        'action': 'create',
        'email': email,
        'password': password,
        'role': role.value,
        if (fullName != null && fullName.trim().isNotEmpty) 'fullName': fullName.trim(),
      },
    );
    _throwIfError(response.data);
  }

  Future<void> resetPassword({
    required String userId,
    required String newPassword,
  }) async {
    final response = await SupabaseService.client.functions.invoke(
      'admin-users',
      body: {
        'action': 'reset-password',
        'userId': userId,
        'newPassword': newPassword,
      },
    );
    _throwIfError(response.data);
  }

  /// Cambiar el rol de un usuario existente sí se puede hacer con un update
  /// normal, protegido por RLS (no necesita la Edge Function).
  Future<void> updateRole({
    required String userId,
    required UserRole role,
  }) async {
    await SupabaseService.client
        .from('profiles')
        .update({'role': role.value})
        .eq('id', userId);
  }

  /// Igual que el rol, cambiar el nombre es un update normal sobre
  /// `profiles`, protegido por RLS.
  Future<void> updateFullName({
    required String userId,
    required String fullName,
  }) async {
    await SupabaseService.client
        .from('profiles')
        .update({'full_name': fullName.trim().isEmpty ? null : fullName.trim()})
        .eq('id', userId);
  }

  /// Eliminar una cuenta requiere la Admin API de Supabase Auth
  /// (`service_role key`), por eso pasa por la Edge Function. Esta valida
  /// que quien llama no se esté eliminando a sí mismo.
  Future<void> deleteUser({required String userId}) async {
    final response = await SupabaseService.client.functions.invoke(
      'admin-users',
      body: {
        'action': 'delete',
        'userId': userId,
      },
    );
    _throwIfError(response.data);
  }

  void _throwIfError(dynamic data) {
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
  }
}
