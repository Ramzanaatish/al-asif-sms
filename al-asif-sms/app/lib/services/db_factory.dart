import 'dart:io' show Platform;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Picks the SQLite implementation for the platform the app runs on.
///
/// Android and iOS use the platform `sqflite` implementation. Desktop
/// (Windows, macOS, Linux) has no platform implementation, so the identical
/// `sqflite` API runs on FFI instead. Every repository and [LocalDb] call
/// stays exactly the same on both; only this factory differs.
///
/// The database file lives in the per-user application support folder
/// (see LocalDb._databasesDir), never inside the install folder, so
/// reinstalling or updating the app never touches it. Call
/// [initDatabaseFactory] once at startup, before any database use.
bool _ffiReady = false;

void initDatabaseFactory() {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
    return;
  }
  if (_ffiReady) return;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  _ffiReady = true;
}
