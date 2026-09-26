import 'package:flutter_test/flutter_test.dart';
import 'package:arriendos_app/config/environment_config.dart';
import 'package:arriendos_app/models/building.dart';
import 'package:arriendos_app/models/unit.dart';
import 'package:arriendos_app/models/contract.dart';
import 'package:arriendos_app/models/monthly_payment.dart';
import 'package:arriendos_app/models/abono.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  group('EnvironmentConfig Tests', () {
    test('Default environment starts as production or configured', () {
      expect(EnvironmentConfig.prodUrl, contains('supabase.co'));
      expect(EnvironmentConfig.localUrl, contains('54321'));
    });

    test('Toggling environment changes currentUrl', () async {
      await EnvironmentConfig.setEnvironment(AppEnvironment.local);
      expect(EnvironmentConfig.isLocal, isTrue);
      expect(EnvironmentConfig.currentUrl, equals(EnvironmentConfig.localUrl));

      await EnvironmentConfig.setEnvironment(AppEnvironment.production);
      expect(EnvironmentConfig.isProduction, isTrue);
      expect(EnvironmentConfig.currentUrl, equals(EnvironmentConfig.prodUrl));
    });
  });

  group('Model Serialization Tests', () {
    test('Building toMap and fromMap are symmetrical', () {
      final b = Building(
        id: 'b-1',
        name: 'Edificio Los Pinos',
        address: 'Calle 10 # 5-20',
      );
      final map = b.toMap();
      final fromMap = Building.fromMap(map);

      expect(fromMap.id, equals(b.id));
      expect(fromMap.name, equals(b.name));
      expect(fromMap.address, equals(b.address));
    });

    test('Unit toMap and fromMap are symmetrical', () {
      final u = Unit(
        id: 'u-1',
        buildingId: 'b-1',
        number: '101',
        baseValue: 1250000,
      );
      final map = u.toMap();
      final fromMap = Unit.fromMap(map);

      expect(fromMap.id, equals(u.id));
      expect(fromMap.buildingId, equals(u.buildingId));
      expect(fromMap.number, equals(u.number));
      expect(fromMap.baseValue, equals(1250000));
    });

    test('Contract toMap and fromMap are symmetrical', () {
      final c = Contract(
        id: 'c-1',
        unitId: 'u-1',
        tenantName: 'Carlos Pérez',
        phone: '3001234567',
        startDate: DateTime(2026, 1, 1),
        contractValue: 1300000,
      );
      final map = c.toMap();
      final fromMap = Contract.fromMap(map);

      expect(fromMap.id, equals(c.id));
      expect(fromMap.tenantName, equals('Carlos Pérez'));
      expect(fromMap.contractValue, equals(1300000));
      expect(fromMap.active, isTrue);
    });

    test('MonthlyPayment calculation and serialization', () {
      final p = MonthlyPayment(
        id: 'p-1',
        contractId: 'c-1',
        month: 3,
        year: 2026,
        totalValue: 1000000,
        paidValue: 1000000,
        dueDate: DateTime(2026, 3, 5),
        status: PaymentStatus.pagado,
      );
      final map = p.toMap();
      final fromMap = MonthlyPayment.fromMap(map);

      expect(fromMap.paidValue, equals(1000000));
      expect(fromMap.status, equals(PaymentStatus.pagado));
    });

    test('Abono serialization', () {
      final a = Abono(
        id: 'a-1',
        paymentId: 'p-1',
        amount: 500000,
        date: DateTime(2026, 3, 2),
        note: 'Transferencia Bancolombia',
      );
      final map = a.toMap();
      final fromMap = Abono.fromMap(map);

      expect(fromMap.amount, equals(500000));
      expect(fromMap.note, equals('Transferencia Bancolombia'));
    });
  });
}
