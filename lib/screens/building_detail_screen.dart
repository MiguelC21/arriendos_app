import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/building.dart';
import '../models/unit.dart';
import '../providers/unit_provider.dart';
import '../providers/contract_provider.dart';
import '../providers/building_stats_provider.dart';
import 'unit_detail_screen.dart';
import '../utils/formatters.dart';
import '../providers/building_provider.dart';
import '../widgets/status_badge.dart';
import '../widgets/connection_status_badge.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/empty_state_view.dart';

class BuildingDetailScreen extends ConsumerStatefulWidget {
  final Building building;
  const BuildingDetailScreen({super.key, required this.building});

  @override
  ConsumerState<BuildingDetailScreen> createState() =>
      _BuildingDetailScreenState();
}

class _BuildingDetailScreenState extends ConsumerState<BuildingDetailScreen> {
  String _unitSearchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(unitProvider.notifier).loadUnitsForBuilding(widget.building.id);
      ref
          .read(contractProvider.notifier)
          .loadActiveContractsForBuilding(widget.building.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final unitsMap = ref.watch(unitProvider);
    final units = unitsMap[widget.building.id] ?? [];
    final debtAsync = ref.watch(buildingDebtProvider(widget.building.id));
    final occupancyAsync = ref.watch(buildingOccupancyProvider(widget.building.id));
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    final filteredUnits = units.where((u) {
      if (_unitSearchQuery.isEmpty) return true;
      return u.number.toLowerCase().contains(_unitSearchQuery.toLowerCase());
    }).toList();

    // ==========================================
    // 🖥️ VISTA WEB / DESKTOP (DOS COLUMNAS)
    // ==========================================
    Widget desktopContent(double debt, int totalUnits, int rentedUnits) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PANEL IZQUIERDO: FICHA DEL EDIFICIO
            SizedBox(
              width: 340,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.apartment_rounded,
                                color: theme.colorScheme.primary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.building.name,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  Text(
                                    widget.building.address,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Divider(
                          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                        ),
                        const SizedBox(height: 16),
                        _buildStatRow(
                          'Total Unidades',
                          '$totalUnits apartamentos',
                          Icons.grid_view_rounded,
                          theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        _buildStatRow(
                          'Ocupación',
                          '$rentedUnits de $totalUnits alquilados',
                          Icons.person_pin_rounded,
                          const Color(0xFF10B981),
                        ),
                        const SizedBox(height: 12),
                        _buildStatRow(
                          'Deuda Acumulada',
                          currencyFormat.format(debt),
                          Icons.monetization_on_rounded,
                          debt > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _showAddUnitDialog(context, ref),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Agregar Apartamento'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 28),

            // PANEL DERECHO: CUADRÍCULA DE APARTAMENTOS
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final title = Text(
                        'Apartamentos y Unidades ($totalUnits)',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.4,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      );
                      final search = SizedBox(
                        width: 240,
                        height: 42,
                        child: TextField(
                          onChanged: (val) => setState(() => _unitSearchQuery = val.trim()),
                          decoration: InputDecoration(
                            hintText: 'Buscar número o apto...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 18),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            fillColor: isDark ? const Color(0xFF181A1F) : Colors.white,
                          ),
                        ),
                      );

                      // En desktop angosto, título y buscador no caben en una
                      // sola fila: se apilan en vez de aplastar el texto.
                      if (constraints.maxWidth >= 480) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [title, search],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          title,
                          const SizedBox(height: 12),
                          search,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  if (units.isEmpty)
                    EmptyStateView(
                      icon: Icons.meeting_room_outlined,
                      title: 'No hay apartamentos creados',
                      description: 'Agrega el primer apartamento u oficina para este inmueble.',
                      buttonText: 'Agregar Apartamento',
                      onButtonPressed: () => _showAddUnitDialog(context, ref),
                    )
                  else if (filteredUnits.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'No hay apartamentos con "$_unitSearchQuery"',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 440,
                        mainAxisExtent: 155,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: filteredUnits.length,
                      itemBuilder: (context, index) {
                        return _UnitCard(unit: filteredUnits[index]);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ==========================================
    // 📱 VISTA MÓVIL
    // ==========================================
    Widget mobileContent(double debt, int totalUnits, int rentedUnits) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen Deuda Edificio
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Deuda Total del Inmueble',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: debt > 0.1
                              ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                              : const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          debt > 0.1 ? 'Con Saldo' : 'Al Día',
                          style: TextStyle(
                            color: debt > 0.1 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$rentedUnits/$totalUnits Apartamentos',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        currencyFormat.format(debt),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Apartamentos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$totalUnits unidades',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (units.isEmpty)
              EmptyStateView(
                icon: Icons.meeting_room_outlined,
                title: 'No hay apartamentos en este inmueble',
                description: 'Crea tu primer apartamento u oficina para empezar.',
                buttonText: 'Agregar Apartamento',
                onButtonPressed: () => _showAddUnitDialog(context, ref),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: units.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _UnitCard(unit: units[index]);
                },
              ),
            const SizedBox(height: 100),
          ],
        ),
      );
    }

    final totalUnits = occupancyAsync.value?['total'] ?? units.length;
    final rentedUnits = occupancyAsync.value?['rented'] ?? 0;
    final currentDebt = debtAsync.value ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.building.name),
        actions: [
          const ConnectionStatusBadge(),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () {
              ref.invalidate(buildingDebtProvider(widget.building.id));
              ref.invalidate(buildingOccupancyProvider(widget.building.id));
              ref.read(unitProvider.notifier).loadUnitsForBuilding(widget.building.id);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Eliminar Inmueble',
            onPressed: () => _showDeleteConfirmDialog(context, ref),
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isDesktop
          ? desktopContent(currentDebt, totalUnits, rentedUnits)
          : mobileContent(currentDebt, totalUnits, rentedUnits),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: isDesktop
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton.icon(
                onPressed: () => _showAddUnitDialog(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Agregar Apartamento'),
              ),
            ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddUnitDialog(BuildContext context, WidgetRef ref) {
    final numberController = TextEditingController(text: 'Apartamento ');
    final valueController = TextEditingController();

    showAdaptiveModal(
      context: context,
      title: 'Nuevo Apartamento',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: numberController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Número o Nombre',
              hintText: 'Ej: Apto 101, Local 2',
              prefixIcon: Icon(Icons.door_front_door_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: valueController,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            decoration: const InputDecoration(
              labelText: 'Valor Base de Arriendo',
              hintText: '\$ 1.200.000',
              prefixIcon: Icon(Icons.attach_money_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              if (numberController.text.trim().isNotEmpty) {
                final cleanedValue = valueController.text.replaceAll(RegExp(r'[^0-9]'), '');
                final baseValue = double.tryParse(cleanedValue) ?? 0.0;

                final unit = Unit(
                  buildingId: widget.building.id,
                  number: numberController.text.trim(),
                  baseValue: baseValue,
                );
                ref.read(unitProvider.notifier).addUnit(unit, ref);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Guardar Apartamento'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar Inmueble?'),
        content: Text(
          'Esta acción eliminará "${widget.building.name}" junto con todos sus apartamentos y contratos.\n\n¿Deseas continuar?',
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
              await ref.read(buildingProvider.notifier).deleteBuilding(widget.building.id, null);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _UnitCard extends ConsumerWidget {
  final Unit unit;
  const _UnitCard({required this.unit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contractMap = ref.watch(contractProvider);
    final contract = contractMap[unit.id];
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
            MaterialPageRoute(builder: (_) => UnitDetailScreen(unit: unit)),
          );
        },
        borderRadius: BorderRadius.circular(16),
        hoverColor: theme.colorScheme.primary.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      unit.number,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (contract != null)
                    ref.watch(unitStatusProvider(unit.id)).when(
                          data: (status) => StatusBadge(status: status),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        )
                  else
                    const StatusBadge(status: 'Disponible'),
                  IconButton(
                    tooltip: 'Editar Apartamento',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _showEditUnitDialog(context, ref),
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Eliminar Apartamento',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _showDeleteUnitConfirmDialog(context, ref),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    contract != null ? Icons.person_outline_rounded : Icons.lock_open_rounded,
                    size: 14,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      contract != null ? contract.tenantName : 'Disponible para arriendo',
                      style: TextStyle(
                        fontSize: 13,
                        color: contract != null
                            ? (isDark ? Colors.white70 : const Color(0xFF475569))
                            : theme.colorScheme.primary,
                        fontWeight: contract != null ? FontWeight.w500 : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Canon: ${currencyFormat.format(contract?.contractValue ?? unit.baseValue)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                    ),
                  ),
                  if (contract != null)
                    ref.watch(unitDebtProvider(unit.id)).when(
                          data: (debt) => debt > 0.1
                              ? Text(
                                  'Debe: ${currencyFormat.format(debt)}',
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : const SizedBox.shrink(),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditUnitDialog(BuildContext context, WidgetRef ref) {
    final numberController = TextEditingController(text: unit.number);
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '',
      decimalDigits: 0,
    );
    final valueController = TextEditingController(
      text: currencyFormat.format(unit.baseValue).trim(),
    );

    showAdaptiveModal(
      context: context,
      title: 'Editar Apartamento',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: numberController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Número o Nombre',
              hintText: 'Ej: Apto 101, Local 2',
              prefixIcon: Icon(Icons.door_front_door_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: valueController,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            decoration: const InputDecoration(
              labelText: 'Valor Base de Arriendo',
              hintText: '\$ 1.200.000',
              prefixIcon: Icon(Icons.attach_money_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              if (numberController.text.trim().isNotEmpty) {
                final cleanedValue = valueController.text.replaceAll(RegExp(r'[^0-9]'), '');
                final baseValue = double.tryParse(cleanedValue) ?? 0.0;

                final updatedUnit = Unit(
                  id: unit.id,
                  buildingId: unit.buildingId,
                  number: numberController.text.trim(),
                  baseValue: baseValue,
                  createdAt: unit.createdAt,
                );
                ref.read(unitProvider.notifier).updateUnit(updatedUnit, ref);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Guardar Cambios'),
          ),
        ],
      ),
    );
  }

  void _showDeleteUnitConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar Apartamento?'),
        content: Text(
          'Esta acción eliminará "${unit.number}" junto con su contrato y pagos asociados de forma permanente.\n\n¿Deseas continuar?',
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
              await ref
                  .read(unitProvider.notifier)
                  .deleteUnit(unit.id, unit.buildingId, ref);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
