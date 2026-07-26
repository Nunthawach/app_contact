import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/contact_model.dart';

class LocalDatabaseService {
  static Database? _database;
  static final List<LocalContact> _webInMemoryContacts = [];

  static Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, 'enterprise_directory.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE local_global_contacts (
            id TEXT PRIMARY KEY,
            normalized_phone TEXT NOT NULL,
            display_name TEXT NOT NULL,
            sources_count INTEGER DEFAULT 1,
            updated_at INTEGER NOT NULL
          )
        ''');

        await db.execute('CREATE INDEX idx_local_phone ON local_global_contacts(normalized_phone)');
        await db.execute('CREATE INDEX idx_local_name ON local_global_contacts(display_name)');
      },
    );
  }

  /// Search Query with Mobile (SQLite) and Web (In-Memory) support
  static Future<List<LocalContact>> searchContacts(String query) async {
    if (kIsWeb) {
      if (query.trim().isEmpty) return _webInMemoryContacts;
      final q = query.toLowerCase();
      return _webInMemoryContacts.where((c) =>
        c.displayName.toLowerCase().contains(q) ||
        c.normalizedPhone.contains(q)
      ).toList();
    }

    final db = await database;
    if (db == null) return [];

    if (query.trim().isEmpty) {
      final results = await db.query(
        'local_global_contacts',
        orderBy: 'sources_count DESC, display_name ASC',
        limit: 50,
      );
      return results.map((m) => LocalContact.fromMap(m)).toList();
    }

    final cleanQuery = query.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final results = await db.rawQuery('''
      SELECT * FROM local_global_contacts
      WHERE normalized_phone LIKE ? 
         OR display_name LIKE ?
      ORDER BY sources_count DESC, display_name ASC
      LIMIT 50
    ''', ['%$cleanQuery%', '%$query%']);

    return results.map((m) => LocalContact.fromMap(m)).toList();
  }

  /// Batch Save Contacts
  static Future<void> batchSaveContacts(List<LocalContact> contacts) async {
    if (kIsWeb) {
      for (var c in contacts) {
        _webInMemoryContacts.removeWhere((item) => item.id == c.id);
        _webInMemoryContacts.add(c);
      }
      return;
    }

    final db = await database;
    if (db == null) return;
    Batch batch = db.batch();
    for (var contact in contacts) {
      batch.insert(
        'local_global_contacts',
        contact.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Get Last Sync Timestamp
  static Future<int> getLastSyncTimestamp() async {
    if (kIsWeb) return 0;
    final db = await database;
    if (db == null) return 0;
    final res = await db.rawQuery('SELECT MAX(updated_at) as max_ts FROM local_global_contacts');
    if (res.isNotEmpty && res.first['max_ts'] != null) {
      return res.first['max_ts'] as int;
    }
    return 0;
  }
}
