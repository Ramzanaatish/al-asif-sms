import 'dart:convert';
import 'dart:io' show Directory, File, Platform;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'db_factory.dart';

/// Offline-first local database for the Al-Asif School Management app.
///
/// Every synced entity table has:
///   id          INTEGER PRIMARY KEY AUTOINCREMENT  (local id, permanent)
///   server_id   INTEGER NULL                       (backend PK, set on sync)
///   data        TEXT                               (full JSON in server shape)
///   dirty       INTEGER DEFAULT 0                  (1 = local changes not yet pushed)
///   deleted     INTEGER DEFAULT 0                  (soft delete, 1 = pending delete)
///   provisional INTEGER DEFAULT 0                  (1 = auto-number not yet confirmed)
///   updated_at  TEXT                               (ISO-8601)
/// plus a few filter columns per table for fast local queries.
///
/// All cross-table references inside the local DB use LOCAL ids. The sync
/// service translates local <-> server ids at the boundary (see
/// lib/services/SYNC_PROTOCOL.md).
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  static const _dbName = 'alasif_sms.db';
  static const _version = 1;

  /// Schema version, written into backup metadata and checked on restore.
  static int get schemaVersion => _version;

  /// Ordered schema migrations, keyed by the version they produce.
  ///
  /// When [_version] is raised, [openDatabase] runs [onUpgrade], which
  /// first copies the database file aside and then applies every step from
  /// the old version up to the new one, in order. A migration must only
  /// ADD things (tables, columns, indexes) or copy data into a new shape —
  /// it must never drop a table or delete rows, so an app update can never
  /// lose the school's data.
  ///
  /// To ship a schema change: add its statements under the new version
  /// number, raise [_version], and add a test in
  /// test/local_db_upgrade_test.dart that opens a database at the old
  /// version, inserts rows, reopens it, and checks the rows are still there.
  static const Map<int, List<String>> _migrations = {
    // Version 1 is the original schema (created by onCreate below).
    // Version 2 entries go here when the first schema change ships.
  };

  Database? _db;

  // Test-only override for the databases directory, so flutter test can
  // point the database at a temp folder instead of the app's data folder.
  // Never set in the app.
  static String? _testDatabasesDir;

  @visibleForTesting
  static set testDatabasesDir(String? dir) => _testDatabasesDir = dir;

  Future<String> _databasesDir() async {
    final testDir = _testDatabasesDir;
    if (testDir != null) return testDir;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // sqflite_common_ffi's default getDatabasesPath() is relative to the
      // current working directory (`.dart_tool/sqflite_common_ffi/databases`).
      // That is not writable under Program Files, so the installed Windows
      // app failed to open its database with SQLITE_CANTOPEN (14). Use the
      // per-user application support folder instead: stable across installs
      // and updates, and always writable.
      final support = await getApplicationSupportDirectory();
      return p.join(support.path, 'databases');
    }
    return getDatabasesPath();
  }

  /// Test-only: the resolved databases directory.
  @visibleForTesting
  Future<String> get databasesDir => _databasesDir();

  Future<Database>? _opening;

  Future<Database> get db async {
    final d = _db;
    if (d != null) return d;
    // Serialise concurrent first-callers so the DB is opened/seeded once.
    final f = _opening ??= _open();
    try {
      _db = await f;
    } finally {
      _opening = null;
    }
    return _db!;
  }

  /// Flush any WAL content into the main file so a plain file copy is complete.
  Future<void> checkpoint() async {
    final d = await db;
    try {
      await d.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {}
  }

  /// Absolute path of the database file.
  Future<String> dbPath() async {
    final dir = await _databasesDir();
    return p.join(dir, _dbName);
  }

  /// Close the database. The next [db] access reopens it lazily.
  /// Used by BackupService to get a stable file snapshot for backup/restore.
  Future<void> close() async {
    final d = _db;
    _db = null;
    await d?.close();
  }

  /// Names of every table included in a CSV backup: all entity tables plus
  /// the audit log. The sync queue (transient) and meta (device-specific
  /// keys like the backup folder) are deliberately left out.
  static List<String> get csvBackupTables => [..._tables.keys, 'audit_log'];

  /// All rows of one table, ordered by id, as column-name maps.
  /// Used by the CSV backup export.
  Future<List<Map<String, Object?>>> exportTable(String table) async {
    final d = await db;
    return d.query(table, orderBy: 'id');
  }

  /// Column names of one table, in table order, from PRAGMA table_info.
  Future<List<String>> tableColumns(String table) async {
    final d = await db;
    final info = await d.rawQuery('PRAGMA table_info($table)');
    return [for (final row in info) row['name'] as String];
  }

  /// Declared column types of one table (for example INTEGER or TEXT),
  /// keyed by column name. Used by the CSV backup import to restore
  /// numbers as numbers (a CSV file itself carries only text).
  Future<Map<String, String>> tableColumnTypes(String table) async {
    final d = await db;
    final info = await d.rawQuery('PRAGMA table_info($table)');
    return {
      for (final row in info)
        (row['name'] as String): ((row['type'] as String?) ?? '').toUpperCase(),
    };
  }

  /// Replace one table's rows with the given rows (import side of a CSV
  /// backup). Runs in a transaction: the old rows are deleted first, then
  /// every row is inserted with its original id, and the autoincrement
  /// counter is reset so the next new row continues after the highest id.
  /// The caller must have validated the table name and columns first.
  Future<void> importTable(
    String table,
    List<String> columns,
    List<Map<String, Object?>> rows,
  ) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete(table);
      for (final row in rows) {
        await txn.insert(table, row);
      }
      try {
        await txn.rawDelete(
            'DELETE FROM sqlite_sequence WHERE name = ?', [table]);
      } catch (_) {
        // sqlite_sequence only exists for AUTOINCREMENT tables; a missing
        // one just means the counter needs no reset.
      }
    });
  }

  // ---------------------------------------------------------------- schema

  /// Extra (filter) columns per entity table. Every table also gets the
  /// standard sync columns defined in [_syncCols].
  static const Map<String, String> _tables = {
    'students':
        'admission_no TEXT, roll_number INTEGER, name TEXT, class_id INTEGER, section_id INTEGER, session_id INTEGER, status TEXT',
    'staff':
        'name TEXT, staff_type TEXT, status TEXT',
    'staff_leaves':
        'staff_id INTEGER, status TEXT, from_date TEXT',
    'salaries':
        'staff_id INTEGER, month INTEGER, year INTEGER',
    'classes':
        'name TEXT, level_order INTEGER',
    'sections':
        'class_id INTEGER, name TEXT',
    'subjects':
        'class_id INTEGER, name TEXT',
    'syllabus':
        'class_id INTEGER, subject_id INTEGER, status TEXT',
    'timetable':
        'class_id INTEGER, section_id INTEGER, day_of_week INTEGER',
    'student_attendance':
        'date TEXT, student_id INTEGER, status TEXT',
    'staff_attendance':
        'date TEXT, staff_id INTEGER, status TEXT',
    'fee_heads':
        'name TEXT, class_id INTEGER',
    'fee_challans':
        'challan_no TEXT, student_id INTEGER, month INTEGER, year INTEGER, status TEXT',
    'fee_receipts':
        'receipt_no TEXT, challan_id INTEGER',
    'expense_categories':
        'name TEXT',
    'expenses':
        'category_id INTEGER, date TEXT',
    'holidays':
        'date TEXT, kind TEXT',
    'exam_terms':
        'name TEXT, term_type TEXT, session_id INTEGER',
    'date_sheets':
        'term_id INTEGER, class_id INTEGER, subject_id INTEGER, exam_date TEXT',
    'marks':
        'term_id INTEGER, class_id INTEGER, subject_id INTEGER, student_id INTEGER',
    'notices':
        'audience TEXT, created_at TEXT',
    'complaints':
        'status TEXT, parent_user_id INTEGER',
  };

  static const _syncCols =
      'server_id INTEGER, data TEXT NOT NULL DEFAULT \'{}\', dirty INTEGER NOT NULL DEFAULT 0, '
      'deleted INTEGER NOT NULL DEFAULT 0, provisional INTEGER NOT NULL DEFAULT 0, '
      'updated_at TEXT NOT NULL';

  Future<Database> _open() async {
    initDatabaseFactory();
    final dir = await _databasesDir();
    await Directory(dir).create(recursive: true);
    final path = p.join(dir, _dbName);
    final database = await openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        for (final e in _tables.entries) {
          await db.execute(
              'CREATE TABLE ${e.key}(id INTEGER PRIMARY KEY AUTOINCREMENT, ${e.value}, $_syncCols)');
        }
        await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_student_attendance_unique ON student_attendance(date, student_id)');
        await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_staff_attendance_unique ON staff_attendance(date, staff_id)');
        await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_marks_unique ON marks(term_id, subject_id, student_id)');
        await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_students_admission ON students(admission_no)');
        await db.execute(
            'CREATE TABLE sync_queue(id INTEGER PRIMARY KEY AUTOINCREMENT, entity TEXT NOT NULL, op TEXT NOT NULL, local_id INTEGER, payload_json TEXT NOT NULL DEFAULT \'{}\', attempts INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)');
        await db.execute(
            'CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT)');
        await db.execute(
            'CREATE TABLE audit_log(id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT, action TEXT NOT NULL, entity TEXT, entity_id INTEGER, details TEXT, created_at TEXT NOT NULL)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _backupBeforeMigration(db, oldVersion);
        for (var v = oldVersion + 1; v <= newVersion; v++) {
          final steps = _migrations[v];
          if (steps == null) continue;
          for (final sql in steps) {
            await db.execute(sql);
          }
        }
      },
    );
    await _maybeSeed(database);
    await _migrateLegacyQueue(database);
    return database;
  }

  /// Copy the database file aside before a schema migration runs, so a
  /// failed or interrupted upgrade can always be recovered by hand. The
  /// copy sits next to the live file and is never deleted by the app.
  Future<void> _backupBeforeMigration(Database db, int oldVersion) async {
    try {
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      final file = File(db.path);
      if (!await file.exists()) return;
      final backup = File('${db.path}.bak-v$oldVersion');
      if (await backup.exists()) return;
      await file.copy(backup.path);
    } catch (_) {
      // A backup copy must never block the migration itself.
    }
  }

  // ------------------------------------------------------------- seeding

  /// First-run seed: if the DB has no classes and we cannot reach the server,
  /// load the bundled seed.json so the app is usable fully offline.
  Future<void> _maybeSeed(Database database) async {
    final n = Sqflite.firstIntValue(
            await database.rawQuery('SELECT COUNT(*) FROM classes')) ??
        0;
    if (n > 0) return;
    try {
      final raw = await rootBundle.loadString('assets/seed.json');
      final seed = jsonDecode(raw) as Map<String, dynamic>;
      final now = DateTime.now().toIso8601String();
      final batch = database.batch();
      for (final c in (seed['classes'] as List? ?? [])) {
        final m = (c as Map).cast<String, dynamic>();
        batch.insert('classes', {
          'server_id': null,
          'name': m['name'],
          'level_order': m['level_order'],
          'data': jsonEncode({
            'id': 0,
            'name': m['name'],
            'level_order': m['level_order'],
            'student_count': m['student_count'],
            'sections': [],
          }),
          'dirty': 0,
          'deleted': 0,
          'provisional': 0,
          'updated_at': now,
        });
      }
      for (final h in (seed['fee_heads'] as List? ?? [])) {
        final m = (h as Map).cast<String, dynamic>();
        batch.insert('fee_heads', {
          'server_id': null,
          'name': m['name'],
          'class_id': null,
          'data': jsonEncode({
            'id': 0,
            'name': m['name'],
            'amount': m['amount'],
            'frequency': m['frequency'],
            'class_id': null,
          }),
          'dirty': 0,
          'deleted': 0,
          'provisional': 0,
          'updated_at': now,
        });
      }
      for (final c in (seed['expense_categories'] as List? ?? [])) {
        batch.insert('expense_categories', {
          'server_id': null,
          'name': c.toString(),
          'data': jsonEncode({'id': 0, 'name': c.toString()}),
          'dirty': 0,
          'deleted': 0,
          'provisional': 0,
          'updated_at': now,
        });
      }
      await batch.commit(noResult: true);
      await database.insert('meta', {
        'key': 'seeded_offline',
        'value': DateTime.now().toIso8601String()
      });
    } catch (_) {
      // Asset missing or unreadable: leave DB empty; sync will fill it.
    }
  }

  /// Best-effort migration of the legacy shared_preferences attendance queue
  /// (pre-offline-first versions) into the new sync_queue. Legacy payloads
  /// carry SERVER student ids; they are flagged so the sync service pushes
  /// them without local->server id translation.
  Future<void> _migrateLegacyQueue(Database database) async {
    // Implemented via SyncService.migrateLegacyQueue which needs
    // SharedPreferences; called from there after providers exist.
  }

  // ------------------------------------------------------------- generic CRUD

  String _now() => DateTime.now().toIso8601String();

  Future<int> insert(String table, Map<String, Object?> values) async {
    final d = await db;
    final v = Map<String, Object?>.from(values)
      ..putIfAbsent('updated_at', _now)
      ..putIfAbsent('data', () => '{}');
    return d.insert(table, v,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateById(String table, int id, Map<String, Object?> values) {
    return _updateWhere(table, values, 'id = ?', [id]);
  }

  Future<int> updateByServerId(
      String table, int serverId, Map<String, Object?> values) {
    return _updateWhere(table, values, 'server_id = ?', [serverId]);
  }

  Future<int> _updateWhere(String table, Map<String, Object?> values,
      String where, List<Object?> args) async {
    final d = await db;
    final v = Map<String, Object?>.from(values)..['updated_at'] = _now();
    return d.update(table, v, where: where, whereArgs: args);
  }

  Future<List<Map<String, Object?>>> query(String table,
      {String? where,
      List<Object?>? whereArgs,
      String? orderBy,
      int? limit}) async {
    final d = await db;
    return d.query(table,
        where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit);
  }

  Future<Map<String, Object?>?> getById(String table, int id) async {
    final rows = await query(table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> getByServerId(String table, int serverId) async {
    final rows = await query(table,
        where: 'server_id = ?', whereArgs: [serverId], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Soft delete: marks deleted=1 + dirty=1 and enqueues a delete op.
  Future<void> softDelete(String table, String entity, int localId) async {
    await updateById(table, localId, {'deleted': 1, 'dirty': 1});
    await enqueue(entity, 'delete', localId, {});
  }

  Future<int> count(String table,
      {String? where, List<Object?>? whereArgs}) async {
    final d = await db;
    final w = where == null ? '' : ' WHERE $where';
    return Sqflite.firstIntValue(await d
            .rawQuery('SELECT COUNT(*) FROM $table$w', whereArgs)) ??
        0;
  }

  // ------------------------------------------------------------- sync queue

  Future<void> enqueue(String entity, String op, int? localId,
      Map<String, dynamic> payload) async {
    final d = await db;
    await d.insert('sync_queue', {
      'entity': entity,
      'op': op,
      'local_id': localId,
      'payload_json': jsonEncode(payload),
      'attempts': 0,
      'created_at': _now(),
    });
    await audit('system', 'queue_$op', entity, localId, '');
  }

  Future<List<Map<String, Object?>>> pendingOps() async {
    return query('sync_queue', orderBy: 'id ASC');
  }

  Future<int> pendingCount() async => count('sync_queue');

  Future<void> dequeue(int id) async {
    final d = await db;
    await d.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> bumpAttempts(int id) async {
    final d = await db;
    await d.rawUpdate(
        'UPDATE sync_queue SET attempts = attempts + 1 WHERE id = ?', [id]);
  }

  // ------------------------------------------------------------- meta (kv)

  Future<String?> getMeta(String key) async {
    final d = await db;
    final rows = await d.query('meta',
        columns: ['value'], where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setMeta(String key, String value) async {
    final d = await db;
    await d.insert('meta', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getMetaJson(String key) async {
    final v = await getMeta(key);
    if (v == null) return null;
    try {
      return (jsonDecode(v) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  Future<void> setMetaJson(String key, Map<String, dynamic> value) async {
    await setMeta(key, jsonEncode(value));
  }

  /// Monotonic local sequence, e.g. nextSeq('admission_no:2026') -> 7.
  Future<int> nextSeq(String name) async {
    final key = 'seq:$name';
    final cur = int.tryParse(await getMeta(key) ?? '0') ?? 0;
    final nxt = cur + 1;
    await setMeta(key, nxt.toString());
    return nxt;
  }

  /// Peek the next sequence value WITHOUT consuming it.
  Future<int> peekSeq(String name) async {
    final key = 'seq:$name';
    return (int.tryParse(await getMeta(key) ?? '0') ?? 0) + 1;
  }

  // ------------------------------------------------------------- audit

  Future<void> audit(String username, String action, String entity,
      int? entityId, String details) async {
    final d = await db;
    await d.insert('audit_log', {
      'username': username,
      'action': action,
      'entity': entity,
      'entity_id': entityId,
      'details': details,
      'created_at': _now(),
    });
  }

  Future<List<Map<String, Object?>>> auditList({int limit = 100}) async {
    return query('audit_log', orderBy: 'id DESC', limit: limit);
  }

  // ------------------------------------------------------------- helpers

  static Map<String, dynamic> dataOf(Map<String, Object?> row) {
    final raw = row['data'];
    if (raw is String && raw.isNotEmpty) {
      try {
        return (jsonDecode(raw) as Map).cast<String, dynamic>();
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  static int intOf(Object? v, [int fallback = 0]) =>
      (v as num?)?.toInt() ?? fallback;

  static double doubleOf(Object? v, [double fallback = 0]) =>
      (v as num?)?.toDouble() ?? fallback;

  static String strOf(Object? v, [String fallback = '']) =>
      v?.toString() ?? fallback;
}
