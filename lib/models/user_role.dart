enum UserRole {
  developer,
  admin,
  viewer;

  static UserRole fromString(String? value) {
    switch (value) {
      case 'developer':
        return UserRole.developer;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.viewer;
    }
  }

  String get value => name;

  String get label {
    switch (this) {
      case UserRole.developer:
        return 'Desarrollador';
      case UserRole.admin:
        return 'Administrador';
      case UserRole.viewer:
        return 'Usuario (solo lectura)';
    }
  }

  /// Puede crear, editar y eliminar datos de negocio (inmuebles, unidades,
  /// contratos, pagos, abonos).
  bool get canEditData => this == UserRole.developer || this == UserRole.admin;

  /// Puede cambiar entre entorno Local y Producción.
  bool get canManageEnvironment => this == UserRole.developer;

  /// Puede crear cuentas, cambiar roles y resetear contraseñas de otros.
  bool get canManageUsers => this == UserRole.developer || this == UserRole.admin;
}
