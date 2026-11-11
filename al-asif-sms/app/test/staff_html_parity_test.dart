import 'dart:convert';
import 'dart:io';

import 'package:alasif_sms/repositories/staff_repository.dart';
import 'package:alasif_sms/services/db_factory.dart';
import 'package:alasif_sms/services/local_db.dart';
import 'package:alasif_sms/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'temp_dir_helper.dart';

/// Guards the HTML-parity rule (v1.4.7): the Staff screen must behave
/// like the HTML (Complete v7) — table Name | Role | Class | Contact |
/// Monthly Salary | Status | Remove, and the Add Staff modal's fields
/// (name, Urdu name, role, class, salary, since, contact, password).
/// The Urdu name, class and password ride in the local data JSON (the
/// server's staff record has no such fields) and must NOT be sent to
/// the server.
void main() {
  late Directory tmp;
  late StaffRepository repo;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tmp = await Directory.systemTemp.createTemp('alasif_staff_');
    initDatabaseFactory();
    LocalDb.testDatabasesDir = tmp.path;
    repo = StaffRepository();
    await LocalDb.instance.db;
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

  test('create stores the HTML fields and the role maps to staff_type',
      () async {
    final member = await repo.create({
      'name': 'Miss Asia',
      'name_urdu': 'مس آسیہ',
      'staff_type': 'teaching',
      'designation': 'Teacher',
      'class_name': 'Play Group',
      'salary_monthly': 25000,
      'joining_date': '2026-01-15',
      'phone': '0300-1234567',
      'password': 'teacher123',
    });
    expect(member.id, greaterThan(0));
    expect(member.nameUrdu, 'مس آسیہ');
    expect(member.className, 'Play Group');
    expect(member.password, 'teacher123');
    expect(member.roleLabel, 'Teacher');
    expect(member.salaryMonthly, 25000);
    final listed = await repo.list();
    expect(listed.length, 1);
    expect(listed.first.name, 'Miss Asia');
    // The queued server payload carries only the server's fields.
    final db = LocalDb.instance;
    final first = await db.db;
    final ops = await first.query('sync_queue',
        where: "entity = 'staff' AND op = 'create'");
    expect(ops.length, 1);
    final payload =
        jsonDecode(ops.first['payload_json'] as String) as Map;
    expect(payload.containsKey('password'), isFalse);
    expect(payload.containsKey('class_name'), isFalse);
    expect(payload.containsKey('name_urdu'), isFalse);
    expect(payload['designation'], 'Teacher');
  });

  test('Clerk maps to non_teaching and remove soft-deletes', () async {
    final clerk = await repo.create({
      'name': 'Ahmed Clerk',
      'staff_type': 'non_teaching',
      'designation': 'Clerk',
      'salary_monthly': 15000,
    });
    expect(clerk.staffType, 'non_teaching');
    expect(clerk.roleLabel, 'Clerk');
    final teacher = await repo.create({
      'name': 'Miss Nadia Ali',
      'staff_type': 'teaching',
      'designation': 'Teacher',
      'class_name': 'Nursery',
      'salary_monthly': 25000,
    });
    expect((await repo.list()).length, 2);
    await repo.remove(clerk.id);
    final remaining = await repo.list();
    expect(remaining.length, 1);
    expect(remaining.first.id, teacher.id);
  });
}
