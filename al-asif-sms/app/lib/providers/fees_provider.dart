import 'package:flutter/foundation.dart';

import '../models/academics.dart';
import '../models/fee.dart';
import '../models/student.dart';
import '../repositories/academics_repository.dart';
import '../repositories/fees_repository.dart';
import '../repositories/student_repository.dart';

/// Provider for the single Fees screen (HTML parity): generate (single +
/// bulk), student charges, fee types, and the challans table. All data
/// loads from the local DB first; sync runs in the background.
class FeesProvider extends ChangeNotifier {
  final _repo = FeesRepository();
  final _students = StudentRepository();
  final _academics = AcademicsRepository();

  List<FeeHead> heads = [];
  List<StudentCharge> charges = [];
  List<Challan> challans = [];
  List<Student> students = [];
  List<ClassInfo> classes = [];
  Map<int, double> classFees = {};
  List<Defaulter> defaulters = [];
  List<Receipt> receipts = [];
  CollectionReport? report;

  /// Challans generated in this session (the HTML's lastBatch): powers
  /// the batch bar (Download CSV + Print challans).
  List<Challan> lastBatch = [];

  bool loading = false;
  String? error;

  Future<void> loadAll() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      heads = await _repo.heads();
      charges = await _repo.charges();
      classFees = await _repo.classFees();
      students = await _students.list(status: 'active');
      classes = await _academics.classes();
      await loadChallans();
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadHeads() async {
    heads = await _repo.heads();
    charges = await _repo.charges();
    classFees = await _repo.classFees();
    notifyListeners();
  }

  Future<void> createHead(Map<String, dynamic> body) async {
    await _repo.createHead(body);
    await loadHeads();
  }

  Future<void> deleteHead(int id) async {
    await _repo.deleteHead(id);
    await loadHeads();
  }

  Future<void> addCharge(StudentCharge charge) async {
    await _repo.addCharge(charge);
    await loadHeads();
  }

  Future<void> deleteCharge(String name) async {
    await _repo.deleteCharge(name);
    await loadHeads();
  }

  Future<void> setClassFee(int classId, double amount) async {
    await _repo.setClassFee(classId, amount);
    classFees = await _repo.classFees();
    notifyListeners();
  }

  Future<Challan> generateSingle({
    required int studentId,
    required int month,
    required int year,
    required List<int> headIds,
    List<String> chargeNames = const [],
  }) async {
    final challan = await _repo.generateSingle(
      studentId: studentId,
      month: month,
      year: year,
      headIds: headIds,
      chargeNames: chargeNames,
    );
    lastBatch = [challan];
    await loadChallans();
    return challan;
  }

  Future<({int created, int skipped})> generateBulk({
    int? classId,
    required int month,
    required int year,
    required List<int> headIds,
    List<String> chargeNames = const [],
  }) async {
    final res = await _repo.generateBulk(
      classId: classId,
      month: month,
      year: year,
      headIds: headIds,
      chargeNames: chargeNames,
    );
    if (res.created > 0) {
      // The batch is the challans just created for this month.
      final fresh = await _repo.challans(month: month, year: year);
      lastBatch = fresh
          .where((c) =>
              classId == null ||
              students
                      .where((s) => s.id == c.studentId)
                      .firstOrNull
                      ?.classId ==
                  classId)
          .toList();
    }
    await loadChallans();
    return res;
  }

  Future<Challan> generateCharge({
    required int studentId,
    required String chargeName,
    required int month,
    required int year,
  }) async {
    final challan = await _repo.generateSingle(
      studentId: studentId,
      month: month,
      year: year,
      headIds: const [],
      chargeNames: [chargeName],
    );
    lastBatch = [challan];
    await loadChallans();
    return challan;
  }

  Future<int> generateChallans({
    required int classId,
    required int month,
    required int year,
    required List<int> headIds,
  }) async {
    final res = await generateBulk(
        classId: classId, month: month, year: year, headIds: headIds);
    return res.created;
  }

  Future<void> loadChallans({
    int? studentId,
    int? month,
    int? year,
    String? status,
  }) async {
    try {
      challans = await _repo.challans(
        studentId: studentId,
        month: month,
        year: year,
        status: status,
      );
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<Receipt> collect(
    int challanId, {
    required double amount,
    double discount = 0,
    required String paymentMethod,
  }) =>
      _repo.collect(
        challanId,
        amount: amount,
        discount: discount,
        paymentMethod: paymentMethod,
      );

  /// The HTML's "Mark paid": full collect, so the server stays in sync.
  Future<Receipt> markPaid(int challanId) async {
    final receipt = await _repo.markPaid(challanId);
    await loadChallans();
    return receipt;
  }

  /// Remove duplicate challans; returns how many were removed.
  Future<int> dedupeChallans() async {
    final removed = await _repo.dedupeChallans();
    await loadChallans();
    return removed;
  }

  Future<List<ReceiptLine>> duesForStudent(int studentId) =>
      _repo.duesForStudent(studentId);

  Future<void> loadDefaulters({int? month, int? year}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      defaulters = await _repo.defaulters(month: month, year: year);
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadReport({int? month, int? year}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      report = await _repo.collectionReport(month: month, year: year);
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadReceipts({int? month, int? year, int? classId}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      receipts = await _repo.receipts(month: month, year: year, classId: classId);
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }
}
