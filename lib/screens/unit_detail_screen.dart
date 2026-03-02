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
      appBar: AppBar(title: Text('Apartamento ${widget.unit.number}')),
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
                        data: (status) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
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
                            if (status != 'Disponible') ...[
                              const SizedBox(height: 10),
                              ref
                                  .watch(unitDebtProvider(widget.unit.id))
                                  .when(
                                    data: (debt) => Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Deuda Total:',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          currencyFormat.format(debt),
                                          style: TextStyle(
                                            color: debt > 0
                                                ? Colors.redAccent
                                                : Colors.green,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    loading: () => const SizedBox.shrink(),
                                    error: (_, __) => const SizedBox.shrink(),
                                  ),
                            ],
                          ],
                        ),
                        loading: () => const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (_, _) => const Text(
                          'Error al cargar estado',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                  const Divider(height: 30, color: Colors.white12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Inquilino: ${contract?.tenantName ?? 'Disponible'}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      if (contract != null)
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: Color(0xFF38BDF8),
                          ),
                          onPressed: () =>
                              _showEditTenantDialog(context, ref, contract),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Editar Inquilino',
                        ),
                    ],
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
                                  if (!context.mounted) return;
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
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return _ContractDialogContent(
              nameController: nameController,
              phoneController: phoneController,
              valueController: valueController,
              selectedDate: selectedDate,
              unit: widget.unit,
              ref: ref,
              onDateChanged: (date) => setModalState(() => selectedDate = date),
            );
          },
        );
      },
    );
  }

  void _showEditTenantDialog(
    BuildContext context,
    WidgetRef ref,
    Contract contract,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          _EditTenantDialogContent(contract: contract, ref: ref),
    );
  }

  void _showAddAbonoDialog(
    BuildContext context,
    WidgetRef ref,
    Contract contract,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          _AbonoDialogContent(contract: contract, unit: widget.unit, ref: ref),
    );
  }
}

class _ContractDialogContent extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController valueController;
  final DateTime selectedDate;
  final Unit unit;
  final WidgetRef ref;
  final Function(DateTime) onDateChanged;

  const _ContractDialogContent({
    required this.nameController,
    required this.phoneController,
    required this.valueController,
    required this.selectedDate,
    required this.unit,
    required this.ref,
    required this.onDateChanged,
  });

  @override
  State<_ContractDialogContent> createState() => _ContractDialogContentState();
}

class _ContractDialogContentState extends State<_ContractDialogContent> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            controller: widget.nameController,
            decoration: const InputDecoration(labelText: 'Nombre Inquilino'),
            enabled: !_isLoading,
          ),
          TextField(
            controller: widget.phoneController,
            decoration: const InputDecoration(labelText: 'Teléfono'),
            keyboardType: TextInputType.phone,
            enabled: !_isLoading,
          ),
          TextField(
            controller: widget.valueController,
            decoration: const InputDecoration(labelText: 'Valor Mensual'),
            keyboardType: TextInputType.number,
            enabled: !_isLoading,
          ),
          const SizedBox(height: 20),
          const Text(
            'Fecha de Inicio:',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _isLoading
                ? null
                : () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: widget.selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      widget.onDateChanged(picked);
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
                  Text(
                    DateFormat('dd / MM / yyyy').format(widget.selectedDate),
                  ),
                  const Icon(Icons.calendar_today, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (widget.nameController.text.isNotEmpty) {
                        setState(() => _isLoading = true);
                        try {
                          final c = Contract(
                            unitId: widget.unit.id,
                            tenantName: widget.nameController.text,
                            phone: widget.phoneController.text,
                            startDate: widget.selectedDate,
                            contractValue:
                                double.tryParse(widget.valueController.text) ??
                                widget.unit.baseValue,
                          );
                          await widget.ref
                              .read(contractProvider.notifier)
                              .addContract(
                                c,
                                widget.unit.buildingId,
                                widget.ref,
                              );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Contrato creado con éxito',
                                ),
                                backgroundColor: Colors.green.shade700,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                  vertical: 20,
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } finally {
                          if (context.mounted) {
                            setState(() => _isLoading = false);
                          }
                        }
                      }
                    },
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Comenzar Contrato'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _AbonoDialogContent extends StatefulWidget {
  final Contract contract;
  final Unit unit;
  final WidgetRef ref;

  const _AbonoDialogContent({
    required this.contract,
    required this.unit,
    required this.ref,
  });

  @override
  State<_AbonoDialogContent> createState() => _AbonoDialogContentState();
}

class _AbonoDialogContentState extends State<_AbonoDialogContent> {
  final _amountController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_validateAmount);
  }

  @override
  void dispose() {
    _amountController.removeListener(_validateAmount);
    _amountController.dispose();
    super.dispose();
  }

  void _validateAmount() {
    // Solo llamamos a setState para que el build re-evalúe los flags isOverLimit e isInvalid
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final debtAsync = widget.ref.watch(unitDebtProvider(widget.unit.id));
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    final currentDebt = debtAsync.asData?.value ?? 0.0;
    final inputAmount = double.tryParse(_amountController.text) ?? 0.0;
    final isOverLimit = inputAmount > currentDebt;
    final isInvalid = inputAmount <= 0;

    return Padding(
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
          const SizedBox(height: 10),
          debtAsync.when(
            data: (debt) => Text(
              'Deuda Pendiente: ${currencyFormat.format(debt)}',
              style: TextStyle(
                color: debt > 0 ? Colors.redAccent : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Monto Pagado',
              prefixText: '\$',
              errorText: isOverLimit
                  ? 'No puedes superar la deuda total'
                  : null,
            ),
            keyboardType: TextInputType.number,
            enabled: !_isLoading,
          ),
          const SizedBox(height: 15),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isLoading || isOverLimit || isInvalid)
                  ? null
                  : () async {
                      if (inputAmount > 0) {
                        setState(() => _isLoading = true);
                        try {
                          await widget.ref
                              .read(paymentProvider.notifier)
                              .applyCascadingPayment(
                                totalAmount: inputAmount,
                                method: 'Efectivo',
                                contractId: widget.contract.id,
                                buildingId: widget.unit.buildingId,
                                unitId: widget.unit.id,
                                ref: widget.ref,
                              );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Pago registrado correctamente',
                                ),
                                backgroundColor: Colors.green.shade700,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                  vertical: 20,
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } finally {
                          if (context.mounted) {
                            setState(() => _isLoading = false);
                          }
                        }
                      }
                    },
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Guardar Pago'),
            ),
          ),
          const SizedBox(height: 20),
        ],
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

    if (payments.isEmpty) {
      return const Text(
        'Generando primer cobro...',
        style: TextStyle(color: Colors.white54),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final p = payments[index];
        final monthName = _getMonthName(p.month);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 5,
              ),
              title: Text(
                '$monthName ${p.year}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              subtitle: Text(
                '${currencyFormat.format(p.paidValue)} / ${currencyFormat.format(p.totalValue)}',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              trailing: _StatusBadge(status: p.status.name),
              children: [
                Consumer(
                  builder: (context, ref, child) {
                    final abonosAsync = ref.watch(abonosProvider(p.id));
                    return abonosAsync.when(
                      data: (abonos) {
                        if (abonos.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(15),
                            child: Text(
                              'Sin abonos registrados',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: [
                            const Divider(
                              height: 1,
                              color: Colors.white12,
                              indent: 15,
                              endIndent: 15,
                            ),
                            ...abonos.map((a) {
                              final fullDateTime = DateFormat(
                                "EEEE d 'de' MMMM, yyyy - hh:mm a",
                                'es_ES',
                              ).format(a.date);
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.receipt_long_outlined,
                                  size: 18,
                                  color: Color(0xFF38BDF8),
                                ),
                                title: Text(
                                  'Abono: ${currencyFormat.format(a.value)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  'Fecha: ${fullDateTime[0].toUpperCase()}${fullDateTime.substring(1)}',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: Text(
                                  a.method,
                                  style: const TextStyle(
                                    color: Colors.white24,
                                    fontSize: 11,
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 10),
                          ],
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.all(15),
                        child: Center(
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      error: (err, _) => Padding(
                        padding: const EdgeInsets.all(15),
                        child: Text(
                          'Error al cargar abonos',
                          style: TextStyle(
                            color: Colors.redAccent.shade100,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
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
        color: color.withValues(alpha: 0.1),
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

class _EditTenantDialogContent extends StatefulWidget {
  final Contract contract;
  final WidgetRef ref;

  const _EditTenantDialogContent({required this.contract, required this.ref});

  @override
  State<_EditTenantDialogContent> createState() =>
      _EditTenantDialogContentState();
}

class _EditTenantDialogContentState extends State<_EditTenantDialogContent> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contract.tenantName);
    _phoneController = TextEditingController(text: widget.contract.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            'Editar Datos del Inquilino',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nombre Completo'),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'Teléfono'),
            keyboardType: TextInputType.phone,
            enabled: !_isLoading,
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (_nameController.text.isNotEmpty) {
                        setState(() => _isLoading = true);
                        try {
                          final updatedContract = widget.contract.copyWith(
                            tenantName: _nameController.text,
                            phone: _phoneController.text,
                          );
                          await widget.ref
                              .read(contractProvider.notifier)
                              .updateContract(updatedContract, widget.ref);

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Datos actualizados correctamente',
                                ),
                                backgroundColor: Colors.green.shade700,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                  vertical: 20,
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } finally {
                          if (context.mounted) {
                            setState(() => _isLoading = false);
                          }
                        }
                      }
                    },
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Actualizar Datos'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
