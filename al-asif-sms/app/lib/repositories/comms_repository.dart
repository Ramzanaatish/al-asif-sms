import 'dart:convert';

import '../models/comms.dart';
import '../services/local_db.dart';
import '../services/sync_service.dart';

/// Offline-first comms repository. Same public API as before.
class CommsRepository {
  final _db = LocalDb.instance;
  final _sync = SyncService.instance;

  Future<List<Notice>> notices({String? audience}) async {
    final role = await _db.getMeta('cached_role');
    final where = <String>['deleted = 0'];
    final args = <Object?>[];
    if (audience != null) {
      where.add('audience = ?');
      args.add(audience);
    } else if (role == 'parent') {
      // mirror the server: parents only see 'all' + 'parents'
      where.add("audience IN ('all','parents')");
    }
    final rows = await _db.query('notices',
        where: where.join(' AND '),
        whereArgs: args,
        orderBy: 'created_at DESC',
        limit: 100);
    return rows.map((r) => Notice.fromJson(_rowJson(r))).toList();
  }

  Future<Notice> publishNotice(Map<String, dynamic> body) async {
    final data = <String, dynamic>{
      'id': 0,
      'title': body['title']?.toString() ?? '',
      'body': body['body']?.toString() ?? '',
      'audience': body['audience']?.toString() ?? 'all',
      'created_by': '',
      'created_at': DateTime.now().toIso8601String(),
    };
    final localId = await _db.insert('notices', {
      'audience': data['audience'],
      'created_at': data['created_at'],
      'dirty': 1,
      'data': jsonEncode(data),
    });
    data['id'] = localId;
    await _db.updateById('notices', localId, {'data': jsonEncode(data)});
    await _db.enqueue('notices', 'create', localId, _plain(body));
    await _sync.notifyDirty();
    return Notice.fromJson(data);
  }

  Future<List<Complaint>> complaints() async {
    final role = await _db.getMeta('cached_role');
    final where = <String>['deleted = 0'];
    final args = <Object?>[];
    if (role == 'parent') {
      // server ids: the backend filters parent_user_id == user.id
      final uid = await _db.getMeta('cached_user_id');
      final pid = await _db.getMeta('cached_parent_user_id') ?? uid;
      where.add('parent_user_id = ?');
      args.add(pid);
    }
    final rows = await _db.query('complaints',
        where: where.join(' AND '),
        whereArgs: args,
        orderBy: 'created_at DESC',
        limit: 200);
    final out = <Complaint>[];
    for (final r in rows) {
      final data = _rowJson(r);
      final sid = LocalDb.intOf(data['student_id']);
      if (sid != 0) {
        final srow = await _db.getById('students', sid);
        data['student_name'] =
            srow == null ? '' : LocalDb.strOf(srow['name']);
      }
      out.add(Complaint.fromJson(data));
    }
    return out;
  }

  Future<Complaint> fileComplaint(Map<String, dynamic> body) async {
    final data = <String, dynamic>{
      'id': 0,
      'student_id': body['student_id'],
      'subject': body['subject']?.toString() ?? '',
      'body': body['body']?.toString() ?? body['description']?.toString() ?? '',
      'status': 'open',
      'parent_user_id': await _db.getMeta('cached_parent_user_id') ??
          await _db.getMeta('cached_user_id'),
      'created_at': DateTime.now().toIso8601String(),
    };
    final localId = await _db.insert('complaints', {
      'status': 'open',
      'parent_user_id': data['parent_user_id'],
      'created_at': data['created_at'],
      'dirty': 1,
      'data': jsonEncode(data),
    });
    data['id'] = localId;
    await _db.updateById('complaints', localId, {'data': jsonEncode(data)});
    // server takes {student_id, subject, body}; parent derived from JWT
    await _db.enqueue('complaints', 'create', localId, {
      if (body['student_id'] != null) 'student_id': body['student_id'],
      'subject': data['subject'],
      'body': data['body'],
    });
    await _sync.notifyDirty();
    return Complaint.fromJson(data);
  }

  Future<Complaint> resolveComplaint(int id, String status) async {
    final row = await _db.getById('complaints', id);
    if (row == null) throw Exception('Complaint not found');
    final data = Map<String, dynamic>.from(_rowJson(row));
    data['status'] = status;
    await _db.updateById('complaints', id, {
      'status': status,
      'dirty': 1,
      'data': jsonEncode(data),
    });
    await _db.enqueue('complaint_resolve', 'action', id, {
      'local_id': id,
      'status': status,
    });
    await _sync.notifyDirty();
    return Complaint.fromJson(data);
  }

  /// Parent home: one ChildSummary per linked student, computed locally.
  /// Mirrors backend /parent/summary (single linked child).
  Future<List<ChildSummary>> parentSummary() async {
    final linkId = await _db.getMeta('linked_student_id');
    final srow = linkId == null
        ? null
        : await _db.getById('students', int.tryParse(linkId) ?? 0);
    if (srow == null) return [];
    final sid = (srow['id'] as num).toInt();
    final sdata = LocalDb.dataOf(srow);

    final attRows = await _db.query('student_attendance',
        where: 'student_id = ? AND deleted = 0', whereArgs: [sid]);
    final present =
        attRows.where((r) => LocalDb.strOf(r['status']) == 'present').length;
    final attPct = attRows.isEmpty
        ? 0.0
        : (1000 * present / attRows.length).round() / 10;

    final challans = await _db.query('fee_challans',
        where: 'student_id = ? AND deleted = 0', whereArgs: [sid]);
    var balance = 0.0;
    for (final c in challans) {
      final d = LocalDb.dataOf(c);
      balance += LocalDb.doubleOf(d['total_amount']) -
          LocalDb.doubleOf(d['discount']) -
          LocalDb.doubleOf(d['amount_paid']);
    }
    balance = (balance * 100).round() / 100;

    // latest result %: newest term with marks for this student
    var lastPct = 0.0;
    final marksRows = await _db.query('marks',
        where: 'student_id = ? AND deleted = 0',
        whereArgs: [sid],
        orderBy: 'term_id DESC',
        limit: 50);
    if (marksRows.isNotEmpty) {
      final termId = LocalDb.intOf(marksRows.first['term_id']);
      var obtained = 0.0, total = 0.0;
      for (final mr in marksRows) {
        if (LocalDb.intOf(mr['term_id']) != termId) break;
        final d = LocalDb.dataOf(mr);
        obtained += LocalDb.doubleOf(d['obtained_marks']);
        total += LocalDb.doubleOf(d['total_marks']);
      }
      if (total > 0) lastPct = (1000 * obtained / total).round() / 10;
    }

    return [
      ChildSummary.fromJson({
        'student_id': sid,
        'name': LocalDb.strOf(srow['name']),
        'class_name': sdata['class_name']?.toString() ?? '',
        'attendance_pct': attPct,
        'fee_balance': balance,
        'last_result_pct': lastPct,
      })
    ];
  }

  // ------------------------------------------------------------ helpers

  Map<String, dynamic> _rowJson(Map<String, Object?> row) {
    final data = LocalDb.dataOf(row);
    data['id'] = (row['id'] as num).toInt();
    return data;
  }

  Map<String, dynamic> _plain(Map<String, dynamic> body) {
    final out = <String, dynamic>{};
    body.forEach((k, v) {
      if (v != null) out[k] = v;
    });
    return out;
  }
}
