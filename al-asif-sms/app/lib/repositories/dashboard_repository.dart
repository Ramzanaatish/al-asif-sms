import '../models/dashboard.dart';
import '../services/local_db.dart';

/// Offline-first dashboard repository: principal dashboard computed locally,
/// mirroring backend/dashboard.py exactly.
class DashboardRepository {
  final _db = LocalDb.instance;

  Future<DashboardData> principal() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final now = DateTime.now();

    final totalStudents = await _db.count('students',
        where: "status = 'active' AND deleted = 0");
    final totalStaff = await _db.count('staff',
        where: "status = 'active' AND deleted = 0");

    final challans = await _db.query('fee_challans',
        where: 'month = ? AND year = ? AND deleted = 0',
        whereArgs: [now.month, now.year]);
    var feeCollected = 0.0;
    var defaulters = 0;
    for (final c in challans) {
      final d = LocalDb.dataOf(c);
      feeCollected += LocalDb.doubleOf(d['amount_paid']);
      if (LocalDb.strOf(c['status']) != 'paid') defaulters++;
    }
    feeCollected = (feeCollected * 100).round() / 100;

    final attRows = await _db.query('student_attendance',
        where: 'date = ? AND deleted = 0', whereArgs: [today]);
    final present =
        attRows.where((r) => LocalDb.strOf(r['status']) == 'present').length;
    final attPct = attRows.isEmpty
        ? 0.0
        : (1000 * present / attRows.length).round() / 10;

    final staffRows = await _db.query('staff_attendance',
        where: 'date = ? AND deleted = 0', whereArgs: [today]);
    final staffPresent = staffRows
        .where((r) => LocalDb.strOf(r['status']) == 'present')
        .length;

    final start =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final expenses = await _db.query('expenses',
        where: 'date >= ? AND deleted = 0', whereArgs: [start]);
    var expTotal = 0.0;
    for (final e in expenses) {
      expTotal += LocalDb.doubleOf(LocalDb.dataOf(e)['amount']);
    }
    final salaries = await _db.query('salaries',
        where: 'month = ? AND year = ? AND deleted = 0',
        whereArgs: [now.month, now.year]);
    var salTotal = 0.0;
    for (final s in salaries) {
      salTotal += LocalDb.doubleOf(LocalDb.dataOf(s)['net']);
    }
    final profit =
        ((feeCollected - expTotal - salTotal) * 100).round() / 100;

    return DashboardData.fromJson({
      'total_students': totalStudents,
      'total_staff': totalStaff,
      'fee_collected_month': feeCollected,
      'defaulters_count': defaulters,
      'attendance_pct_today': attPct,
      'staff_present_today': staffPresent,
      'profit_month': profit,
    });
  }
}
