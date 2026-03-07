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

class BuildingDetailScreen extends ConsumerStatefulWidget {
  final Building building;
  const BuildingDetailScreen({super.key, required this.building});

  @override
  ConsumerState<BuildingDetailScreen> createState() =>
      _BuildingDetailScreenState();
}

class _BuildingDetailScreenState extends ConsumerState<BuildingDetailScreen> {
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

    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.building.name),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(buildingDebtProvider(widget.building.id));
              ref
                  .read(unitProvider.notifier)
                  .loadUnitsForBuilding(widget.building.id);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: () => _showDeleteConfirmDialog(context, ref),
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(buildingDebtProvider(widget.building.id));
          await ref
              .read(unitProvider.notifier)
              .loadUnitsForBuilding(widget.building.id);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Card de Total Pendiente Real
              debtAsync.when(
                data: (debt) => Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Pendiente',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.white54,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${units.length} Apartamentos',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            currencyFormat.format(debt),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: debt > 0 ? 1.0 : 0.0,
                          minHeight: 10,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            debt > 0 ? Colors.orangeAccent : Colors.greenAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Text('Error: $e'),
              ),
              const SizedBox(height: 30),
              // Listado de Apartamentos
              if (units.isEmpty)
                const Center(
                  child: Text(
                    'No hay apartamentos en este inmueble',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: units.length,
                  itemBuilder: (context, index) {
                    final unit = units[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _UnitCard(unit: unit),
                    );
                  },
                ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ElevatedButton.icon(
          onPressed: () => _showAddUnitDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Agregar Apartamento'),
        ),
      ),
    );
  }

  void _showAddUnitDialog(BuildContext context, WidgetRef ref) {
    final numberController = TextEditingController(text: 'Apartamento ');
    final valueController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nuevo Apartamento',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: numberController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Número (Ej: Apartamento 102)',
              ),
            ),
            TextField(
              controller: valueController,
              decoration: const InputDecoration(
                labelText: 'Valor Arriendo Base',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                if (numberController.text.isNotEmpty) {
                  final u = Unit(
                    buildingId: widget.building.id,
                    number: numberController.text.trim(),
                    baseValue:
                        double.tryParse(
                          valueController.text.replaceAll('.', ''),
                        ) ??
                        0.0,
                  );
                  ref.read(unitProvider.notifier).addUnit(u, ref);
                  Navigator.pop(context);
                }
              },
              child: const Text('Guardar Apartamento'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('¿Eliminar Inmueble?'),
        content: Text(
          'Esta acción eliminará "${widget.building.name}" junto con todos sus apartamentos, contratos, pagos y abonos. Esta acción no se puede deshacer.\n\n¿Deseas continuar?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Cerrar diálogo
              Navigator.pop(context); // Volver al Dashboard
              await ref
                  .read(buildingProvider.notifier)
                  .deleteBuilding(widget.building.id, ref);
            },
            child: const Text(
              'Eliminar Todo',
              style: TextStyle(color: Colors.redAccent),
            ),
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

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UnitDetailScreen(unit: unit)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unit.number,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (contract != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Paga los ${contract.startDate.day} de cada mes',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        contract?.tenantName ?? 'Disponible',
                        style: TextStyle(
                          color: contract != null
                              ? Colors.white70
                              : Colors.tealAccent,
                          fontSize: 14,
                        ),
                      ),
                      if (contract != null) ...[
                        const SizedBox(width: 8),
                        ref
                            .watch(unitStatusProvider(unit.id))
                            .when(
                              data: (status) => _StatusBadge(status: status),
                              loading: () => const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              error: (_, _) => const Icon(
                                Icons.error,
                                size: 12,
                                color: Colors.red,
                              ),
                            ),
                      ],
                    ],
                  ),
                  if (contract != null)
                    ref
                        .watch(unitDebtProvider(unit.id))
                        .when(
                          data: (debt) => debt > 0
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Deuda: ${NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0).format(debt)}',
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white24),
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditUnitDialog(context, ref, unit);
                } else if (value == 'delete') {
                  _showDeleteConfirmDialog(context, ref, unit);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit, size: 20),
                    title: Text('Editar'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(
                      Icons.delete,
                      size: 20,
                      color: Colors.redAccent,
                    ),
                    title: Text(
                      'Eliminar',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUnitDialog(BuildContext context, WidgetRef ref, Unit unit) {
    final numberController = TextEditingController(text: unit.number);
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '',
      decimalDigits: 0,
    );
    final valueController = TextEditingController(
      text: currencyFormat.format(unit.baseValue).trim(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Editar Apartamento',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: numberController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Número (Ej: Apartamento 102)',
              ),
            ),
            TextField(
              controller: valueController,
              decoration: const InputDecoration(
                labelText: 'Valor Arriendo Base',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                if (numberController.text.isNotEmpty) {
                  final updatedUnit = Unit(
                    id: unit.id,
                    buildingId: unit.buildingId,
                    number: numberController.text.trim(),
                    baseValue:
                        double.tryParse(
                          valueController.text.replaceAll('.', ''),
                        ) ??
                        0.0,
                  );
                  ref.read(unitProvider.notifier).updateUnit(updatedUnit, ref);
                  Navigator.pop(context);
                }
              },
              child: const Text('Guardar Cambios'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    Unit unit,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Eliminar Apartamento'),
        content: Text(
          '¿Estás seguro de que deseas eliminar el Apartamento ${unit.number}? Esta acción no se puede deshacer y eliminará todos sus contratos y pagos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(unitProvider.notifier)
                  .deleteUnit(unit.id, unit.buildingId, ref);
              Navigator.pop(context);
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.green;
    if (status == 'En Mora') color = Colors.redAccent;
    if (status == 'Pendiente') color = Colors.orangeAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '• $status',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
