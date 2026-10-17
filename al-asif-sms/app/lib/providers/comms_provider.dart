import 'package:flutter/foundation.dart';

import '../models/comms.dart';
import '../repositories/comms_repository.dart';

class CommsProvider extends ChangeNotifier {
  final _repo = CommsRepository();

  List<Notice> notices = [];
  List<Complaint> complaints = [];
  List<ChildSummary> children = [];
  bool loading = false;
  String? error;

  Future<void> loadNotices({String? audience}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      notices = await _repo.notices(audience: audience);
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> publishNotice(Map<String, dynamic> body) async {
    await _repo.publishNotice(body);
    await loadNotices();
  }

  Future<void> loadComplaints() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      complaints = await _repo.complaints();
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> fileComplaint(Map<String, dynamic> body) async {
    await _repo.fileComplaint(body);
    await loadComplaints();
  }

  Future<void> resolveComplaint(int id, String status) async {
    await _repo.resolveComplaint(id, status);
    await loadComplaints();
  }

  Future<void> loadParentSummary() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      children = await _repo.parentSummary();
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }
}
