import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'local_db.dart';

/// Thrown when a `.alasif` backup file fails validation, with a message
/// safe to show directly in the UI.
class BackupValidationException implements Exception {
  final String message;
  BackupValidationException(this.message);
  @override
  String toString() => message;
}

/// Summary of a validated backup, shown in the restore confirmation dialog.
class BackupInfo {
  final File file;
  final String createdAt;
  final int schemaVersion;
  final Map<String, int> tables;
  final int pendingSync;

  const BackupInfo({
    required this.file,
    required this.createdAt,
    required this.schemaVersion,
    required this.tables,
    required this.pendingSync,
  });

  int get studentCount => tables['students'] ?? 0;
  int get receiptCount => tables['fee_receipts'] ?? 0;
}

/// Automatic + manual backup of the whole local database.
///
/// A backup is a single `.alasif` file: a ZIP containing `backup.db`
/// (a byte copy of the SQLite file) and `metadata.json`
/// (format/schema version, SHA-256 checksum, creation time, row counts).
///
/// Auto-backup policy:
/// * once a day (checked whenever the app records a change / starts),
/// * after every 50 local changes,
/// * only the newest 7 backup files are kept.
///
/// Backups are written to `Documents/AlAsifBackups/` when that shared
/// folder is writable, otherwise to the app's external files directory
/// (`Android/data/com.alasif.schoolms/files/AlAsifBackups`) — always
/// reachable through the phone's file manager.
class BackupService extends ChangeNotifier {
  BackupService._();
  static final BackupService instance = BackupService._();

  final _db = LocalDb.instance;

  static const _formatVersion = 1;
  static const _keepCount = 7;
  static const _changeThreshold = 50;

  /// Tables whose row counts are recorded in backup metadata.
  static const _countedTables = [
    'students',
    'staff',
    'student_attendance',
    'staff_attendance',
    'fee_challans',
    'fee_receipts',
    'expenses',
    'salaries',
    'marks',
    'notices',
    'complaints',
    'holidays',
    'exam_terms',
  ];

  bool _running = false;
  bool get isRunning => _running;

  String? _lastBackupLabel;
  String? get lastBackupLabel => _lastBackupLabel;

  int _backupCount = 0;
  int get backupCount => _backupCount;

  String? _backupDirPath;
  String? get backupDirPath => _backupDirPath;

  Future<void> init() async {
    await refreshStatus();
    await checkDailyBackup();
  }

  /// Resolve (and create) the backup directory, remembering the choice.
  Future<Directory> backupDir() async {
    if (_backupDirPath != null) {
      final d = Directory(_backupDirPath!);
      if (await d.exists()) return d;
    }
    final saved = await _db.getMeta('backup_dir');
    if (saved != null) {
      final d = Directory(saved);
      try {
        await d.create(recursive: true);
        _backupDirPath = saved;
        return d;
      } catch (_) {}
    }
    final candidates = <String>[];
    if (Platform.isAndroid) {
      // Shared, user-visible location (works without special permissions on
      // most devices; falls through to the app folder when not writable).
      candidates.add('/storage/emulated/0/Documents/AlAsifBackups');
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        candidates.add(p.join(ext.path, 'AlAsifBackups'));
      }
    }
    final appDoc = await getApplicationDocumentsDirectory();
    candidates.add(p.join(appDoc.path, 'AlAsifBackups'));
    for (final c in candidates) {
      try {
        final d = await Directory(c).create(recursive: true);
        // prove writability
        final probe = File(p.join(d.path, '.writetest'));
        await probe.writeAsString('ok');
        await probe.delete();
        _backupDirPath = d.path;
        await _db.setMeta('backup_dir', d.path);
        return d;
      } catch (_) {}
    }
    throw Exception('Could not create a backup folder on this device.');
  }

  Future<List<File>> listBackups() async {
    try {
      final dir = await backupDir();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.alasif'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      return files;
    } catch (_) {
      return [];
    }
  }

  Future<void> refreshStatus() async {
    try {
      final files = await listBackups();
      _backupCount = files.length;
      _lastBackupLabel = await _db.getMeta('last_backup_at');
    } catch (_) {}
    notifyListeners();
  }

  // ------------------------------------------------------------ auto triggers

  /// Called after every local write (via SyncService.notifyDirty).
  Future<void> recordChange() async {
    try {
      final cur =
          int.tryParse(await _db.getMeta('changes_since_backup') ?? '0') ?? 0;
      final nxt = cur + 1;
      await _db.setMeta('changes_since_backup', nxt.toString());
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final lastDay = await _db.getMeta('last_backup_date');
      if (lastDay != today) {
        await backupNow();
        return;
      }
      if (nxt >= _changeThreshold) {
        await backupNow();
      }
    } catch (_) {
      // backups must never break normal app use
    }
  }

  /// Run once at startup: back up if none was made today.
  Future<void> checkDailyBackup() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final lastDay = await _db.getMeta('last_backup_date');
      if (lastDay != today) await backupNow();
    } catch (_) {}
  }

  // ------------------------------------------------------------ backup

  /// Create a backup now. Returns the backup file path.
  Future<String> backupNow() async {
    if (_running) throw Exception('A backup is already in progress.');
    _running = true;
    notifyListeners();
    try {
      final dir = await backupDir();
      // Close the DB for a stable, complete file snapshot, then reopen.
      await _db.close();
      List<int> bytes;
      try {
        bytes = await File(await _db.dbPath()).readAsBytes();
      } finally {
        await _db.db;
      }
      final digest = sha256.convert(bytes).toString();
      final counts = <String, int>{};
      for (final t in _countedTables) {
        try {
          counts[t] = await _db.count(t);
        } catch (_) {
          counts[t] = 0;
        }
      }
      final now = DateTime.now();
      final meta = {
        'format': 'alasif-backup',
        'format_version': _formatVersion,
        'schema_version': LocalDb.schemaVersion,
        'app': 'com.alasif.schoolms',
        'created_at': now.toIso8601String(),
        'db_sha256': digest,
        'db_bytes': bytes.length,
        'tables': counts,
        'pending_sync': await _db.pendingCount(),
      };
      final metaBytes = utf8.encode(jsonEncode(meta));
      final archive = Archive()
        ..addFile(ArchiveFile('backup.db', bytes.length, bytes))
        ..addFile(ArchiveFile('metadata.json', metaBytes.length, metaBytes));
      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) throw Exception('Could not pack the backup.');
      final stamp =
          '${now.year}${_two(now.month)}${_two(now.day)}-${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
      final file =
          File(p.join(dir.path, 'alasif-backup-$stamp.alasif'));
      await file.writeAsBytes(zipBytes);

      await _prune(dir);

      final today = now.toIso8601String().substring(0, 10);
      await _db.setMeta('last_backup_date', today);
      await _db.setMeta('last_backup_at', now.toIso8601String());
      await _db.setMeta('changes_since_backup', '0');
      await refreshStatus();
      return file.path;
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  Future<void> _prune(Directory dir) async {
    final files = await listBackups();
    for (final f in files.skip(_keepCount)) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  // ------------------------------------------------------------ restore

  /// Let the user pick a `.alasif` file and validate it.
  /// Returns null when the user cancels.
  Future<BackupInfo?> pickAndValidate() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['alasif'],
      withData: false,
    );
    if (result == null || result.files.single.path == null) return null;
    return validateBackup(File(result.files.single.path!));
  }

  /// Validate a backup file: extension, zip layout, schema version, checksum.
  Future<BackupInfo> validateBackup(File file) async {
    if (!file.path.toLowerCase().endsWith('.alasif')) {
      throw BackupValidationException(
          'Not a backup file: the file must end with .alasif');
    }
    late Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    } catch (_) {
      throw BackupValidationException(
          'This file is not a valid backup (cannot unpack it).');
    }
    ArchiveFile? dbFile;
    ArchiveFile? metaFile;
    for (final f in archive.files) {
      if (!f.isFile) continue;
      if (f.name == 'backup.db') dbFile = f;
      if (f.name == 'metadata.json') metaFile = f;
    }
    if (dbFile == null || metaFile == null) {
      throw BackupValidationException(
          'This file is not a valid backup (missing database or metadata).');
    }
    late Map<String, dynamic> meta;
    try {
      meta = (jsonDecode(utf8.decode(metaFile.content as List<int>)) as Map)
          .cast<String, dynamic>();
    } catch (_) {
      throw BackupValidationException(
          'This file is not a valid backup (broken metadata).');
    }
    if (meta['format'] != 'alasif-backup') {
      throw BackupValidationException(
          'This file was not created by the Al-Asif app.');
    }
    final schemaVersion = (meta['schema_version'] as num?)?.toInt() ?? -1;
    if (schemaVersion != LocalDb.schemaVersion) {
      throw BackupValidationException(
          'Backup schema v$schemaVersion does not match this app '
          '(v${LocalDb.schemaVersion}). It cannot be restored.');
    }
    final dbBytes = dbFile.content as List<int>;
    final digest = sha256.convert(dbBytes).toString();
    if (digest != meta['db_sha256']?.toString()) {
      throw BackupValidationException(
          'Backup is corrupted (checksum mismatch). It cannot be restored.');
    }
    final tables = <String, int>{};
    for (final e in ((meta['tables'] as Map?) ?? const {}).entries) {
      tables[e.key.toString()] = (e.value as num?)?.toInt() ?? 0;
    }
    return BackupInfo(
      file: file,
      createdAt: meta['created_at']?.toString() ?? '',
      schemaVersion: schemaVersion,
      tables: tables,
      pendingSync: (meta['pending_sync'] as num?)?.toInt() ?? 0,
    );
  }

  /// Replace the local database with a validated backup.
  /// The caller must have shown the confirmation dialog first.
  Future<void> restore(BackupInfo info) async {
    if (_running) throw Exception('A backup is already in progress.');
    _running = true;
    notifyListeners();
    try {
      final archive =
          ZipDecoder().decodeBytes(await info.file.readAsBytes());
      ArchiveFile? dbFile;
      for (final f in archive.files) {
        if (f.isFile && f.name == 'backup.db') {
          dbFile = f;
          break;
        }
      }
      if (dbFile == null) {
        throw BackupValidationException(
            'This file is not a valid backup (missing database).');
      }
      final dbBytes = dbFile.content as List<int>;
      // Re-validate checksum at restore time for safety.
      await validateBackup(info.file);
      await _db.close();
      try {
        final path = await _db.dbPath();
        await File(path).writeAsBytes(dbBytes, flush: true);
        // Remove any stale journal/WAL sidecars from the previous DB.
        for (final suffix in ['-journal', '-wal', '-shm']) {
          try {
            await File('$path$suffix').delete();
          } catch (_) {}
        }
      } finally {
        await _db.db; // reopen (runs migrations/seeds if needed)
      }
      final now = DateTime.now();
      await _db.setMeta('last_backup_date',
          now.toIso8601String().substring(0, 10));
      await _db.setMeta('changes_since_backup', '0');
      await refreshStatus();
    } finally {
      _running = false;
      notifyListeners();
    }
  }
}
