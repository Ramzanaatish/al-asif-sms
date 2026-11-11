import 'fee.dart';

/// One row of the HTML dashboard's "Class-wise Strength" donut legend:
/// class name, its teacher, how many active students, and the share of the
/// school (rounded, exactly like the HTML: Math.round(n / total * 100)).
class ClassStrength {
  final int classId;
  final String className;
  final String teacher;
  final int count;
  final int pct;

  const ClassStrength({
    required this.classId,
    required this.className,
    this.teacher = '',
    this.count = 0,
    this.pct = 0,
  });

  factory ClassStrength.fromJson(Map<String, dynamic> j) => ClassStrength(
        classId: (j['class_id'] as num?)?.toInt() ?? 0,
        className: j['class_name']?.toString() ?? '',
        teacher: j['teacher']?.toString() ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
        pct: (j['pct'] as num?)?.toInt() ?? 0,
      );
}

/// Dashboard numbers. The fields the HTML dashboard shows are the
/// "HTML" group below (8 stat cards, absent/leave name lists, the class
/// donut and the fee-heads table). The older fields (attendance %, staff
/// present, defaulters, profit) are still computed because Fees and
/// Reports read the same numbers; the dashboard screen itself no longer
/// shows them, exactly like the HTML.
class DashboardData {
  final int totalStudents;
  final int totalStaff;
  final double feeCollectedMonth;
  final double attendancePctToday;
  final int staffPresentToday;
  final double profitMonth;
  final int defaultersCount;

  /// HTML dashboard: the 8 stat cards.
  final int totalClasses;
  final int presentToday;
  final int absentToday;
  final int onLeaveToday;
  final double expensesMonth;

  /// HTML dashboard: "Absent Today" / "On Leave Today" name lists,
  /// each entry "Name (Class)".
  final List<String> absentNames;
  final List<String> leaveNames;

  /// HTML dashboard: "Class-wise Strength" donut (all classes, in
  /// level order, including zero-strength ones).
  final List<ClassStrength> classStrength;

  /// HTML dashboard: "Fee Heads" table.
  final List<FeeHead> feeHeads;

  const DashboardData({
    this.totalStudents = 0,
    this.totalStaff = 0,
    this.feeCollectedMonth = 0,
    this.attendancePctToday = 0,
    this.staffPresentToday = 0,
    this.profitMonth = 0,
    this.defaultersCount = 0,
    this.totalClasses = 0,
    this.presentToday = 0,
    this.absentToday = 0,
    this.onLeaveToday = 0,
    this.expensesMonth = 0,
    this.absentNames = const [],
    this.leaveNames = const [],
    this.classStrength = const [],
    this.feeHeads = const [],
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) => DashboardData(
        totalStudents: (j['total_students'] as num?)?.toInt() ?? 0,
        totalStaff: (j['total_staff'] as num?)?.toInt() ?? 0,
        feeCollectedMonth:
            (j['fee_collected_month'] as num?)?.toDouble() ?? 0,
        attendancePctToday:
            (j['attendance_pct_today'] as num?)?.toDouble() ?? 0,
        staffPresentToday:
            (j['staff_present_today'] as num?)?.toInt() ?? 0,
        profitMonth: (j['profit_month'] as num?)?.toDouble() ?? 0,
        defaultersCount: (j['defaulters_count'] as num?)?.toInt() ?? 0,
        totalClasses: (j['total_classes'] as num?)?.toInt() ?? 0,
        presentToday: (j['present_today'] as num?)?.toInt() ?? 0,
        absentToday: (j['absent_today'] as num?)?.toInt() ?? 0,
        onLeaveToday: (j['on_leave_today'] as num?)?.toInt() ?? 0,
        expensesMonth: (j['expenses_month'] as num?)?.toDouble() ?? 0,
        absentNames: (j['absent_names'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        leaveNames: (j['leave_names'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        classStrength: (j['class_strength'] as List?)
                ?.map((e) =>
                    ClassStrength.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
        feeHeads: (j['fee_heads'] as List?)
                ?.map((e) =>
                    FeeHead.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
      );
}
