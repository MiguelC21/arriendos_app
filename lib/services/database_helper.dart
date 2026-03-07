import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/building.dart';
import '../models/unit.dart';
import '../models/contract.dart';
import '../models/monthly_payment.dart';
import '../models/abono.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'arriendos_v2.db');
    return await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 🏠 INMUEBLES
    await db.execute('''
      CREATE TABLE buildings(
        id TEXT PRIMARY KEY,
        name TEXT,
        address TEXT,
        createdAt TEXT
      )
    ''');

    // 🏢 APARTAMENTOS (Units)
    await db.execute('''
      CREATE TABLE units(
        id TEXT PRIMARY KEY,
        buildingId TEXT,
        numero TEXT,
        valorBase REAL,
        fechaLimite INTEGER,
        creadoEn TEXT,
        FOREIGN KEY (buildingId) REFERENCES buildings (id) ON DELETE CASCADE
      )
    ''');

    // 📝 CONTRATOS
    await db.execute('''
      CREATE TABLE contracts(
        id TEXT PRIMARY KEY,
        apartamentoId TEXT,
        nombreInquilino TEXT,
        telefono TEXT,
        fechaInicio TEXT,
        fechaFin TEXT,
        valorContrato REAL,
        activo INTEGER,
        creadoEn TEXT,
        FOREIGN KEY (apartamentoId) REFERENCES units (id) ON DELETE CASCADE
      )
    ''');

    // 💰 PAGOS_MENSUALES
    await db.execute('''
      CREATE TABLE monthly_payments(
        id TEXT PRIMARY KEY,
        contratoId TEXT,
        mes INTEGER,
        año INTEGER,
        valorTotal REAL,
        valorPagado REAL,
        fechaVencimiento TEXT,
        estado TEXT,
        creadoEn TEXT,
        FOREIGN KEY (contratoId) REFERENCES contracts (id) ON DELETE CASCADE
      )
    ''');

    // 💸 ABONOS (Asegurar que exista en onCreate)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS abonos(
        id TEXT PRIMARY KEY,
        pagoId TEXT,
        valor REAL,
        fecha TEXT,
        metodo TEXT,
        creadoEn TEXT,
        FOREIGN KEY (pagoId) REFERENCES monthly_payments (id) ON DELETE CASCADE
      )
    ''');

    // Índices para optimización ⚡
    await _createIndexes(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createIndexes(db);
    }
  }

  Future<void> _createIndexes(Database db) async {
    // Acelera la carga de abonos por mes
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_abonos_pagoId ON abonos(pagoId)',
    );

    // Acelera el pago en cascada (busca pagos no terminados de un contrato)
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_contract_val ON monthly_payments(contratoId, valorPagado)',
    );

    // Acelera el listado de unidades por edificio
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_units_buildingId ON units(buildingId)',
    );

    // Acelera la búsqueda de contratos activos por unidad
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_contracts_unit_active ON contracts(apartamentoId, activo)',
    );
  }

  // --- CRUD METHODS ---

  // Buildings
  Future<int> insertBuilding(Building building) async {
    final db = await database;
    return await db.insert(
      'buildings',
      building.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Building>> getBuildings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'buildings',
      orderBy: 'name',
    );
    return List.generate(maps.length, (i) => Building.fromMap(maps[i]));
  }

  Future<int> deleteBuilding(String buildingId) async {
    final db = await database;
    return await db.delete(
      'buildings',
      where: 'id = ?',
      whereArgs: [buildingId],
    );
  }

  // Units
  Future<int> insertUnit(Unit unit) async {
    final db = await database;
    return await db.insert(
      'units',
      unit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Unit>> getUnitsForBuilding(String buildingId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'units',
      where: 'buildingId = ?',
      whereArgs: [buildingId],
    );
    return List.generate(maps.length, (i) => Unit.fromMap(maps[i]));
  }

  Future<int> updateUnit(Unit unit) async {
    final db = await database;
    return await db.update(
      'units',
      unit.toMap(),
      where: 'id = ?',
      whereArgs: [unit.id],
    );
  }

  Future<int> deleteUnit(String unitId) async {
    final db = await database;
    return await db.delete('units', where: 'id = ?', whereArgs: [unitId]);
  }

  // Contracts
  Future<int> insertContract(Contract contract) async {
    final db = await database;
    return await db.insert(
      'contracts',
      contract.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Contract?> getActiveContractForUnit(String unitId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'contracts',
      where: 'apartamentoId = ? AND activo = 1',
      whereArgs: [unitId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Contract.fromMap(maps.first);
  }

  Future<int> terminateContract(String contractId) async {
    final db = await database;
    return await db.delete(
      'contracts',
      where: 'id = ?',
      whereArgs: [contractId],
    );
  }

  Future<int> updateContract(Contract contract) async {
    final db = await database;
    return await db.update(
      'contracts',
      contract.toMap(),
      where: 'id = ?',
      whereArgs: [contract.id],
    );
  }

  // Monthly Payments
  Future<int> insertMonthlyPayment(MonthlyPayment payment) async {
    final db = await database;
    return await db.insert(
      'monthly_payments',
      payment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertMonthlyPaymentsBatch(List<MonthlyPayment> payments) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (var payment in payments) {
        batch.insert(
          'monthly_payments',
          payment.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<MonthlyPayment>> getPaymentsForContract(String contractId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'monthly_payments',
      where: 'contratoId = ?',
      whereArgs: [contractId],
      orderBy: 'año DESC, mes DESC',
    );
    return List.generate(maps.length, (i) => MonthlyPayment.fromMap(maps[i]));
  }

  Future<MonthlyPayment?> getPaymentForMonth(
    String contractId,
    int month,
    int year,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'monthly_payments',
      where: 'contratoId = ? AND mes = ? AND año = ?',
      whereArgs: [contractId, month, year],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return MonthlyPayment.fromMap(maps.first);
  }

  // Abonos
  Future<int> insertAbono(Abono abono) async {
    final db = await database;
    return await db.transaction((txn) async {
      await txn.insert('abonos', abono.toMap());

      // Actualizar valorPagado en monthly_payments
      await txn.execute(
        '''
        UPDATE monthly_payments 
        SET valorPagado = valorPagado + ?,
            estado = CASE 
              WHEN (valorPagado + ?) >= valorTotal THEN 'pagado'
              ELSE 'parcial'
            END
        WHERE id = ?
      ''',
        [abono.value, abono.value, abono.paymentId],
      );

      return 1;
    });
  }

  Future<List<Abono>> getAbonosForPayment(String paymentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'abonos',
      where: 'pagoId = ?',
      whereArgs: [paymentId],
      orderBy: 'fecha DESC',
    );
    return List.generate(maps.length, (i) => Abono.fromMap(maps[i]));
  }

  Future<void> applyCascadingPayment({
    required double totalAmount,
    required String method,
    required String contractId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Obtener pagos pendientes ordenamos por antigüedad
      final List<Map<String, dynamic>> maps = await txn.query(
        'monthly_payments',
        where: 'contratoId = ? AND valorPagado < valorTotal',
        whereArgs: [contractId],
        orderBy: 'año ASC, mes ASC',
      );

      double remainingMoney = totalAmount;

      for (var map in maps) {
        if (remainingMoney <= 0) break;

        final paymentId = map['id'] as String;
        final total = map['valorTotal'] as double;
        final paid = map['valorPagado'] as double;
        final debt = total - paid;

        double amountToApply = remainingMoney >= debt ? debt : remainingMoney;

        // Insertar Abono
        final abonoId =
            DateTime.now().millisecondsSinceEpoch.toString() +
            remainingMoney.toInt().toString();
        await txn.insert('abonos', {
          'id': abonoId,
          'pagoId': paymentId,
          'valor': amountToApply,
          'fecha': DateTime.now().toIso8601String(),
          'metodo': method,
          'creadoEn': DateTime.now().toIso8601String(),
        });

        // Actualizar Pago Mensual
        await txn.execute(
          '''
          UPDATE monthly_payments 
          SET valorPagado = valorPagado + ?,
              estado = CASE 
                WHEN (valorPagado + ?) >= valorTotal THEN 'pagado'
                ELSE 'parcial'
              END
          WHERE id = ?
        ''',
          [amountToApply, amountToApply, paymentId],
        );

        remainingMoney -= amountToApply;
      }
    });
  }

  Future<int> deleteAbono(String abonoId) async {
    final db = await database;
    return await db.transaction((txn) async {
      // 1. Obtener datos del abono para saber cuánto restar y de qué pago
      final List<Map<String, dynamic>> maps = await txn.query(
        'abonos',
        where: 'id = ?',
        whereArgs: [abonoId],
      );

      if (maps.isEmpty) return 0;
      final abono = maps.first;
      final paymentId = abono['pagoId'] as String;
      final value = abono['valor'] as double;

      // 2. Borrar el abono
      await txn.delete('abonos', where: 'id = ?', whereArgs: [abonoId]);

      // 3. Actualizar el pago mensual
      await txn.execute(
        '''
        UPDATE monthly_payments 
        SET valorPagado = valorPagado - ?,
            estado = CASE 
              WHEN (valorPagado - ?) <= 0 THEN 'mora'
              WHEN (valorPagado - ?) < valorTotal THEN 'parcial'
              ELSE 'pagado'
            END
        WHERE id = ?
      ''',
        [value, value, value, paymentId],
      );

      return 1;
    });
  }

  // Aggregated Stats
  Future<double> getUnitDebt(String unitId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT SUM(mp.valorTotal - mp.valorPagado) as totalDebt
      FROM monthly_payments mp
      JOIN contracts c ON mp.contratoId = c.id
      WHERE c.apartamentoId = ? AND c.activo = 1
    ''',
      [unitId],
    );
    return (result.first['totalDebt'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getBuildingDebt(String buildingId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT SUM(mp.valorTotal - mp.valorPagado) as totalDebt
      FROM monthly_payments mp
      JOIN contracts c ON mp.contratoId = c.id
      JOIN units u ON c.apartamentoId = u.id
      WHERE u.buildingId = ? AND c.activo = 1
    ''',
      [buildingId],
    );
    return (result.first['totalDebt'] as num?)?.toDouble() ?? 0.0;
  }
}
