import 'package:flutter/material.dart';

import 'screens/attendance/attendance_home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/exams/exams_home_screen.dart';
import 'screens/expenses/expense_list_screen.dart';
import 'screens/fees/fees_home_screen.dart';
import 'screens/reports_home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/staff/staff_list_screen.dart';
import 'screens/students/student_list_screen.dart';

/// One drawer entry.
class MenuEntry {
  final String title;
  final IconData icon;
  final Widget Function() builder;
  const MenuEntry(this.title, this.icon, this.builder);
}

/// Role -> visible screens. The menu matches the final HTML (Complete v7)
/// exactly: Dashboard, Students, Staff, Fees, Exams, Attendance, Expenses,
/// Reports, Settings — nothing else. Profit & Loss lives inside Reports
/// (as a tile), not as its own menu entry; attendance marking lives inside
/// the Attendance screen, not as a separate entry. There is no Academics,
/// Notices, Complaints, Audit Log, Salaries or parent menu: none of those
/// exist in the HTML.
List<MenuEntry> menuForRole(String role) {
  final dashboard = MenuEntry('Dashboard', Icons.dashboard,
      () => const PrincipalDashboardScreen());
  final students = MenuEntry('Students', Icons.people,
      () => const StudentListScreen());
  final staff = MenuEntry('Staff', Icons.badge,
      () => const StaffListScreen());
  final fees = MenuEntry('Fees', Icons.receipt_long,
      () => const FeesHomeScreen());
  final exams = MenuEntry('Exams', Icons.assignment,
      () => const ExamsHomeScreen());
  final attendance = MenuEntry('Attendance', Icons.fact_check,
      () => const AttendanceHomeScreen());
  final expenses = MenuEntry('Expenses', Icons.money_off,
      () => const ExpenseListScreen());
  final reports = MenuEntry('Reports', Icons.bar_chart,
      () => const ReportsHomeScreen());
  final settings = MenuEntry('Settings', Icons.settings,
      () => const SettingsScreen());

  switch (role) {
    case 'principal':
    case 'administrator':
      return [
        dashboard,
        students,
        staff,
        fees,
        exams,
        attendance,
        expenses,
        reports,
        settings,
      ];
    case 'teacher':
      // Teacher hides Fees, Expenses, Staff and Settings (same as the HTML).
      return [
        dashboard,
        MenuEntry('Students', Icons.people,
            () => const StudentListScreen(readOnly: true)),
        attendance,
        exams,
        reports,
      ];
    case 'accountant':
      return [
        fees,
        expenses,
        reports,
      ];
    default:
      return [];
  }
}
