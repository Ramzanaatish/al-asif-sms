import 'package:flutter/foundation.dart';

import '../models/audit.dart';
import '../repositories/audit_repository.dart';

class AuditProvider extends ChangeNotifier {
  final _repo = AuditRepository();

  List<AuditEntry> entries = [];
  bool loading = false;
  String? error;

  Future<void> load({int limit = 100}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      entries = await _repo.list(limit: limit);
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }
}
