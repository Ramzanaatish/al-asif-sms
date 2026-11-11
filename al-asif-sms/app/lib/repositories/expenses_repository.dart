import 'dart:convert';

import '../models/expense.dart';
import '../services/local_db.dart';
import '../services/sync_service.dart';

/// Offline-first expenses repository. Same public API as before.
class ExpensesRepository {
  final _db = LocalDb.instance;
  final _sync = SyncService.instance;

  Future<List<ExpenseCategory>> categories() async {
    final rows = await _db.query('expense_categories',
        where: 'deleted = 0', orderBy: 'name ASC');
    return rows.map((r) => ExpenseCategory.fromJson(_rowJson(r))).toList();
  }

  Future<ExpenseCategory> createCategory(String name) async {
    final data = {'id': 0, 'name': name};
    final localId = await _db.insert('expense_categories', {
      'name': name,
      'dirty': 1,
      'data': jsonEncode(data),
    });
    data['id'] = localId;
    await _db.updateById(
        'expense_categories', localId, {'data': jsonEncode(data)});
    await _db.enqueue('expense_categories', 'create', localId, {'name': name});
    await _sync.notifyDirty();
    return ExpenseCategory.fromJson(data);
  }

  Future<List<Expense>> list(
      {int? month, int? year, int? categoryId}) async {
    final where = <String>['deleted = 0'];
    final args = <Object?>[];
    if (month != null && year != null) {
      final days = DateTime(year, month + 1, 0).day;
      where.add('date >= ? AND date <= ?');
      args.add('$year-${month.toString().padLeft(2, '0')}-01');
      args.add('$year-${month.toString().padLeft(2, '0')}-${days.toString().padLeft(2, '0')}');
    }
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }
    final rows = await _db.query('expenses',
        where: where.join(' AND '), whereArgs: args, orderBy: 'date DESC');
    final out = <Expense>[];
    for (final r in rows) {
      final data = _rowJson(r);
      final crow = await _db.getById(
          'expense_categories', LocalDb.intOf(r['category_id']));
      data['category_name'] =
          crow == null ? '' : LocalDb.strOf(crow['name']);
      // server shape uses "category" in list; accept both
      data['category'] = data['category_name'];
      out.add(Expense.fromJson(data));
    }
    return out;
  }

  Future<Expense> create(Map<String, dynamic> body) async {
    final crow = body['category_id'] != null
        ? await _db.getById(
            'expense_categories', (body['category_id'] as num).toInt())
        : null;
    final data = <String, dynamic>{
      'id': 0,
      'category_id': body['category_id'],
      'category_name': crow == null ? '' : LocalDb.strOf(crow['name']),
      'date': body['date']?.toString() ??
          DateTime.now().toIso8601String().substring(0, 10),
      'amount': (body['amount'] as num?)?.toDouble() ?? 0,
      'description': body['description']?.toString() ?? '',
      'paid_to': body['paid_to']?.toString() ?? '',
    };
    final localId = await _db.insert('expenses', {
      'category_id': body['category_id'],
      'date': data['date'],
      'dirty': 1,
      'data': jsonEncode(data),
    });
    data['id'] = localId;
    await _db.updateById('expenses', localId, {'data': jsonEncode(data)});
    await _db.enqueue('expenses', 'create', localId, _plain(body));
    await _sync.notifyDirty();
    return Expense.fromJson(data);
  }

  /// Remove an expense (soft delete, like the HTML's Delete button).
  Future<void> delete(int id) async {
    await _db.softDelete('expenses', 'expenses', id);
    await _sync.notifyDirty();
  }

  Future<ProfitLoss> profitLoss({int? month, int? year}) async {
    final m = month ?? DateTime.now().month;
    final y = year ?? DateTime.now().year;
    // fee collected from challans of this month/year
    final challans = await _db.query('fee_challans',
        where: 'month = ? AND year = ? AND deleted = 0',
        whereArgs: [m, y]);
    var feeCollected = 0.0;
    for (final c in challans) {
      feeCollected += LocalDb.doubleOf(LocalDb.dataOf(c)['amount_paid']);
    }
    // expenses in date range
    final days = DateTime(y, m + 1, 0).day;
    final start = '$y-${m.toString().padLeft(2, '0')}-01';
    final end = '$y-${m.toString().padLeft(2, '0')}-${days.toString().padLeft(2, '0')}';
    final expenses = await _db.query('expenses',
        where: 'date >= ? AND date <= ? AND deleted = 0',
        whereArgs: [start, end]);
    var expensesTotal = 0.0;
    final byCat = <String, double>{};
    for (final e in expenses) {
      final amt = LocalDb.doubleOf(LocalDb.dataOf(e)['amount']);
      expensesTotal += amt;
      final crow = await _db.getById(
          'expense_categories', LocalDb.intOf(e['category_id']));
      final name = crow == null ? 'Other' : LocalDb.strOf(crow['name']);
      byCat[name] = (byCat[name] ?? 0) + amt;
    }
    // salaries of this month/year
    final salaries = await _db.query('salaries',
        where: 'month = ? AND year = ? AND deleted = 0',
        whereArgs: [m, y]);
    var salariesTotal = 0.0;
    for (final s in salaries) {
      salariesTotal += LocalDb.doubleOf(LocalDb.dataOf(s)['net']);
    }
    final totalOutgoing = expensesTotal + salariesTotal;
    return ProfitLoss.fromJson({
      'month': m,
      'year': y,
      'fee_collected': feeCollected,
      'expenses_total': expensesTotal,
      'expenses_by_category': byCat.entries
          .map((e) => {'category': e.key, 'amount': e.value})
          .toList(),
      'salaries_total': salariesTotal,
      'total_outgoing': totalOutgoing,
      'net_profit': feeCollected - totalOutgoing,
    });
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
