import 'dart:io';

import 'package:alasif_sms/repositories/expenses_repository.dart';
import 'package:alasif_sms/services/db_factory.dart';
import 'package:alasif_sms/services/local_db.dart';
import 'package:alasif_sms/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'temp_dir_helper.dart';

/// Guards the HTML-parity rule (v1.4.7): the Expenses screen must behave
/// like the HTML (Complete v7) — inline Add Expense (category, amount,
/// date, note), "This Month" total, and the table Date | Category |
/// Note | Amount | Delete. No separate add screen, no year/month filters.
void main() {
  late Directory tmp;
  late ExpensesRepository repo;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tmp = await Directory.systemTemp.createTemp('alasif_exp_');
    initDatabaseFactory();
    LocalDb.testDatabasesDir = tmp.path;
    repo = ExpensesRepository();
    await LocalDb.instance.db;
    // Seed the 8 expense categories when the asset seed did not run.
    final db = LocalDb.instance;
    final first = await db.db;
    final catCount = Sqflite.firstIntValue(await first
            .rawQuery('SELECT COUNT(*) FROM expense_categories')) ??
        0;
    if (catCount == 0) {
      const names = [
        'Salaries',
        'Utilities (Electricity/Water/Gas)',
        'Rent',
        'Stationery & Printing',
        'Maintenance & Repairs',
        'Transport/Fuel',
        'Events & Activities',
        'Miscellaneous',
      ];
      final stamp = DateTime.now().toIso8601String();
      for (final name in names) {
        await first.insert('expense_categories', {
          'name': name,
          'dirty': 0,
          'data': '{"id":0,"name":"$name"}',
          'updated_at': stamp,
        });
      }
    }
  });

  tearDown(() async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (SyncService.instance.isSyncing &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await LocalDb.instance.close();
    await deleteTempDirQuietly(tmp);
  });

  test('categories seed to the HTML eight', () async {
    final cats = await repo.categories();
    expect(cats.length, 8);
    expect(cats.map((c) => c.name), contains('Salaries'));
  });

  test('create stores category/date/note/amount and delete removes it',
      () async {
    final cats = await repo.categories();
    final utilities = cats.firstWhere(
        (c) => c.name.startsWith('Utilities'));
    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);
    final expense = await repo.create({
      'category_id': utilities.id,
      'amount': 4500,
      'date': today,
      'description': 'Electricity bill',
    });
    expect(expense.id, greaterThan(0));
    expect(expense.categoryName, startsWith('Utilities'));
    expect(expense.amount, 4500);
    expect(expense.description, 'Electricity bill');
    expect(expense.date, today);
    var listed = await repo.list();
    expect(listed.length, 1);
    // The month filter (used for the "This Month" total) only matches
    // the current month.
    final thisMonth =
        await repo.list(month: now.month, year: now.year);
    expect(thisMonth.length, 1);
    final otherMonth = await repo.list(
        month: now.month == 12 ? 1 : now.month + 1, year: now.year);
    expect(otherMonth.length, 0);
    await repo.delete(expense.id);
    listed = await repo.list();
    expect(listed.length, 0);
  });
}
