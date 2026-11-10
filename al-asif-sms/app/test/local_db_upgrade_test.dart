import 'dart:convert';
import 'dart:io';

import 'package:alasif_sms/services/db_factory.dart';
import 'package:alasif_sms/services/local_db.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'temp_dir_helper.dart';

/// Guards the update promise: closing the app and reopening it (the way an
/// app update does) must keep every row, and the first-run seed must not
/// duplicate itself.
///
/// Runs against a temp folder through the FFI implementation, so it works
/// on the desktop host (Windows runner / Linux) exactly where the Windows
/// app will run. It does not touch the real database folder.
void main() {
  test('reopening the database after an app update keeps every row',
      () async {
    // Plain unit tests have no Flutter binding, so rootBundle cannot load
    // assets/seed.json. Initialise the test binding so the first-run seed
    // (which reads the bundled seed.json) works exactly like in the app.
    TestWidgetsFlutterBinding.ensureInitialized();

    final tmp = await Directory.systemTemp.createTemp('alasif_upgrade_');
    try {
      initDatabaseFactory();
      LocalDb.testDatabasesDir = tmp.path;

      final db = LocalDb.instance;

      // First open: creates the schema and runs the first-run seed.
      final first = await db.db;
      final classes = Sqflite.firstIntValue(await first
              .rawQuery('SELECT COUNT(*) FROM classes')) ??
          0;
      expect(classes, greaterThan(0));

      // A row written by the "old" version.
      final now = DateTime.now().toIso8601String();
      final id = await first.insert('students', {
        'server_id': null,
        'admission_no': 'TEST-001',
        'roll_number': 1,
        'name': 'Test Student',
        'class_id': 1,
        'section_id': null,
        'session_id': null,
        'status': 'active',
        'data': jsonEncode({'id': 0, 'name': 'Test Student'}),
        'dirty': 1,
        'deleted': 0,
        'provisional': 0,
        'updated_at': now,
      });
      expect(id, greaterThan(0));

      // Simulate the app update: close and reopen.
      await db.close();
      final second = await db.db;

      final rows = await second.query(
        'students',
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(rows, hasLength(1));
      expect(rows.first['name'], 'Test Student');
      expect(rows.first['admission_no'], 'TEST-001');
      expect(rows.first['dirty'], 1);

      // The seed did not run again on reopen.
      final classesAfter = Sqflite.firstIntValue(await second
              .rawQuery('SELECT COUNT(*) FROM classes')) ??
          0;
      expect(classesAfter, classes);

      await db.close();
    } finally {
      LocalDb.testDatabasesDir = null;
      await deleteTempDirQuietly(tmp);
    }
  });
}
