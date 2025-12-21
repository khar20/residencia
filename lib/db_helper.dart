import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tenants_manager.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Increment version if you change schema
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // Tenants table
    await db.execute('''
      CREATE TABLE tenants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        nationality TEXT NOT NULL,
        doc_type TEXT NOT NULL,
        doc_number TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    // Room registrations table
    await db.execute('''
      CREATE TABLE registrations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tenant_id INTEGER NOT NULL,
        room_number TEXT NOT NULL,
        check_in_date TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (tenant_id) REFERENCES tenants (id)
      )
    ''');
  }

  // Retrieve distinct document types
  Future<List<String>> getDistinctDocTypes() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT DISTINCT doc_type FROM tenants WHERE is_deleted = 0 ORDER BY doc_type ASC',
    );

    List<String> types = result
        .map((row) => row['doc_type'] as String)
        .toList();

    final defaults = ['ID Card', 'Passport', 'Driver License', 'Other'];
    for (var def in defaults) {
      if (!types.contains(def)) {
        types.add(def);
      }
    }
    return types;
  }

  // CRUD TENANTS

  Future<int> createTenant(Tenant tenant) async {
    final db = await instance.database;
    return await db.insert('tenants', tenant.toMap());
  }

  Future<List<Tenant>> readAllTenants() async {
    final db = await instance.database;
    // Filter out soft-deleted records
    final result = await db.query(
      'tenants',
      where: 'is_deleted = 0',
      orderBy: 'last_name ASC',
    );
    return result.map((json) => Tenant.fromMap(json)).toList();
  }

  Future<int> updateTenant(Tenant tenant) async {
    final db = await instance.database;
    return db.update(
      'tenants',
      tenant.toMap(),
      where: 'id = ?',
      whereArgs: [tenant.id],
    );
  }

  Future<int> deleteTenant(int id) async {
    final db = await instance.database;
    // Soft Delete: Update flag instead of removing row
    return await db.update(
      'tenants',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // CRUD REGISTRATIONS

  Future<int> createRegistration(RoomRegistration reg) async {
    final db = await instance.database;
    return await db.insert('registrations', reg.toMap());
  }

  Future<List<RoomRegistration>> readRegistrationsByTenant(int tenantId) async {
    final db = await instance.database;
    final result = await db.query(
      'registrations',
      where: 'tenant_id = ? AND is_deleted = 0',
      whereArgs: [tenantId],
      orderBy: 'check_in_date DESC',
    );
    return result.map((json) => RoomRegistration.fromMap(json)).toList();
  }

  Future<int> updateRegistration(RoomRegistration reg) async {
    final db = await instance.database;
    return db.update(
      'registrations',
      reg.toMap(),
      where: 'id = ?',
      whereArgs: [reg.id],
    );
  }

  Future<int> deleteRegistration(int id) async {
    final db = await instance.database;
    // Soft delete
    return await db.update(
      'registrations',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
