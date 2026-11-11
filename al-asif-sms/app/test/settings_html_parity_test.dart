import 'dart:io';

import 'package:alasif_sms/models/fee.dart';
import 'package:alasif_sms/repositories/fees_repository.dart';
import 'package:alasif_sms/repositories/school_info_repository.dart';
import 'package:alasif_sms/repositories/teacher_assignments_repository.dart';
import 'package:alasif_sms/services/db_factory.dart';
import 'package:alasif_sms/services/local_db.dart';
import 'package:alasif_sms/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'temp_dir_helper.dart';

/// Guards the HTML-parity rule (v1.4.7): the Settings screen must behave
/// like the HTML (Complete v7) — School Info & Login, Class Monthly Fee,
/// Teacher Assignments, Student Charges, Server Sync, Reset demo data.
void main() {
  late Directory tmp;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tmp = await Directory.systemTemp.createTemp('alasif_settings_');
    initDatabaseFactory();
    LocalDb.testDatabasesDir = tmp.path;
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

  test('school info defaults match the HTML seed and round-trip', () async {
    final repo = SchoolInfoRepository();
    final d = await repo.get();
    expect(d.address, 'Basti Shaikhan, Zafar Abad, Tehsil Liaquatpur');
    expect(d.tehsil, 'Liaquatpur');
    expect(d.type, 'Private');
    expect(d.shift, 'Morning');
    await repo.save(const SchoolInfo(
      emis: '35202001',
      address: 'New Address',
      tehsil: 'Rahim Yar Khan',
      type: 'Govt',
      shift: 'Evening',
      showPrincipalSign: false,
    ));
    final saved = await repo.get();
    expect(saved.emis, '35202001');
    expect(saved.address, 'New Address');
    expect(saved.tehsil, 'Rahim Yar Khan');
    expect(saved.type, 'Govt');
    expect(saved.shift, 'Evening');
    expect(saved.showPrincipalSign, isFalse);
  });

  test('class fees round-trip through the meta table', () async {
    final fees = FeesRepository();
    final before = await fees.classFees();
    expect(before.isEmpty, isTrue);
    await fees.setClassFee(1, 900);
    await fees.setClassFee(11, 1200);
    final after = await fees.classFees();
    expect(after[1], 900);
    expect(after[11], 1200);
  });

  test('student charges add and delete', () async {
    final fees = FeesRepository();
    await fees.addCharge(
        const StudentCharge(name: 'Library Fund', amount: 150));
    await fees.addCharge(
        const StudentCharge(name: 'Lab Fee', amount: 250, classId: 4));
    var list = await fees.charges();
    expect(list.any((c) => c.name == 'Library Fund'), isTrue);
    expect(list.firstWhere((c) => c.name == 'Lab Fee').classId, 4);
    await fees.deleteCharge('Library Fund');
    list = await fees.charges();
    expect(list.any((c) => c.name == 'Library Fund'), isFalse);
  });

  test('teacher assignments round-trip', () async {
    final repo = TeacherAssignmentsRepository();
    await repo.setClassAssignments([
      {'teacher': 'Miss Asia', 'class_id': 1},
      {'teacher': 'Miss Nadia Ali', 'class_id': 2},
    ]);
    await repo.setSubjectAssignments([
      {'teacher': 'Miss Asia', 'class_id': 1, 'subject': 'English'},
    ]);
    expect(await repo.classesForTeacher('Miss Asia'), contains(1));
    expect(await repo.subjectsForTeacher('Miss Asia', 1),
        contains('English'));
    expect(await repo.subjectsForTeacher('Miss Asia', 2), isEmpty);
  });

  test('reset demo data wipes the DB and re-seeds on next open', () async {
    final db = LocalDb.instance;
    final first = await db.db;
    await first.insert('students', {
      'admission_no': 'AS-TEST-1',
      'name': 'Test Student',
      'class_id': 1,
      'status': 'active',
      'data': '{"id":0,"name":"Test Student"}',
      'updated_at': DateTime.now().toIso8601String(),
    });
    await db.resetDemoData();
    final reopened = await db.db;
    final rows = await reopened.query('students',
        where: 'admission_no = ?', whereArgs: ['AS-TEST-1']);
    expect(rows, isEmpty);
    // Seed re-ran: the 11 classes are back.
    final classes = await reopened.query('classes');
    expect(classes.length, 11);
  });
}
