import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/building_provider.dart';
import '../providers/dashboard_provider.dart';
import '../models/building.dart';
import 'building_detail_screen.dart';
import 'tenant_list_screen.dart';
import 'settings_screen.dart';
import '../providers/building_stats_provider.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/kpi_card.dart';
import '../widgets/adaptive_dialog.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final buildings = ref.watch(buildingProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    final bodyContent = SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 36.0 : 20.0,
        vertical: 24.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. RESUMEN FINANCIERO Y KPIS
          statsAsync.when(
            data: (stats) => Column(
              children: [
                // Tarjeta Principal de Ingresos
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TenantListScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF15161A), const Color(0xFF0D0E10)]
                            : [Colors.white, const Color(0xFFF1F5F9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.payments_rounded,
                                    size: 20,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Recaudo del Mes',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('MMMM yyyy', 'es_ES').format(DateTime.now()).toUpperCase(),
                                      style: TextStyle(
                                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${(stats.progress * 100).toInt()}% Cumplido',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              currencyFormat.format(stats.totalPaid),
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.6,
                              ),
                            ),
                            Text(
                              'Meta mensual: ${currencyFormat.format(stats.totalExpected)}',
                              style: TextStyle(
                                color: isDark ? Colors.white38 : const Color(0xFF64748B),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: stats.progress,
                            minHeight: 9,
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Tarjetas KPI Secundarias
                Row(
                  children: [
                    Expanded(
                      child: KpiCard(
                        title: 'Inquilinos Activos',
                        value: '${stats.activeTenants}',
                        subtitle: 'Contratos vigentes',
                        icon: Icons.people_alt_rounded,
                        accentColor: const Color(0xFF10B981),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TenantListScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: KpiCard(
                        title: 'Pendiente de Cobro',
                        value: currencyFormat.format(stats.pendingDebt),
                        subtitle: 'Saldo restante por recaudar',
                        icon: Icons.pending_actions_rounded,
                        accentColor: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, s) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 36),

          // 2. ENCABEZADO Y BARRA DE BÚSQUEDA
          LayoutBuilder(
            builder: (context, constraints) {
              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Directorio de Inmuebles',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Gestiona tus propiedades, edificios y apartamentos',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                ],
              );

              if (!isDesktop) return titleBlock;

              final searchAndButton = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 260,
                    height: 44,
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Buscar inmueble...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                        fillColor: isDark ? const Color(0xFF181A1F) : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showAddBuildingDialog(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nuevo Inmueble'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(160, 44),
                    ),
                  ),
                ],
              );

              // En desktop angosto (justo sobre el umbral de 768px) el título
              // y el buscador+botón no caben en una sola fila: el título
              // queda con tan poco espacio que el texto se parte letra por
              // letra. Apilamos verticalmente en vez de forzar la fila.
              const minWidthForInlineHeader = 620.0;
              if (constraints.maxWidth >= minWidthForInlineHeader) {
                return Row(
                  children: [
                    Expanded(child: titleBlock),
                    searchAndButton,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleBlock,
                  const SizedBox(height: 14),
                  searchAndButton,
                ],
              );
            },
          ),
          if (!isDesktop) ...[
            const SizedBox(height: 14),
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o dirección...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                fillColor: isDark ? const Color(0xFF181A1F) : Colors.white,
              ),
            ),
          ],
          const SizedBox(height: 18),

          // 3. CUADRÍCULA O LISTADO DE INMUEBLES
          buildings.when(
            data: (list) {
              final filteredList = list.where((b) {
                if (_searchQuery.isEmpty) return true;
                return b.name.toLowerCase().contains(_searchQuery) ||
                    b.address.toLowerCase().contains(_searchQuery);
              }).toList();

              if (list.isEmpty) {
                return EmptyStateView(
                  icon: Icons.apartment_rounded,
                  title: 'No tienes inmuebles registrados',
                  description:
                      'Registra tu primera casa, edificio o conjunto para empezar a administrar arriendos sin conexión.',
                  buttonText: 'Agregar Inmueble',
                  onButtonPressed: () => _showAddBuildingDialog(context, ref),
                );
              }

              if (filteredList.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No se encontraron inmuebles con "$_searchQuery"',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }

              if (isDesktop) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 520,
                    mainAxisExtent: 185,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                  ),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    return _BuildingCard(building: filteredList[index]);
                  },
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  return _BuildingCard(building: filteredList[index]);
                },
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 50),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, s) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 44,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Modo sin conexión',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => ref.read(buildingProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar sincronización'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );

    return ResponsiveLayout(
      title: 'Inmuebles',
      selectedIndex: 0,
      actions: [
        IconButton(
          tooltip: 'Refrescar datos',
          onPressed: () {
            ref.invalidate(dashboardStatsProvider);
            ref.read(buildingProvider.notifier).refresh();
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
        if (!isDesktop)
          IconButton(
            tooltip: 'Ajustes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
      ],
      mobileBody: Stack(
        children: [
          bodyContent,
          if (!isDesktop)
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: ElevatedButton.icon(
                onPressed: () => _showAddBuildingDialog(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Agregar Inmueble'),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddBuildingDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();

    showAdaptiveModal(
      context: context,
      title: 'Nuevo Inmueble',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre del Inmueble',
              hintText: 'Ej: Edificio Santa Fe o Casa Campestre',
              prefixIcon: Icon(Icons.apartment_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: addressController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Dirección o Ubicación',
              hintText: 'Ej: Calle 100 # 15-20',
              prefixIcon: Icon(Icons.location_on_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                final b = Building(
                  name: nameController.text.trim(),
                  address: addressController.text.trim(),
                );
                ref.read(buildingProvider.notifier).addBuilding(b);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Guardar Inmueble'),
          ),
        ],
      ),
    );
  }
}

class _BuildingCard extends ConsumerWidget {
  final Building building;

  const _BuildingCard({required this.building});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BuildingDetailScreen(building: building),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        hoverColor: theme.colorScheme.primary.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.apartment_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          building.name,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                building.address,
                                style: TextStyle(
                                  color: isDark ? Colors.white38 : const Color(0xFF64748B),
                                  fontSize: 12.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      size: 20,
                    ),
                    color: theme.cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditBuildingDialog(context, ref, building);
                      } else if (value == 'delete') {
                        _showDeleteConfirmDialog(context, ref, building);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18, color: theme.colorScheme.primary),
                            const SizedBox(width: 10),
                            Text(
                              'Editar',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                            SizedBox(width: 10),
                            Text('Eliminar', style: TextStyle(color: Color(0xFFEF4444))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Estadísticas de Ocupación y Deuda del Edificio
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ref.watch(buildingOccupancyProvider(building.id)).when(
                        data: (occ) {
                          final total = occ['total'] ?? 0;
                          final rented = occ['rented'] ?? 0;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '$rented/$total',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Alquilados',
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                  ref.watch(buildingDebtProvider(building.id)).when(
                        data: (debt) {
                          final hasDebt = debt > 0.1;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: hasDebt
                                  ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                                  : const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              hasDebt
                                  ? 'Deuda: ${currencyFormat.format(debt)}'
                                  : 'Al día',
                              style: TextStyle(
                                color: hasDebt
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF10B981),
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditBuildingDialog(
    BuildContext context,
    WidgetRef ref,
    Building building,
  ) {
    final nameController = TextEditingController(text: building.name);
    final addressController = TextEditingController(text: building.address);

    showAdaptiveModal(
      context: context,
      title: 'Editar Inmueble',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              prefixIcon: Icon(Icons.apartment_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: addressController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Dirección',
              prefixIcon: Icon(Icons.location_on_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                final updatedBuilding = building.copyWith(
                  name: nameController.text.trim(),
                  address: addressController.text.trim(),
                );
                ref.read(buildingProvider.notifier).updateBuilding(updatedBuilding);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Guardar Cambios'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    Building building,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar Inmueble?'),
        content: Text(
          'Esta acción eliminará "${building.name}" junto con todos sus apartamentos, contratos y pagos asociados de forma segura.\n\n¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              minimumSize: const Size(120, 44),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(buildingProvider.notifier).deleteBuilding(building.id, null);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
