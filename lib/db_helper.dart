import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  static const String dbName = 'residencia_database.db';
  static const String tableTenants = 'tenants';
  static const String tableRegistrations = 'registrations';

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    String path;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop Setup
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final directory = await getApplicationDocumentsDirectory();
      path = join(directory.path, filePath);
    } else {
      // Mobile Setup
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
    }

    return await openDatabase(
      path,
      version: 1,
      onConfigure: _onConfigure,
      onCreate: _createDB,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableTenants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        nationality TEXT NOT NULL,
        doc_type TEXT NOT NULL,
        doc_number TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableRegistrations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tenant_id INTEGER NOT NULL,
        room_number TEXT NOT NULL,
        check_in_date TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (tenant_id) REFERENCES $tableTenants (id) ON DELETE CASCADE
      )
    ''');

    // Index for searching names and docs
    await db.execute(
      'CREATE INDEX idx_tenants_search ON $tableTenants(first_name, last_name, doc_number)',
    );

    // Index for Autocomplete suggestions
    await db.execute(
      'CREATE INDEX idx_tenants_doctype ON $tableTenants(doc_type)',
    );
    await db.execute(
      'CREATE INDEX idx_tenants_nationality ON $tableTenants(nationality)',
    );

    // Index for finding registrations quickly
    await db.execute(
      'CREATE INDEX idx_registrations_tenant ON $tableRegistrations(tenant_id)',
    );
  }

  // Clear Database
  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete(tableRegistrations);
      await txn.delete(tableTenants);
      // Reset ID counters
      await txn.rawDelete(
        "DELETE FROM sqlite_sequence WHERE name='$tableTenants' OR name='$tableRegistrations'",
      );
    });
  }

  // CRUD Tenants
  Future<int> createTenant(Tenant tenant) async {
    final db = await instance.database;
    return await db.insert(tableTenants, tenant.toMap());
  }

  Future<List<Tenant>> readAllTenants() async {
    final db = await instance.database;
    final result = await db.query(
      tableTenants,
      where: 'is_deleted = 0',
      orderBy: 'id DESC',
    );
    return result.map((json) => Tenant.fromMap(json)).toList();
  }

  Future<int> updateTenant(Tenant tenant) async {
    final db = await instance.database;
    return db.update(
      tableTenants,
      tenant.toMap(),
      where: 'id = ?',
      whereArgs: [tenant.id],
    );
  }

  Future<int> deleteTenant(int id) async {
    final db = await instance.database;
    return await db.update(
      tableTenants,
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Tenant>> searchTenants(String keyword) async {
    final db = await instance.database;
    final result = await db.query(
      tableTenants,
      where:
          'is_deleted = 0 AND (first_name LIKE ? OR last_name LIKE ? OR doc_number LIKE ?)',
      whereArgs: ['%$keyword%', '%$keyword%', '%$keyword%'],
      orderBy: 'id DESC',
    );
    return result.map((json) => Tenant.fromMap(json)).toList();
  }

  // HELPERS
  Future<List<String>> getDistinctDocTypes() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      "SELECT DISTINCT doc_type FROM $tableTenants WHERE is_deleted = 0 AND doc_type IS NOT NULL AND doc_type != '' ORDER BY doc_type ASC",
    );
    return result.map((row) => row['doc_type'] as String).toList();
  }

  Future<List<String>> getDistinctNationalities() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      "SELECT DISTINCT nationality FROM $tableTenants WHERE is_deleted = 0 AND nationality IS NOT NULL AND nationality != '' ORDER BY nationality ASC",
    );
    return result.map((row) => row['nationality'] as String).toList();
  }

  // CRUD Registrations
  Future<int> createRegistration(RoomRegistration reg) async {
    final db = await instance.database;
    return await db.insert(tableRegistrations, reg.toMap());
  }

  Future<List<RoomRegistration>> readRegistrationsByTenant(int tenantId) async {
    final db = await instance.database;
    final result = await db.query(
      tableRegistrations,
      where: 'tenant_id = ? AND is_deleted = 0',
      whereArgs: [tenantId],
      orderBy: 'check_in_date DESC',
    );
    return result.map((json) => RoomRegistration.fromMap(json)).toList();
  }

  Future<int> updateRegistration(RoomRegistration reg) async {
    final db = await instance.database;
    return db.update(
      tableRegistrations,
      reg.toMap(),
      where: 'id = ?',
      whereArgs: [reg.id],
    );
  }

  Future<int> deleteRegistration(int id) async {
    final db = await instance.database;
    return await db.update(
      tableRegistrations,
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // IMPORT/EXPORT HELPERS
  Future<int?> getTenantIdByDoc(String docNumber) async {
    final db = await instance.database;
    final result = await db.query(
      tableTenants,
      columns: ['id'],
      where: 'doc_number = ? AND is_deleted = 0',
      whereArgs: [docNumber],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first['id'] as int;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllRegistrationsForExport() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT 
        r.room_number, 
        r.check_in_date, 
        t.id as tenant_id,
        t.first_name,
        t.last_name,
        t.doc_type,
        t.doc_number 
      FROM $tableRegistrations r
      INNER JOIN $tableTenants t ON r.tenant_id = t.id
      WHERE r.is_deleted = 0 AND t.is_deleted = 0
    ''');
  }
}
