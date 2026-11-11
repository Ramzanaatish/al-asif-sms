import 'dart:convert';

import '../models/attendance.dart';
import '../services/local_db.dart';
import '../services/sync_service.dart';

/// Offline-first attendance repository. Same public API as before.
///
/// Attendance rows are upserted locally by (date, student) and the whole
/// payload is queued as one bulk op. Holidays are expanded locally the same
/// way the server does.
class AttendanceRepository {
  final _db = LocalDb.instance;
  final _sync = SyncService.instance;

  Future<int> saveStudentAttendance(Map<String, dynamic> payload) async {
    final date = payload['date']?.toString() ?? '';
    final records = (payload['records'] as List? ?? [])
        .map((r) => (r as Map).cast<String, dynamic>())
        .toList();
    var saved = 0;
    for (final r in records) {
      final sid = (r['student_id'] as num?)?.toInt();
      if (sid == null) continue;
      final status = r['status']?.toString() ?? 'present';
      final leaveType =
          status == 'leave' ? r['leave_type']?.toString() : null;
      final existing = await _db.query('student_attendance',
          where: 'date = ? AND student_id = ? AND deleted = 0',
          whereArgs: [date, sid],
          limit: 1);
      final data = {
        'student_id': sid,
        'status': status,
        'leave_type': leaveType,
      };
      if (existing.isEmpty) {
        await _db.insert('student_attendance', {
          'date': date,
          'student_id': sid,
          'status': status,
          'dirty': 1,
          'data': jsonEncode(data),
        });
      } else {
        final lid = (existing.first['id'] as num).toInt();
        await _db.updateById('student_attendance', lid, {
          'status': status,
          'dirty': 1,
          'data': jsonEncode(data),
        });
      }
      saved++;
    }
    await _db.enqueue('attendance_students', 'bulk', null, {
      'date': date,
      'class_id': payload['class_id'],
      'section_id': payload['section_id'],
      'records': records,
    });
    await _sync.notifyDirty();
    return saved;
  }

  Future<List<Map<String, dynamic>>> studentRecords({
    String? date,
    int? classId,
    int? sectionId,
  }) async {
    final where = <String>['student_attendance.deleted = 0'];
    final args = <Object?>[];
    if (date != null) {
      where.add('student_attendance.date = ?');
      args.add(date);
    }
    final d = await _db.db;
    final rows = await d.rawQuery(
        'SELECT student_attendance.*, students.name AS sname, students.class_id AS scid '
        'FROM student_attendance LEFT JOIN students ON students.id = student_attendance.student_id '
        'WHERE ${where.join(' AND ')}'
        '${classId != null ? ' AND students.class_id = ?' : ''}'
        '${sectionId != null ? ' AND students.section_id = ?' : ''}',
        [...args, if (classId != null) classId, if (sectionId != null) sectionId]);
    return rows
        .map((r) => {
              'student_id': r['student_id'],
              'name': r['sname']?.toString() ?? '',
              'class_name': '',
              'status': r['status']?.toString(),
              'leave_type': LocalDb.dataOf(r)['leave_type']?.toString(),
            })
        .toList();
  }

  Future<void> saveStaffAttendance(
      String date, List<Map<String, dynamic>> records) async {
    for (final r in records) {
      final sid = (r['staff_id'] as num?)?.toInt();
      if (sid == null) continue;
      final status = r['status']?.toString() ?? 'present';
      final existing = await _db.query('staff_attendance',
          where: 'date = ? AND staff_id = ? AND deleted = 0',
          whereArgs: [date, sid],
          limit: 1);
      final data = {'staff_id': sid, 'status': status};
      if (existing.isEmpty) {
        await _db.insert('staff_attendance', {
          'date': date,
          'staff_id': sid,
          'status': status,
          'dirty': 1,
          'data': jsonEncode(data),
        });
      } else {
        await _db.updateById('staff_attendance',
            (existing.first['id'] as num).toInt(), {
          'status': status,
          'dirty': 1,
          'data': jsonEncode(data),
        });
      }
    }
    await _db.enqueue('attendance_staff', 'bulk', null, {
      'date': date,
      'records': records,
    });
    await _sync.notifyDirty();
  }

  Future<List<Map<String, dynamic>>> staffRecords({String? date}) async {
    final where = <String>['staff_attendance.deleted = 0'];
    final args = <Object?>[];
    if (date != null) {
      where.add('staff_attendance.date = ?');
      args.add(date);
    }
    final d = await _db.db;
    final rows = await d.rawQuery(
        'SELECT staff_attendance.*, staff.name AS sname FROM staff_attendance '
        'LEFT JOIN staff ON staff.id = staff_attendance.staff_id '
        'WHERE ${where.join(' AND ')}',
        args);
    return rows
        .map((r) => {
              'staff_id': r['staff_id'],
              'name': r['sname']?.toString() ?? '',
              'status': r['status']?.toString(),
            })
        .toList();
  }

  Future<int> sendAbsentAlerts(String date) async {
    final d = await _db.db;
    final rows = await d.rawQuery(
        'SELECT students.id FROM student_attendance '
        'LEFT JOIN students ON students.id = student_attendance.student_id '
        'WHERE student_attendance.date = ? AND student_attendance.status = ? '
        'AND student_attendance.deleted = 0 AND students.guardian_phone IS NOT NULL '
        "AND students.guardian_phone != ''",
        [date, 'absent']);
    final queued = rows.length;
    await _db.enqueue('absent_alerts', 'action', null, {'date': date});
    await _sync.notifyDirty();
    return queued;
  }

  /// Per-day attendance register for one class + month (the Reports
  /// "Monthly Attendance Report"): students in roll order, the days of
  /// the month, and each student's P/A/L per day. Returns
  /// (students, daysInMonth, totalDays, cells) where cells maps
  /// studentId -> day -> 'P' | 'A' | 'L'.
  Future<({
    List<Map<String, dynamic>> students,
    int daysInMonth,
    int totalDays,
    Map<int, Map<int, String>> cells,
  })> register({
    required int classId,
    required int month,
    required int year,
  }) async {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final prefix =
        '$year-${month.toString().padLeft(2, '0')}';
    final students = await _db.query('students',
        where: "class_id = ? AND status = 'active' AND deleted = 0",
        whereArgs: [classId],
        orderBy:
            'CASE WHEN roll_number IS NULL THEN 1 ELSE 0 END, roll_number ASC, name ASC');
    final rows = await _db.query('student_attendance',
        where: 'date LIKE ? AND deleted = 0',
        whereArgs: ['$prefix-%']);
    final cells = <int, Map<int, String>>{};
    final markedDays = <String>{};
    for (final r in rows) {
      final sid = LocalDb.intOf(r['student_id']);
      final date = LocalDb.strOf(r['date']);
      final day = int.tryParse(date.substring(8, 10)) ?? 0;
      if (day < 1 || day > daysInMonth) continue;
      // Only days with a record for this class count as school days.
      final studentClass = students
          .where((s) => (s['id'] as num).toInt() == sid)
          .firstOrNull;
      if (studentClass == null) continue;
      markedDays.add(date);
      final status = LocalDb.strOf(r['status']);
      (cells[sid] ??= {})[day] =
          status == 'present' ? 'P' : status == 'absent' ? 'A' : 'L';
    }
    return (
      students: students
          .map((s) => {
                'id': s['id'],
                'name': LocalDb.strOf(s['name']),
                'roll': s['roll_number'],
              })
          .toList(),
      daysInMonth: daysInMonth,
      totalDays: markedDays.length,
      cells: cells,
    );
  }

  Future<MonthlyAttendanceReport> monthly({
    int? month,
    int? year,
    int? classId,
  }) async {
    final m = month ?? DateTime.now().month;
    final y = year ?? DateTime.now().year;
    final start = DateTime(y, m, 1);
    final end = DateTime(y, m + 1, 1);
    final s0 =
        '${y.toString()}-${m.toString().padLeft(2, '0')}-01';
    final e0 =
        '${end.year}-${end.month.toString().padLeft(2, '0')}-01';

    final holidays = await _holidayDates(s0, e0);
    final holidaySet = holidays.map((h) => h['date']).toSet();

    final where = <String>[
      'students.deleted = 0',
      "students.status = 'active'"
    ];
    final args = <Object?>[];
    if (classId != null) {
      where.add('students.class_id = ?');
      args.add(classId);
    }
    final students = await _db.query('students',
        where: where.join(' AND '),
        whereArgs: args,
        orderBy:
            'CASE WHEN roll_number IS NULL THEN 1 ELSE 0 END, roll_number ASC, name ASC');

    final marked = await _db.query('student_attendance',
        where: 'date >= ? AND date < ? AND deleted = 0',
        whereArgs: [s0, e0]);
    final markedDates = marked
        .map((r) => LocalDb.strOf(r['date']))
        .toSet()
        .where((dt) => !holidaySet.contains(dt))
        .length;

    final studentsJson = <Map<String, dynamic>>[];
    for (final s in students) {
      final sid = (s['id'] as num).toInt();
      var present = 0, absent = 0, leave = 0;
      for (final r in marked) {
        if (LocalDb.intOf(r['student_id']) != sid) continue;
        if (holidaySet.contains(LocalDb.strOf(r['date']))) continue;
        switch (LocalDb.strOf(r['status'])) {
          case 'present':
            present++;
            break;
          case 'absent':
            absent++;
            break;
          case 'leave':
            leave++;
            break;
        }
      }
      final total = present + absent + leave;
      studentsJson.add({
        'student_id': sid,
        'name': LocalDb.strOf(s['name']),
        'present': present,
        'absent': absent,
        'leave': leave,
        'pct': total > 0 ? (100 * present / total) : 0,
        'fee_status': await _feeStatus(sid, m, y),
      });
    }
    return MonthlyAttendanceReport.fromJson({
      'days': markedDates,
      'working_days': markedDates,
      'students': studentsJson,
      'holidays': holidays,
    });
  }

  Future<String> _feeStatus(int studentId, int month, int year) async {
    final rows = await _db.query('fee_challans',
        where: 'student_id = ? AND month = ? AND year = ? AND deleted = 0',
        whereArgs: [studentId, month, year],
        limit: 1);
    if (rows.isEmpty) return 'Not Paid';
    switch (LocalDb.strOf(rows.first['status'])) {
      case 'paid':
        return 'Paid';
      case 'partial':
        return 'Partial';
      default:
        return 'Not Paid';
    }
  }

  Future<List<HolidayInfo>> holidays(
      {required int month, required int year}) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    final s0 = _dstr(start), e0 = _dstr(end);
    final list = await _holidayDates(s0, e0);
    return list.map((h) => HolidayInfo.fromJson(h)).toList();
  }

  /// Expand holiday ranges into individual day entries (server-compatible).
  Future<List<Map<String, dynamic>>> _holidayDates(
      String start, String end) async {
    final rows = await _db.query('holidays', where: 'deleted = 0');
    final out = <Map<String, dynamic>>[];
    final s = DateTime.parse(start);
    final e = DateTime.parse(end);
    for (final r in rows) {
      final d0 = DateTime.tryParse(LocalDb.strOf(r['date']));
      if (d0 == null) continue;
      final rdata = LocalDb.dataOf(r);
      final rawEnd = rdata['end_date']?.toString() ?? '';
      final d1 = rawEnd.isEmpty ? d0 : (DateTime.tryParse(rawEnd) ?? d0);
      var d = d0.isBefore(s) ? s : d0;
      final last = d1.isBefore(e.subtract(const Duration(days: 1)))
          ? d1
          : e.subtract(const Duration(days: 1));
      while (!d.isAfter(last)) {
        out.add({
          'date': _dstr(d),
          'kind': LocalDb.strOf(r['kind'], 'unexpected'),
          'description': rdata['description']?.toString() ?? '',
        });
        d = d.add(const Duration(days: 1));
      }
    }
    return out;
  }

  String _dstr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> addHoliday({
    required String date,
    String? endDate,
    String kind = 'unexpected',
    String? description,
  }) async {
    final data = {
      'id': 0,
      'date': date,
      'end_date': endDate,
      'kind': kind,
      'description': description ?? '',
    };
    final localId = await _db.insert('holidays', {
      'date': date,
      'kind': kind,
      'dirty': 1,
      'data': jsonEncode(data),
    });
    data['id'] = localId;
    await _db.updateById('holidays', localId, {'data': jsonEncode(data)});
    await _db.enqueue('holidays', 'create', localId, {
      'date': date,
      if (endDate != null) 'end_date': endDate,
      'kind': kind,
      if (description != null) 'description': description,
    });
    await _sync.notifyDirty();
  }
}
