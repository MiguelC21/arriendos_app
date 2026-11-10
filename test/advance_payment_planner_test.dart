import 'package:flutter_test/flutter_test.dart';
import 'package:arriendos_app/models/contract.dart';
import 'package:arriendos_app/models/monthly_payment.dart';
import 'package:arriendos_app/services/advance_payment_planner.dart';

void main() {
  final contract = Contract(
    id: 'c-1',
    unitId: 'u-1',
    tenantName: 'Test',
    phone: '300',
    startDate: DateTime(2026, 7, 15),
    contractValue: 180000,
  );

  MonthlyPayment pay(int year, int month, {double paid = 0}) {
    final p = MonthlyPayment.forPeriod(contract, year, month);
    return MonthlyPayment(
      id: p.id,
      contractId: p.contractId,
      month: month,
      year: year,
      totalValue: p.totalValue,
      paidValue: paid,
      dueDate: p.dueDate,
    );
  }

  String period(PlannedApplication a) => '${a.payment.year}-${a.payment.month}';

  group('AdvancePaymentPlanner', () {
    test('sin adelanto solo cubre meses existentes pendientes', () {
      final existing = [pay(2026, 10, paid: 180000), pay(2026, 11)];
      final plan = AdvancePaymentPlanner.plan(
        contract: contract,
        existing: existing,
        amount: 100000,
      );
      expect(plan.applications.length, 1);
      expect(period(plan.applications.first), '2026-11');
      expect(plan.applications.first.amount, 100000);
      expect(plan.newPayments, isEmpty);
    });

    test('adelanto de 3 meses completos crea 3 meses nuevos', () {
      final existing = [pay(2026, 11, paid: 180000)];
      final plan = AdvancePaymentPlanner.plan(
        contract: contract,
        existing: existing,
        amount: 3 * 180000,
        advanceMonths: 3,
      );
      expect(plan.applications.map(period), ['2026-12', '2027-1', '2027-2']);
      expect(plan.applications.every((a) => a.isNew && !a.isPartial), isTrue);
      expect(plan.unapplied, 0);
    });

    test('primero paga la deuda y luego adelanta', () {
      final existing = [pay(2026, 10), pay(2026, 11, paid: 80000)];
      final plan = AdvancePaymentPlanner.plan(
        contract: contract,
        existing: existing,
        amount: 180000 + 100000 + 180000,
        advanceMonths: 1,
      );
      expect(plan.applications.map(period), ['2026-10', '2026-11', '2026-12']);
      expect(plan.applications[0].amount, 180000);
      expect(plan.applications[1].amount, 100000);
      expect(plan.applications[2].amount, 180000);
      expect(plan.newPayments.length, 1);
    });

    test('pago parcial de un mes adelantado deja el último mes parcial', () {
      final existing = [pay(2026, 11, paid: 180000)];
      final plan = AdvancePaymentPlanner.plan(
        contract: contract,
        existing: existing,
        amount: 270000, // 1.5 meses
        advanceMonths: 3,
      );
      expect(plan.applications.length, 2);
      expect(plan.applications[0].amount, 180000);
      expect(plan.applications[1].amount, 90000);
      expect(plan.applications[1].isPartial, isTrue);
      // No crea el tercer mes porque ya no queda dinero.
      expect(plan.newPayments.length, 2);
    });

    test('un mes adelantado a medias se completa antes de crear otro', () {
      final existing = [
        pay(2026, 11, paid: 180000),
        pay(2026, 12, paid: 90000),
      ];
      final plan = AdvancePaymentPlanner.plan(
        contract: contract,
        existing: existing,
        amount: 90000 + 180000,
        advanceMonths: 1,
      );
      expect(plan.applications.map(period), ['2026-12', '2027-1']);
      expect(plan.applications[0].isNew, isFalse);
      expect(plan.applications[1].isNew, isTrue);
    });

    test('monto mayor a la capacidad queda sin aplicar', () {
      final existing = [pay(2026, 11, paid: 180000)];
      final plan = AdvancePaymentPlanner.plan(
        contract: contract,
        existing: existing,
        amount: 1000000,
        advanceMonths: 2,
      );
      expect(plan.applied, 360000);
      expect(plan.unapplied, 640000);
    });

    test('capacity suma deuda + meses adelantados', () {
      final existing = [pay(2026, 10), pay(2026, 11, paid: 80000)];
      expect(
        AdvancePaymentPlanner.capacity(
          contract: contract,
          existing: existing,
          advanceMonths: 3,
        ),
        180000 + 100000 + 3 * 180000,
      );
      expect(
        AdvancePaymentPlanner.capacity(contract: contract, existing: existing),
        280000,
      );
    });

    test('adelantar sin contrato lanza error', () {
      expect(
        () => AdvancePaymentPlanner.plan(
          contract: null,
          existing: const [],
          amount: 1,
          advanceMonths: 1,
        ),
        throwsArgumentError,
      );
    });

    test('el id de un mes adelantado es el mismo en cualquier dispositivo', () {
      final a = MonthlyPayment.forPeriod(contract, 2027, 3);
      final b = MonthlyPayment.forPeriod(contract, 2027, 3);
      expect(a.id, b.id);
      expect(a.id, isNot(MonthlyPayment.forPeriod(contract, 2027, 4).id));
    });

    test('estado: sin adelantos no hay texto especial', () {
      final now = DateTime(2026, 11, 10);
      expect(
        AdvancePaymentPlanner.advanceStatusLabel(
          [pay(2026, 10, paid: 180000), pay(2026, 11, paid: 180000)],
          now,
        ),
        isNull,
      );
    });

    test('estado: un mes siguiente a medias', () {
      final now = DateTime(2026, 11, 10);
      expect(
        AdvancePaymentPlanner.advanceStatusLabel(
          [pay(2026, 11, paid: 180000), pay(2026, 12, paid: 50000)],
          now,
        ),
        'Adelanto parcial mes siguiente',
      );
    });

    test('estado: N meses completos', () {
      final now = DateTime(2026, 11, 10);
      final three = [
        pay(2026, 11, paid: 180000),
        pay(2026, 12, paid: 180000),
        pay(2027, 1, paid: 180000),
        pay(2027, 2, paid: 180000),
      ];
      expect(AdvancePaymentPlanner.advanceStatusLabel(three, now),
          'Adelanto de 3 meses');
      expect(
        AdvancePaymentPlanner.advanceStatusLabel(
            [pay(2026, 12, paid: 180000)], now),
        'Adelanto de 1 mes',
      );
    });

    test('estado: meses completos más uno parcial', () {
      final now = DateTime(2026, 11, 10);
      expect(
        AdvancePaymentPlanner.advanceStatusLabel(
          [
            pay(2026, 12, paid: 180000),
            pay(2027, 1, paid: 180000),
            pay(2027, 2, paid: 40000),
          ],
          now,
        ),
        'Adelanto de 2 meses + parcial',
      );
    });

    test('isAdvanceAt solo es verdadero para meses posteriores al actual', () {
      final now = DateTime(2026, 11, 10);
      expect(pay(2026, 10).isAdvanceAt(now), isFalse);
      expect(pay(2026, 11).isAdvanceAt(now), isFalse);
      expect(pay(2026, 12).isAdvanceAt(now), isTrue);
      expect(pay(2027, 1).isAdvanceAt(now), isTrue);
    });
  });
}
