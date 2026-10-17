class DashboardData {
  final int totalStudents;
  final int totalStaff;
  final double feeCollectedMonth;
  final double attendancePctToday;
  final int staffPresentToday;
  final double profitMonth;
  final int defaultersCount;

  const DashboardData({
    this.totalStudents = 0,
    this.totalStaff = 0,
    this.feeCollectedMonth = 0,
    this.attendancePctToday = 0,
    this.staffPresentToday = 0,
    this.profitMonth = 0,
    this.defaultersCount = 0,
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) => DashboardData(
        totalStudents: (j['total_students'] as num?)?.toInt() ?? 0,
        totalStaff: (j['total_staff'] as num?)?.toInt() ?? 0,
        feeCollectedMonth:
            (j['fee_collected_month'] as num?)?.toDouble() ?? 0,
        attendancePctToday:
            (j['attendance_pct_today'] as num?)?.toDouble() ?? 0,
        staffPresentToday: (j['staff_present_today'] as num?)?.toInt() ?? 0,
        profitMonth: (j['profit_month'] as num?)?.toDouble() ?? 0,
        defaultersCount: (j['defaulters_count'] as num?)?.toInt() ?? 0,
      );
}
