import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_role.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/tenant_list_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/user_management_screen.dart';
import '../services/auth_service.dart';
import 'connection_status_badge.dart';

class ResponsiveLayout extends ConsumerWidget {
  final Widget mobileBody;
  final int selectedIndex;
  final String title;
  final List<Widget>? actions;
  final Widget? breadcrumb;

  const ResponsiveLayout({
    super.key,
    required this.mobileBody,
    this.selectedIndex = 0,
    required this.title,
    this.actions,
    this.breadcrumb,
  });

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 768;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesk = isDesktop(context);

    if (!isDesk) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            const ConnectionStatusBadge(),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 20,
              ),
              tooltip: isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
              onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
            ),
            ...?actions,
            const SizedBox(width: 6),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: _UserAvatarMenu(),
            ),
          ],
        ),
        body: mobileBody,
      );
    }

    // ==========================================
    // 💻 LAYOUT PROFESIONAL DESKTOP / WEB
    // ==========================================
    final sidebarBg = isDark ? const Color(0xFF0C0D10) : Colors.white;
    final sidebarBorder = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFE2E8F0);

    return Scaffold(
      body: Row(
        children: [
          // 1. SIDEBAR LATERAL FIJO
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: sidebarBg,
              border: Border(
                right: BorderSide(color: sidebarBorder, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 28),
                // Logo & Título de Marca
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              const Color(0xFF6366F1), // Indigo
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.apartment_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Arriendos',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.4,
                            ),
                          ),
                          Text(
                            'Panel Inmobiliario',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : const Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Chip de Conectividad y Entorno
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Conexión:',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        ConnectionStatusBadge(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22),
                  child: _UserProfileTile(),
                ),
                const SizedBox(height: 16),
                Divider(color: sidebarBorder, height: 1),
                const SizedBox(height: 16),
                // Opciones del Menú
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'MENÚ PRINCIPAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _SidebarItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Inmuebles',
                  isSelected: selectedIndex == 0,
                  onTap: () {
                    if (selectedIndex != 0) {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    }
                  },
                ),
                _SidebarItem(
                  icon: Icons.people_alt_rounded,
                  label: 'Inquilinos',
                  isSelected: selectedIndex == 1,
                  onTap: () {
                    if (selectedIndex != 1) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TenantListScreen()),
                      );
                    }
                  },
                ),
                _SidebarItem(
                  icon: Icons.settings_rounded,
                  label: 'Ajustes y Entorno',
                  isSelected: selectedIndex == 2,
                  onTap: () {
                    if (selectedIndex != 2) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    }
                  },
                ),
                if (ref.watch(canManageUsersProvider))
                  _SidebarItem(
                    icon: Icons.group_outlined,
                    label: 'Gestión de Usuarios',
                    isSelected: selectedIndex == 3,
                    onTap: () {
                      if (selectedIndex != 3) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UserManagementScreen()),
                        );
                      }
                    },
                  ),
                const Spacer(),
                Divider(color: sidebarBorder, height: 1),
                // Footer con Toggle de Tema (Claro / Oscuro)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: InkWell(
                    onTap: () => ref.read(themeModeProvider.notifier).toggleTheme(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isDark ? 'Tema Claro' : 'Tema Oscuro',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isDark ? 'Activar' : 'Activar',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                  child: Text(
                    'Arriendos App • v1.0.0 Local-First',
                    style: TextStyle(
                      color: isDark ? Colors.white24 : const Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. CONTENIDO PRINCIPAL ADAPTATIVO
          Expanded(
            child: Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              appBar: AppBar(
                title: Row(
                  children: [
                    if (breadcrumb != null) ...[
                      breadcrumb!,
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                    ],
                    Text(title),
                  ],
                ),
                actions: actions,
              ),
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: mobileBody,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón circular con las iniciales del usuario. Al tocarlo abre un menú con
/// su correo, su rol, acceso a Gestión de Usuarios (si aplica) y Cerrar
/// sesión. Se usa tanto en el sidebar de escritorio como en el AppBar móvil.
class _UserAvatarMenu extends ConsumerWidget {
  const _UserAvatarMenu();

  Future<void> _handleSelected(BuildContext context, String value) async {
    if (value == 'logout') {
      await AuthService().signOut();
      // `AuthGate`, en la raíz de la app, reacciona solo al cambio de
      // sesión: solo hace falta volver a esa raíz para que se vea.
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else if (value == 'manage_users') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UserManagementScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final role = ref.watch(currentUserRoleProvider).valueOrNull ?? UserRole.viewer;
    final canManageUsers = ref.watch(canManageUsersProvider);
    final email = AuthService().currentUser?.email ?? '';
    final fullName = ref.watch(currentUserFullNameProvider).valueOrNull;
    final displayName = (fullName != null && fullName.trim().isNotEmpty) ? fullName : email;
    final initials = _initialsFor(displayName);

    return PopupMenuButton<String>(
      tooltip: 'Cuenta y sesión',
      onSelected: (value) => _handleSelected(context, value),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
              if (displayName != email) ...[
                const SizedBox(height: 1),
                Text(
                  email,
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 2),
              Text(
                role.label,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (canManageUsers)
          const PopupMenuItem<String>(
            value: 'manage_users',
            child: Row(
              children: [
                Icon(Icons.group_outlined, size: 18),
                SizedBox(width: 10),
                Text('Gestión de Usuarios'),
              ],
            ),
          ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: Color(0xFFEF4444)),
              SizedBox(width: 10),
              Text('Cerrar sesión', style: TextStyle(color: Color(0xFFEF4444))),
            ],
          ),
        ),
      ],
      child: CircleAvatar(
        radius: 18,
        backgroundColor: theme.colorScheme.primary,
        child: Text(
          initials,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }
}

/// "Miguel Angel" -> "MA", "admin@gmail.com" -> "A".
String _initialsFor(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '?';
  final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length >= 2) {
    return (words[0][0] + words[1][0]).toUpperCase();
  }
  return trimmed[0].toUpperCase();
}

/// Fila con el avatar (botón de cuenta) + correo y rol del usuario, usada en
/// el sidebar de escritorio.
class _UserProfileTile extends ConsumerWidget {
  const _UserProfileTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final role = ref.watch(currentUserRoleProvider).valueOrNull ?? UserRole.viewer;
    final email = AuthService().currentUser?.email ?? '';
    final fullName = ref.watch(currentUserFullNameProvider).valueOrNull;
    final displayName = (fullName != null && fullName.trim().isNotEmpty) ? fullName : email;

    return Row(
      children: [
        const _UserAvatarMenu(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                role.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: activeColor.withValues(alpha: 0.08),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: isDark ? 0.15 : 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: activeColor.withValues(alpha: 0.3), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? activeColor
                      : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? activeColor
                          : (isDark ? Colors.white : const Color(0xFF1E293B)),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: activeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
