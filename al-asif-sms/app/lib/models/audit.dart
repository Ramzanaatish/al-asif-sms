class AuditEntry {
  final int id;
  final String user;
  final String action;
  final String entity;
  final String entityId;
  final String createdAt;

  const AuditEntry({
    required this.id,
    this.user = '',
    this.action = '',
    this.entity = '',
    this.entityId = '',
    this.createdAt = '',
  });

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        id: (j['id'] as num?)?.toInt() ?? 0,
        user: j['user']?.toString() ?? '',
        action: j['action']?.toString() ?? '',
        entity: j['entity']?.toString() ?? '',
        entityId: j['entity_id']?.toString() ?? '',
        createdAt: j['created_at']?.toString() ?? '',
      );
}
