import 'package:flutter/foundation.dart';

import '../models/attendance.dart';
import '../repositories/attendance_repository.dart';
import '../services/sync_service.dart';

/// Attendance is now fully offline-first: the repository writes to SQLite
/// immediately and the SyncService pushes when online, so there is no need
/// for a provider-level queue anymore. Method names are unchanged; the old
/// shared_preferences queue is drained once on first run after upgrade.
class AttendanceProvider extends ChangeNotifier {
  final _repo = AttendanceRepository();
  AttendanceRepository get repo => _repo;
  final _sync = SyncService.instance;

  MonthlyAttendanceReport? monthlyReport;
  bool loading = false;
  String? error;
  int pendingCount = 0;
  bool syncing = false;

  Future<void> _refreshPendingCount() async {
    pendingCount = _sync.pendingCount;
    notifyListeners();
  }

  Future<void> init() async {
    await _refreshPendingCount();
    await syncPending();
  }

  /// Saves attendance; returns {'saved': n}. Offline saves never fail —
  /// they queue in SyncService automatically.
  Future<Map<String, dynamic>> saveStudentAttendance(
      Map<String, dynamic> payload) async {
    final saved = await _repo.saveStudentAttendance(payload);
    await _refreshPendingCount();
    return {'saved': saved};
  }

  /// Retained for API compatibility: triggers a global sync and reports
  /// the queue state.
  Future<Map<String, int>> syncPending() async {
    if (syncing) return {'synced': 0, 'failed': pendingCount};
    syncing = true;
    notifyListeners();
    try {
      await _sync.syncNow();
    } finally {
      syncing = false;
      await _refreshPendingCount();
    }
    return {'synced': 0, 'failed': _sync.pendingCount};
  }

  Future<int> sendAbsentAlerts(String date) => _repo.sendAbsentAlerts(date);

  Future<List<Map<String, dynamic>>> fetchStudentRecords({
    String? date,
    int? classId,
    int? sectionId,
  }) =>
      _repo.studentRecords(date: date, classId: classId, sectionId: sectionId);

  Future<void> saveStaffAttendance(
      String date, List<Map<String, dynamic>> records) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _repo.saveStaffAttendance(date, records);
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadMonthly({int? month, int? year, int? classId}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      monthlyReport =
          await _repo.monthly(month: month, year: year, classId: classId);
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }
}
