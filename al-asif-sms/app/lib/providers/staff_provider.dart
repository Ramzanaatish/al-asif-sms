import 'package:flutter/foundation.dart';

import '../models/staff.dart';
import '../repositories/staff_repository.dart';

class StaffProvider extends ChangeNotifier {
  final _repo = StaffRepository();

  List<StaffMember> staff = [];
  List<StaffLeave> leaves = [];
  List<SalaryRecord> salaries = [];
  bool loading = false;
  String? error;

  Future<void> loadStaff({String? staffType, String? status}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      staff = await _repo.list(staffType: staffType, status: status);
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<StaffMember> detail(int id) => _repo.detail(id);

  Future<void> add(Map<String, dynamic> body) async {
    await _repo.create(body);
    notifyListeners();
  }

  Future<void> loadLeaves({String? status}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      leaves = await _repo.leaves(status: status);
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> decideLeave(int id, String decision) async {
    await _repo.decideLeave(id, decision);
    notifyListeners();
  }

  Future<void> loadSalaries({int? month, int? year}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      salaries = await _repo.salaries(month: month, year: year);
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<SalaryRecord> paySalary(Map<String, dynamic> body) async {
    final rec = await _repo.paySalary(body);
    notifyListeners();
    return rec;
  }
}
