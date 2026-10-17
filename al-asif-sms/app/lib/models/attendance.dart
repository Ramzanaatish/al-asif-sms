class AttendanceMark {
  final int studentId;
  final int? rollNumber;
  final String name;
  String status; // present | absent | leave
  String? leaveType; // sick | casual | urgent (when leave)

  AttendanceMark({
    required this.studentId,
    this.rollNumber,
    required this.name,
    this.status = 'present',
    this.leaveType,
  });
}

class MonthlyAttendanceRow {
  final int studentId;
  final String name;
  final int present;
  final int absent;
  final int leave;
  final double pct;
  final String feeStatus; // Paid | Partial | Not Paid

  const MonthlyAttendanceRow({
    required this.studentId,
    required this.name,
    this.present = 0,
    this.absent = 0,
    this.leave = 0,
    this.pct = 0,
    this.feeStatus = 'Not Paid',
  });

  factory MonthlyAttendanceRow.fromJson(Map<String, dynamic> j) =>
      MonthlyAttendanceRow(
        studentId: (j['student_id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        present: (j['present'] as num?)?.toInt() ?? 0,
        absent: (j['absent'] as num?)?.toInt() ?? 0,
        leave: (j['leave'] as num?)?.toInt() ?? 0,
        pct: (j['pct'] as num?)?.toDouble() ?? 0,
        feeStatus: j['fee_status']?.toString() ?? 'Not Paid',
      );
}

class MonthlyAttendanceReport {
  final int days;
  final List<MonthlyAttendanceRow> students;
  final List<HolidayInfo> holidays;

  const MonthlyAttendanceReport(
      {this.days = 0, this.students = const [], this.holidays = const []});

  factory MonthlyAttendanceReport.fromJson(Map<String, dynamic> j) {
    final list = (j['students'] as List?) ?? const [];
    final hols = (j['holidays'] as List?) ?? const [];
    return MonthlyAttendanceReport(
      days: (j['days'] as num?)?.toInt() ??
          (j['working_days'] as num?)?.toInt() ??
          0,
      students: list
          .map((s) =>
              MonthlyAttendanceRow.fromJson((s as Map).cast<String, dynamic>()))
          .toList(),
      holidays: hols
          .map((h) =>
              HolidayInfo.fromJson((h as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class HolidayInfo {
  final String date;
  final String kind; // unexpected|summer|winter|other
  final String description;

  const HolidayInfo({this.date = '', this.kind = 'unexpected', this.description = ''});

  factory HolidayInfo.fromJson(Map<String, dynamic> j) => HolidayInfo(
        date: j['date']?.toString() ?? '',
        kind: j['kind']?.toString() ?? 'unexpected',
        description: j['description']?.toString() ?? '',
      );

  String get kindLabel {
    switch (kind) {
      case 'summer':
        return 'Summer Vacation';
      case 'winter':
        return 'Winter Vacation';
      case 'other':
        return 'Holiday';
      default:
        return 'Unexpected Holiday';
    }
  }
}
