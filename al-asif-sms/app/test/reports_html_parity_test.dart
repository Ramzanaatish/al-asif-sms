import 'dart:convert';
import 'dart:io';

import 'package:alasif_sms/models/student.dart';
import 'package:alasif_sms/printing/character_certificate.dart';
import 'package:alasif_sms/printing/student_result.dart';
import 'package:alasif_sms/repositories/attendance_repository.dart';
import 'package:alasif_sms/repositories/exams_repository.dart';
import 'package:alasif_sms/repositories/fees_repository.dart';
import 'package:alasif_sms/services/db_factory.dart';
import 'package:alasif_sms/services/local_db.dart';
import 'package:alasif_sms/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'temp_dir_helper.dart';

/// Guards the HTML-parity rule (v1.4.7): the Reports screen must behave
/// like the HTML (Complete v7) — 9-type generator (result / leaving /
/// character / benazir / attendance / collection / defaulter / P&L /
/// experience), the per-head Monthly Collection Report table, and the
/// Class Strength table.
void main() {
  late Directory tmp;
  late FeesRepository fees;
  late AttendanceRepository attendance;
  late ExamsRepository exams;

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
    tmp = await Directory.systemTemp.createTemp('alasif_reports_');
    initDatabaseFactory();
    LocalDb.testDatabasesDir = tmp.path;
    fees = FeesRepository();
    attendance = AttendanceRepository();
    exams = ExamsRepository();
    final db = LocalDb.instance;
    final first = await db.db;
    final headCount = Sqflite.firstIntValue(
            await first.rawQuery('SELECT COUNT(*) FROM fee_heads')) ??
        0;
    if (headCount == 0) {
      final stamp = DateTime.now().toIso8601String();
      final data = {
        'id': 0,
        'name': 'Monthly Tuition Fee',
        'amount': 800,
        'frequency': 'monthly',
      };
      final id = await first.insert('fee_heads', {
        'name': 'Monthly Tuition Fee',
        'dirty': 0,
        'data': jsonEncode(data),
        'updated_at': stamp,
      });
      data['id'] = id;
      await first.update('fee_heads', {'data': jsonEncode(data)},
          where: 'id = ?', whereArgs: [id]);
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

  test('allDefaulters lists only students with unpaid challans', () async {
    final s1 = await addStudent('Ahmed Saleem', 1);
    final s2 = await addStudent('Bilal Ahmed', 1);
    final heads = await fees.heads();
    final tuition =
        heads.firstWhere((h) => h.name == 'Monthly Tuition Fee');
    await fees.generateSingle(
        studentId: s1, month: 11, year: 2026, headIds: [tuition.id]);
    await fees.generateSingle(
        studentId: s2, month: 11, year: 2026, headIds: [tuition.id]);
    var list = await fees.allDefaulters();
    expect(list.length, 2);
    expect(list.first['due'], 800);
    final challans = await fees.challans(month: 11, year: 2026);
    await fees.markPaid(
        challans.firstWhere((c) => c.studentId == s1).id);
    list = await fees.allDefaulters();
    expect(list.length, 1);
    expect(list.first['student_id'], s2);
  });

  test('register returns per-day P/A/L cells for the class', () async {
    final s1 = await addStudent('Ahmed Saleem', 1);
    final s2 = await addStudent('Bilal Ahmed', 1);
    final db = LocalDb.instance;
    final first = await db.db;
    final stamp = DateTime.now().toIso8601String();
    Future<void> mark(int sid, String date, String status) async {
      await first.insert('student_attendance', {
        'date': date,
        'student_id': sid,
        'status': status,
        'dirty': 0,
        'data': jsonEncode({
          'date': date, 'student_id': sid, 'status': status,
        }),
        'updated_at': stamp,
      });
    }

    await mark(s1, '2026-11-02', 'present');
    await mark(s1, '2026-11-03', 'absent');
    await mark(s2, '2026-11-02', 'leave');
    final reg = await attendance.register(
        classId: 1, month: 11, year: 2026);
    expect(reg.daysInMonth, 30);
    expect(reg.totalDays, 2);
    expect(reg.students.length, 2);
    expect(reg.cells[s1]?[2], 'P');
    expect(reg.cells[s1]?[3], 'A');
    expect(reg.cells[s2]?[2], 'L');
    expect(reg.cells[s2]?[3], isNull);
  });

  test('result card math matches the HTML (total, %, grade, Pass)', () {
    final card = StudentResultPdf.fromMarks(
      studentName: 'Ahmed Saleem',
      fatherName: 'Muhammad Saleem',
      className: 'Play Group',
      admissionNo: 'AS-2026-0001',
      rollNo: '1',
      term: 'First Term',
      marks: const [
        (subject: 'English', total: 100, obtained: 80),
        (subject: 'Urdu', total: 100, obtained: 90),
        (subject: 'Maths', total: 100, obtained: null),
      ],
      date: '11 November 2026',
    );
    expect(card.totalMarks, 300);
    expect(card.obtainedMarks, 170);
    expect(card.pct, 57);
    expect(card.overallGrade, 'D');
    expect(card.result, 'Pass');
    expect(card.subjects[0].grade, 'A');
    expect(card.subjects[1].grade, 'A+');
    expect(card.subjects[2].grade, '-');
  });

  test('character certificate PDF builds', () async {
    final student = Student(
      id: 1,
      admissionNo: 'AS-2026-0001',
      name: 'Ahmed Saleem',
      className: 'Play Group',
      guardianName: 'Muhammad Saleem',
    );
    final bytes = await CharacterCertificatePdf.build(
      student: student,
      certificateNo: 'CC-AS-2026-0001',
      date: '11 November 2026',
    );
    expect(bytes.length, greaterThan(1000));
  });
}
