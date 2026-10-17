import 'dart:convert';

import '../models/academics.dart';
import '../services/local_db.dart';
import '../services/sync_service.dart';

/// Offline-first academics repository. Same public API as before.
class AcademicsRepository {
  final _db = LocalDb.instance;
  final _sync = SyncService.instance;

  Future<List<ClassInfo>> classes() async {
    final rows = await _db.query('classes',
        where: 'deleted = 0', orderBy: 'level_order ASC');
    final out = <ClassInfo>[];
    for (final r in rows) {
      final cid = (r['id'] as num).toInt();
      final secs = await _db.query('sections',
          where: 'class_id = ? AND deleted = 0',
          whereArgs: [cid],
          orderBy: 'name ASC');
      final nStudents = await _db.count('students',
          where: 'class_id = ? AND status = ? AND deleted = 0',
          whereArgs: [cid, 'active']);
      final data = _rowJson(r);
      data['student_count'] = nStudents;
      data['sections'] = secs.map((s) => _rowJson(s)).toList();
      out.add(ClassInfo.fromJson(data));
    }
    return out;
  }

  Future<Section> createSection(int classId, String name) async {
    final data = {'id': 0, 'name': name, 'class_id': classId};
    final localId = await _db.insert('sections', {
      'class_id': classId,
      'name': name,
      'dirty': 1,
      'data': jsonEncode(data),
    });
    data['id'] = localId;
    await _db.updateById('sections', localId, {'data': jsonEncode(data)});
    await _db.enqueue('sections', 'create', localId,
        {'class_id': classId, 'name': name});
    await _sync.notifyDirty();
    return Section.fromJson(data);
  }

  Future<List<Subject>> subjects({int? classId}) async {
    final where = <String>['deleted = 0'];
    final args = <Object?>[];
    if (classId != null) {
      where.add('class_id = ?');
      args.add(classId);
    }
    final rows = await _db.query('subjects',
        where: where.join(' AND '), whereArgs: args, orderBy: 'name ASC');
    return rows.map((r) => Subject.fromJson(_rowJson(r))).toList();
  }

  Future<Subject> createSubject(int classId, String name) async {
    final data = <String, dynamic>{
      'id': 0,
      'class_id': classId,
      'name': name,
    };
    final localId = await _db.insert('subjects', {
      'class_id': classId,
      'name': name,
      'dirty': 1,
      'data': jsonEncode(data),
    });
    data['id'] = localId;
    await _db.updateById('subjects', localId, {'data': jsonEncode(data)});
    await _db.enqueue(
        'subjects', 'create', localId, {'class_id': classId, 'name': name});
    await _sync.notifyDirty();
    return Subject.fromJson(data);
  }

  Future<List<SyllabusTopic>> syllabus({int? classId, int? subjectId}) async {
    final where = <String>['deleted = 0'];
    final args = <Object?>[];
    if (classId != null) {
      where.add('class_id = ?');
      args.add(classId);
    }
    if (subjectId != null) {
      where.add('subject_id = ?');
      args.add(subjectId);
    }
    final rows = await _db.query('syllabus',
        where: where.join(' AND '), whereArgs: args);
    final out = <SyllabusTopic>[];
    for (final r in rows) {
      final data = _rowJson(r);
      data['subject_name'] =
          await _nameOf('subjects', LocalDb.intOf(r['subject_id']));
      out.add(SyllabusTopic.fromJson(data));
    }
    return out;
  }

  Future<SyllabusTopic> addSyllabusTopic(
      int classId, int subjectId, String topic) async {
    final data = <String, dynamic>{
      'id': 0,
      'class_id': classId,
      'subject_id': subjectId,
      'topic': topic,
      'status': 'planned',
    };
    final localId = await _db.insert('syllabus', {
      'class_id': classId,
      'subject_id': subjectId,
      'status': 'planned',
      'dirty': 1,
      'data': jsonEncode(data),
    });
    data['id'] = localId;
    await _db.updateById('syllabus', localId, {'data': jsonEncode(data)});
    await _db.enqueue('syllabus', 'create', localId, {
      'class_id': classId,
      'subject_id': subjectId,
      'topic': topic,
    });
    await _sync.notifyDirty();
    return SyllabusTopic.fromJson(data);
  }

  Future<void> updateSyllabusStatus(int id, String status) async {
    final row = await _db.getById('syllabus', id);
    if (row == null) throw Exception('Syllabus topic not found');
    final data = Map<String, dynamic>.from(_rowJson(row));
    data['status'] = status;
    await _db.updateById('syllabus', id, {
      'status': status,
      'dirty': 1,
      'data': jsonEncode(data),
    });
    await _db.enqueue('syllabus_status', 'action', id, {
      'local_id': id,
      'status': status,
    });
    await _sync.notifyDirty();
  }

  Future<List<TimetableEntry>> timetable(
      {int? classId, int? sectionId}) async {
    final where = <String>['deleted = 0'];
    final args = <Object?>[];
    if (classId != null) {
      where.add('class_id = ?');
      args.add(classId);
    }
    if (sectionId != null) {
      where.add('section_id = ?');
      args.add(sectionId);
    }
    final rows = await _db.query('timetable',
        where: where.join(' AND '),
        whereArgs: args,
        orderBy: 'day_of_week ASC');
    final out = <TimetableEntry>[];
    for (final r in rows) {
      final data = _rowJson(r);
      // server returns the subject name under 'subject'; accept both keys
      data['subject_name'] = data['subject_name'] ??
          data['subject'] ??
          await _nameOf('subjects', LocalDb.intOf(r['subject_id']));
      data['teacher_name'] =
          await _nameOf('staff', LocalDb.intOf(r['teacher_id']));
      out.add(TimetableEntry.fromJson(data));
    }
    return out;
  }

  /// Add a single timetable entry (server takes one entry per POST).
  Future<void> addTimetableEntry(Map<String, dynamic> body) async {
    final data = <String, dynamic>{
      'id': 0,
      'class_id': body['class_id'],
      'section_id': body['section_id'],
      'day_of_week': body['day_of_week'],
      'period_no': body['period_no'],
      'subject_id': body['subject_id'],
      'teacher_id': body['teacher_id'],
      'room': body['room']?.toString() ?? '',
    };
    final localId = await _db.insert('timetable', {
      'class_id': body['class_id'],
      'section_id': body['section_id'],
      'day_of_week': body['day_of_week'],
      'dirty': 1,
      'data': jsonEncode(data),
    });
    data['id'] = localId;
    await _db.updateById('timetable', localId, {'data': jsonEncode(data)});
    await _db.enqueue('timetable', 'create', localId, _plain(body));
    await _sync.notifyDirty();
  }

  // ------------------------------------------------------------ helpers

  Future<String> _nameOf(String table, int id) async {
    if (id == 0) return '';
    final r = await _db.getById(table, id);
    return r == null ? '' : LocalDb.strOf(r['name']);
  }

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
