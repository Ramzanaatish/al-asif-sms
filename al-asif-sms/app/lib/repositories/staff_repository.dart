import 'dart:convert';

import '../models/staff.dart';
import '../services/local_db.dart';
import '../services/sync_service.dart';

/// Offline-first staff repository. Same public API as before.
class StaffRepository {
  final _db = LocalDb.instance;
  final _sync = SyncService.instance;

  Future<List<StaffMember>> list({String? staffType, String? status}) async {
    final where = <String>['deleted = 0'];
    final args = <Object?>[];
    if (staffType != null) {
      where.add('staff_type = ?');
      args.add(staffType);
    }
    final st = status ?? 'active';
    if (st != 'all') {
      where.add('status = ?');
      args.add(st);
    }
    final rows = await _db.query('staff',
        where: where.join(' AND '), whereArgs: args, orderBy: 'name ASC');
    return rows.map((r) => StaffMember.fromJson(_rowJson(r))).toList();
  }

  Future<StaffMember> detail(int id) async {
    final row = await _db.getById('staff', id);
    if (row == null) throw Exception('Staff not found');
    return StaffMember.fromJson(_rowJson(row));
  }

  Future<StaffMember> create(Map<String, dynamic> body) async {
    final data = <String, dynamic>{
      'id': 0,
      'name': body['name']?.toString() ?? '',
      'staff_type': body['staff_type']?.toString() ?? 'teaching',
      'designation': body['designation']?.toString() ?? '',
      'phone': body['phone']?.toString() ?? '',
      'cnic': body['cnic']?.toString() ?? '',
      'salary_monthly': (body['salary_monthly'] as num?)?.toDouble() ?? 0,
      'joining_date': body['joining_date']?.toString(),
      'status': body['status']?.toString() ?? 'active',
    };
    final localId = await _db.insert('staff', {
      'name': data['name'],
      'staff_type': data['staff_type'],
      'status': data['status'],
      'dirty': 1,
      'data': jsonEncode(data),
    });
    data['id'] = localId;
    await _db.updateById('staff', localId, {'data': jsonEncode(data)});
    await _db.enqueue('staff', 'create', localId, _plain(body));
    await _sync.notifyDirty();
    return StaffMember.fromJson(data);
  }

  Future<StaffMember> update(int id, Map<String, dynamic> body) async {
    final row = await _db.getById('staff', id);
    if (row == null) throw Exception('Staff not found');
    final data = Map<String, dynamic>.from(_rowJson(row));
    for (final e in _plain(body).entries) {
      data[e.key] = e.value;
    }
    await _db.updateById('staff', id, {
      'name': data['name'],
      'staff_type': data['staff_type'],
      'status': data['status'],
      'dirty': 1,
      'data': jsonEncode(data),
    });
    await _db.enqueue('staff', 'update', id, _plain(body));
    await _sync.notifyDirty();
    return StaffMember.fromJson(data);
  }

  Future<List<StaffLeave>> leaves({String? status}) async {
    final where = <String>['deleted = 0'];
    final args = <Object?>[];
    if (status != null) {
      where.add('staff_leaves.status = ?');
      args.add(status);
    }
    final rows = await _db.query('staff_leaves',
        where: where.join(' AND '), whereArgs: args, orderBy: 'from_date DESC');
    final out = <StaffLeave>[];
    for (final r in rows) {
      final data = _rowJson(r);
      final srow = await _db.getById('staff', LocalDb.intOf(r['staff_id']));
      data['staff_name'] = srow == null ? '' : LocalDb.strOf(srow['name']);
      out.add(StaffLeave.fromJson(data));
    }
    return out;
  }

  Future<void> applyLeave(Map<String, dynamic> body) async {
    final data = <String, dynamic>{
      'id': 0,
      'staff_id': body['staff_id'],
      'from_date': body['from_date']?.toString(),
      'to_date': body['to_date']?.toString(),
      'reason': body['reason']?.toString() ?? '',
      'status': 'pending',
    };
    final localId = await _db.insert('staff_leaves', {
      'staff_id': body['staff_id'],
      'status': 'pending',
      'from_date': data['from_date'],
      'dirty': 1,
      'data': jsonEncode(data),
    });
    data['id'] = localId;
    await _db.updateById('staff_leaves', localId, {'data': jsonEncode(data)});
    await _db.enqueue('staff_leaves', 'create', localId, _plain(body));
    await _sync.notifyDirty();
  }

  Future<void> decideLeave(int id, String decision) async {
    final row = await _db.getById('staff_leaves', id);
    if (row == null) throw Exception('Leave not found');
    final data = Map<String, dynamic>.from(_rowJson(row));
    data['status'] = decision;
    await _db.updateById('staff_leaves', id, {
      'status': decision,
      'dirty': 1,
      'data': jsonEncode(data),
    });
    await _db.enqueue('leave_decision', 'action', id, {
      'leave_local_id': id,
      'decision': decision,
    });
    await _sync.notifyDirty();
  }

  Future<List<SalaryRecord>> salaries({int? month, int? year}) async {
    final where = <String>['deleted = 0'];
    final args = <Object?>[];
    if (month != null) {
      where.add('month = ?');
      args.add(month);
    }
    if (year != null) {
      where.add('year = ?');
      args.add(year);
    }
    final rows = await _db.query('salaries',
        where: where.join(' AND '),
        whereArgs: args,
        orderBy: 'year DESC, month DESC');
    final out = <SalaryRecord>[];
    for (final r in rows) {
      final data = _rowJson(r);
      final srow = await _db.getById('staff', LocalDb.intOf(r['staff_id']));
      data['staff_name'] = srow == null ? '' : LocalDb.strOf(srow['name']);
      out.add(SalaryRecord.fromJson(data));
    }
    return out;
  }

  Future<SalaryRecord> paySalary(Map<String, dynamic> body) async {
    final staffId = (body['staff_id'] as num).toInt();
    final month = (body['month'] as num).toInt();
    final year = (body['year'] as num).toInt();
    final dup = await _db.query('salaries',
        where: 'staff_id = ? AND month = ? AND year = ? AND deleted = 0',
        whereArgs: [staffId, month, year],
        limit: 1);
    if (dup.isNotEmpty) {
      throw Exception('Salary already recorded for this month');
    }
    final srow = await _db.getById('staff', staffId);
    final basic = srow == null
        ? 0.0
        : LocalDb.doubleOf(LocalDb.dataOf(srow)['salary_monthly']);
    final allowances = (body['allowances'] as num?)?.toDouble() ?? 0;
    final deductions = (body['deductions'] as num?)?.toDouble() ?? 0;
    final net = basic + allowances - deductions;
    final data = <String, dynamic>{
      'id': 0,
      'staff_id': staffId,
      'staff_name': srow == null ? '' : LocalDb.strOf(srow['name']),
      'month': month,
      'year': year,
      'basic': basic,
      'allowances': allowances,
      'deductions': deductions,
      'net': net,
      'paid_date': DateTime.now().toIso8601String().substring(0, 10),
    };
    final localId = await _db.insert('salaries', {
      'staff_id': staffId,
      'month': month,
      'year': year,
      'dirty': 1,
      'data': jsonEncode(data),
    });
    data['id'] = localId;
    await _db.updateById('salaries', localId, {'data': jsonEncode(data)});
    await _db.enqueue('salaries', 'create', localId, {
      'staff_id': staffId,
      'month': month,
      'year': year,
      'allowances': allowances,
      'deductions': deductions,
    });
    await _sync.notifyDirty();
    return SalaryRecord.fromJson(data);
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
