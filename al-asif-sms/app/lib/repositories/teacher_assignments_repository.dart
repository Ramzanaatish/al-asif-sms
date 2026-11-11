import 'dart:convert';

import '../config.dart';
import '../services/local_db.dart';

/// Teacher class/subject assignments (the HTML's S.teacherClass and
/// S.teacherSubject, managed in Settings → Teacher Assignments). There
/// is no server table for them, so they live in the meta table and are
/// local-only. The fixed class teachers in AppConfig.classTeachers are
/// always included as assignments.
class TeacherAssignmentsRepository {
  final _db = LocalDb.instance;

  static const _classKey = 'teacher_class_assignments';
  static const _subjectKey = 'teacher_subject_assignments';

  Future<List<Map<String, dynamic>>> _load(String key) async {
    final raw = await _db.getMeta(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List? ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(String key, List<Map<String, dynamic>> rows) async {
    await _db.setMeta(key, jsonEncode(rows));
  }

  /// Class ids assigned to [teacher]: the fixed class-teacher mapping
  /// plus any user-managed assignments.
  Future<List<int>> classesForTeacher(String teacher) async {
    final out = <int>{};
    AppConfig.classTeachers.forEach((className, t) {
      if (t == teacher) {
        final id = AppConfig.classNames.indexOf(className) + 1;
        if (id > 0) out.add(id);
      }
    });
    for (final row in await _load(_classKey)) {
      if (row['teacher'] == teacher) {
        final id = (row['class_id'] as num?)?.toInt();
        if (id != null) out.add(id);
      }
    }
    return out.toList()..sort();
  }

  /// Subject names assigned to [teacher] for [classId] (user-managed
  /// only; empty means "all subjects for the class").
  Future<List<String>> subjectsForTeacher(
      String teacher, int classId) async {
    final out = <String>[];
    for (final row in await _load(_subjectKey)) {
      if (row['teacher'] == teacher &&
          (row['class_id'] as num?)?.toInt() == classId) {
        final name = row['subject']?.toString() ?? '';
        if (name.isNotEmpty) out.add(name);
      }
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> classAssignments() =>
      _load(_classKey);

  Future<List<Map<String, dynamic>>> subjectAssignments() =>
      _load(_subjectKey);

  Future<void> setClassAssignments(
          List<Map<String, dynamic>> rows) =>
      _save(_classKey, rows);

  Future<void> setSubjectAssignments(
          List<Map<String, dynamic>> rows) =>
      _save(_subjectKey, rows);
}
