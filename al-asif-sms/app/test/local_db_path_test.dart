import 'package:alasif_sms/services/local_db.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the v1.3.4 installed-app startup crash: sqflite_common_ffi's
/// default getDatabasesPath() is relative to the current working directory
/// (`.dart_tool/sqflite_common_ffi/databases`), which is not writable under
/// Program Files, so the installed app failed with SQLITE_CANTOPEN (14).
/// The databases directory must come from the per-user application support
/// folder instead.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('databases dir uses the app support folder, never the working directory',
      () async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationSupportDirectory') {
        return '/tmp/fake-app-support';
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    LocalDb.testDatabasesDir = null;
    final dir = await LocalDb.instance.databasesDir;
    expect(dir, contains('fake-app-support'));
    expect(dir, isNot(contains('.dart_tool')));
  });
}
