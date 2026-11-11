import 'package:flutter/foundation.dart';

import '../models/academics.dart';
import '../models/exam.dart';
import '../models/student.dart';
import '../repositories/academics_repository.dart';
import '../repositories/exams_repository.dart';
import '../repositories/staff_repository.dart';
import '../repositories/student_repository.dart';
import '../repositories/teacher_assignments_repository.dart';

/// Provider for the Exams & Marks screen (HTML parity): grading scale +
/// subject-wise marks entry. Terms and subjects fall back to the HTML's
/// lists when the DB has none; saving a mark stores the chosen term /
/// subject so the marks table keeps real foreign keys.
class ExamsProvider extends ChangeNotifier {
  final _repo = ExamsRepository();
  final _academics = AcademicsRepository();
  final _students = StudentRepository();
  final _staff = StaffRepository();
  final _assignments = TeacherAssignmentsRepository();

  List<ClassInfo> classes = [];
  List<Student> students = [];
  List<Term> terms = [];
  List<Subject> subjects = [];
  List<String> teachers = [];
  Map<int, double> marks = {};
  int markTotal = 100;
  bool loading = false;
  String? error;

  Future<void> loadBase() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      classes = await _academics.classes();
      terms = await _repo.termsOrHtml();
      final staff = await _staff.list(staffType: 'teaching');
      teachers = staff.map((s) => s.name).toList();
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<Term> ensureTerm(String name) async {
    final term = await _repo.ensureTerm(name);
    terms = await _repo.termsOrHtml();
    notifyListeners();
    return term;
  }

  Future<Subject> ensureSubject(int classId, String name) async {
    final subject = await _academics.ensureSubject(classId, name);
    notifyListeners();
    return subject;
  }

  /// Subjects for [classId], filtered to the selected teacher's
  /// assignments when the teacher has any for this class.
  Future<List<Subject>> subjectsFor({
    required int classId,
    String? teacher,
  }) async {
    var list = await _academics.subjectsForClass(classId);
    if (teacher != null && teacher.isNotEmpty) {
      final mine = await _assignments.subjectsForTeacher(teacher, classId);
      if (mine.isNotEmpty) {
        list = list.where((s) => mine.contains(s.name)).toList();
      }
    }
    return list;
  }

  /// Classes visible to the selected teacher (all classes when no
  /// teacher is selected).
  Future<List<ClassInfo>> classesFor(String? teacher) async {
    if (teacher == null || teacher.isEmpty) return classes;
    final ids = await _assignments.classesForTeacher(teacher);
    return classes.where((c) => ids.contains(c.id)).toList();
  }

  Future<void> loadMarks({
    required int termId,
    required int classId,
    required int subjectId,
  }) async {
    try {
      students = await _students.list(classId: classId, status: 'active');
      final rows = await _repo.marks(
          termId: termId, classId: classId, subjectId: subjectId);
      marks = {
        for (final r in rows)
          (r['student_id'] as num).toInt():
              (r['obtained_marks'] as num?)?.toDouble() ?? 0,
      };
      markTotal = await _repo.markTotal(
          classId: classId, subjectId: subjectId, termId: termId);
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  /// Save one student's mark (auto-save). Resolves the term/subject
  /// names to stored rows first, so id-0 fallback entries become real.
  Future<void> saveMark({
    required String termName,
    required int classId,
    required String subjectName,
    required int studentId,
    required double obtained,
  }) async {
    final term = await _repo.ensureTerm(termName);
    final subject = await _academics.ensureSubject(classId, subjectName);
    final total = await _repo.markTotal(
        classId: classId, subjectId: subject.id, termId: term.id);
    await _repo.saveMark(
      termId: term.id,
      classId: classId,
      subjectId: subject.id,
      studentId: studentId,
      obtained: obtained,
      total: total.toDouble(),
    );
    marks[studentId] = obtained;
    // A newly stored term/subject changes the dropdowns' ids.
    terms = await _repo.termsOrHtml();
    notifyListeners();
  }

  Future<void> setMarkTotal({
    required int termId,
    required int classId,
    required int subjectId,
    required int total,
  }) async {
    await _repo.setMarkTotal(
        classId: classId, subjectId: subjectId, termId: termId, total: total);
    markTotal = total;
    notifyListeners();
  }
}
