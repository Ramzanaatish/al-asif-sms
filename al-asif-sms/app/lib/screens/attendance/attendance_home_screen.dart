import 'package:flutter/material.dart';

import '../../config.dart';
import 'attendance_report_screen.dart';
import 'mark_attendance_screen.dart';
import 'staff_attendance_screen.dart';

/// Tab hub for the Attendance module.
class AttendanceHomeScreen extends StatelessWidget {
  const AttendanceHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _Item('Mark Attendance', Icons.fact_check,
          const MarkAttendanceScreen(embedded: false)),
      _Item('Staff Attendance', Icons.badge,
          const StaffAttendanceScreen()),
      _Item('Monthly Report', Icons.table_chart,
          const AttendanceReportScreen()),
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
