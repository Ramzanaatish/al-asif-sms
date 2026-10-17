import 'dart:convert';

import '../models/student.dart';
import '../services/local_db.dart';
import '../services/sync_service.dart';

/// Offline-first student repository.
///
/// Reads always come from the local SQLite database; writes are applied
/// locally immediately and enqueued for background sync. Public signatures
/// are unchanged so screens/providers keep working as before.
class StudentRepository {
  final _db = LocalDb.instance;
  final _sync = SyncService.instance;

  Future<List<Student>> list({
    int? classId,
    int? sectionId,
    String? status,
    String? search,
  }) async {
    final where = <String>['deleted = 0'];
    final args = <Object?>[];
    if (classId != null) {
      where.add('class_id = ?');
      args.add(classId);
    }
    if (sectionId != null) {
      where.add('section_id = ?');
      args.add(sectionId);
    }
    if (status != null && status != 'all') {
      where.add('status = ?');
      args.add(status);
    } else if (status == null) {
      where.add('status = ?');
      args.add('active');
    }
    if (search != null && search.isNotEmpty) {
      where.add('(name LIKE ? OR admission_no LIKE ?)');
      args.add('%$search%');
      args.add('%$search%');
    }
    final rows = await _db.query('students',
        where: where.join(' AND '),
        whereArgs: args,
        orderBy:
            'CASE WHEN roll_number IS NULL THEN 1 ELSE 0 END, roll_number ASC, name ASC');
    return rows.map((r) => Student.fromJson(_rowJson(r))).toList();
  }

  Future<Student> detail(int id) async {
    final row = await _db.getById('students', id);
    if (row == null) throw Exception('Student not found');
    final data = Map<String, dynamic>.from(_rowJson(row));
    data['attendance_pct'] = await _attendancePct(id);
    data['fee_balance'] = await _feeBalance(id);
    return Student.fromJson(data);
  }

  Future<double> _attendancePct(int studentId) async {
    final rows = await _db.query('student_attendance',
        where: 'student_id = ? AND deleted = 0', whereArgs: [studentId]);
    if (rows.isEmpty) return 0;
    final present =
        rows.where((r) => LocalDb.strOf(r['status']) == 'present').length;
    return present * 100.0 / rows.length;
  }

  Future<double> _feeBalance(int studentId) async {
    final rows = await _db.query('fee_challans',
        where: 'student_id = ? AND deleted = 0', whereArgs: [studentId]);
    var bal = 0.0;
    for (final r in rows) {
      bal += LocalDb.doubleOf(r['total_amount']) -
          LocalDb.doubleOf(r['discount']) -
          LocalDb.doubleOf(r['amount_paid']);
    }
    return bal;
  }

  Future<Student> create(Map<String, dynamic> body) async {
    final year = DateTime.now().year;
    final seq = await _db.nextSeq('admission_no:$year');
    final admissionNo = 'AS-$year-${seq.toString().padLeft(4, '0')}';
    final classRow = body['class_id'] != null
        ? await _db.getById('classes', (body['class_id'] as num).toInt())
        : null;
    final sectionRow = body['section_id'] != null
        ? await _db.getById('sections', (body['section_id'] as num).toInt())
        : null;
    final data = <String, dynamic>{
      'id': 0,
      'admission_no': admissionNo,
      'roll_number': body['roll_number'],
      'name': body['name']?.toString() ?? '',
      'dob': body['dob']?.toString(),
      'gender': body['gender']?.toString(),
      'class_id': body['class_id'],
      'class_name': classRow == null ? '' : LocalDb.strOf(classRow['name']),
      'section_id': body['section_id'],
      'section_name':
          sectionRow == null ? '' : LocalDb.strOf(sectionRow['name']),
      'guardian_name': body['guardian_name']?.toString() ?? '',
      'guardian_phone': body['guardian_phone']?.toString() ?? '',
      'guardian_relation': body['guardian_relation']?.toString() ?? '',
      'address': body['address']?.toString() ?? '',
      'status': 'active',
      'photo_path': body['photo_path']?.toString(),
      'documents': body['documents'] ?? [],
      'admission_date':
          DateTime.now().toIso8601String().substring(0, 10),
      'attendance_pct': 0,
      'fee_balance': 0,
    };
    final localId = await _db.insert('students', {
      'admission_no': admissionNo,
      'roll_number': body['roll_number'],
      'name': data['name'],
      'class_id': body['class_id'],
      'section_id': body['section_id'],
      'status': 'active',
      'dirty': 1,
      'provisional': 1,
      'data': jsonEncode(data),
    });
    data['id'] = localId;
    await _db.updateById('students', localId, {'data': jsonEncode(data)});
    await _db.enqueue('students', 'create', localId, {
      ..._plainBody(body),
      'admission_no': admissionNo,
    });
    await _sync.notifyDirty();
    return Student.fromJson(data);
  }

  /// Next auto-generated admission number (peek; the create call consumes it).
  Future<String> nextAdmissionNo() async {
    final year = DateTime.now().year;
    final nxt = await _db.peekSeq('admission_no:$year');
    return 'AS-$year-${nxt.toString().padLeft(4, '0')}';
  }

  Future<Student> update(int id, Map<String, dynamic> body) async {
    final row = await _db.getById('students', id);
    if (row == null) throw Exception('Student not found');
    final data = Map<String, dynamic>.from(_rowJson(row));
    for (final e in _plainBody(body).entries) {
      data[e.key] = e.value;
    }
    // refresh denormalised names
    if (body['class_id'] != null) {
      final c = await _db.getById('classes', (body['class_id'] as num).toInt());
      data['class_id'] = body['class_id'];
      data['class_name'] = c == null ? '' : LocalDb.strOf(c['name']);
    }
    if (body.containsKey('section_id')) {
      final sid = body['section_id'];
      final s = sid != null
          ? await _db.getById('sections', (sid as num).toInt())
          : null;
      data['section_id'] = sid;
      data['section_name'] = s == null ? '' : LocalDb.strOf(s['name']);
    }
    await _db.updateById('students', id, {
      'name': data['name'],
      'class_id': data['class_id'],
      'section_id': data['section_id'],
      'roll_number': data['roll_number'],
      'status': data['status'],
      'dirty': 1,
      'data': jsonEncode(data),
    });
    await _db.enqueue('students', 'update', id, _plainBody(body));
    await _sync.notifyDirty();
    return Student.fromJson(data);
  }

  /// Returns {'student': {...}, 'certificate': {...}} like the server.
  Future<Map<String, dynamic>> markLeft(
      int id, String leavingDate, String reason) async {
    final row = await _db.getById('students', id);
    if (row == null) throw Exception('Student not found');
    final data = Map<String, dynamic>.from(_rowJson(row));
    data['status'] = 'left';
    data['leaving_date'] = leavingDate;
    data['leaving_reason'] = reason;
    await _db.updateById('students', id, {
      'status': 'left',
      'dirty': 1,
      'data': jsonEncode(data),
    });
    await _db.enqueue('student_mark_left', 'action', id, {
      'student_local_id': id,
      'leaving_date': leavingDate,
      'reason': reason,
    });
    await _sync.notifyDirty();
    final year = DateTime.tryParse(leavingDate)?.year ?? DateTime.now().year;
    final certNo = 'LC-${id.toString().padLeft(5, '0')}-$year';
    data['certificate_no'] = certNo; // confirmed/updated on sync
    await _db.updateById('students', id, {'data': jsonEncode(data)});
    return {
      'student': data,
      'certificate': {
        'certificate_no': certNo,
        'student_name': data['name'],
        'admission_no': data['admission_no'],
        'class_name': data['class_name'],
        'dob': data['dob'],
        'guardian_name': data['guardian_name'],
        'admission_date': data['admission_date'],
        'leaving_date': leavingDate,
        'reason': reason,
        'school': 'AL-ASIF PUBLIC MIDDLE SCHOOL BASTI SHAIKHAN (REGD.)',
        'principal': 'Mrs. Hajra Iqbal',
      },
    };
  }

  Future<Map<String, dynamic>> promote({
    required int fromClassId,
    required int toClassId,
    required List<int> promotedIds,
    required List<int> retainedIds,
    required int sessionId,
  }) async {
    var promoted = 0;
    for (final id in promotedIds) {
      final row = await _db.getById('students', id);
      if (row == null || LocalDb.strOf(row['status']) != 'active') continue;
      final toClass = await _db.getById('classes', toClassId);
      final data = Map<String, dynamic>.from(_rowJson(row));
      data['class_id'] = toClassId;
      data['class_name'] =
          toClass == null ? '' : LocalDb.strOf(toClass['name']);
      data['section_id'] = null;
      data['section_name'] = '';
      await _db.updateById('students', id, {
        'class_id': toClassId,
        'section_id': null,
        'dirty': 1,
        'data': jsonEncode(data),
      });
      promoted++;
    }
    await _db.enqueue('student_promote', 'action', null, {
      'from_class_id': fromClassId,
      'to_class_id': toClassId,
      'promoted_ids': promotedIds,
      'retained_ids': retainedIds,
      'session_id': sessionId,
    });
    await _sync.notifyDirty();
    return {
      'promoted': promoted,
      'retained': retainedIds.length,
    };
  }

  // ------------------------------------------------------------ helpers

  Map<String, dynamic> _rowJson(Map<String, Object?> row) {
    final data = LocalDb.dataOf(row);
    data['id'] = (row['id'] as num).toInt();
    return data;
  }

  /// Strip nulls and Flutter-only keys from an outgoing body.
  Map<String, dynamic> _plainBody(Map<String, dynamic> body) {
    final out = <String, dynamic>{};
    body.forEach((k, v) {
      if (v != null) out[k] = v;
    });
    return out;
  }
}
