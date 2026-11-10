import '../models/contract.dart';
import '../models/monthly_payment.dart';

/// Monto que se aplicará a un pago mensual concreto.
class PlannedApplication {
  final MonthlyPayment payment;
  final double amount;

  /// `true` si este pago mensual aún no existe y hay que crearlo (mes
  /// adelantado).
  final bool isNew;

  const PlannedApplication({
    required this.payment,
    required this.amount,
    required this.isNew,
  });

  /// `true` si el monto no cubre por completo lo que falta de ese mes.
  bool get isPartial =>
      amount < (payment.totalValue - payment.paidValue) - 0.01;
}

/// Resultado de repartir un monto entre los meses de un contrato.
class PaymentPlan {
  final List<PlannedApplication> applications;
  final double unapplied;

  const PaymentPlan({required this.applications, required this.unapplied});

  /// Meses que hay que crear porque todavía no existen (adelantos).
  List<MonthlyPayment> get newPayments =>
      applications.where((a) => a.isNew).map((a) => a.payment).toList();

  double get applied => applications.fold(0.0, (sum, a) => sum + a.amount);
}

/// Reparte un pago "en cascada" sobre los meses de un contrato y, si se
/// pide, sobre meses futuros que aún no existen (pagos adelantados).
///
/// Orden de aplicación:
///  1. Los meses existentes con saldo pendiente, del más antiguo al más
///     reciente (incluye meses adelantados que quedaron a medias).
///  2. Hasta [advanceMonths] meses nuevos, a continuación del último mes
///     existente. Un mes nuevo solo se crea si le llega parte del monto, así
///     que un pago parcial deja el último mes "Parcial" y nunca crea meses
///     sin dinero aplicado.
///
/// Es lógica pura (sin Hive ni red): sirve tanto para la vista previa del
/// diálogo como para el registro real, y se puede probar de forma aislada.
class AdvancePaymentPlanner {
  static const double _epsilon = 0.01;

  static PaymentPlan plan({
    required Contract? contract,
    required List<MonthlyPayment> existing,
    required double amount,
    int advanceMonths = 0,
  }) {
    if (advanceMonths > 0 && contract == null) {
      throw ArgumentError('Se requiere el contrato para adelantar meses.');
    }

    final applications = <PlannedApplication>[];
    double remaining = amount;

    final pending = existing
        .where((p) => p.totalValue - p.paidValue > _epsilon)
        .toList()
      ..sort((a, b) => _index(a.year, a.month).compareTo(_index(b.year, b.month)));

    for (final p in pending) {
      if (remaining <= _epsilon) break;
      final owed = p.totalValue - p.paidValue;
      final toApply = remaining >= owed ? owed : remaining;
      applications.add(
        PlannedApplication(payment: p, amount: toApply, isNew: false),
      );
      remaining -= toApply;
    }

    if (advanceMonths > 0 && remaining > _epsilon) {
      var next = _nextIndex(contract!, existing);
      for (var i = 0; i < advanceMonths && remaining > _epsilon; i++) {
        final year = next ~/ 12;
        final month = next % 12 + 1;
        final payment = MonthlyPayment.forPeriod(contract, year, month);
        final toApply =
            remaining >= payment.totalValue ? payment.totalValue : remaining;
        applications.add(
          PlannedApplication(payment: payment, amount: toApply, isNew: true),
        );
        remaining -= toApply;
        next++;
      }
    }

    return PaymentPlan(
      applications: applications,
      unapplied: remaining > _epsilon ? remaining : 0.0,
    );
  }

  /// Monto máximo que se puede aplicar con [advanceMonths] meses nuevos.
  static double capacity({
    required Contract? contract,
    required List<MonthlyPayment> existing,
    int advanceMonths = 0,
  }) {
    return plan(
      contract: contract,
      existing: existing,
      amount: 1e12,
      advanceMonths: advanceMonths,
    ).applied;
  }

  /// Texto de estado para una unidad sin deuda que tiene meses adelantados,
  /// o `null` si no hay ningún adelanto con dinero aplicado.
  ///
  ///  - "Adelanto parcial mes siguiente": solo hay un mes siguiente a medias.
  ///  - "Adelanto de 3 meses": hay 3 meses futuros pagados por completo.
  ///  - "Adelanto de 2 meses + parcial": meses completos y uno a medias.
  static String? advanceStatusLabel(List<MonthlyPayment> payments, DateTime now) {
    final advance = payments
        .where((p) => p.isAdvanceAt(now) && p.paidValue > _epsilon)
        .toList();
    if (advance.isEmpty) return null;

    final full = advance
        .where((p) => p.paidValue >= p.totalValue - _epsilon)
        .length;
    final partial = advance.length - full;

    String months(int n) => n == 1 ? '1 mes' : '$n meses';

    if (full == 0) {
      final nextIndex = _index(now.year, now.month) + 1;
      final isNextMonth =
          advance.any((p) => _index(p.year, p.month) == nextIndex);
      return isNextMonth ? 'Adelanto parcial mes siguiente' : 'Adelanto parcial';
    }
    if (partial == 0) return 'Adelanto de ${months(full)}';
    return 'Adelanto de ${months(full)} + parcial';
  }

  static int _index(int year, int month) => year * 12 + (month - 1);

  /// Índice del primer mes que aún no existe, a continuación del último
  /// pago registrado del contrato.
  static int _nextIndex(Contract contract, List<MonthlyPayment> existing) {
    if (existing.isEmpty) {
      return _index(contract.startDate.year, contract.startDate.month);
    }
    final latest = existing
        .map((p) => _index(p.year, p.month))
        .reduce((a, b) => a > b ? a : b);
    return latest + 1;
  }
}
