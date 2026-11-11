import 'dart:convert';
import 'dart:io';

import 'package:alasif_sms/repositories/academics_repository.dart';
import 'package:alasif_sms/repositories/exams_repository.dart';
import 'package:alasif_sms/services/db_factory.dart';
import 'package:alasif_sms/services/local_db.dart';
import 'package:alasif_sms/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'temp_dir_helper.dart';

/// Guards the HTML-parity rule (v1.4.7): the Exams & Marks screen must
/// behave like the HTML (Complete v7) — grading scale A+ 90+ ... F
/// below 40, subject-wise marks entry with the HTML's five terms and
/// per-class subject lists, total marks per class|subject|term (default
/// 100), and auto-save that never floods the sync queue.
void main() {
  late Directory tmp;
  late ExamsRepository exams;
  late AcademicsRepository academics;

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
    tmp = await Directory.systemTemp.createTemp('alasif_exams_');
    initDatabaseFactory();
    LocalDb.testDatabasesDir = tmp.path;
    exams = ExamsRepository();
    academics = AcademicsRepository();
    final db = LocalDb.instance;
    final first = await db.db;
    // Seed the 11 classes when the asset seed did not run.
    final classCount = Sqflite.firstIntValue(
            await first.rawQuery('SELECT COUNT(*) FROM classes')) ??
        0;
    if (classCount == 0) {
      const names = [
        'Play Group', 'Nursery', 'Prep', '1st', '2nd', '3rd', '4th',
        '5th', '6th', '7th', '8th',
      ];
      final stamp = DateTime.now().toIso8601String();
      for (var i = 0; i < names.length; i++) {
        await first.insert('classes', {
          'name': names[i],
          'level_order': i + 1,
          'data': jsonEncode({'id': 0, 'name': names[i]}),
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

  test('grading scale matches the HTML', () {
    expect(ExamsRepository.gradeFor(95, 100), 'A+');
    expect(ExamsRepository.gradeFor(90, 100), 'A+');
    expect(ExamsRepository.gradeFor(89, 100), 'A');
    expect(ExamsRepository.gradeFor(80, 100), 'A');
    expect(ExamsRepository.gradeFor(75, 100), 'B');
    expect(ExamsRepository.gradeFor(65, 100), 'C');
    expect(ExamsRepository.gradeFor(55, 100), 'D');
    expect(ExamsRepository.gradeFor(45, 100), 'E');
    expect(ExamsRepository.gradeFor(39, 100), 'F');
    expect(ExamsRepository.gradeFor(0, 100), 'F');
    expect(ExamsRepository.gradeFor(42, 50), 'A');
    expect(ExamsRepository.gradeFor(0, 0), '-');
  });

  test('terms fall back to the HTML five and ensureTerm stores them',
      () async {
    final fallback = await exams.termsOrHtml();
    expect(fallback.map((t) => t.name), [
      'Monthly Test', 'First Term', 'Mid Term', 'Final Term', 'Annual',
    ]);
    final term = await exams.ensureTerm('First Term');
    expect(term.id, greaterThan(0));
    expect(term.termType, 'monthly');
    final again = await exams.ensureTerm('First Term');
    expect(again.id, term.id);
    final annual = await exams.ensureTerm('Annual');
    expect(annual.termType, 'annual');
    final stored = await exams.terms();
    expect(stored.length, 2);
  });

  test('subjects fall back to the HTML lists per class band', () async {
    final junior = await academics.subjectsForClass(1);
    expect(junior.map((s) => s.name), [
      'English', 'Urdu', 'Maths', 'Islamiat', 'General Knowledge',
    ]);
    final primary = await academics.subjectsForClass(5);
    expect(primary.map((s) => s.name),
        containsAll(['Science', 'Social Studies']));
    final middle = await academics.subjectsForClass(10);
    expect(middle.map((s) => s.name),
        containsAll(['Pakistan Studies', 'Computer Science']));
    final stored = await academics.ensureSubject(1, 'Maths');
    expect(stored.id, greaterThan(0));
    final again = await academics.ensureSubject(1, 'Maths');
    expect(again.id, stored.id);
  });

  test('mark totals default to 100 and persist per class|subject|term',
      () async {
    final term = await exams.ensureTerm('First Term');
    final subject = await academics.ensureSubject(1, 'Maths');
    expect(
        await exams.markTotal(
            classId: 1, subjectId: subject.id, termId: term.id),
        100);
    await exams.setMarkTotal(
        classId: 1, subjectId: subject.id, termId: term.id, total: 50);
    expect(
        await exams.markTotal(
            classId: 1, subjectId: subject.id, termId: term.id),
        50);
    expect(
        await exams.markTotal(
            classId: 2, subjectId: subject.id, termId: term.id),
        100);
  });

  test('saveMark auto-saves one mark and coalesces the sync queue',
      () async {
    final sid = await addStudent('Ahmed Saleem', 1);
    final term = await exams.ensureTerm('First Term');
    final subject = await academics.ensureSubject(1, 'Maths');
    await exams.saveMark(
      termId: term.id,
      classId: 1,
      subjectId: subject.id,
      studentId: sid,
      obtained: 42,
      total: 50,
    );
    await exams.saveMark(
      termId: term.id,
      classId: 1,
      subjectId: subject.id,
      studentId: sid,
      obtained: 45,
      total: 50,
    );
    final rows = await exams.marks(
        termId: term.id, classId: 1, subjectId: subject.id);
    expect(rows.length, 1);
    expect(rows.first['obtained_marks'], 45);
    expect(rows.first['total_marks'], 50);
    // Two auto-saves leave exactly ONE pending bulk op for the
    // combination (the second supersedes the first).
    final db = LocalDb.instance;
    final first = await db.db;
    final ops = await first.query('sync_queue',
        where: "entity = 'marks' AND op = 'bulk'");
    expect(ops.length, 1);
    final payload =
        jsonDecode(ops.first['payload_json'] as String) as Map;
    expect((payload['records'] as List).length, 1);
    expect((payload['records'] as List).first['obtained_marks'], 45);
  });
}
