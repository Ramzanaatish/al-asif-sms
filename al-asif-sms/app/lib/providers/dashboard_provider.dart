import 'package:flutter/foundation.dart';

import '../models/dashboard.dart';
import '../repositories/dashboard_repository.dart';

class DashboardProvider extends ChangeNotifier {
  final _repo = DashboardRepository();

  DashboardData? data;
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      data = await _repo.principal();
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }
}
