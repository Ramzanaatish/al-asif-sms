import 'dart:convert';

import '../models/fee.dart';
import '../services/local_db.dart';
import '../services/sync_service.dart';

/// Offline-first fees repository. Same public API as before.
///
/// Challan generation and fee collection work fully offline with provisional
/// numbers (see SYNC_PROTOCOL.md); the sync service reconciles them with the
/// server afterwards.
class FeesRepository {
  final _db = LocalDb.instance;
  final _sync = SyncService.instance;

  Future<List<FeeHead>> heads() async {
    final rows = await _db.query('fee_heads',
        where: 'deleted = 0', orderBy: 'name ASC');
    return rows.map((r) => FeeHead.fromJson(_rowJson(r))).toList();
  }

  Future<FeeHead> createHead(Map<String, dynamic> body) async {
    final data = <String, dynamic>{
      'id': 0,
      'name': body['name']?.toString() ?? '',
      'amount': (body['amount'] as num?)?.toDouble() ?? 0,
      'frequency': body['frequency']?.toString() ?? 'monthly',
      'class_id': body['class_id'],
    };
    final localId = await _db.insert('fee_heads', {
      'name': data['name'],
      'class_id': body['class_id'],
      'dirty': 1,
      'data': jsonEncode(data),
    });
    data['id'] = localId;
    await _db.updateById('fee_heads', localId, {'data': jsonEncode(data)});
    await _db.enqueue('fee_heads', 'create', localId, _plain(body));
    await _sync.notifyDirty();
    return FeeHead.fromJson(data);
  }

  Future<int> generateChallans({
    required int classId,
    required int month,
    required int year,
    required List<int> headIds,
  }) async {
    var total = 0.0;
    for (final h in headIds) {
      final row = await _db.getById('fee_heads', h);
      if (row != null) total += LocalDb.doubleOf(LocalDb.dataOf(row)['amount']);
    }
    if (total <= 0) throw Exception('No valid fee heads');
    final students = await _db.query('students',
        where: 'class_id = ? AND status = ? AND deleted = 0',
        whereArgs: [classId, 'active']);
    var created = 0;
    final mm = month.toString().padLeft(2, '0');
    for (final s in students) {
      final sid = (s['id'] as num).toInt();
      final exists = await _db.query('fee_challans',
          where: 'student_id = ? AND month = ? AND year = ? AND deleted = 0',
          whereArgs: [sid, month, year],
          limit: 1);
      if (exists.isNotEmpty) continue;
      final challanNo =
          'CH-$year$mm-${sid.toString().padLeft(5, '0')}';
      final data = <String, dynamic>{
        'id': 0,
        'challan_no': challanNo,
        'student_id': sid,
        'student_name': LocalDb.strOf(s['name']),
        'month': month,
        'year': year,
        'total_amount': total,
        'discount': 0,
        'amount_paid': 0,
        'balance': total,
        'status': 'unpaid',
      };
      final localId = await _db.insert('fee_challans', {
        'challan_no': challanNo,
        'student_id': sid,
        'month': month,
        'year': year,
        'status': 'unpaid',
        'dirty': 1,
        'provisional': 1,
        'data': jsonEncode(data),
      });
      data['id'] = localId;
      await _db.updateById('fee_challans', localId, {'data': jsonEncode(data)});
      created++;
    }
    await _db.enqueue('challans_generate', 'action', null, {
      'class_id': classId,
      'month': month,
      'year': year,
      'head_ids': headIds,
    });
    await _sync.notifyDirty();
    return created;
  }

  Future<List<Challan>> challans({
    int? studentId,
    int? month,
    int? year,
    String? status,
  }) async {
    final where = <String>['deleted = 0'];
    final args = <Object?>[];
    if (studentId != null) {
      where.add('student_id = ?');
      args.add(studentId);
    }
    if (month != null) {
      where.add('month = ?');
      args.add(month);
    }
    if (year != null) {
      where.add('year = ?');
      args.add(year);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status);
    }
    final rows = await _db.query('fee_challans',
        where: where.join(' AND '), whereArgs: args, orderBy: 'id DESC', limit: 500);
    return rows.map((r) => Challan.fromJson(_rowJson(r))).toList();
  }

  /// Collect fee offline: updates the challan, creates a provisional receipt,
  /// enqueues the collect op. Returns the Urdu receipt object.
  Future<Receipt> collect(
    int challanId, {
    required double amount,
    double discount = 0,
    required String paymentMethod,
  }) async {
    final crow = await _db.getById('fee_challans', challanId);
    if (crow == null) throw Exception('Challan not found');
    final cdata = Map<String, dynamic>.from(_rowJson(crow));
    if (amount <= 0 || discount < 0) {
      throw Exception('Invalid amount.');
    }
    final remaining = LocalDb.doubleOf(cdata['total_amount']) -
        LocalDb.doubleOf(cdata['discount']) -
        LocalDb.doubleOf(cdata['amount_paid']) -
        discount;
    if (amount > remaining + 0.01) {
      throw Exception(
          'Amount exceeds the remaining balance (${remaining.toStringAsFixed(0)}).');
    }
    final newDiscount = LocalDb.doubleOf(cdata['discount']) + discount;
    final newPaid = LocalDb.doubleOf(cdata['amount_paid']) + amount;
    final total = LocalDb.doubleOf(cdata['total_amount']);
    final balance = total - newDiscount - newPaid;
    final status =
        balance <= 0.01 ? 'paid' : (newPaid > 0 ? 'partial' : 'unpaid');
    cdata['discount'] = newDiscount;
    cdata['amount_paid'] = newPaid;
    cdata['balance'] = balance;
    cdata['status'] = status;
    await _db.updateById('fee_challans', challanId, {
      'status': status,
      'dirty': 1,
      'data': jsonEncode(cdata),
    });

    final seq = await _db.nextSeq('receipt');
    final receiptNo =
        'R-${challanId.toString().padLeft(6, '0')}-${seq.toString().padLeft(3, '0')}';
    final now = DateTime.now();
    final rdata = <String, dynamic>{
      'id': 0,
      'receipt_no': receiptNo,
      'challan_id': challanId,
      'amount': amount,
      'payment_method': paymentMethod,
      'received_at': now.toIso8601String(),
      'received_by': '',
      'student_name': cdata['student_name'],
      'admission_no': await _admissionNoOf(LocalDb.intOf(crow['student_id'])),
      'class_name': await _classNameOf(LocalDb.intOf(crow['student_id'])),
      'guardian_name': await _guardianOf(LocalDb.intOf(crow['student_id'])),
      'month': cdata['month'],
      'year': cdata['year'],
      'total_amount': total,
      'discount': newDiscount,
      'balance': balance,
      'school': 'AL-ASIF PUBLIC MIDDLE SCHOOL BASTI SHAIKHAN (REGD.)',
      'principal': 'Mrs. Hajra Iqbal',
    };
    final receiptId = await _db.insert('fee_receipts', {
      'receipt_no': receiptNo,
      'challan_id': challanId,
      'dirty': 1,
      'provisional': 1,
      'data': jsonEncode(rdata),
    });
    rdata['id'] = receiptId;
    await _db.updateById('fee_receipts', receiptId, {'data': jsonEncode(rdata)});

    await _db.enqueue('fee_collect', 'action', null, {
      'challan_local_id': challanId,
      'receipt_local_id': receiptId,
      'amount': amount,
      'discount': discount,
      'payment_method': paymentMethod,
    });
    await _sync.notifyDirty();
    return Receipt.fromJson(rdata);
  }

  Future<List<Defaulter>> defaulters({int? month, int? year}) async {
    final where = <String>['deleted = 0', 'status != ?'];
    final args = <Object?>['paid'];
    if (month != null) {
      where.add('month = ?');
      args.add(month);
    }
    if (year != null) {
      where.add('year = ?');
      args.add(year);
    }
    final rows = await _db.query('fee_challans',
        where: where.join(' AND '), whereArgs: args);
    final out = <Defaulter>[];
    for (final r in rows) {
      final data = _rowJson(r);
      final srow = await _db.getById(
          'students', LocalDb.intOf(r['student_id']));
      final sdata = srow == null ? <String, dynamic>{} : LocalDb.dataOf(srow);
      out.add(Defaulter.fromJson({
        'student_id': r['student_id'],
        'name': data['student_name'],
        'class_name': sdata['class_name'] ?? '',
        'guardian_phone': sdata['guardian_phone'] ?? '',
        'balance': data['balance'],
      }));
    }
    return out;
  }

  Future<CollectionReport> collectionReport({int? month, int? year}) async {
    final m = month ?? DateTime.now().month;
    final y = year ?? DateTime.now().year;
    final classes = await _db.query('classes',
        where: 'deleted = 0', orderBy: 'level_order ASC');
    final rows = <Map<String, dynamic>>[];
    var expTotal = 0.0, colTotal = 0.0;
    for (final c in classes) {
      final cid = (c['id'] as num).toInt();
      final challans = await _db.query('fee_challans',
          where:
              'month = ? AND year = ? AND deleted = 0 AND student_id IN (SELECT id FROM students WHERE class_id = ? AND deleted = 0)',
          whereArgs: [m, y, cid]);
      var expected = 0.0, collected = 0.0, defaulters = 0;
      for (final ch in challans) {
        final d = LocalDb.dataOf(ch);
        expected += LocalDb.doubleOf(d['total_amount']) -
            LocalDb.doubleOf(d['discount']);
        collected += LocalDb.doubleOf(d['amount_paid']);
        if (LocalDb.strOf(d['status']) != 'paid') defaulters++;
      }
      rows.add({
        'class_name': LocalDb.strOf(c['name']),
        'expected': expected,
        'collected': collected,
        'defaulters': defaulters,
      });
      expTotal += expected;
      colTotal += collected;
    }
    return CollectionReport.fromJson({
      'month': m,
      'year': y,
      'classes': rows,
      'totals': {
        'expected': expTotal,
        'collected': colTotal,
        'pct': expTotal > 0 ? 100 * colTotal / expTotal : 0,
      },
    });
  }

  Future<List<Receipt>> receipts(
      {int? month, int? year, int? classId}) async {
    final where = <String>['fee_receipts.deleted = 0'];
    final args = <Object?>[];
    if (month != null) {
      where.add('fee_challans.month = ?');
      args.add(month);
    }
    if (year != null) {
      where.add('fee_challans.year = ?');
      args.add(year);
    }
    final d = await _db.db;
    final rows = await d.rawQuery(
        'SELECT fee_receipts.* FROM fee_receipts '
        'LEFT JOIN fee_challans ON fee_challans.id = fee_receipts.challan_id '
        'LEFT JOIN students ON students.id = fee_challans.student_id '
        '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}'
        '${classId != null ? ' AND students.class_id = ?' : ''} '
        'ORDER BY fee_receipts.id ASC',
        [...args, if (classId != null) classId]);
    return rows.map((r) => Receipt.fromJson(_rowJson(r))).toList();
  }

  // ------------------------------------------------------------ helpers

  Future<String> _admissionNoOf(int studentId) async {
    final s = await _db.getById('students', studentId);
    return s == null ? '' : LocalDb.strOf(s['admission_no']);
  }

  Future<String> _classNameOf(int studentId) async {
    final s = await _db.getById('students', studentId);
    if (s == null) return '';
    return LocalDb.strOf(LocalDb.dataOf(s)['class_name']);
  }

  Future<String> _guardianOf(int studentId) async {
    final s = await _db.getById('students', studentId);
    if (s == null) return '';
    return LocalDb.strOf(LocalDb.dataOf(s)['guardian_name']);
  }

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
