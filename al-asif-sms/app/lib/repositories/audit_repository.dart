import '../models/audit.dart';
import '../services/local_db.dart';

/// Audit log reads come from the local audit_log table.
class AuditRepository {
  final _db = LocalDb.instance;

  Future<List<AuditEntry>> list({int limit = 200}) async {
    final rows = await _db.query('audit_log',
        orderBy: 'created_at DESC', limit: limit);
    return rows
        .map((r) => AuditEntry.fromJson({
              'id': r['id'],
              'user': r['username'],
              'action': r['action'],
              'entity': r['entity'],
              'entity_id': r['entity_id'],
              'created_at': r['created_at'],
            }))
        .toList();
  }
}
