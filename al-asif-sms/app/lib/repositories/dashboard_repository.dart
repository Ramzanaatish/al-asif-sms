import '../config.dart';
import '../models/dashboard.dart';
import '../models/fee.dart';
import '../services/local_db.dart';

/// Offline-first dashboard repository: principal dashboard computed locally,
/// mirroring backend/dashboard.py exactly, plus the HTML dashboard's own
/// numbers (present / absent / leave counts and name lists, class-wise
/// strength for the donut, and the fee-heads table).
class DashboardRepository {
  final _db = LocalDb.instance;

  Future<DashboardData> principal() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final now = DateTime.now();

    final totalStudents = await _db.count('students',
        where: "status = 'active' AND deleted = 0");
    final totalStaff = await _db.count('staff',
        where: "status = 'active' AND deleted = 0");
    final totalClasses = await _db.count('classes',
        where: 'deleted = 0');

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
    final absent =
        attRows.where((r) => LocalDb.strOf(r['status']) == 'absent').length;
    final onLeave =
        attRows.where((r) => LocalDb.strOf(r['status']) == 'leave').length;
    final attPct = attRows.isEmpty
        ? 0.0
        : (1000 * present / attRows.length).round() / 10;

    // HTML "Absent Today" / "On Leave Today" name lists: "Name (Class)".
    // Student name and class live on the student row (name and class_id
    // columns, with the data JSON as fallback for older rows).
    final students = await _db.query('students',
        where: "status = 'active' AND deleted = 0");
    final classes = await _db.query('classes',
        where: 'deleted = 0', orderBy: 'level_order ASC');
    final absentNames = <String>[];
    final leaveNames = <String>[];
    if (absent + onLeave > 0) {
      final stuById = <int, Map<String, Object?>>{};
      for (final s in students) {
        stuById[(s['id'] as num).toInt()] = s;
      }
      final clsNameById = <int, String>{};
      for (final c in classes) {
        clsNameById[(c['id'] as num).toInt()] = LocalDb.strOf(c['name']);
      }
      for (final r in attRows) {
        final status = LocalDb.strOf(r['status']);
        if (status != 'absent' && status != 'leave') continue;
        final s = stuById[(r['student_id'] as num?)?.toInt() ?? -1];
        if (s == null) continue;
        final d = LocalDb.dataOf(s);
        final name = LocalDb.strOf(s['name']).isNotEmpty
            ? LocalDb.strOf(s['name'])
            : LocalDb.strOf(d['name']);
        final classId =
            (s['class_id'] as num?)?.toInt() ?? (d['class_id'] as num?)?.toInt();
        final cls = classId == null ? '-' : (clsNameById[classId] ?? '-');
        final entry = '$name ($cls)';
        if (status == 'absent') {
          absentNames.add(entry);
        } else {
          leaveNames.add(entry);
        }
      }
    }

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
    expTotal = (expTotal * 100).round() / 100;
    final salaries = await _db.query('salaries',
        where: 'month = ? AND year = ? AND deleted = 0',
        whereArgs: [now.month, now.year]);
    var salTotal = 0.0;
    for (final s in salaries) {
      salTotal += LocalDb.doubleOf(LocalDb.dataOf(s)['net']);
    }
    final profit =
        ((feeCollected - expTotal - salTotal) * 100).round() / 100;

    // HTML "Class-wise Strength": every class in level order, with its
    // teacher (AppConfig.classTeachers — the school's fixed assignments)
    // and its share of the school, rounded like the HTML.
    final countByClass = <int, int>{};
    for (final s in students) {
      final d = LocalDb.dataOf(s);
      final classId =
          (s['class_id'] as num?)?.toInt() ?? (d['class_id'] as num?)?.toInt();
      if (classId != null) {
        countByClass[classId] = (countByClass[classId] ?? 0) + 1;
      }
    }
    final classStrength = <Map<String, dynamic>>[];
    for (final c in classes) {
      final id = (c['id'] as num).toInt();
      final name = LocalDb.strOf(c['name']);
      final count = countByClass[id] ?? 0;
      final pct = totalStudents > 0
          ? (100 * count / totalStudents).round()
          : 0;
      classStrength.add({
        'class_id': id,
        'class_name': name,
        'teacher': AppConfig.classTeacher(name),
        'count': count,
        'pct': pct,
      });
    }

    // HTML "Fee Heads" table, in the same order as the Fees screen.
    final headRows = await _db.query('fee_heads',
        where: 'deleted = 0', orderBy: 'name ASC');
    final feeHeads = headRows.map((r) {
      final data = LocalDb.dataOf(r);
      data['id'] = (r['id'] as num).toInt();
      return FeeHead.fromJson(data);
    }).toList();

    return DashboardData.fromJson({
      'total_students': totalStudents,
      'total_staff': totalStaff,
      'fee_collected_month': feeCollected,
      'defaulters_count': defaulters,
      'attendance_pct_today': attPct,
      'staff_present_today': staffPresent,
      'profit_month': profit,
      'total_classes': totalClasses,
      'present_today': present,
      'absent_today': absent,
      'on_leave_today': onLeave,
      'expenses_month': expTotal,
      'absent_names': absentNames,
      'leave_names': leaveNames,
      'class_strength': classStrength,
      'fee_heads': feeHeads
          .map((h) => {
                'id': h.id,
                'name': h.name,
                'amount': h.amount,
                'frequency': h.frequency,
                'class_id': h.classId,
              })
          .toList(),
    });
  }
}
