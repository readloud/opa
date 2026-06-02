import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'opa_app.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabel harvests
    await db.execute('''
      CREATE TABLE harvests(
        id TEXT PRIMARY KEY,
        block_id TEXT NOT NULL,
        block_name TEXT NOT NULL,
        tonase REAL NOT NULL,
        harvest_date TEXT NOT NULL,
        photo_url TEXT,
        created_by TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        sync_error TEXT
      )
    ''');

    // Tabel inspections
    await db.execute('''
      CREATE TABLE inspections(
        id TEXT PRIMARY KEY,
        block_id TEXT NOT NULL,
        tree_id TEXT,
        condition TEXT NOT NULL,
        notes TEXT,
        photo_url TEXT,
        latitude REAL,
        longitude REAL,
        created_by TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        sync_error TEXT
      )
    ''');

    // Tabel sync_queue
    await db.execute('''
      CREATE TABLE sync_queue(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        endpoint TEXT NOT NULL,
        method TEXT NOT NULL,
        payload TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL
      )
    ''');
  }

  // Generic insert
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  // Generic query
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? isSynced,
    int? limit,
  }) async {
    final db = await database;
    String sql = 'SELECT * FROM $table';
    List<Object?> args = [];

    if (isSynced != null) {
      sql += ' WHERE is_synced = ?';
      args.add(isSynced ? 1 : 0);
    }

    if (limit != null) {
      sql += ' LIMIT ?';
      args.add(limit);
    }

    return await db.rawQuery(sql, args);
  }

  // Update sync status
  Future<void> markAsSynced(String table, String id) async {
    final db = await database;
    await db.update(
      table,
      {'is_synced': 1, 'sync_error': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}