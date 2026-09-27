import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/unit.dart';
import '../models/contract.dart';
import '../providers/auth_provider.dart';
import '../providers/contract_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/building_stats_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/formatters.dart';

import '../widgets/connection_status_badge.dart';
import '../widgets/status_badge.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/empty_state_view.dart';

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
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final canEdit = ref.watch(canEditProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget buildInfoCard() {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Valor Arriendo:',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    fontSize: 14,
                  ),
                ),
                Text(
                  currencyFormat.format(
                    contract?.contractValue ?? widget.unit.baseValue,
                  ),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: -0.4,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Vence: ${contract?.startDate.day ?? 5} de cada mes',
              style: TextStyle(
                color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 12),
            ref.watch(unitStatusProvider(widget.unit.id)).when(
                  data: (status) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Estado:',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF64748B),
                              fontSize: 13.5,
                            ),
                          ),
                          StatusBadge(status: status),
                        ],
                      ),
                      if (status != 'Disponible') ...[
                        const SizedBox(height: 10),
                        ref.watch(unitDebtProvider(widget.unit.id)).when(
                              data: (debt) => Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Deuda Total:',
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  Text(
                                    currencyFormat.format(debt),
                                    style: TextStyle(
                                      color: debt > 0.1 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
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
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, _) => const Text(
                    'Error al cargar estado',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            Divider(
              height: 28,
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inquilino',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        contract?.tenantName ?? 'Disponible',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                if (contract != null && canEdit)
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: () => _showEditTenantDialog(context, ref, contract),
                    tooltip: 'Editar Inquilino',
                  ),
              ],
            ),
            if (contract != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.phone_outlined,
                    size: 14,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    contract.phone.isNotEmpty ? contract.phone : 'Sin teléfono',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                  if (contract.phone.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () => _launchWhatsApp(contract.phone),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF25D366).withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 11,
                              color: Color(0xFF25D366),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'WhatsApp',
                              style: TextStyle(
                                color: Color(0xFF25D366),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (canEdit) ...[
                const SizedBox(height: 20),
                if (isDesktop) ...[
                  ElevatedButton.icon(
                    onPressed: () => _showAddAbonoDialog(context, ref, contract),
                    icon: const Icon(Icons.add_card_rounded, size: 18),
                    label: const Text('Registrar Pago / Abono'),
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('¿Finalizar Contrato?'),
                        content: const Text(
                          'Esta acción finalizará el contrato del inquilino y liberará la unidad para un nuevo arrendamiento.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                            ),
                            onPressed: () async {
                              await ref.read(contractProvider.notifier).terminateContract(
                                    contract.id,
                                    widget.unit.id,
                                    widget.unit.buildingId,
                                    ref,
                                  );
                              if (!context.mounted) return;
                              Navigator.pop(context);
                            },
                            child: const Text('Finalizar'),
                          ),
                        ],
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 46),
                    side: const BorderSide(color: Color(0xFFEF4444), width: 1),
                    foregroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                  label: const Text('Finalizar Contrato'),
                ),
              ],
            ] else ...[
              if (canEdit) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => _showAddContractDialog(context, ref),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Asignar Inquilino'),
                ),
              ],
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.unit.number),
        actions: const [
          ConnectionStatusBadge(),
          SizedBox(width: 12),
        ],
      ),
      body: isDesktop
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 360,
                    child: buildInfoCard(),
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Historial de Cobros y Pagos',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.4,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              if (contract != null && canEdit)
                                ElevatedButton.icon(
                                  onPressed: () => _showAddAbonoDialog(context, ref, contract),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('Nuevo Abono'),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(150, 40),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          if (contract != null)
                            _PaymentHistoryList(contract: contract, unit: widget.unit)
                          else
                            const EmptyStateView(
                              icon: Icons.history_rounded,
                              title: 'Sin pagos registrados',
                              description:
                                  'Asigna un inquilino a este apartamento para comenzar a liquidar los cobros mensuales.',
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildInfoCard(),
                  const SizedBox(height: 30),
                  if (contract != null) ...[
                    Text(
                      'Historial de Pagos',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PaymentHistoryList(contract: contract, unit: widget.unit),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
      floatingActionButton: (!isDesktop && contract != null && canEdit)
          ? FloatingActionButton.extended(
              onPressed: () => _showAddAbonoDialog(context, ref, contract),
              label: const Text('Registrar Pago'),
              icon: const Icon(Icons.add_card),
            )
          : null,
    );
  }

  Future<void> _launchWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    // Asumimos código de país Colombia (+57) si no tiene suficientes dígitos
    final formattedPhone = cleanPhone.length == 10
        ? '57$cleanPhone'
        : cleanPhone;
    final url = Uri.parse('whatsapp://send?phone=$formattedPhone');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
    } else {
      // Si no puede abrir whatsapp://, intentar con la web como respaldo
      final webUrl = Uri.parse('https://wa.me/$formattedPhone');
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _showAddContractDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '',
      decimalDigits: 0,
    );
    final valueController = TextEditingController(
      text: currencyFormat.format(widget.unit.baseValue).trim(),
    );
    DateTime selectedDate = DateTime.now();

    showAdaptiveModal(
      context: context,
      title: 'Nuevo Contrato de Arriendo',
      builder: (ctx) {
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
    showAdaptiveModal(
      context: context,
      title: 'Editar Inquilino',
      builder: (ctx) =>
          _EditTenantDialogContent(contract: contract, ref: ref),
    );
  }

  void _showAddAbonoDialog(
    BuildContext context,
    WidgetRef ref,
    Contract contract,
  ) {
    showAdaptiveModal(
      context: context,
      title: 'Registrar Abono / Pago',
      maxWidth: 580,
      builder: (ctx) =>
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.nameController,
          decoration: const InputDecoration(
            labelText: 'Nombre Completo del Inquilino',
            hintText: 'Ej: CARLOS GÓMEZ',
            prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
          ),
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [UpperCaseTextFormatter()],
          enabled: !_isLoading,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: widget.phoneController,
          decoration: const InputDecoration(
            labelText: 'Teléfono o Celular',
            hintText: 'Ej: 300 123 4567',
            prefixIcon: Icon(Icons.phone_outlined, size: 20),
          ),
          keyboardType: TextInputType.phone,
          enabled: !_isLoading,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: widget.valueController,
          decoration: const InputDecoration(
            labelText: 'Canon Mensual Acordado',
            hintText: '250.000',
            prefixIcon: Icon(Icons.payments_outlined, size: 20),
            prefixText: '\$ ',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [CurrencyInputFormatter()],
          enabled: !_isLoading,
        ),
        const SizedBox(height: 16),
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
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Fecha de Inicio del Contrato',
              prefixIcon: Icon(Icons.calendar_month_outlined, size: 20),
              suffixIcon: Icon(Icons.arrow_drop_down_rounded, size: 24),
            ),
            child: Text(
              DateFormat('dd / MM / yyyy').format(widget.selectedDate),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _isLoading
              ? null
              : () async {
                  if (widget.nameController.text.isNotEmpty &&
                      widget.valueController.text.isNotEmpty) {
                    setState(() => _isLoading = true);
                    try {
                      final contractValue =
                          double.tryParse(
                            widget.valueController.text.replaceAll('.', ''),
                          ) ??
                          widget.unit.baseValue;

                      final c = Contract(
                        unitId: widget.unit.id,
                        tenantName: widget.nameController.text.trim(),
                        phone: widget.phoneController.text.trim(),
                        startDate: widget.selectedDate,
                        contractValue: contractValue,
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
          icon: _isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.assignment_turned_in_outlined, size: 20),
          label: Text(_isLoading ? 'Creando Contrato...' : 'Comenzar Contrato'),
        ),
      ],
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
    final inputAmount =
        double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0.0;
    final isOverLimit = inputAmount > currentDebt;
    final isInvalid = inputAmount <= 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: debtAsync.maybeWhen(
              data: (debt) => debt > 0
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFF0FDF4),
              orElse: () => const Color(0xFFF8FAFC),
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: debtAsync.maybeWhen(
                data: (debt) => debt > 0
                    ? const Color(0xFFFECACA)
                    : const Color(0xFFBBF7D0),
                orElse: () => const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Deuda Pendiente:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              debtAsync.when(
                data: (debt) => Text(
                  currencyFormat.format(debt),
                  style: TextStyle(
                    color: debt > 0
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF16A34A),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                loading: () => const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => const Text('Error'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _amountController,
          decoration: InputDecoration(
            labelText: 'Monto a Abonar',
            hintText: '0',
            prefixIcon: const Icon(Icons.attach_money_rounded, size: 20),
            errorText: isOverLimit
                ? 'No puedes superar la deuda total'
                : null,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [CurrencyInputFormatter()],
          enabled: !_isLoading,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: (_isLoading || isOverLimit || isInvalid)
              ? null
              : () async {
                  if (inputAmount > 0) {
                    setState(() => _isLoading = true);
                    try {
                      await widget.ref
                          .read(
                            paymentProvider(widget.contract.id).notifier,
                          )
                          .applyCascadingPayment(
                            totalAmount: inputAmount,
                            method: 'Efectivo',
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
          icon: _isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle_outline, size: 20),
          label: Text(_isLoading ? 'Registrando...' : 'Confirmar Abono'),
        ),
      ],
    );
  }
}

class _PaymentHistoryList extends ConsumerWidget {
  final Contract contract;
  final Unit unit;
  const _PaymentHistoryList({required this.contract, required this.unit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentProvider(contract.id));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    return paymentsAsync.when(
      data: (payments) {
        if (payments.isEmpty) {
          return Text(
            'Sin historial de pagos.',
            style: TextStyle(
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
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
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                ),
              ),
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 5,
                  ),
                  title: Text(
                    '$monthName ${p.year}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    '${currencyFormat.format(p.paidValue)} / ${currencyFormat.format(p.totalValue)}',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                  trailing: _StatusBadge(
                    status: p.status.name,
                    month: p.month,
                    year: p.year,
                  ),
                  children: [
                    Consumer(
                      builder: (context, ref, child) {
                        final abonosAsync = ref.watch(abonosProvider(p.id));
                        return abonosAsync.when(
                          data: (abonos) {
                            if (abonos.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(15),
                                child: Text(
                                  'Sin abonos registrados',
                                  style: TextStyle(
                                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }
                            return Column(
                              children: [
                                Divider(
                                  height: 1,
                                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
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
                                      'Abono: ${currencyFormat.format(a.amount)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Fecha: ${fullDateTime[0].toUpperCase()}${fullDateTime.substring(1)}',
                                      style: TextStyle(
                                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: !ref.watch(canEditProvider)
                                        ? null
                                        : IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            backgroundColor: Theme.of(context).cardColor,
                                            title: Text(
                                              '¿Deshacer Pago?',
                                              style: TextStyle(
                                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              ),
                                            ),
                                            content: Text(
                                              'Esta acción eliminará el abono y ajustará el saldo pendiente del mes. ¿Deseas continuar?',
                                              style: TextStyle(
                                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('Cancelar'),
                                              ),
                                              TextButton(
                                                onPressed: () async {
                                                  Navigator.pop(context);
                                                  await ref
                                                      .read(
                                                        paymentProvider(
                                                          p.contractId,
                                                        ).notifier,
                                                      )
                                                      .deleteAbono(
                                                        abonoId: a.id,
                                                        buildingId:
                                                            unit.buildingId,
                                                        unitId: unit.id,
                                                        ref: ref,
                                                      );
                                                },
                                                child: const Text(
                                                  'Eliminar',
                                                  style: TextStyle(
                                                    color: Colors.redAccent,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(30.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Center(
        child: Text(
          'Error al cargar el historial: $err',
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
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
  final int month;
  final int year;

  const _StatusBadge({
    required this.status,
    required this.month,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isPastMonth =
        year < now.year || (year == now.year && month < now.month);

    String label = 'Pendiente';

    if (status == 'pagado') {
      label = 'Pagado';
    } else if (status == 'parcial') {
      label = 'Parcial';
    } else if (status == 'mora' || (isPastMonth && status == 'pendiente')) {
      label = status == 'mora' ? 'Mora' : 'Pendiente';
    } else if (status == 'pendiente') {
      label = 'Pendiente';
    }

    return StatusBadge(status: label);
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Nombre Completo del Inquilino',
            hintText: 'Ej: CARLOS GÓMEZ',
            prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
          ),
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [UpperCaseTextFormatter()],
          enabled: !_isLoading,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Teléfono o Celular',
            hintText: 'Ej: 300 123 4567',
            prefixIcon: Icon(Icons.phone_outlined, size: 20),
          ),
          keyboardType: TextInputType.phone,
          enabled: !_isLoading,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _isLoading
              ? null
              : () async {
                  if (_nameController.text.isNotEmpty) {
                    setState(() => _isLoading = true);
                    try {
                      final updatedContract = widget.contract.copyWith(
                        tenantName: _nameController.text.trim(),
                        phone: _phoneController.text.trim(),
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
          icon: _isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_outlined, size: 20),
          label: Text(_isLoading ? 'Guardando...' : 'Guardar Cambios'),
        ),
      ],
    );
  }
}

