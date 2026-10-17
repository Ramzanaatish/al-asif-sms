class Notice {
  final int id;
  final String title;
  final String body;
  final String audience; // all | parents | staff
  final String createdAt;
  final String createdBy;

  const Notice({
    required this.id,
    this.title = '',
    this.body = '',
    this.audience = 'all',
    this.createdAt = '',
    this.createdBy = '',
  });

  factory Notice.fromJson(Map<String, dynamic> j) => Notice(
        id: (j['id'] as num?)?.toInt() ?? 0,
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        audience: j['audience']?.toString() ?? 'all',
        createdAt: j['created_at']?.toString() ?? '',
        createdBy: j['created_by']?.toString() ?? '',
      );
}

class Complaint {
  final int id;
  final int? studentId;
  final String studentName;
  final String subject;
  final String body;
  final String status; // open | resolved
  final String createdAt;

  const Complaint({
    required this.id,
    this.studentId,
    this.studentName = '',
    this.subject = '',
    this.body = '',
    this.status = 'open',
    this.createdAt = '',
  });

  factory Complaint.fromJson(Map<String, dynamic> j) => Complaint(
        id: (j['id'] as num?)?.toInt() ?? 0,
        studentId: (j['student_id'] as num?)?.toInt(),
        studentName: j['student_name']?.toString() ?? '',
        subject: j['subject']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        status: j['status']?.toString() ?? 'open',
        createdAt: j['created_at']?.toString() ?? '',
      );
}

class ChildSummary {
  final int studentId;
  final String name;
  final String className;
  final double attendancePct;
  final double feeBalance;
  final double lastResultPct;

  const ChildSummary({
    required this.studentId,
    this.name = '',
    this.className = '',
    this.attendancePct = 0,
    this.feeBalance = 0,
    this.lastResultPct = 0,
  });

  factory ChildSummary.fromJson(Map<String, dynamic> j) => ChildSummary(
        studentId: (j['student_id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        className: j['class_name']?.toString() ?? '',
        attendancePct: (j['attendance_pct'] as num?)?.toDouble() ?? 0,
        feeBalance: (j['fee_balance'] as num?)?.toDouble() ?? 0,
        lastResultPct: (j['last_result_pct'] as num?)?.toDouble() ?? 0,
      );
}
