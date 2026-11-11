import 'dart:convert';
import 'dart:io';

import 'package:alasif_sms/models/fee.dart';
import 'package:alasif_sms/repositories/fees_repository.dart';
import 'package:alasif_sms/services/db_factory.dart';
import 'package:alasif_sms/services/local_db.dart';
import 'package:alasif_sms/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'temp_dir_helper.dart';

/// Guards the HTML-parity rule (v1.4.7): the Fees screen must behave like
/// the HTML (Complete v7) Fees screen — single-student challan with dues
/// checkboxes (one challan for all checked dues), bulk generate (all
/// school / by class), student charges, fee types, mark-paid, and duplicate
/// removal. Charges and per-class tuition overrides live in the meta
/// table (no server table exists for them).
void main() {
  late Directory tmp;
  late FeesRepository repo;

  Future<int> addStudent(String name, int classId) async {
    final db = LocalDb.instance;
    final first = await db.db;
    final stamp = DateTime.now().toIso8601String();
    final data = {
      'id': 0,
      'admission_no': 'AS-2026-${name.hashCode.abs() % 10000}',
      'name': name,
      'class_id': classId,
      'class_name': 'Play Group',
      'status': 'active',
    };
    final id = await first.insert('students', {
      'admission_no': data['admission_no'],
      'name': name,
      'class_id': classId,
      'status': 'active',
      'data': jsonEncode(data),
      'updated_at': stamp,
    });
    data['id'] = id;
    await first.update('students', {'data': jsonEncode(data)},
        where: 'id = ?', whereArgs: [id]);
    return id;
  }

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tmp = await Directory.systemTemp.createTemp('alasif_fees_');
    initDatabaseFactory();
    LocalDb.testDatabasesDir = tmp.path;
    repo = FeesRepository();
    // Seed the 4 fee heads when the asset seed did not run.
    final db = LocalDb.instance;
    final first = await db.db;
    final headCount = Sqflite.firstIntValue(
            await first.rawQuery('SELECT COUNT(*) FROM fee_heads')) ??
        0;
    if (headCount == 0) {
      const heads = [
        ('Monthly Tuition Fee', 800.0, 'monthly'),
        ('Admission Fee', 2000.0, 'onetime'),
        ('Annual Examination Fee', 1200.0, 'annual'),
        ('Monthly Test Fee', 200.0, 'monthly'),
      ];
      final stamp = DateTime.now().toIso8601String();
      for (final (name, amount, freq) in heads) {
        final data = {
          'id': 0,
          'name': name,
          'amount': amount,
          'frequency': freq,
        };
        final id = await first.insert('fee_heads', {
          'name': name,
          'dirty': 0,
          'data': jsonEncode(data),
          'updated_at': stamp,
        });
        data['id'] = id;
        await first.update('fee_heads', {'data': jsonEncode(data)},
            where: 'id = ?', whereArgs: [id]);
      }
    }
  });

  tearDown(() async {
    // Every repository write fires notifyDirty(), which kicks off a
    // background syncNow() (unawaited). Wait for it to settle before
    // closing the DB and deleting the temp dir, or the next test's open
    // races with the still-running sync and fails with a disk I/O error.
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (SyncService.instance.isSyncing &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await LocalDb.instance.close();
    await deleteTempDirQuietly(tmp);
  });

  test('charges seed to the HTML defaults and round-trip', () async {
    final charges = await repo.charges();
    expect(charges.length, 2);
    expect(charges.map((c) => c.name),
        containsAll(['Paper Printing Fee', 'Sports Fund']));
    await expectLater(
        repo.addCharge(
            const StudentCharge(name: 'Paper Printing Fee', amount: 100)),
        throwsA(isA<Exception>()));
    await repo.addCharge(
        const StudentCharge(name: 'Library Fee', amount: 50));
    expect((await repo.charges()).length, 3);
    await repo.deleteCharge('Library Fee');
    expect((await repo.charges()).length, 2);
  });

  test('class fee overrides the monthly tuition amount', () async {
    final heads = await repo.heads();
    final tuition =
        heads.firstWhere((h) => h.name == 'Monthly Tuition Fee');
    expect(await repo.headAmountFor(tuition, 1), 800);
    await repo.setClassFee(1, 900);
    expect(await repo.headAmountFor(tuition, 1), 900);
    expect(await repo.headAmountFor(tuition, 2), 800);
    await repo.setClassFee(1, 0);
    expect(await repo.headAmountFor(tuition, 1), 800);
  });

  test('single generate: one challan for all checked dues', () async {
    final sid = await addStudent('Ahmed Saleem', 1);
    final heads = await repo.heads();
    final tuition =
        heads.firstWhere((h) => h.name == 'Monthly Tuition Fee');
    final testFee =
        heads.firstWhere((h) => h.name == 'Monthly Test Fee');
    final challan = await repo.generateSingle(
      studentId: sid,
      month: 11,
      year: 2026,
      headIds: [tuition.id, testFee.id],
      chargeNames: ['Sports Fund'],
    );
    expect(challan.challanNo, startsWith('CH-202611-'));
    expect(challan.totalAmount, 800 + 200 + 200);
    expect(challan.head, 'Monthly Tuition Fee');
    expect(challan.items.length, 3);
    expect(challan.headLabel, 'Monthly Tuition Fee (+2 more)');
    expect(challan.status, 'unpaid');
    await expectLater(
        repo.generateSingle(
          studentId: sid,
          month: 11,
          year: 2026,
          headIds: [tuition.id],
        ),
        throwsA(isA<Exception>()));
  });

  test('bulk generate: one per active student, skips existing', () async {
    final s1 = await addStudent('Ahmed Saleem', 1);
    final s2 = await addStudent('Bilal Ahmed', 1);
    final heads = await repo.heads();
    final tuition =
        heads.firstWhere((h) => h.name == 'Monthly Tuition Fee');
    final first = await repo.generateBulk(
        classId: 1, month: 11, year: 2026, headIds: [tuition.id]);
    expect(first.created, 2);
    expect(first.skipped, 0);
    final second = await repo.generateBulk(
        classId: 1, month: 11, year: 2026, headIds: [tuition.id]);
    expect(second.created, 0);
    expect(second.skipped, 2);
    final challans = await repo.challans(month: 11, year: 2026);
    expect(challans.map((c) => c.studentId), containsAll([s1, s2]));
  });

  test('mark paid collects the full balance', () async {
    final sid = await addStudent('Ahmed Saleem', 1);
    final heads = await repo.heads();
    final tuition =
        heads.firstWhere((h) => h.name == 'Monthly Tuition Fee');
    final challan = await repo.generateSingle(
      studentId: sid,
      month: 11,
      year: 2026,
      headIds: [tuition.id],
    );
    final receipt = await repo.markPaid(challan.id);
    expect(receipt.amountPaid, 800);
    final after = (await repo.challans(month: 11, year: 2026)).first;
    expect(after.status, 'paid');
  });

  test('dedupe keeps one per student+head+month, preferring paid', () async {
    final sid = await addStudent('Ahmed Saleem', 1);
    final heads = await repo.heads();
    final tuition =
        heads.firstWhere((h) => h.name == 'Monthly Tuition Fee');
    // Two challans for the same student/head/month (the duplicate the
    // HTML's "Remove duplicate challans" cleans up).
    final c1 = await repo.generateSingle(
      studentId: sid,
      month: 11,
      year: 2026,
      headIds: [tuition.id],
    );
    final db = LocalDb.instance;
    final first = await db.db;
    final stamp = DateTime.now().toIso8601String();
    final data = {
      'id': 0,
      'challan_no': 'CH-202611-99999',
      'student_id': sid,
      'student_name': 'Ahmed Saleem',
      'month': 11,
      'year': 2026,
      'total_amount': 800,
      'discount': 0,
      'amount_paid': 0,
      'balance': 800,
      'status': 'unpaid',
      'head': 'Monthly Tuition Fee',
      'items': [
        {'name': 'Monthly Tuition Fee', 'amount': 800}
      ],
    };
    final dupId = await first.insert('fee_challans', {
      'challan_no': 'CH-202611-99999',
      'student_id': sid,
      'month': 11,
      'year': 2026,
      'status': 'unpaid',
      'data': jsonEncode(data),
      'updated_at': stamp,
    });
    data['id'] = dupId;
    await first.update('fee_challans', {'data': jsonEncode(data)},
        where: 'id = ?', whereArgs: [dupId]);
    final removed = await repo.dedupeChallans();
    expect(removed, 1);
    final remaining = await repo.challans(month: 11, year: 2026);
    expect(remaining.length, 1);
    expect(remaining.first.id, c1.id);
  });

  test('per-head collection groups by fee head', () async {
    final s1 = await addStudent('Ahmed Saleem', 1);
    final s2 = await addStudent('Bilal Ahmed', 1);
    final heads = await repo.heads();
    final tuition =
        heads.firstWhere((h) => h.name == 'Monthly Tuition Fee');
    final testFee =
        heads.firstWhere((h) => h.name == 'Monthly Test Fee');
    final c1 = await repo.generateSingle(
      studentId: s1,
      month: 11,
      year: 2026,
      headIds: [tuition.id, testFee.id],
    );
    await repo.generateSingle(
      studentId: s2,
      month: 11,
      year: 2026,
      headIds: [tuition.id],
    );
    await repo.markPaid(c1.id);
    final rows = await repo.perHeadCollection(month: 11, year: 2026);
    final tuitionRow =
        rows.firstWhere((r) => r['head'] == 'Monthly Tuition Fee');
    expect(tuitionRow['challans'], 2);
    expect(tuitionRow['paid'], 1);
    expect(tuitionRow['amount'], 1000);
    final testRow =
        rows.firstWhere((r) => r['head'] == 'Monthly Test Fee');
    expect(testRow['challans'], 1);
    expect(testRow['amount'], 1000);
  });
}
