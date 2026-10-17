import 'package:flutter/foundation.dart';

import '../models/academics.dart';
import '../repositories/academics_repository.dart';

class AcademicsProvider extends ChangeNotifier {
  final _repo = AcademicsRepository();

  List<ClassInfo> classes = [];
  List<Subject> subjects = [];
  List<SyllabusTopic> syllabus = [];
  List<TimetableEntry> timetable = [];
  bool loading = false;
  String? error;

  Future<void> loadClasses() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      classes = await _repo.classes();
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadSubjects({int? classId}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      subjects = await _repo.subjects(classId: classId);
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> addSubject(int classId, String name) async {
    await _repo.createSubject(classId, name);
    notifyListeners();
  }

  Future<void> loadSyllabus({int? classId, int? subjectId}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      syllabus = await _repo.syllabus(classId: classId, subjectId: subjectId);
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> addSyllabusTopic(
      int classId, int subjectId, String topic) async {
    await _repo.addSyllabusTopic(classId, subjectId, topic);
    notifyListeners();
  }

  Future<void> setSyllabusStatus(int id, String status) async {
    await _repo.updateSyllabusStatus(id, status);
    final i = syllabus.indexWhere((t) => t.id == id);
    if (i >= 0) {
      syllabus[i] = SyllabusTopic(
        id: syllabus[i].id,
        classId: syllabus[i].classId,
        subjectId: syllabus[i].subjectId,
        subjectName: syllabus[i].subjectName,
        topic: syllabus[i].topic,
        status: status,
      );
    }
    notifyListeners();
  }

  Future<void> loadTimetable({int? classId, int? sectionId}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      timetable =
          await _repo.timetable(classId: classId, sectionId: sectionId);
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> addTimetableEntry(Map<String, dynamic> body) async {
    await _repo.addTimetableEntry(body);
    notifyListeners();
  }
}
