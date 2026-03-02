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
    return await openDatabase(path, version: 1, onCreate: _onCreate);
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

    // Índice único para evitar duplicados de pagos por mes/año
    await db.execute(
      'CREATE UNIQUE INDEX idx_payment_contract_date ON monthly_payments(contratoId, mes, año)',
    );

    // 💸 ABONOS
    await db.execute('''
      CREATE TABLE abonos(
        id TEXT PRIMARY KEY,
        pagoId TEXT,
        valor REAL,
        fecha TEXT,
        metodo TEXT,
        creadoEn TEXT,
        FOREIGN KEY (pagoId) REFERENCES monthly_payments (id) ON DELETE CASCADE
      )
    ''');
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
    return await db.update(
      'contracts',
      {'activo': 0, 'fechaFin': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [contractId],
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
}
