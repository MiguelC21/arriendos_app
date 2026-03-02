import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/unit.dart';
import '../models/contract.dart';
import '../providers/contract_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/building_stats_provider.dart';

class UnitDetailScreen extends ConsumerStatefulWidget {
  final Unit unit;
  const UnitDetailScreen({super.key, required this.unit});

  @override
  ConsumerState<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends ConsumerState<UnitDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(contractProvider.notifier)
          .loadActiveContractForUnit(widget.unit.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contractMap = ref.watch(contractProvider);
    final contract = contractMap[widget.unit.id];
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(title: Text('Apto ${widget.unit.number}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card (Valor Arriendo, Inquilino) - Referencia Imagen 3
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Valor Arriendo:',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        currencyFormat.format(
                          contract?.contractValue ?? widget.unit.baseValue,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Vence: ${contract?.startDate.day ?? 5} de cada mes',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 10),
                  ref
                      .watch(unitStatusProvider(widget.unit.id))
                      .when(
                        data: (status) => Text(
                          'Estado: $status',
                          style: TextStyle(
                            color: status == 'Al Día'
                                ? Colors.green
                                : (status == 'En Mora'
                                      ? Colors.redAccent
                                      : Colors.orangeAccent),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        loading: () => const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (_, __) => const Text(
                          'Error al cargar estado',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                  const Divider(height: 30, color: Colors.white12),
                  Text(
                    'Inquilino: ${contract?.tenantName ?? 'Disponible'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (contract != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      '📞 Tel: ${contract.phone}',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF1E293B),
                            title: const Text('Finalizar Contrato'),
                            content: Text(
                              '¿Estás seguro de que deseas finalizar el contrato de ${contract.tenantName}? El apartamento quedará disponible.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await ref
                                      .read(contractProvider.notifier)
                                      .terminateContract(
                                        contract.id,
                                        widget.unit.id,
                                        widget.unit.buildingId,
                                        ref,
                                      );
                                  Navigator.pop(context); // Cerrar diálogo
                                },
                                child: const Text(
                                  'Confirmar',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white10,
                      ),
                      child: const Text('Finalizar Contrato'),
                    ),
                  ] else ...[
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => _showAddContractDialog(context, ref),
                      child: const Text('Asignar Inquilino'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),
            if (contract != null) ...[
              const Text(
                'Historial de Pagos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              _PaymentHistoryList(contract: contract),
            ],
          ],
        ),
      ),
      floatingActionButton: contract != null
          ? FloatingActionButton.extended(
              onPressed: () => _showAddAbonoDialog(context, ref, contract),
              label: const Text('Registrar Pago'),
              icon: const Icon(Icons.add_card),
            )
          : null,
    );
  }

  void _showAddContractDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final valueController = TextEditingController(
      text: widget.unit.baseValue.toString(),
    );
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                'Nuevo Contrato',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre Inquilino',
                ),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Teléfono'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: valueController,
                decoration: const InputDecoration(labelText: 'Valor Mensual'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              const Text(
                'Fecha de Inicio:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(
                          context,
                        ).colorScheme.copyWith(onPrimary: Colors.white),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setModalState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd / MM / yyyy').format(selectedDate)),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    final c = Contract(
                      unitId: widget.unit.id,
                      tenantName: nameController.text,
                      phone: phoneController.text,
                      startDate: selectedDate,
                      contractValue:
                          double.tryParse(valueController.text) ??
                          widget.unit.baseValue,
                    );
                    ref
                        .read(contractProvider.notifier)
                        .addContract(c, widget.unit.buildingId, ref);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Comenzar Contrato'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddAbonoDialog(
    BuildContext context,
    WidgetRef ref,
    Contract contract,
  ) {
    final amountController = TextEditingController();

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
              'Registrar Abono',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Monto Pagado',
                prefixText: '\$',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 15),
            const Text(
              'Método de Pago:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            DropdownButton<String>(
              isExpanded: true,
              value: 'Efectivo',
              dropdownColor: const Color(0xFF1E293B),
              items: [
                'Efectivo',
                'Transferencia',
                'Nequi/Daviplata',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {},
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0.0;
                if (amount > 0) {
                  await ref
                      .read(paymentProvider.notifier)
                      .applyCascadingPayment(
                        totalAmount: amount,
                        method: 'Efectivo', // Podríamos hacerlo dinámico
                        contractId: contract.id,
                        buildingId: widget.unit.buildingId,
                        unitId: widget.unit.id,
                        ref: ref,
                      );
                  Navigator.pop(context);
                }
              },
              child: const Text('Guardar Pago'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _PaymentHistoryList extends ConsumerWidget {
  final Contract contract;
  const _PaymentHistoryList({required this.contract});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Cargar historial
    Future.microtask(
      () => ref
          .read(paymentProvider.notifier)
          .loadPaymentsForContract(contract.id),
    );
    final payments = ref.watch(paymentProvider);
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    if (payments.isEmpty)
      return const Text(
        'Generando primer cobro...',
        style: TextStyle(color: Colors.white54),
      );

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final p = payments[index];
        final monthName = _getMonthName(p.month);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$monthName ${p.year}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${currencyFormat.format(p.paidValue)} / ${currencyFormat.format(p.totalValue)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
              _StatusBadge(status: p.status.name),
            ],
          ),
        );
      },
    );
  }

  String _getMonthName(int month) {
    final dates = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return dates[month];
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.orange;
    String label = 'Pendiente';

    if (status == 'pagado') {
      color = Colors.green;
      label = 'Pagado';
    } else if (status == 'parcial') {
      color = Colors.blue;
      label = 'Parcial';
    } else if (status == 'mora') {
      color = Colors.redAccent;
      label = 'Mora';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
