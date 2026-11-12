import 'dart:async';

import 'package:alasif_sms/services/sync_service.dart';

/// Runs before every test file in test/.
///
/// Disables SyncService's fire-and-forget background work (auto-backup
/// counting + background sync) for the whole test run. Those two unawaited
/// tasks race with each test's tearDown (close + delete the temp dir) and
/// re-open the shared LocalDb singleton at a stale temp directory, which
/// made the parity tests flaky (UNIQUE constraint on admission_no,
/// "database has already been closed", "unable to open database file").
/// Repository writes still enqueue their sync ops and refresh the pending
/// count; only the background firing is skipped. Never used by the app.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SyncService.testMode = true;
  await testMain();
}
