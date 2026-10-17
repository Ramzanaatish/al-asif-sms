import 'package:flutter/material.dart';

import '../config.dart';
import 'attendance/attendance_report_screen.dart';
import 'exams/analytics_screen.dart';
import 'exams/annual_result_screen.dart';
import 'exams/monthly_result_screen.dart';
import 'fees/collection_report_screen.dart';

/// Tab hub: the school's printable/analytical reports in one place.
class ReportsHomeScreen extends StatelessWidget {
  const ReportsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _Item('Fee Collection Report', Icons.bar_chart,
          const CollectionReportScreen()),
      _Item('Result Analytics', Icons.analytics, const AnalyticsScreen()),
      _Item('Attendance Report', Icons.table_chart,
          const AttendanceReportScreen()),
      _Item('Monthly Result', Icons.assignment_turned_in,
          const MonthlyResultScreen()),
      _Item('Annual Result', Icons.emoji_events, const AnnualResultScreen()),
    ];
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: items
          .map((it) => Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => it.screen),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(it.icon, size: 44, color: AppColors.navy),
                      const SizedBox(height: 10),
                      Text(it.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _Item {
  final String title;
  final IconData icon;
  final Widget screen;
  _Item(this.title, this.icon, this.screen);
}
