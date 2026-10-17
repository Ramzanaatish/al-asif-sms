import 'package:flutter/foundation.dart';

import '../models/student.dart';
import '../repositories/student_repository.dart';

class StudentProvider extends ChangeNotifier {
  final _repo = StudentRepository();

  List<Student> students = [];
  bool loading = false;
  String? error;

  Future<void> load({
    int? classId,
    int? sectionId,
    String? status,
    String? search,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      students = await _repo.list(
        classId: classId,
        sectionId: sectionId,
        status: status,
        search: search,
      );
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<Student> detail(int id) => _repo.detail(id);

  Future<String> nextAdmissionNo() => _repo.nextAdmissionNo();

  Future<void> admit(Map<String, dynamic> body) async {
    await _repo.create(body);
    notifyListeners();
  }

  /// Returns the raw mark-left response (student + certificate).
  Future<Map<String, dynamic>> markLeft(
          int id, String leavingDate, String reason) =>
      _repo.markLeft(id, leavingDate, reason);

  Future<Map<String, dynamic>> promote({
    required int fromClassId,
    required int toClassId,
    required List<int> promotedIds,
    required List<int> retainedIds,
    required int sessionId,
  }) =>
      _repo.promote(
        fromClassId: fromClassId,
        toClassId: toClassId,
        promotedIds: promotedIds,
        retainedIds: retainedIds,
        sessionId: sessionId,
      );
}
