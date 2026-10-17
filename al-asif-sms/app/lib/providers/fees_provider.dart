import 'package:flutter/foundation.dart';

import '../models/fee.dart';
import '../repositories/fees_repository.dart';

class FeesProvider extends ChangeNotifier {
  final _repo = FeesRepository();

  List<FeeHead> heads = [];
  List<Challan> challans = [];
  List<Defaulter> defaulters = [];
  List<Receipt> receipts = [];
  CollectionReport? report;
  bool loading = false;
  String? error;

  Future<void> loadHeads() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      heads = await _repo.heads();
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> createHead(Map<String, dynamic> body) async {
    await _repo.createHead(body);
    await loadHeads();
  }

  Future<int> generateChallans({
    required int classId,
    required int month,
    required int year,
    required List<int> headIds,
  }) =>
      _repo.generateChallans(
        classId: classId,
        month: month,
        year: year,
        headIds: headIds,
      );

  Future<void> loadChallans({
    int? studentId,
    int? month,
    int? year,
    String? status,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
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
    loading = false;
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
