import 'package:flutter/foundation.dart';

import '../models/exam.dart';
import '../repositories/exams_repository.dart';

class ExamsProvider extends ChangeNotifier {
  final _repo = ExamsRepository();

  List<Term> terms = [];
  List<DateSheetEntry> datesheets = [];
  ClassResult? monthlyResult;
  ClassResult? annualResult;
  ExamAnalytics? analytics;
  bool loading = false;
  String? error;

  Future<void> loadTerms() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      terms = await _repo.terms();
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> createTerm(Map<String, dynamic> body) async {
    await _repo.createTerm(body);
    await loadTerms();
  }

  Future<void> loadDatesheets({int? termId, int? classId}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      datesheets = await _repo.datesheets(termId: termId, classId: classId);
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> addDatesheetEntry(Map<String, dynamic> body) async {
    await _repo.addDatesheetEntry(body);
    notifyListeners();
  }

  Future<int> saveMarks(Map<String, dynamic> payload) =>
      _repo.saveMarks(payload);

  Future<void> loadMonthlyResult({int? termId, int? classId}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      monthlyResult =
          await _repo.monthlyResult(termId: termId, classId: classId);
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadAnnualResult({int? classId, int? sessionId}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      annualResult =
          await _repo.annualResult(classId: classId, sessionId: sessionId);
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadAnalytics({int? termId, int? classId}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      analytics = await _repo.analytics(termId: termId, classId: classId);
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }
}
