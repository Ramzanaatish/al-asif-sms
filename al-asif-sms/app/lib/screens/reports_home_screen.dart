import 'package:flutter/material.dart';

import '../config.dart';
import '../widgets/pro_cards.dart';
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
      _Item(
        'Fee Collection Report',
        'Month-wise fee collection summary',
        Icons.bar_chart,
        const CollectionReportScreen(),
      ),
      _Item(
        'Result Analytics',
        'Class-wise performance overview',
        Icons.analytics,
        const AnalyticsScreen(),
      ),
      _Item(
        'Attendance Report',
        'Monthly attendance register',
        Icons.table_chart,
        const AttendanceReportScreen(),
      ),
      _Item(
        'Monthly Result',
        'Monthly test result cards',
        Icons.assignment_turned_in,
        const MonthlyResultScreen(),
      ),
      _Item(
        'Annual Result',
        'Annual result cards & certificates',
        Icons.emoji_events,
        const AnnualResultScreen(),
      ),
    ];
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: tileColumns(context),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 76,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        return ReportTile(
          title: it.title,
          subtitle: it.subtitle,
          icon: it.icon,
          color: AppColors.navy,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => it.screen),
          ),
        );
      },
    );
  }
}

class _Item {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget screen;
  _Item(this.title, this.subtitle, this.icon, this.screen);
}
