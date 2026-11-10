import 'dart:async';
import 'dart:io';

/// Delete a temp directory created by a test.
///
/// On Windows the OS can still hold a just-closed SQLite file for a moment,
/// so the delete can fail with errno 32 even though the test itself passed.
/// Retry briefly, then give up quietly: temp cleanup is housekeeping, and a
/// leftover temp dir must never fail a test.
Future<void> deleteTempDirQuietly(Directory dir) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      return;
    } catch (_) {
      if (attempt == 4) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}
