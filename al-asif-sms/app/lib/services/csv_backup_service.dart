import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

import 'local_db.dart';

/// CSV backup: the whole database as one CSV file per table, inside a zip.
///
/// Export ("download"): Settings -> Export CSV backup. The zip holds
/// `<table>.csv` files (students.csv, fee_challans.csv, ...). Unzip it and
/// every file opens in Excel — Urdu text is written with a UTF-8 BOM so
/// Excel shows it correctly.
///
/// Import ("upload"): Settings -> Import CSV backup. Pick a zip made by an
/// export (or the same files edited by hand in Excel). The headers are
/// checked against the real columns first, and only then does every table
/// in the file REPLACE that table's rows. Import runs in transactions; a
/// broken file changes nothing.
///
/// The .alasif backup stays the main backup (it also carries the checksum
/// and schema version). CSV is the human-readable one: open it, check it,
/// fix a name, import it back.
class CsvBackupService {
  CsvBackupService._();
  static final CsvBackupService instance = CsvBackupService._();

  LocalDb get _db => LocalDb.instance;

  String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}-'
        '${two(n.hour)}${two(n.minute)}${two(n.second)}';
  }

  /// Export every table to CSV and pack the files into one zip.
  ///
  /// When [savePath] is given (tests), the zip is written there. Otherwise
  /// the user picks where to save it. Returns the saved file path, or null
  /// when the user cancels the save dialog.
  Future<String?> exportCsvBackup({String? savePath}) async {
    final archive = Archive();
    for (final table in LocalDb.csvBackupTables) {
      final columns = await _db.tableColumns(table);
      final rows = await _db.exportTable(table);
      final csvRows = <List<Object?>>[
        columns,
        for (final row in rows) [for (final c in columns) row[c]],
      ];
      final text = const ListToCsvConverter().convert(csvRows);
      // UTF-8 BOM: without it Excel on Windows shows Urdu as garbage.
      final bytes = utf8.encode('\uFEFF$text');
      archive.addFile(ArchiveFile('$table.csv', bytes.length, bytes));
    }
    final zipBytes = ZipEncoder().encode(archive)!;
    final fileName = 'alasif-csv-backup-${_stamp()}.zip';
    if (savePath != null) {
      await File(savePath).writeAsBytes(zipBytes);
      return savePath;
    }
    return FilePicker.platform.saveFile(
      dialogTitle: 'Save CSV backup',
      fileName: fileName,
      bytes: Uint8List.fromList(zipBytes),
    );
  }

  /// Let the user pick a CSV backup zip. Returns its path, or null when
  /// the user cancels.
  Future<String?> pickCsvBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Pick a CSV backup zip',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    return result?.files.single.path;
  }

  /// Read a backup zip and check it, without changing the database.
  /// Returns one entry per known table found, with its row count.
  /// Throws [CsvBackupException] with a plain message when the file is
  /// not a CSV backup or a table does not match.
  Future<CsvBackupSummary> validateCsvBackup(String path) async {
    final parsed = await _readBackup(path);
    if (parsed.isEmpty) {
      throw const CsvBackupException(
          'No known table found. This is not an Al-Asif CSV backup.');
    }
    return CsvBackupSummary({
      for (final e in parsed.entries) e.key: e.value.length - 1,
    });
  }

  /// Import a backup zip that [validateCsvBackup] already checked.
  /// Every table in the file replaces that table's rows.
  /// Returns a short summary for the confirmation message.
  Future<CsvBackupSummary> importCsvBackupFile(String path) async {
    final parsed = await _readBackup(path);
    if (parsed.isEmpty) {
      throw const CsvBackupException(
          'No known table found. This is not an Al-Asif CSV backup.');
    }
    final counts = <String, int>{};
    for (final entry in parsed.entries) {
      final table = entry.key;
      final rows = entry.value;
      final columns = await _db.tableColumns(table);
      final types = await _db.tableColumnTypes(table);
      _checkHeader(table, columns, rows.first);
      final dataRows = rows
          .skip(1)
          .map((r) => _toRow(columns, types, r))
          .toList();
      await _db.importTable(table, columns, dataRows);
      counts[table] = dataRows.length;
    }
    return CsvBackupSummary(counts);
  }

  /// Read the zip into table -> parsed CSV rows (first row is the header).
  /// Unknown files are ignored; known tables are header-checked here so
  /// both validate and import see the same checks.
  Future<Map<String, List<List<dynamic>>>> _readBackup(String path) async {
    final bytes = await File(path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final known = LocalDb.csvBackupTables.toSet();
    final parsed = <String, List<List<dynamic>>>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = file.name.split('/').last;
      if (!name.toLowerCase().endsWith('.csv')) continue;
      final table = name.substring(0, name.length - 4);
      if (!known.contains(table)) continue;
      final text = utf8.decode(file.content as List<int>);
      final rows =
          const CsvToListConverter().convert(text.replaceFirst('\uFEFF', ''));
      if (rows.isEmpty) {
        throw CsvBackupException('Table $table is empty.');
      }
      final columns = await _db.tableColumns(table);
      _checkHeader(table, columns, rows.first);
      parsed[table] = rows;
    }
    return parsed;
  }

  void _checkHeader(
      String table, List<String> columns, List<dynamic> header) {
    final matches = header.length == columns.length &&
        List.generate(
          columns.length,
          (i) => header[i].toString() == columns[i],
        ).every((e) => e);
    if (!matches) {
      throw CsvBackupException(
          'Table $table does not match. The columns are different — '
          'maybe this file is from another app or an old version.');
    }
  }

  Map<String, Object?> _toRow(List<String> columns, Map<String, String> types,
      List<dynamic> values) {
    final row = <String, Object?>{};
    for (var i = 0; i < columns.length; i++) {
      final value = i < values.length ? values[i] : null;
      row[columns[i]] = _convert(types[columns[i]] ?? '', value);
    }
    return row;
  }

  Object? _convert(String type, Object? value) {
    if (value == null) return null;
    final text = value.toString();
    if (text.isEmpty) return null;
    if (type.contains('INT')) return int.tryParse(text) ?? text;
    return text;
  }
}

/// What a CSV backup holds: one row count per table found in the file.
class CsvBackupSummary {
  final Map<String, int> tables;

  const CsvBackupSummary(this.tables);

  int get tableCount => tables.length;

  int get rowCount => tables.values.fold(0, (a, b) => a + b);

  @override
  String toString() => '$tableCount tables, $rowCount rows.';
}

class CsvBackupException implements Exception {
  final String message;
  const CsvBackupException(this.message);
  @override
  String toString() => message;
}
