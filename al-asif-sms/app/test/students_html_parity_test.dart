import 'dart:convert';
import 'dart:io';

import 'package:alasif_sms/repositories/student_repository.dart';
import 'package:alasif_sms/services/db_factory.dart';
import 'package:alasif_sms/services/local_db.dart';
import 'package:alasif_sms/services/urdu_transliterate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'temp_dir_helper.dart';

/// Guards the HTML-parity rule (v1.4.1): the Students screen must match
/// the HTML (Complete v7) Students table — Photo, Adm No, Name, Father,
/// B-Form, Contact, Class, Status — and the New Student form must carry
/// the HTML's fields (Urdu auto-fill, mother, group, New/Old admission,
/// B-Form, contact) with the roll number auto-assigned per class.
void main() {
  group('Urdu transliterator (ported from the HTML)', () {
    test('known names come from the dictionary', () {
      expect(transliterate('Ahmed'), 'احمد');
      expect(transliterate('Muhammad Saleem'), 'محمد سلیم');
      expect(transliterate('Fatima'), 'فاطمہ');
      expect(transliterate('Ayesha'), 'عائشہ');
    });

    test('unknown names use the rule engine, exactly like the HTML', () {
      // These are the HTML's own outputs (imperfect, but identical —
      // the app must auto-fill what the HTML auto-fills, not better).
      expect(transliterate('Saif-ur-Rahman'), 'سایف عر رحمان');
      expect(transliterate('Zoya'), 'زیہ');
    });

    test('empty and single-word inputs', () {
      expect(transliterate(''), '');
      expect(transliterate(null), '');
      expect(transliterate('Ali'), 'علی');
    });

    test('urduName prefers the stored value', () {
      expect(urduName('احمد', 'Ahmed'), 'احمد');
      expect(urduName('', 'Ahmed'), 'احمد');
      expect(urduName(null, 'Zoya'), 'زیہ');
    });
  });

  group('student repository — HTML fields', () {
    late Directory tmp;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tmp = await Directory.systemTemp.createTemp('alasif_stu_');
      initDatabaseFactory();
      LocalDb.testDatabasesDir = tmp.path;
    });

    tearDown(() async {
      await LocalDb.instance.close();
      await deleteTempDirQuietly(tmp);
    });

    Future<void> seedClass() async {
      final db = await LocalDb.instance.db;
      final count = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM classes')) ??
          0;
      if (count == 0) {
        await db.insert('classes', {
          'name': 'Play Group',
          'level_order': 1,
          'data': jsonEncode({'id': 0, 'name': 'Play Group'}),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }

    test('create stores the HTML fields and auto-assigns the roll', () async {
      await seedClass();
      final repo = StudentRepository();
      final first = await repo.create({
        'name': 'Ahmed Test',
        'name_urdu': 'احمد',
        'guardian_name': 'Muhammad Saleem',
        'father_urdu': 'محمد سلیم',
        'mother_name': 'Ayesha Bibi',
        'mother_name_urdu': 'عائشہ بی بی',
        'group_name': 'Science',
        'adm_status': 'New',
        'class_id': 1,
        'section_name': 'A',
        'b_form': '35202-1234567-1',
        'guardian_phone': '0300-1234567',
        'guardian_relation': 'Father',
      });
      expect(first.admissionNo, startsWith('AS-'));
      expect(first.rollNumber, 1);
      expect(first.nameUrdu, 'احمد');
      expect(first.guardianName, 'Muhammad Saleem');
      expect(first.fatherUrdu, 'محمد سلیم');
      expect(first.motherName, 'Ayesha Bibi');
      expect(first.motherNameUrdu, 'عائشہ بی بی');
      expect(first.groupName, 'Science');
      expect(first.admStatus, 'New');
      expect(first.sectionName, 'A');
      expect(first.bForm, '35202-1234567-1');
      expect(first.guardianPhone, '0300-1234567');

      // The second student in the same class gets roll 2.
      final second = await repo.create({
        'name': 'Fatima Test',
        'class_id': 1,
        'guardian_name': 'Ali Raza',
        'guardian_phone': '0301-7654321',
        'guardian_relation': 'Father',
      });
      expect(second.rollNumber, 2);
      expect(second.nameUrdu, '');
      expect(second.admStatus, 'New');

      // Edit (the HTML Edit button): the update merges the new fields.
      final updated = await repo.update(first.id, {
        'name': 'Ahmed Test',
        'name_urdu': 'احمد ٹیسٹ',
        'b_form': '35202-7654321-9',
        'adm_status': 'Old',
      });
      expect(updated.nameUrdu, 'احمد ٹیسٹ');
      expect(updated.bForm, '35202-7654321-9');
      expect(updated.admStatus, 'Old');
      // Unchanged fields survive the update.
      expect(updated.motherName, 'Ayesha Bibi');
      expect(updated.guardianName, 'Muhammad Saleem');

      // Delete (the HTML Delete button): the student leaves the list.
      await repo.deleteStudent(second.id);
      final remaining = await repo.list(status: 'all');
      expect(remaining.map((s) => s.id), contains(first.id));
      expect(remaining.map((s) => s.id), isNot(contains(second.id)));
    });

    test('the imported 217-student row reads back with the new fields',
        () async {
      // The performa CSV import writes the Flutter 14-column format with
      // a full data JSON; the new fields default safely when absent.
      await seedClass();
      final db = await LocalDb.instance.db;
      final stamp = DateTime.now().toIso8601String();
      await db.insert('students', {
        'admission_no': 'AS-2026-0001',
        'roll_number': 1,
        'name': 'Ahmed Saleem',
        'class_id': 1,
        'status': 'active',
        'data': jsonEncode({
          'id': 0,
          'name': 'Ahmed Saleem',
          'guardian_name': 'Muhammad Saleem',
          'guardian_phone': '03093771506',
          'class_id': 1,
          'class_name': 'Play Group',
        }),
        'dirty': 0,
        'deleted': 0,
        'provisional': 0,
        'updated_at': stamp,
      });
      final students = await StudentRepository().list(status: 'all');
      expect(students.length, 1);
      final s = students.first;
      expect(s.name, 'Ahmed Saleem');
      expect(s.guardianName, 'Muhammad Saleem');
      expect(s.bForm, '');
      expect(s.nameUrdu, '');
      expect(urduName(s.nameUrdu, s.name), 'احمد سلیم');
    });
  });
}
