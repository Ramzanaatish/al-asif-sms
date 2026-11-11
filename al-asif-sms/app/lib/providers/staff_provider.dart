import 'package:flutter/foundation.dart';

import '../models/staff.dart';
import '../repositories/staff_repository.dart';

/// Provider for the Staff screen (HTML parity): table + Add Staff modal.
/// Leave requests and salaries stay in the repository (sync data layer);
/// the HTML Staff screen has no UI for them.
class StaffProvider extends ChangeNotifier {
  final _repo = StaffRepository();

  List<StaffMember> staff = [];
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

  Future<StaffMember> add(Map<String, dynamic> body) async {
    final member = await _repo.create(body);
    await loadStaff();
    return member;
  }

  Future<void> remove(int id) async {
    await _repo.remove(id);
    await loadStaff();
  }

  Future<StaffMember> detail(int id) => _repo.detail(id);
}
