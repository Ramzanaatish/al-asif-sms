import 'dart:convert';
import 'dart:io';

import 'package:alasif_sms/models/dashboard.dart';
import 'package:alasif_sms/repositories/dashboard_repository.dart';
import 'package:alasif_sms/services/db_factory.dart';
import 'package:alasif_sms/services/local_db.dart';
import 'package:alasif_sms/widgets/class_donut.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'temp_dir_helper.dart';

/// Guards the HTML-parity rule (v1.4.0): the dashboard must show exactly
/// what the HTML (Complete v7) dashboard shows — the same 8 stat cards,
/// the Absent / On Leave name lists, the Class-wise Strength donut
/// (same colours, same "Class — Teacher · n (p%)" legend) and the
/// Fee Heads table. Numbers come from the local database, never from
/// hard-coded demo values.
void main() {
  test('dashboard numbers match the HTML dashboard', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tmp = await Directory.systemTemp.createTemp('alasif_dash_');
    try {
      initDatabaseFactory();
      LocalDb.testDatabasesDir = tmp.path;
      final db = LocalDb.instance;
      final first = await db.db;
      final now = DateTime.now();
      final today = now.toIso8601String().substring(0, 10);
      final stamp = now.toIso8601String();

      // The first open seeds 11 classes + 4 fee heads from assets/seed.json.
      // Insert them only if the seed did not run (asset load can be silent
      // in tests), so the counts never double.
      final classCount = Sqflite.firstIntValue(
              await first.rawQuery('SELECT COUNT(*) FROM classes')) ??
          0;
      if (classCount == 0) {
        const names = [
          'Play Group',
          'Nursery',
          'Prep',
          '1st',
          '2nd',
          '3rd',
          '4th',
          '5th',
          '6th',
          '7th',
          '8th'
        ];
        for (var i = 0; i < names.length; i++) {
          await first.insert('classes', {
            'name': names[i],
            'level_order': i + 1,
            'data': jsonEncode({'id': 0, 'name': names[i]}),
            'updated_at': stamp,
          });
        }
      }
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
        for (final h in heads) {
          await first.insert('fee_heads', {
            'name': h.$1,
            'class_id': null,
            'data': jsonEncode({
              'id': 0,
              'name': h.$1,
              'amount': h.$2,
              'frequency': h.$3,
            }),
            'updated_at': stamp,
          });
        }
      }

      // 5 active students: 2 Play Group, 1 Nursery, 2 in 1st.
      final studentIds = <int>[];
      final students = [
        ('Ahmed Test', 1),
        ('Fatima Test', 1),
        ('Bilal Test', 2),
        ('Ayesha Test', 4),
        ('Usman Test', 4),
      ];
      for (var i = 0; i < students.length; i++) {
        final id = await first.insert('students', {
          'server_id': null,
          'admission_no': 'T-${101 + i}',
          'roll_number': i + 1,
          'name': students[i].$1,
          'class_id': students[i].$2,
          'section_id': null,
          'session_id': null,
          'status': 'active',
          'data': jsonEncode({
            'id': 0,
            'name': students[i].$1,
            'class_id': students[i].$2,
          }),
          'dirty': 0,
          'deleted': 0,
          'provisional': 0,
          'updated_at': stamp,
        });
        studentIds.add(id);
      }

      // Today's attendance: 2 present, 1 absent (Fatima, Nursery),
      // 1 on leave (Bilal, 1st). Usman has no row.
      final attendance = [
        (studentIds[0], 'present'),
        (studentIds[1], 'absent'),
        (studentIds[2], 'leave'),
        (studentIds[3], 'present'),
      ];
      for (final a in attendance) {
        await first.insert('student_attendance', {
          'date': today,
          'student_id': a.$1,
          'status': a.$2,
          'data': jsonEncode({}),
          'updated_at': stamp,
        });
      }

      // One paid challan this month (Rs 800 collected) + one unpaid.
      await first.insert('fee_challans', {
        'challan_no': 'CH-T1',
        'student_id': studentIds[0],
        'month': now.month,
        'year': now.year,
        'status': 'paid',
        'data': jsonEncode({'amount_paid': 800.0}),
        'updated_at': stamp,
      });
      await first.insert('fee_challans', {
        'challan_no': 'CH-T2',
        'student_id': studentIds[1],
        'month': now.month,
        'year': now.year,
        'status': 'unpaid',
        'data': jsonEncode({'amount_paid': 0.0}),
        'updated_at': stamp,
      });

      // Rs 1,500 expense this month + Rs 9,999 last month (must not count).
      final thisMonth =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-05';
      final lastMonthDate = DateTime(now.year, now.month - 1, 5)
          .toIso8601String()
          .substring(0, 10);
      await first.insert('expenses', {
        'category_id': null,
        'date': thisMonth,
        'data': jsonEncode({'amount': 1500.0}),
        'updated_at': stamp,
      });
      await first.insert('expenses', {
        'category_id': null,
        'date': lastMonthDate,
        'data': jsonEncode({'amount': 9999.0}),
        'updated_at': stamp,
      });

      final d = await DashboardRepository().principal();

      expect(d.totalStudents, 5);
      expect(d.totalClasses, 11);
      expect(d.presentToday, 2);
      expect(d.absentToday, 1);
      expect(d.onLeaveToday, 1);
      expect(d.absentNames, ['Fatima Test (Play Group)']);
      expect(d.leaveNames, ['Bilal Test (Nursery)']);
      expect(d.feeCollectedMonth, 800.0);
      expect(d.expensesMonth, 1500.0);
      expect(d.defaultersCount, 1);
      expect(d.attendancePctToday, 50.0);

      expect(d.classStrength.length, 11);
      final play = d.classStrength.firstWhere((c) => c.classId == 1);
      expect(play.className, 'Play Group');
      expect(play.teacher, 'Miss Asia');
      expect(play.count, 2);
      expect(play.pct, 40);
      final nursery = d.classStrength.firstWhere((c) => c.classId == 2);
      expect(nursery.count, 1);
      expect(nursery.pct, 20);
      final firstClass = d.classStrength.firstWhere((c) => c.classId == 4);
      expect(firstClass.count, 2);
      expect(firstClass.pct, 40);
      final prep = d.classStrength.firstWhere((c) => c.classId == 3);
      expect(prep.count, 0);
      expect(prep.pct, 0);

      expect(d.feeHeads.length, 4);
      final tuition = d.feeHeads
          .firstWhere((h) => h.name == 'Monthly Tuition Fee');
      expect(tuition.amount, 800.0);
      expect(tuition.frequency, 'monthly');
    } finally {
      await LocalDb.instance.close();
      await deleteTempDirQuietly(tmp);
    }
  });

  testWidgets('class donut shows the HTML legend and total',
      (tester) async {
    const strength = [
      ClassStrength(
          classId: 1,
          className: 'Play Group',
          teacher: 'Miss Asia',
          count: 2,
          pct: 40),
      ClassStrength(
          classId: 2,
          className: 'Nursery',
          teacher: 'Miss Nadia Ali',
          count: 1,
          pct: 20),
      ClassStrength(
          classId: 3, className: 'Prep', teacher: 'Mrs. Mehwish Sharif',
          count: 2, pct: 40),
    ];
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: ClassDonut(strength: strength, total: 5),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Total Students'), findsOneWidget);
    // The legend is one RichText per row (spans split the string), so
    // the finder must look inside RichText, not plain Text widgets.
    expect(
        find.textContaining('Play Group — Miss Asia', findRichText: true),
        findsOneWidget);
    expect(
        find.textContaining('Nursery — Miss Nadia Ali', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('(40%)', findRichText: true), findsWidgets);
  });
}
