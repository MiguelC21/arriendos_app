import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_role.dart';
import '../providers/auth_provider.dart';
import '../services/admin_users_service.dart';
import '../services/auth_service.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/search_field.dart';

final _adminUsersServiceProvider = Provider<AdminUsersService>((ref) => AdminUsersService());

final _profilesProvider = FutureProvider<List<ProfileSummary>>((ref) async {
  return ref.watch(_adminUsersServiceProvider).listProfiles();
});

final _searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final _roleFilterProvider = StateProvider.autoDispose<UserRole?>((ref) => null);

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(_profilesProvider);
    final isDeveloper = ref.watch(isDeveloperProvider);
    final searchQuery = ref.watch(_searchQueryProvider);
    final roleFilter = ref.watch(_roleFilterProvider);
    final currentUserId = AuthService().currentUser?.id;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () => ref.invalidate(_profilesProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateUserDialog(context, ref, isDeveloper),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Crear Usuario'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SearchField(
                  hintText: 'Buscar por nombre o correo...',
                  onChanged: (value) => ref.read(_searchQueryProvider.notifier).state = value.trim().toLowerCase(),
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _RoleFilterChip(
                        label: 'Todos',
                        selected: roleFilter == null,
                        onSelected: () => ref.read(_roleFilterProvider.notifier).state = null,
                      ),
                      const SizedBox(width: 8),
                      _RoleFilterChip(
                        label: UserRole.developer.label,
                        selected: roleFilter == UserRole.developer,
                        onSelected: () => ref.read(_roleFilterProvider.notifier).state = UserRole.developer,
                      ),
                      const SizedBox(width: 8),
                      _RoleFilterChip(
                        label: UserRole.admin.label,
                        selected: roleFilter == UserRole.admin,
                        onSelected: () => ref.read(_roleFilterProvider.notifier).state = UserRole.admin,
                      ),
                      const SizedBox(width: 8),
                      _RoleFilterChip(
                        label: UserRole.viewer.label,
                        selected: roleFilter == UserRole.viewer,
                        onSelected: () => ref.read(_roleFilterProvider.notifier).state = UserRole.viewer,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: profilesAsync.when(
              data: (profiles) {
                final filtered = profiles.where((p) {
                  final matchesQuery = searchQuery.isEmpty ||
                      p.email.toLowerCase().contains(searchQuery) ||
                      (p.fullName?.toLowerCase().contains(searchQuery) ?? false);
                  final matchesRole = roleFilter == null || p.role == roleFilter;
                  return matchesQuery && matchesRole;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      profiles.isEmpty ? 'No hay usuarios.' : 'Ningún usuario coincide con la búsqueda.',
                      style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final profile = filtered[index];
                    return _ProfileTile(
                      profile: profile,
                      isDeveloper: isDeveloper,
                      isSelf: profile.id == currentUserId,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error al cargar usuarios: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateUserDialog(BuildContext context, WidgetRef ref, bool isDeveloper) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    UserRole selectedRole = UserRole.viewer;
    bool isLoading = false;
    String? errorText;

    showAdaptiveModal(
      context: context,
      title: 'Crear Usuario',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
              enabled: !isLoading,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo electrónico'),
              enabled: !isLoading,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña temporal'),
              enabled: !isLoading,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<UserRole>(
              initialValue: selectedRole,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: [
                const DropdownMenuItem(value: UserRole.viewer, child: Text('Usuario (solo lectura)')),
                const DropdownMenuItem(value: UserRole.admin, child: Text('Administrador')),
                // Solo un Developer puede crear otra cuenta Developer.
                if (isDeveloper)
                  const DropdownMenuItem(value: UserRole.developer, child: Text('Desarrollador')),
              ],
              onChanged: isLoading ? null : (value) => setModalState(() => selectedRole = value ?? UserRole.viewer),
            ),
            if (errorText != null) ...[
              const SizedBox(height: 10),
              Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (emailController.text.trim().isEmpty || passwordController.text.length < 6) {
                        setModalState(() => errorText = 'Correo válido y contraseña de al menos 6 caracteres.');
                        return;
                      }
                      setModalState(() {
                        isLoading = true;
                        errorText = null;
                      });
                      try {
                        await ref.read(_adminUsersServiceProvider).createUser(
                              email: emailController.text.trim(),
                              password: passwordController.text,
                              role: selectedRole,
                              fullName: nameController.text,
                            );
                        ref.invalidate(_profilesProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setModalState(() {
                          isLoading = false;
                          errorText = '$e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Crear Usuario'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _RoleFilterChip({required this.label, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12.5)),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? primary : (isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFE2E8F0)),
        ),
      ),
      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
      selectedColor: primary.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        color: selected ? primary : (isDark ? Colors.white70 : const Color(0xFF475569)),
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

class _ProfileTile extends ConsumerWidget {
  final ProfileSummary profile;
  final bool isDeveloper;
  final bool isSelf;

  const _ProfileTile({required this.profile, required this.isDeveloper, required this.isSelf});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasName = profile.fullName != null && profile.fullName!.trim().isNotEmpty;

    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                child: Text(
                  _initialsFor(hasName ? profile.fullName! : profile.email),
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasName ? profile.fullName! : profile.email,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasName) ...[
                      const SizedBox(height: 2),
                      Text(
                        profile.email,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Editar nombre',
                visualDensity: VisualDensity.compact,
                onPressed: () => _showEditNameDialog(context, ref),
                icon: const Icon(Icons.edit_outlined, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: 14),
          DropdownButtonFormField<UserRole>(
            initialValue: profile.role,
            decoration: const InputDecoration(labelText: 'Rol', isDense: true),
            items: [
              const DropdownMenuItem(value: UserRole.viewer, child: Text('Usuario (solo lectura)')),
              const DropdownMenuItem(value: UserRole.admin, child: Text('Administrador')),
              // Un Admin no puede promover a otros a Developer.
              if (isDeveloper || profile.role == UserRole.developer)
                const DropdownMenuItem(value: UserRole.developer, child: Text('Desarrollador')),
            ],
            onChanged: (value) async {
              if (value == null || value == profile.role) return;
              if (value == UserRole.developer && !isDeveloper) return;
              await ref.read(_adminUsersServiceProvider).updateRole(userId: profile.id, role: value);
              ref.invalidate(_profilesProvider);
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showResetPasswordDialog(context, ref),
                icon: const Icon(Icons.lock_reset_rounded, size: 18),
                label: const Text('Restablecer contraseña'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
              const SizedBox(width: 2),
              IconButton(
                tooltip: isSelf ? 'No puedes eliminar tu propia cuenta' : 'Eliminar usuario',
                visualDensity: VisualDensity.compact,
                onPressed: isSelf ? null : () => _showDeleteConfirmDialog(context, ref),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: isSelf ? null : const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController(text: profile.fullName ?? '');
    bool isLoading = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Editar nombre'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre completo'),
                enabled: !isLoading,
              ),
              if (errorText != null) ...[
                const SizedBox(height: 10),
                Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setDialogState(() {
                        isLoading = true;
                        errorText = null;
                      });
                      try {
                        await ref.read(_adminUsersServiceProvider).updateFullName(
                              userId: profile.id,
                              fullName: nameController.text,
                            );
                        ref.invalidate(_profilesProvider);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (e) {
                        setDialogState(() {
                          isLoading = false;
                          errorText = '$e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, WidgetRef ref) {
    bool isLoading = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('¿Eliminar usuario?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Esta acción eliminará permanentemente la cuenta de "${profile.displayName}" (${profile.email}). No se puede deshacer.',
              ),
              if (errorText != null) ...[
                const SizedBox(height: 10),
                Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              onPressed: isLoading
                  ? null
                  : () async {
                      setDialogState(() {
                        isLoading = true;
                        errorText = null;
                      });
                      try {
                        await ref.read(_adminUsersServiceProvider).deleteUser(userId: profile.id);
                        ref.invalidate(_profilesProvider);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (e) {
                        setDialogState(() {
                          isLoading = false;
                          errorText = '$e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context, WidgetRef ref) {
    final passwordController = TextEditingController();
    bool isLoading = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Restablecer contraseña de ${profile.email}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nueva contraseña'),
                enabled: !isLoading,
              ),
              if (errorText != null) ...[
                const SizedBox(height: 10),
                Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (passwordController.text.length < 6) {
                        setDialogState(() => errorText = 'Mínimo 6 caracteres.');
                        return;
                      }
                      setDialogState(() {
                        isLoading = true;
                        errorText = null;
                      });
                      try {
                        await ref.read(_adminUsersServiceProvider).resetPassword(
                              userId: profile.id,
                              newPassword: passwordController.text,
                            );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (e) {
                        setDialogState(() {
                          isLoading = false;
                          errorText = '$e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Restablecer'),
            ),
          ],
        ),
      ),
    );
  }
}
