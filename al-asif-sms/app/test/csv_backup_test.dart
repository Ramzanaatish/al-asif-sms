import 'dart:convert';
import 'dart:io';

import 'package:alasif_sms/services/csv_backup_service.dart';
import 'package:alasif_sms/services/db_factory.dart';
import 'package:alasif_sms/services/local_db.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'temp_dir_helper.dart';
import 'package:sqflite/sqflite.dart';

/// Guards the CSV backup round-trip: export -> wipe the database -> import
/// must bring back every row byte-for-byte, including commas, quotes,
/// newlines and Urdu text inside values.
void main() {
  test('CSV export then import restores every row', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tmp = await Directory.systemTemp.createTemp('alasif_csv_');
    try {
      initDatabaseFactory();
      LocalDb.testDatabasesDir = tmp.path;
      final db = LocalDb.instance;

      final first = await db.db;
      final now = DateTime.now().toIso8601String();
      await first.insert('students', {
        'server_id': null,
        'admission_no': 'CSV-001',
        'roll_number': 1,
        'name': 'Ali, "Test" urdu\nnew line',
        'class_id': 1,
        'section_id': null,
        'session_id': null,
        'status': 'active',
        'data': jsonEncode({'id': 0, 'name': 'Ali'}),
        'dirty': 1,
        'deleted': 0,
        'provisional': 0,
        'updated_at': now,
      });

      final zipPath = '${tmp.path}/backup.zip';
      final saved =
          await CsvBackupService.instance.exportCsvBackup(savePath: zipPath);
      expect(saved, zipPath);
      expect(File(zipPath).existsSync(), isTrue);

      // Wipe: close, delete the database file, reopen fresh.
      await db.close();
      await File(await db.dbPath()).delete();
      final fresh = await db.db;
      final before = Sqflite.firstIntValue(await fresh
              .rawQuery('SELECT COUNT(*) FROM students')) ??
          -1;
      expect(before, 0);

      final summary =
          await CsvBackupService.instance.importCsvBackupFile(zipPath);
      expect(summary.tableCount, greaterThan(0));
      expect(summary.rowCount, greaterThan(0));

      final rows = await fresh.query('students');
      expect(rows, hasLength(1));
      expect(rows.first['admission_no'], 'CSV-001');
      expect(rows.first['name'], 'Ali, "Test" urdu\nnew line');
      expect(rows.first['roll_number'], 1);
      expect(rows.first['dirty'], 1);
      expect(rows.first['data'], jsonEncode({'id': 0, 'name': 'Ali'}));

      await db.close();
    } finally {
      LocalDb.testDatabasesDir = null;
      await deleteTempDirQuietly(tmp);
    }
  });

  test('import rejects a zip whose columns do not match', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tmp = await Directory.systemTemp.createTemp('alasif_csv_bad_');
    try {
      initDatabaseFactory();
      LocalDb.testDatabasesDir = tmp.path;
      await LocalDb.instance.db;

      final archive = Archive();
      final bad = utf8.encode('wrongcol,another\n1,2\n');
      archive.addFile(ArchiveFile('students.csv', bad.length, bad));
      final zipPath = '${tmp.path}/bad.zip';
      await File(zipPath).writeAsBytes(ZipEncoder().encode(archive)!);

      expect(
        () => CsvBackupService.instance.importCsvBackupFile(zipPath),
        throwsA(isA<CsvBackupException>()),
      );

      await LocalDb.instance.close();
    } finally {
      LocalDb.testDatabasesDir = null;
      await deleteTempDirQuietly(tmp);
    }
  });
}
