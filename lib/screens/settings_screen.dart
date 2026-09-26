import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/environment_config.dart';
import '../services/local_storage_service.dart';
import '../services/supabase_service.dart';
import '../services/sync_manager.dart';
import '../providers/building_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/tenant_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/connection_status_badge.dart';
import '../widgets/responsive_layout.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late AppEnvironment _selectedEnv;
  bool _isSwitching = false;

  @override
  void initState() {
    super.initState();
    _selectedEnv = EnvironmentConfig.current;
  }

  Future<void> _changeEnvironment(AppEnvironment newEnv) async {
    if (_isSwitching || newEnv == _selectedEnv) return;

    setState(() => _isSwitching = true);

    try {
      // 1. Guardar y actualizar configuración de entorno
      await EnvironmentConfig.setEnvironment(newEnv);
      setState(() => _selectedEnv = newEnv);

      // 2. Conmutar cajas locales en Hive para aislar datos locales y de producción
      await LocalStorageService.switchEnvironment(newEnv);

      // 3. Conmutar cliente Supabase hacia el nuevo endpoint
      SupabaseService.switchEnvironment();

      // 4. Notificar al sincronizador para refrescar la cola del nuevo entorno y sincronizar
      await ref.read(syncProvider.notifier).onEnvironmentChanged();

      // 5. Invalidar proveedores Riverpod para refrescar UI con los nuevos datos
      ref.invalidate(buildingProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(activeTenantsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newEnv == AppEnvironment.local
                  ? 'Cambiado a entorno Local (Docker :54321)'
                  : 'Cambiado a entorno Producción (Cloud)',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar entorno: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSwitching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncProvider);
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = ResponsiveLayout.isDesktop(context);

    final pendingCount = LocalStorageService.getPendingSyncCount();
    final localBuildings = LocalStorageService.getAllBuildings().length;

    final content = ListView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 40 : 20,
        vertical: 28,
      ),
      children: [
        // 1. SECCIÓN: APARIENCIA VISUAL (CLARO / OSCURO)
        _buildSectionHeader(
          title: 'Apariencia y Tema',
          subtitle: 'Elige el estilo visual que te resulte más claro y cómodo.',
          icon: Icons.palette_outlined,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildThemeOption(
                  title: 'Tema Claro',
                  icon: Icons.light_mode_rounded,
                  isSelected: themeMode == ThemeMode.light,
                  onTap: () => ref.read(themeModeProvider.notifier).setTheme(ThemeMode.light),
                ),
              ),
              Expanded(
                child: _buildThemeOption(
                  title: 'Tema Oscuro',
                  icon: Icons.dark_mode_rounded,
                  isSelected: themeMode == ThemeMode.dark,
                  onTap: () => ref.read(themeModeProvider.notifier).setTheme(ThemeMode.dark),
                ),
              ),
              Expanded(
                child: _buildThemeOption(
                  title: 'Sistema',
                  icon: Icons.brightness_auto_rounded,
                  isSelected: themeMode == ThemeMode.system,
                  onTap: () => ref.read(themeModeProvider.notifier).setTheme(ThemeMode.system),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 36),

        // 2. SECCIÓN: ENTORNO ACTIVO
        _buildSectionHeader(
          title: 'Entorno de la Base de Datos',
          subtitle: 'Alterna entre la base de datos de pruebas local y producción.',
          icon: Icons.layers_rounded,
        ),
        const SizedBox(height: 12),
        _buildEnvironmentCard(
          env: AppEnvironment.production,
          title: 'Producción (Supabase Cloud)',
          subtitle: 'Base de datos oficial en la nube con los datos reales en vivo.',
          icon: Icons.cloud_rounded,
          color: const Color(0xFF10B981),
        ),
        const SizedBox(height: 10),
        _buildEnvironmentCard(
          env: AppEnvironment.local,
          title: 'Pruebas en Local (Docker / CLI)',
          subtitle: 'Aislado en tu computador (127.0.0.1:54321). Seguro para hacer pruebas.',
          icon: Icons.developer_board_rounded,
          color: const Color(0xFFF59E0B),
        ),

        const SizedBox(height: 36),

        // 3. SECCIÓN: SINCRONIZACIÓN Y LOCAL-FIRST
        _buildSectionHeader(
          title: 'Sincronización y Modo Offline',
          subtitle: 'Tus datos se guardan en el dispositivo y se sincronizan automáticamente.',
          icon: Icons.sync_rounded,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Estado de Conexión',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      fontSize: 14,
                    ),
                  ),
                  const ConnectionStatusBadge(),
                ],
              ),
              Divider(
                height: 24,
                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cambios pendientes en cola',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      fontSize: 14,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: pendingCount > 0
                          ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                          : const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$pendingCount operaciones',
                      style: TextStyle(
                        color: pendingCount > 0
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              Divider(
                height: 24,
                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Inmuebles en caché local',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '$localBuildings guardados',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: syncState.isSyncing
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await ref.read(syncProvider.notifier).syncAll();
                        final remaining = LocalStorageService.getPendingSyncCount();
                        if (remaining == 0) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                _selectedEnv == AppEnvironment.local
                                    ? 'Sincronizado con base local de pruebas exitosamente.'
                                    : 'Sincronizado con la nube exitosamente.',
                              ),
                              backgroundColor: const Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } else {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Aviso: Quedaron $remaining operaciones pendientes. Verifica que Supabase local esté activo.',
                              ),
                              backgroundColor: Colors.orange.shade800,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                icon: syncState.isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync_rounded),
                label: Text(
                  syncState.isSyncing
                      ? 'Sincronizando...'
                      : (_selectedEnv == AppEnvironment.local
                          ? 'Sincronizar ahora con base local'
                          : 'Sincronizar ahora con la nube'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 36),

        // 4. SECCIÓN: INFORMACIÓN DE LA APP
        Center(
          child: Column(
            children: [
              Text(
                'Arriendos Premium v1.0.0',
                style: TextStyle(
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Local-First & Multi-Plataforma (Web + Móvil)',
                style: TextStyle(
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return ResponsiveLayout(
      title: 'Ajustes y Entorno',
      selectedIndex: 2,
      mobileBody: content,
    );
  }

  Widget _buildThemeOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF38BDF8).withValues(alpha: 0.15) : const Color(0xFF0284C7).withValues(alpha: 0.1))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4), width: 1.5)
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? theme.colorScheme.primary
                  : (isDark ? Colors.white60 : const Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnvironmentCard({
    required AppEnvironment env,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedEnv == env;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () => _changeEnvironment(env),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : (isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : Colors.grey.withValues(alpha: 0.4),
                  width: 2,
                ),
                color: isSelected ? color : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
