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

  Future<void> deleteHead(int id) async {
    await _db.softDelete('fee_heads', 'fee_heads', id);
    await _sync.notifyDirty();
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

  // ------------------------------------------------------------ charges
  // One-off student charges (Paper Printing Fee, Sports Fund, ...). The
  // HTML keeps charges apart from fee heads; there is no server table for
  // them, so they live in the meta table and are local-only.

  static const _chargesKey = 'student_charges';

  Future<List<StudentCharge>> charges() async {
    final raw = await _db.getMeta(_chargesKey);
    if (raw == null || raw.isEmpty) {
      return const [
        StudentCharge(name: 'Paper Printing Fee', amount: 100),
        StudentCharge(name: 'Sports Fund', amount: 200),
      ];
    }
    try {
      final list = (jsonDecode(raw) as List? ?? [])
          .map((e) => StudentCharge.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<void> addCharge(StudentCharge charge) async {
    final list = await charges();
    if (list.any((c) => c.name.toLowerCase() == charge.name.toLowerCase())) {
      throw Exception('Ye charge pehle se hai.');
    }
    await _db.setMeta(_chargesKey,
        jsonEncode([...list, charge].map((c) => c.toJson()).toList()));
  }

  Future<void> deleteCharge(String name) async {
    final list = await charges();
    list.removeWhere((c) => c.name == name);
    await _db.setMeta(_chargesKey,
        jsonEncode(list.map((c) => c.toJson()).toList()));
  }

  // ------------------------------------------------------------ class fees
  // Per-class monthly tuition overrides (the HTML's S.classFees). The
  // Monthly Tuition Fee head's amount is replaced by the class fee for
  // that student's class when generating challans.

  static const _classFeesKey = 'class_fees';
  static const tuitionHeadName = 'Monthly Tuition Fee';

  Future<Map<int, double>> classFees() async {
    final m = await _db.getMetaJson(_classFeesKey);
    if (m == null) return {};
    final out = <int, double>{};
    m.forEach((k, v) {
      final id = int.tryParse(k);
      if (id != null) out[id] = (v as num?)?.toDouble() ?? 0;
    });
    return out;
  }

  Future<void> setClassFee(int classId, double amount) async {
    final fees = await classFees();
    if (amount <= 0) {
      fees.remove(classId);
    } else {
      fees[classId] = amount;
    }
    await _db.setMetaJson(_classFeesKey,
        {for (final e in fees.entries) e.key.toString(): e.value});
  }

  /// Amount of one fee head for one student's class (class-fee override
  /// applies to the Monthly Tuition head only).
  Future<double> headAmountFor(FeeHead head, int classId) async {
    if (head.name != tuitionHeadName) return head.amount;
    final fees = await classFees();
    return fees[classId] ?? head.amount;
  }

  // ------------------------------------------------------------ generation

  /// Dues for one student: fee heads (class-scoped or all classes) plus
  /// charges, each with the amount that applies to this student's class.
  Future<List<ReceiptLine>> duesForStudent(int studentId) async {
    final srow = await _db.getById('students', studentId);
    if (srow == null) return [];
    final classId = LocalDb.intOf(srow['class_id']);
    final heads = await this.heads();
    final out = <ReceiptLine>[];
    for (final h in heads) {
      if (h.classId != null && h.classId != classId) continue;
      out.add(ReceiptLine(
          name: h.name, amount: await headAmountFor(h, classId)));
    }
    for (final c in await charges()) {
      if (c.classId != null && c.classId != classId) continue;
      out.add(ReceiptLine(name: c.name, amount: c.amount));
    }
    return out;
  }

  /// One challan for one student covering the selected dues (heads by id
  /// plus charges by name). Throws when the student already has a challan
  /// for this month — the server allows one challan per student per month,
  /// so the app keeps the same rule (the HTML checks the first head only;
  /// the server rule wins here).
  Future<Challan> generateSingle({
    required int studentId,
    required int month,
    required int year,
    required List<int> headIds,
    List<String> chargeNames = const [],
  }) async {
    final srow = await _db.getById('students', studentId);
    if (srow == null) throw Exception('Student not found');
    final exists = await _db.query('fee_challans',
        where: 'student_id = ? AND month = ? AND year = ? AND deleted = 0',
        whereArgs: [studentId, month, year],
        limit: 1);
    if (exists.isNotEmpty) {
      throw Exception(
          'Is student ka is month ka challan pehle se bana hua hai.');
    }
    final classId = LocalDb.intOf(srow['class_id']);
    final items = await _dueItems(
        classId: classId, headIds: headIds, chargeNames: chargeNames);
    if (items.isEmpty) throw Exception('Kam se kam aik due select karein.');
    final total = items.fold<double>(0, (s, i) => s + i.amount);
    final challan = await _insertChallan(
      studentRow: srow,
      month: month,
      year: year,
      items: items,
      total: total,
    );
    // Sync path is the class-level generate endpoint (the server has no
    // single-challan endpoint); reconcile adopts the server number.
    await _db.enqueue('challans_generate', 'action', null, {
      'class_id': classId,
      'month': month,
      'year': year,
      'head_ids': headIds,
    });
    await _sync.notifyDirty();
    return challan;
  }

  /// Bulk generate: one challan per active student (one class, or the
  /// whole school when [classId] is null). Returns (created, skipped).
  Future<({int created, int skipped})> generateBulk({
    int? classId,
    required int month,
    required int year,
    required List<int> headIds,
    List<String> chargeNames = const [],
  }) async {
    if (headIds.isEmpty && chargeNames.isEmpty) {
      throw Exception('Kam se kam aik due select karein.');
    }
    final classes = await _db.query('classes',
        where: classId == null ? 'deleted = 0' : 'id = ? AND deleted = 0',
        whereArgs: classId == null ? null : [classId],
        orderBy: 'level_order ASC');
    var created = 0, skipped = 0;
    for (final c in classes) {
      final cid = (c['id'] as num).toInt();
      final students = await _db.query('students',
          where: 'class_id = ? AND status = ? AND deleted = 0',
          whereArgs: [cid, 'active']);
      var classCreated = 0;
      for (final s in students) {
        final sid = (s['id'] as num).toInt();
        final exists = await _db.query('fee_challans',
            where: 'student_id = ? AND month = ? AND year = ? AND deleted = 0',
            whereArgs: [sid, month, year],
            limit: 1);
        if (exists.isNotEmpty) {
          skipped++;
          continue;
        }
        final items = await _dueItems(
            classId: cid, headIds: headIds, chargeNames: chargeNames);
        if (items.isEmpty) {
          skipped++;
          continue;
        }
        final total = items.fold<double>(0, (s2, i) => s2 + i.amount);
        await _insertChallan(
            studentRow: s, month: month, year: year, items: items, total: total);
        classCreated++;
      }
      created += classCreated;
      if (classCreated > 0) {
        await _db.enqueue('challans_generate', 'action', null, {
          'class_id': cid,
          'month': month,
          'year': year,
          'head_ids': headIds,
        });
      }
    }
    await _sync.notifyDirty();
    return (created: created, skipped: skipped);
  }

  /// The selected dues for one class, priced for that class (tuition uses
  /// the class fee; charges are fixed amounts).
  Future<List<ReceiptLine>> _dueItems({
    required int classId,
    required List<int> headIds,
    required List<String> chargeNames,
  }) async {
    final out = <ReceiptLine>[];
    for (final hid in headIds) {
      final row = await _db.getById('fee_heads', hid);
      if (row == null) continue;
      final head = FeeHead.fromJson(_rowJson(row));
      if (head.classId != null && head.classId != classId) continue;
      out.add(ReceiptLine(
          name: head.name,
          amount: await headAmountFor(head, classId)));
    }
    final allCharges = await charges();
    for (final name in chargeNames) {
      final charge = allCharges
          .where((c) => c.name == name)
          .firstOrNull;
      if (charge == null) continue;
      if (charge.classId != null && charge.classId != classId) continue;
      out.add(ReceiptLine(name: charge.name, amount: charge.amount));
    }
    return out;
  }

  Future<Challan> _insertChallan({
    required Map<String, Object?> studentRow,
    required int month,
    required int year,
    required List<ReceiptLine> items,
    required double total,
  }) async {
    final sid = (studentRow['id'] as num).toInt();
    final mm = month.toString().padLeft(2, '0');
    final challanNo = 'CH-$year$mm-${sid.toString().padLeft(5, '0')}';
    final data = <String, dynamic>{
      'id': 0,
      'challan_no': challanNo,
      'student_id': sid,
      'student_name': LocalDb.strOf(studentRow['name']),
      'month': month,
      'year': year,
      'total_amount': total,
      'discount': 0,
      'amount_paid': 0,
      'balance': total,
      'status': 'unpaid',
      'head': items.first.name,
      'items': items
          .map((i) => {'name': i.name, 'amount': i.amount})
          .toList(),
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
    return Challan.fromJson(data);
  }

  Future<int> generateChallans({
    required int classId,
    required int month,
    required int year,
    required List<int> headIds,
  }) async {
    final res = await generateBulk(
        classId: classId, month: month, year: year, headIds: headIds);
    return res.created;
  }

  /// Mark a challan paid in full (the HTML's "Mark paid"): a full collect
  /// through the normal payment path, so the server stays in sync.
  Future<Receipt> markPaid(int challanId) async {
    final row = await _db.getById('fee_challans', challanId);
    if (row == null) throw Exception('Challan not found');
    final data = _rowJson(row);
    final balance = LocalDb.doubleOf(data['total_amount']) -
        LocalDb.doubleOf(data['discount']) -
        LocalDb.doubleOf(data['amount_paid']);
    if (balance <= 0.01) throw Exception('Challan is already paid.');
    return collect(challanId, amount: balance, paymentMethod: 'cash');
  }

  /// Remove duplicate challans (same student + head + month). Keeps one
  /// per group, preferring a paid one, else the first. Returns how many
  /// were removed.
  Future<int> dedupeChallans() async {
    final rows = await _db.query('fee_challans',
        where: 'deleted = 0', orderBy: 'id ASC');
    final groups = <String, List<Map<String, Object?>>>{};
    for (final r in rows) {
      final d = _rowJson(r);
      final key =
          '${r['student_id']}|${d['head'] ?? ''}|${r['month']}|${r['year']}';
      (groups[key] ??= []).add(r);
    }
    var removed = 0;
    for (final group in groups.values) {
      if (group.length <= 1) continue;
      group.sort((a, b) {
        final aPaid = LocalDb.strOf(_rowJson(a)['status']) == 'paid' ? 0 : 1;
        final bPaid = LocalDb.strOf(_rowJson(b)['status']) == 'paid' ? 0 : 1;
        return aPaid.compareTo(bPaid);
      });
      for (final dup in group.skip(1)) {
        await _db.softDelete(
            'fee_challans', 'fee_challans', (dup['id'] as num).toInt());
        removed++;
      }
    }
    if (removed > 0) await _sync.notifyDirty();
    return removed;
  }

  /// All-time defaulter list (the Reports "Defaulter List Report"):
  /// every student with at least one unpaid challan, any month.
  /// Returns [{student_id, name, class_name, challan_nos, due}].
  Future<List<Map<String, dynamic>>> allDefaulters() async {
    final rows = await _db.query('fee_challans',
        where: "status != 'paid' AND deleted = 0", orderBy: 'student_id ASC');
    final byStudent = <int, Map<String, dynamic>>{};
    for (final r in rows) {
      final d = _rowJson(r);
      final sid = (r['student_id'] as num?)?.toInt() ?? 0;
      final entry = byStudent.putIfAbsent(sid, () => {
            'student_id': sid,
            'name': d['student_name']?.toString() ?? '',
            'class_name': '',
            'challan_nos': <String>[],
            'due': 0.0,
          });
      (entry['challan_nos'] as List<String>)
          .add(r['challan_no']?.toString() ?? '');
      entry['due'] = (entry['due'] as double) +
          LocalDb.doubleOf(d['total_amount']) -
          LocalDb.doubleOf(d['amount_paid']);
    }
    for (final entry in byStudent.values) {
      final srow = await _db.getById('students', entry['student_id'] as int);
      if (srow != null) {
        entry['name'] = LocalDb.strOf(srow['name']);
        final classRow = await _db.getById(
            'classes', LocalDb.intOf(srow['class_id']));
        entry['class_name'] =
            classRow == null ? '' : LocalDb.strOf(classRow['name']);
      }
    }
    final out = byStudent.values.toList();
    out.sort((a, b) =>
        (a['name'] as String).compareTo(b['name'] as String));
    return out;
  }

  /// Per-fee-head collection (the Reports "Monthly Collection Report"
  /// table): for each head, how many challans, how many paid, and how
  /// much was collected. Heads come from challan items when present,
  /// otherwise from the challan's head field.
  Future<List<Map<String, dynamic>>> perHeadCollection({
    required int month,
    required int year,
  }) async {
    final rows = await _db.query('fee_challans',
        where: 'month = ? AND year = ? AND deleted = 0',
        whereArgs: [month, year]);
    final byHead = <String, ({int challans, int paid, double amount})>{};
    for (final r in rows) {
      final d = _rowJson(r);
      final items = (d['items'] as List?) ?? const [];
      final names = items.isEmpty
          ? [d['head']?.toString() ?? '']
          : items
              .map((i) => (i as Map)['name']?.toString() ?? '')
              .toList();
      final paid = LocalDb.doubleOf(d['amount_paid']);
      final isPaid = LocalDb.strOf(d['status']) == 'paid';
      for (final name in names) {
        if (name.isEmpty) continue;
        final cur = byHead[name] ?? (challans: 0, paid: 0, amount: 0);
        byHead[name] = (
          challans: cur.challans + 1,
          paid: cur.paid + (isPaid ? 1 : 0),
          amount: cur.amount + paid,
        );
      }
    }
    final out = byHead.entries
        .map((e) => {
              'head': e.key,
              'challans': e.value.challans,
              'paid': e.value.paid,
              'amount': e.value.amount,
            })
        .toList();
    out.sort((a, b) => (a['head'] as String).compareTo(b['head'] as String));
    return out;
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
