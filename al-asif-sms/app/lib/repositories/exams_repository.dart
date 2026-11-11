import 'dart:convert';

import '../models/exam.dart';
import '../services/local_db.dart';
import '../services/sync_service.dart';

/// Offline-first exams repository. Same public API as before.
/// Result/analytics computation mirrors the backend (_result_rows/_grade).
class ExamsRepository {
  final _db = LocalDb.instance;
  final _sync = SyncService.instance;

  Future<List<Term>> terms() async {
    final rows =
        await _db.query('exam_terms', where: 'deleted = 0', orderBy: 'id ASC');
    return rows.map((r) => Term.fromJson(_rowJson(r))).toList();
  }

  Future<Term> createTerm(Map<String, dynamic> body) async {
    final data = <String, dynamic>{
      'id': 0,
      'name': body['name']?.toString() ?? '',
      'term_type': body['term_type']?.toString() ?? 'monthly',
      'session_id': body['session_id'],
      'start_date': body['start_date']?.toString(),
      'end_date': body['end_date']?.toString(),
    };
    final localId = await _db.insert('exam_terms', {
      'name': data['name'],
      'term_type': data['term_type'],
      'dirty': 1,
      'data': jsonEncode(data),
    });
    data['id'] = localId;
    await _db.updateById('exam_terms', localId, {'data': jsonEncode(data)});
    await _db.enqueue('exam_terms', 'create', localId, _plain(body));
    await _sync.notifyDirty();
    return Term.fromJson(data);
  }

  Future<List<DateSheetEntry>> datesheets({int? termId, int? classId}) async {
    final where = <String>['deleted = 0'];
    final args = <Object?>[];
    if (termId != null) {
      where.add('term_id = ?');
      args.add(termId);
    }
    if (classId != null) {
      where.add('class_id = ?');
      args.add(classId);
    }
    final rows = await _db.query('date_sheets',
        where: where.join(' AND '), whereArgs: args, orderBy: 'exam_date ASC');
    final out = <DateSheetEntry>[];
    for (final r in rows) {
      final data = _rowJson(r);
      data['subject'] = await _subjectName(LocalDb.intOf(r['subject_id']));
      data['class_name'] = await _className(LocalDb.intOf(r['class_id']));
      out.add(DateSheetEntry.fromJson(data));
    }
    return out;
  }

  Future<void> addDatesheetEntry(Map<String, dynamic> body) async {
    final data = <String, dynamic>{
      'id': 0,
      'term_id': body['term_id'],
      'class_id': body['class_id'],
      'subject_id': body['subject_id'],
      'exam_date': body['exam_date']?.toString(),
      'start_time': body['start_time']?.toString(),
    };
    final localId = await _db.insert('date_sheets', {
      'term_id': body['term_id'],
      'class_id': body['class_id'],
      'subject_id': body['subject_id'],
      'exam_date': data['exam_date'],
      'dirty': 1,
      'data': jsonEncode(data),
    });
    data['id'] = localId;
    await _db.updateById('date_sheets', localId, {'data': jsonEncode(data)});
    await _db.enqueue('date_sheets', 'create', localId, _plain(body));
    await _sync.notifyDirty();
  }

  // ------------------------------------------------------------ HTML terms
  // The HTML's five term names (Complete v7 marks entry). The terms
  // table is filled by sync; when it is empty the screen falls back to
  // these, and saving a mark creates the term row (like the HTML sync
  // client, which creates missing terms on the server).
  static const List<(String, String)> htmlTerms = [
    ('Monthly Test', 'monthly'),
    ('First Term', 'monthly'),
    ('Mid Term', 'monthly'),
    ('Final Term', 'monthly'),
    ('Annual', 'annual'),
  ];

  /// Terms from the DB when present, otherwise the HTML's five terms
  /// (id 0 = not yet stored; saving a mark stores the chosen one).
  Future<List<Term>> termsOrHtml() async {
    final dbTerms = await terms();
    if (dbTerms.isNotEmpty) return dbTerms;
    return [
      for (final (name, type) in htmlTerms)
        Term(id: 0, name: name, termType: type),
    ];
  }

  /// The Term row for [name] (by exact name), creating it when missing.
  /// Created rows are dirty, so they sync to the server as real terms.
  Future<Term> ensureTerm(String name) async {
    final existing = await terms();
    for (final t in existing) {
      if (t.name == name) return t;
    }
    final type = htmlTerms
        .where((t) => t.$1 == name)
        .firstOrNull
        ?.$2 ?? 'monthly';
    return createTerm({'name': name, 'term_type': type});
  }

  // ------------------------------------------------------------ mark totals
  // Per-class/subject/term total marks (the HTML's S.markTotals, keyed
  // "classId|subjectId|termId"). Default 100.
  static const _markTotalsKey = 'mark_totals';

  Future<int> markTotal({
    required int classId,
    required int subjectId,
    required int termId,
  }) async {
    final m = await _db.getMetaJson(_markTotalsKey);
    final v = m?['$classId|$subjectId|$termId'];
    return (v as num?)?.toInt() ?? 100;
  }

  Future<void> setMarkTotal({
    required int classId,
    required int subjectId,
    required int termId,
    required int total,
  }) async {
    final m = await _db.getMetaJson(_markTotalsKey) ?? {};
    m['$classId|$subjectId|$termId'] = total;
    await _db.setMetaJson(_markTotalsKey, m);
  }

  // ------------------------------------------------------------ single mark
  /// Save ONE student's mark (auto-save on change, like the HTML's
  /// setMark). The local row is upserted, then a single bulk sync op
  /// carrying ALL marks for this (term, class, subject) is enqueued —
  /// any pending op for the same combination is dropped first, so
  /// repeated auto-saves leave at most one queued op per combination
  /// instead of flooding the queue.
  Future<void> saveMark({
    required int termId,
    required int classId,
    required int subjectId,
    required int studentId,
    required double obtained,
    required double total,
  }) async {
    final existing = await _db.query('marks',
        where: 'term_id = ? AND subject_id = ? AND student_id = ? AND deleted = 0',
        whereArgs: [termId, subjectId, studentId],
        limit: 1);
    final data = {
      'term_id': termId,
      'class_id': classId,
      'subject_id': subjectId,
      'student_id': studentId,
      'total_marks': total,
      'obtained_marks': obtained,
    };
    if (existing.isEmpty) {
      await _db.insert('marks', {
        'term_id': termId,
        'class_id': classId,
        'subject_id': subjectId,
        'student_id': studentId,
        'dirty': 1,
        'data': jsonEncode(data),
      });
    } else {
      await _db.updateById('marks', (existing.first['id'] as num).toInt(), {
        'dirty': 1,
        'data': jsonEncode(data),
      });
    }
    // Coalesce: drop any pending bulk op for this combination, then
    // enqueue one carrying the full current record set.
    final pending = await _db.query('sync_queue',
        where: "entity = 'marks' AND op = 'bulk'");
    for (final op in pending) {
      try {
        final p = jsonDecode(LocalDb.strOf(op['payload_json']))
            as Map<String, dynamic>;
        if (p['term_id'] == termId &&
            p['class_id'] == classId &&
            p['subject_id'] == subjectId) {
          await _db.dequeue((op['id'] as num).toInt());
        }
      } catch (_) {
        // A malformed queued payload is left for the sync engine.
      }
    }
    final all = await marks(
        termId: termId, classId: classId, subjectId: subjectId);
    await _db.enqueue('marks', 'bulk', null, {
      'term_id': termId,
      'class_id': classId,
      'subject_id': subjectId,
      'total_marks': total,
      'records': all,
    });
    await _sync.notifyDirty();
  }

  /// Grade for [obtained] out of [total] (the HTML's gradePct): A+ 90+,
  /// A 80+, B 70+, C 60+, D 50+, E 40+, F below 40.
  static String gradeFor(double obtained, double total) {
    if (total <= 0) return '-';
    final pct = (obtained / total * 100).round();
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B';
    if (pct >= 60) return 'C';
    if (pct >= 50) return 'D';
    if (pct >= 40) return 'E';
    return 'F';
  }

  Future<int> saveMarks(Map<String, dynamic> payload) async {
    final termId = (payload['term_id'] as num).toInt();
    final classId = (payload['class_id'] as num).toInt();
    final subjectId = (payload['subject_id'] as num).toInt();
    final totalMarks = (payload['total_marks'] as num?)?.toDouble() ?? 0;
    final records = (payload['records'] as List? ?? [])
        .map((r) => (r as Map).cast<String, dynamic>())
        .toList();
    var saved = 0;
    for (final r in records) {
      final sid = (r['student_id'] as num?)?.toInt();
      if (sid == null) continue;
      final obtained = (r['obtained_marks'] as num?)?.toDouble() ?? 0;
      final existing = await _db.query('marks',
          where:
              'term_id = ? AND subject_id = ? AND student_id = ? AND deleted = 0',
          whereArgs: [termId, subjectId, sid],
          limit: 1);
      final data = {
        'term_id': termId,
        'class_id': classId,
        'subject_id': subjectId,
        'student_id': sid,
        'total_marks': totalMarks,
        'obtained_marks': obtained,
      };
      if (existing.isEmpty) {
        await _db.insert('marks', {
          'term_id': termId,
          'class_id': classId,
          'subject_id': subjectId,
          'student_id': sid,
          'dirty': 1,
          'data': jsonEncode(data),
        });
      } else {
        await _db.updateById('marks',
            (existing.first['id'] as num).toInt(), {
          'dirty': 1,
          'data': jsonEncode(data),
        });
      }
      saved++;
    }
    await _db.enqueue('marks', 'bulk', null, {
      'term_id': termId,
      'class_id': classId,
      'subject_id': subjectId,
      'total_marks': totalMarks,
      'records': records,
    });
    await _sync.notifyDirty();
    return saved;
  }

  Future<List<Map<String, dynamic>>> marks({
    int? termId,
    int? classId,
    int? subjectId,
  }) async {
    final where = <String>['deleted = 0'];
    final args = <Object?>[];
    if (termId != null) {
      where.add('term_id = ?');
      args.add(termId);
    }
    if (classId != null) {
      where.add('class_id = ?');
      args.add(classId);
    }
    if (subjectId != null) {
      where.add('subject_id = ?');
      args.add(subjectId);
    }
    final rows = await _db.query('marks',
        where: where.join(' AND '), whereArgs: args);
    return rows.map((r) {
      final d = LocalDb.dataOf(r);
      return {
        'student_id': r['student_id'],
        'obtained_marks': d['obtained_marks'],
        'total_marks': d['total_marks'],
      };
    }).toList();
  }

  Future<ClassResult> monthlyResult({int? termId, int? classId}) async {
    if (termId == null || classId == null) {
      return ClassResult.fromJson({'students': [], 'subjects': []});
    }
    final term = await _db.getById('exam_terms', termId);
    final rows = await _resultRows([termId], classId);
    return ClassResult.fromJson({
      'term': term == null ? '' : LocalDb.strOf(term['name']),
      'term_type': 'monthly',
      'class_name': await _className(classId),
      'subjects': rows['subjects'],
      'students': rows['rows'],
    });
  }

  Future<ClassResult> annualResult({int? classId, int? sessionId}) async {
    if (classId == null) {
      return ClassResult.fromJson({'students': [], 'subjects': []});
    }
    final terms = await _db.query('exam_terms',
        where: "term_type = 'annual' AND deleted = 0");
    final termIds =
        terms.map((t) => (t['id'] as num).toInt()).toList();
    if (termIds.isEmpty) throw Exception('No annual term found');
    final rows = await _resultRows(termIds, classId);
    return ClassResult.fromJson({
      'term_type': 'annual',
      'class_name': await _className(classId),
      'subjects': rows['subjects'],
      'students': rows['rows'],
    });
  }

  Future<ExamAnalytics> analytics({int? termId, int? classId}) async {
    if (termId == null || classId == null) {
      return ExamAnalytics.fromJson(
          {'subject_averages': [], 'pass_pct': 0, 'top_students': []});
    }
    final rows = await _resultRows([termId], classId);
    final students = rows['rows'] as List<Map<String, dynamic>>;
    final detail = rows['detail'] as Map<String, Map<String, double>>;
    final subjects = rows['subjects'] as List<String>;
    final avgs = <Map<String, dynamic>>[];
    for (final subj in subjects) {
      final pcts = <double>[];
      for (final r in students) {
        final d = detail['${r['student_id']}|$subj']!;
        if (d['total']! > 0) pcts.add(100 * d['obtained']! / d['total']!);
      }
      avgs.add({
        'subject': subj,
        'avg_pct': pcts.isEmpty
            ? 0
            : ((pcts.reduce((a, b) => a + b) / pcts.length * 10).round() / 10),
      });
    }
    final passed = students.where((r) => (r['pct'] as num) >= 33).length;
    return ExamAnalytics.fromJson({
      'subject_averages': avgs,
      'pass_pct': students.isEmpty ? 0 : 100 * passed / students.length,
      'top_students': students
          .take(5)
          .map((r) => {'name': r['name'], 'pct': r['pct']})
          .toList(),
    });
  }

  /// Mirrors backend _result_rows. NOTE: the backend returns
  /// marks[subject] = {obtained, total}, which the app's ResultStudent model
  /// cannot parse (it needs subject -> obtained double, as the result screens
  /// render). The local computation emits the model-compatible shape, which
  /// also fixes that latent online crash.
  Future<Map<String, dynamic>> _resultRows(
      List<int> termIds, int classId) async {
    final students = await _db.query('students',
        where: 'class_id = ? AND status = ? AND deleted = 0',
        whereArgs: [classId, 'active'],
        orderBy: 'name ASC');
    final subjects = await _db.query('subjects',
        where: 'class_id = ? AND deleted = 0', whereArgs: [classId]);
    final marksRows = await _db.query('marks',
        where: 'class_id = ? AND deleted = 0', whereArgs: [classId]);
    // per (student, subject): summed obtained/total across the term set
    final detail = <String, Map<String, double>>{};
    for (final s in students) {
      final sid = (s['id'] as num).toInt();
      for (final subj in subjects) {
        final subId = (subj['id'] as num).toInt();
        final subName = LocalDb.strOf(subj['name']);
        var om = 0.0, tm = 0.0;
        for (final mr in marksRows) {
          if (LocalDb.intOf(mr['student_id']) == sid &&
              LocalDb.intOf(mr['subject_id']) == subId &&
              termIds.contains(LocalDb.intOf(mr['term_id']))) {
            final d = LocalDb.dataOf(mr);
            om += (d['obtained_marks'] as num?)?.toDouble() ?? 0;
            tm += (d['total_marks'] as num?)?.toDouble() ?? 0;
          }
        }
        detail['$sid|$subName'] = {'obtained': om, 'total': tm};
      }
    }
    final rows = <Map<String, dynamic>>[];
    for (final s in students) {
      final sid = (s['id'] as num).toInt();
      final marks = <String, double>{};
      var total = 0.0, obtained = 0.0;
      for (final subj in subjects) {
        final subName = LocalDb.strOf(subj['name']);
        final d = detail['$sid|$subName']!;
        marks[subName] = d['obtained']!;
        obtained += d['obtained']!;
        total += d['total']!;
      }
      final pct = total > 0 ? (100 * obtained / total * 10).round() / 10 : 0.0;
      rows.add({
        'student_id': sid,
        'name': LocalDb.strOf(s['name']),
        'admission_no': LocalDb.strOf(s['admission_no']),
        'marks': marks,
        'total': total,
        'obtained': obtained,
        'pct': pct,
        'grade': _grade(pct),
      });
    }
    rows.sort((a, b) =>
        ((b['pct'] as num).toDouble()).compareTo((a['pct'] as num).toDouble()));
    for (var i = 0; i < rows.length; i++) {
      rows[i]['position'] = i + 1;
    }
    return {
      'rows': rows,
      'detail': detail,
      'subjects': subjects.map((s) => LocalDb.strOf(s['name'])).toList(),
    };
  }

  /// Backend-compatible grading (E >= 33). Note: the app's printed
  /// GradingScale uses E >= 40; result rows keep the backend scale so local
  /// and server results agree.
  String _grade(double pct) {
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B';
    if (pct >= 60) return 'C';
    if (pct >= 50) return 'D';
    if (pct >= 33) return 'E';
    return 'F';
  }

  // ------------------------------------------------------------ helpers

  Future<String> _subjectName(int id) async {
    final r = await _db.getById('subjects', id);
    return r == null ? '' : LocalDb.strOf(r['name']);
  }

  Future<String> _className(int id) async {
    final r = await _db.getById('classes', id);
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
